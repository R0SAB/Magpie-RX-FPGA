module top
(
	input wire clk_27M,
	
	input wire spi_sck,
	input wire spi_mosi,
	output wire spi_miso,
	input wire spi_cs,

	output wire sd_dac_out,

    input wire signed [13:0]adc_in,
    input wire adc_dry
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

spi_interface inst_spi
(
    .spi_cs(spi_cs),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_sck(spi_sck),

    .f0_word_out(f0),
    .modulation_out(modulation),
    .bandwidth_out(bandwidth),

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


// ########################### TEST AM DEMOD ########################

wire [18:0]am_demod_out;

cordic_fullser_angmag
#(
    .STAGES(18),                       
    .ANG_MSB(17),                 
    .IN_MSB(17)                   
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


wire [21:0]cleanup_out;


fir
#(
	.ORDER(150),
	.IN_MSB(17),
	.OUT_MSB(21),
	.TAPS_MSB(17),
	.GAIN_BITS(2),
	.ROM_FILE("src/fir_coeffs/fir_cleanup_5k.txt"),
	.SAMP_SKIP(0)
)
inst_fir_bw
(
	.clk_H(clk_70M),
	.samp_clk(clk_44k),
	.in_1(am_demod_out[17:0] + 100),
	.in_2(0),
    .out_1(cleanup_out),
	.out_2()
);



// ########################### SD DAC ##############################

//wire signed [23:0]test_wire;
//assign test_wire = inst_downsampler.fir_2_I_out;

SD_DAC inst_test_dac
(
    .DACout(sd_dac_out),
    .DACin(cleanup_out[15:0]),
    .Clk(clk_70M),
    .en(1)
);




endmodule