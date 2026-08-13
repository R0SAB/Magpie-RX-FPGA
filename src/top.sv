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

    .s_meter_value_in(s_meter_test)
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
    .sin_in(downsamp_Q),
    .cos_in(downsamp_I),
    .ang_out(),
    .mag_out(am_demod_out),
    .samp_clk(clk_44k),
    .clk_H(clk_70M)
);



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
	.in_1(am_demod_out[23:0]),
	.in_2(0),
    .out_1(cleanup_out),
	.out_2(),
    .bw_in((bandwidth == 2'd0) ? 2'd0 : 2'd1)
);


// ################################ AGC ####################################

wire signed [23:0]agc_out;

agc inst_agc
(
    .audio_in(cleanup_out),
    .audio_out(agc_out),
    .clk_44k(clk_44k),
    .clk_70M(clk_70M)
);


// ############################ DC REMOVER #################################

wire [23:0]dc_remover_out;

dc_remover inst_dc_remover
(
    .in(agc_out),
    .out(dc_remover_out),
    .clk_44k(clk_44k)
);



// ########################### VOLUME CONTROL AND SD DAC ##############################


wire signed [23:0]clamp_in;
reg signed [15:0]clamp_out;

assign clamp_in = dc_remover_out;

always @ (posedge clk_44k)
begin
    if(clamp_in > 32767) clamp_out <= 32767;
    else
    if(clamp_in < -32768) clamp_out  <= -32768;
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


SD_DAC inst_audio_dac
(
    .DACout(sd_dac_out),
    .DACin(volume_audio_out + 16'd32768),
    .Clk(clk_70M),
    .en(1)
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