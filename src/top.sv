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


reg [7:0]s_meter_test;
reg [31:0]div;

always @ (posedge clk_27M)
begin
    if(div < 8000000) div <= div + 1;
    else
    begin
        div <= 0;

        if(s_meter_test < 15) s_meter_test <= s_meter_test + 1;
        else s_meter_test <= 0;
    end
end




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


// ############################# OVR DETECTOR AND S-METER DELAY ##############################

wire [7:0]s_meter_value;

ovr_s_meter_mux inst_s_meter_mux
(
    .adc_in(adc_in),
    .s_meter_in(s_meter_value),
    .s_meter_out(s_meter_spi),
    .clk_70M(clk_70M)
);



// ############################ HETERODYNE ###########################

wire [15:0]het_I;
wire [15:0]het_Q;

heterodyne inst_heterodyne
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
    .bw_in(bandwidth),
    .clk_70M(clk_70M),
    .clk_44k(clk_44k)
);


// ########################### AM DEMOD ################################

wire [24:0]am_demod_out;

cordic_fullser_angmag
#(
    .STAGES(24),                       
    .ANG_MSB(23),                 
    .IN_MSB(23)                   
)
inst_and_demod
(
    .sin_in(downsamp_I + 45),
    .cos_in(downsamp_Q + 45),
    .ang_out(),
    .mag_out(am_demod_out),
    .samp_clk(clk_44k),
    .clk_H(clk_70M)
);


// ######################### SSB DEMOD #############################

wire [23:0]ssb_demod_out;

ssb_demod inst_ssb_demod
(
    .in_I(downsamp_I),
    .in_Q(downsamp_Q),
    .ssb_out(ssb_demod_out),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),

    .ssb_flip((modulation == 2'd0) ? 1'b1 : 1'b0)
);


// ######################### MOD SWITCH ############################

reg [23:0]mod_switch_out;

always @ (posedge clk_44k)
begin
    if(modulation == 2) mod_switch_out <= (am_demod_out >>> 1) - 110;
    else mod_switch_out <= ssb_demod_out;
end

// ########################## FIR CLEANUP #############################


wire [23:0]cleanup_out;


fir_3roms
#(
	.ORDER(150),
	.IN_MSB(23),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(2),
	.ROM_FILE_0("src/fir_coeffs/fir_cleanup_5k.txt"),
    .ROM_FILE_1("src/fir_coeffs/fir_cleanup_3k.txt"),
	.SAMP_SKIP(0)
)
inst_fir_cleanup
(
	.clk_H(clk_70M),
	.samp_clk(clk_44k),
	.in_1(mod_switch_out),
	.in_2(0),
    .out_1(cleanup_out),
	.out_2(),
    .bw_in((bandwidth == 2'd0) ? 2'd0 : 2'd1)
);


// ################################ S-METER AND AGC ####################################

s_meter inst_s_meter
(
    .amplitude_in(cleanup_out),
    .s_meter_out(s_meter_value),
    .clk_44k(clk_44k)
);

wire signed [23:0]agc_out;

agc inst_agc
(
    .audio_in(cleanup_out),
    .audio_out(agc_out),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M),
    .mode((modulation == 2'd2) ? 1 : 0)
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