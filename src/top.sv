module top
(
	input wire clk_50M,
	
	input wire spi_sck,
	input wire spi_mosi,
	output wire spi_miso,
	input wire spi_cs,

	output wire sd_dac_out,

    input wire signed [13:0]adc_in,
    input wire adc_dry,

    output wire mcu_ss_clk,

    output wire spdif_out,

    output wire probe_1,
    output wire probe_2
);


typedef enum integer {MOD_LSB = 0, MOD_USB = 1, MOD_AM = 2} modulation_enum;


// ########################## MAIN CLOCK 70.56 MHz WITH STARTUP DELAY ##############################

wire clk_70M;              

reg [31:0]startup_delay;

always @ (posedge clk_50M)
begin
    if(startup_delay < 27000000) startup_delay <= startup_delay + 1;
end

assign clk_70M = (startup_delay == 27000000)? adc_dry : 0;




// ######################### SPI INTERFACE ###########################

wire [31:0]f0;
wire [1:0]modulation;
wire [1:0]bandwidth;
wire [5:0]volume_5bit;
wire [7:0]s_meter_value;

wire status_ovr;
wire status_sync_lock;

spi_interface inst_spi
(
    .spi_cs(spi_cs),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_sck(spi_sck),

    .f0_word_out(f0),
    .modulation_out(modulation),
    .bandwidth_out(bandwidth),
    .volume_out(volume_5bit),

    .s_meter_value_in(s_meter_value),
    .status_byte_in({6'b0, status_sync_lock, status_ovr})
);


// ############################# ADC OVR DETECTOR ##############################

wire [7:0]s_meter_value;

ovr_detector inst_ovr_detector
(
    .adc_in(adc_in),
    .ovr_out(status_ovr),
    .clk_70M(clk_70M)
);



// ############################ LO ###########################

wire [15:0]het_I;
wire [15:0]het_Q;

lo_mixer inst_lo
(
    .adc_in(adc_in),
    .f0(f0),
    .clk_70M(clk_70M),

    .I_out(het_I),
    .Q_out(het_Q)
);


// ##################### DOWNSAMPLER ###########################

wire clk_441k;
wire clk_44k;
wire [23:0]downsamp_I;
wire [23:0]downsamp_Q;

downsampler inst_downsampler
(
    .het_I_in(het_I),
    .het_Q_in(het_Q),
    .downsamp_I_out(downsamp_I),
    .downsamp_Q_out(downsamp_Q),
    .clk_70M(clk_70M),
    .clk_44k(clk_44k)
);


// ########################### FIR BW ##############################

wire signed [23:0]bw_I_out;
wire signed [23:0]bw_Q_out;

fir_3roms
#(
	.ORDER(1022),
	.IN_MSB(23),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(2),
	.ROM_FILE_0("src/fir_coeffs/fir_4k8.txt"),
    .ROM_FILE_1("src/fir_coeffs/fir_2k8.txt"),
    .ROM_FILE_2("src/fir_coeffs/fir_0k3.txt"),
	.SAMP_SKIP(0)
)
inst_fir_bw
(
	.clk_H(clk_70M),
	.samp_clk(clk_44k),
	.in_1(downsamp_I),
	.in_2(downsamp_Q),
    .out_1(bw_I_out),
	.out_2(bw_Q_out),
    .bw_in(bandwidth)
);



// ######################### SSB DEMOD #############################

wire [23:0]ssb_demod_out;

ssb_demod inst_ssb_demod
(
    .in_I(bw_I_out),
    .in_Q(bw_Q_out),
    .ssb_out(ssb_demod_out),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),

    .ssb_flip((modulation == 2'd0) ? 1'b1 : 1'b0)
);


// ####################### SYNC LO ######################


wire signed [23:0]sync_car_cos;
wire signed [23:0]sync_car_sin;


lo_sync inst_lo_sync
(
    .in_I(downsamp_I),
    .in_Q(downsamp_Q),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),
    .sync_car_cos(sync_car_cos),
    .sync_car_sin(sync_car_sin),
    .lock_out(status_sync_lock)
);

// ########################## SYNC AM DEMOD ##########################

wire signed [23:0]sync_am_out;

sync_am_demod inst_sync_am_demod
(
    .bb_I_in(bw_I_out),
    .bb_Q_in(bw_Q_out),
    .sync_car_cos_in(sync_car_cos),
    .sync_car_sin_in(sync_car_sin),
    .clk_44k(clk_44k),
    .sync_am_out(sync_am_out)
);


// ######################### MOD SWITCH ############################

reg [23:0]mod_switch_out;

always @ (posedge clk_44k)
begin
    if(modulation == MOD_AM) mod_switch_out <= sync_am_out;
    else mod_switch_out <= ssb_demod_out;
end


// ################################ S-METER AND AGC WITH AM SQUELCH ####################################

s_meter inst_s_meter
(
    .amplitude_in(mod_switch_out),
    .s_meter_out(s_meter_value),
    .clk_44k(clk_44k)
);

wire signed [23:0]agc_out;

agc inst_agc
(
    .audio_in(mod_switch_out),
    .audio_out(agc_out),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),
    .mode((modulation == MOD_AM) ? 1 : 0),
    .am_squelch(status_sync_lock)           // Good signal: 1
);


// ############################ AUDIO DC REMOVER #################################

wire [23:0]dc_remover_out;

dc_remover inst_dc_remover
(
    .in(agc_out),
    .out(dc_remover_out),
    .clk_44k(clk_44k)
);

// ############################ BASS BOOST ###############################

wire signed [23:0]bass_boost_out;

bass_booster inst_bass_boost
(
    .in(dc_remover_out),
    .out(bass_boost_out),
    .clk_44k(clk_44k)
);


// ########################### CLAMP, VOLUME CONTROL, SD DAC, SPDIF ##############################


wire signed [23:0]clamp_in;
reg signed [15:0]clamp_out;

assign clamp_in = /*dc_remover_out*/bass_boost_out;

always @ (posedge clk_44k)
begin
    if(clamp_in > 32000) clamp_out <= 32000;
    else
    if(clamp_in < -32000) clamp_out  <= -32000;
    else clamp_out <= clamp_in[15:0];
end

wire signed [15:0]volume_audio_out;

volume_control inst_volume
(
    .volume_5bit_in(volume_5bit),
    .audio_in(clamp_out),
    .audio_out(volume_audio_out),
    .clk_44k(clk_44k)
);


sd_dac_my inst_audio_dac
(
    .clk(clk_70M),
    .in(volume_audio_out),
    .out(sd_dac_out)
);

spdif_tx
#(
    .CLK_H(70.56)
)
inst_spdif
(
    .L_in(clamp_out),
    .R_in(clamp_out),
    .samp_clk_in(clk_44k),
    .clk_H(clk_70M),
    .spdif_out(spdif_out)
);




// ############################# MCU SS CLOCK ###############################

wire ss_clk_H;

mcu_ss_pll your_instance_name
(
    .clkout0(ss_clk_H),
    .clkin(clk_50M)
);

mcu_ss_generator inst_mcu_ss
(
    .clk_H(ss_clk_H),           // 200 MHz
    .ss_clk_out(mcu_ss_clk)       // 8 MHz + 1/32
);



endmodule