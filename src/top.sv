module top
(
	input wire clk_27M,
	
	input wire spi_sck,
	input wire spi_mosi,
	output wire spi_miso,
	input wire spi_cs,

	output wire sd_dac_out,

    input wire signed [13:0]adc_in,
    input wire adc_dry,

    output wire mcu_ss_clk
);


// ########################## MAIN CLOCK 70.56 MHz ##############################

wire clk_70M;              
//assign clk_70M = adc_dry;

reg [31:0]startup_delay;

always @ (posedge clk_27M)
begin
    if(startup_delay < 27000000) startup_delay <= startup_delay + 1;
end

assign clk_70M = (startup_delay == 27000000)? adc_dry : 0;




// ######################### SPI INTERFACE ###########################

wire [31:0]f0;
wire [1:0]modulation;
wire [1:0]bandwidth;
wire [5:0]volume_5bit;
wire [7:0]s_meter_spi;

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

    .s_meter_value_in(s_meter_spi)
);


// ############################# OVR DETECTOR AND S-METER MUX ##############################

wire [7:0]s_meter_value;

ovr_s_meter_mux inst_s_meter_mux
(
    .adc_in(adc_in),
    .s_meter_in(s_meter_value),
    .s_meter_out(s_meter_spi),
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
wire [17:0]downsamp_I;
wire [17:0]downsamp_Q;

downsampler inst_downsampler
(
    .het_I_in(het_I),
    .het_Q_in(het_Q),
    .downsamp_I_out(downsamp_I),
    .downsamp_Q_out(downsamp_Q),
    .clk_70M(clk_70M),
    .clk_44k(clk_44k)
);


// ####################### SYNC CARRIER GEN ######################


wire signed [23:0]sync_car_cos;
wire signed [23:0]sync_car_sin;


lo_sync inst_lo_sync
(
    .in_I(downsamp_I),
    .in_Q(downsamp_Q),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),
    .sync_car_cos(sync_car_cos),
    .sync_car_sin(sync_car_sin)    
);


// ########################### FIR BW ##############################

wire signed [23:0]bw_I_out;
wire signed [23:0]bw_Q_out;

fir_3roms
#(
	.ORDER(1022),
	.IN_MSB(17),
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
    .bw_in(bw_in)
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

// ########################## SYNC AM DEMOD ##########################

reg signed [23:0]delay[0:255];
reg signed [23:0]delay_out;
reg signed [23:0]sync_I;
reg signed [46:0]sync_mult_I;
reg signed [23:0]sync_Q;
reg signed [46:0]sync_mult_Q;
reg signed [24:0]sync_sum;
reg signed [23:0]sync_am_out;

always @ (posedge clk_44k)
begin

    //delay_out <= delay[255];
    //for(int i=1; i<256; i++) delay[i] <= delay[i-1];
    //delay[0] <= ssb_demod_out;

    sync_mult_I <= bw_I_out * sync_car_sin;
    sync_mult_Q <= bw_Q_out * sync_car_cos;

    sync_I <= sync_mult_I[46:23];
    sync_Q <= sync_mult_Q[46:23];

    sync_sum <= sync_I + sync_Q;
    sync_am_out <= sync_sum[23:0];

end


// ######################### MOD SWITCH ############################

reg [23:0]mod_switch_out;

always @ (posedge clk_44k)
begin
    //if(modulation == 2) mod_switch_out <= (am_demod_out >>> 1) - 110;
    if(modulation == 2) mod_switch_out <= sync_am_out;
    else mod_switch_out <= ssb_demod_out;
end


// ################################ S-METER AND AGC ####################################

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
    .mode(/*(modulation == 2'd2) ? 1 : 0*/ 0)
);


// ############################ AUDIO DC REMOVER #################################

wire [23:0]dc_remover_out;

dc_remover inst_dc_remover
(
    .in(agc_out),
    .out(dc_remover_out),
    .clk_44k(clk_44k)
);


// ########################### CLAMP, VOLUME CONTROL AND SD DAC ##############################


wire signed [23:0]clamp_in;
reg signed [15:0]clamp_out;

assign clamp_in = dc_remover_out;

always @ (posedge clk_44k)
begin
    if(clamp_in > 30000) clamp_out <= 30000;
    else
    if(clamp_in < -30000) clamp_out  <= -30000;
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
    .in(volume_audio_out - 1001),
    .out(sd_dac_out)
);



// ############################# MCU SS CLOCK ###############################

wire ss_clk_H;

Gowin_rPLL inst_ss_pll          // 199.8 MHz
(
        .clkout(ss_clk_H),
        .clkin(clk_27M)
);

mcu_ss_generator inst_mcu_ss
(
    .clk_H(ss_clk_H),           // 199.8 MHz
    .ss_clk_out(mcu_ss_clk)       // 8 MHz + 1/32
);



endmodule