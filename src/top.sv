module top
(
	input wire clk_27M,
	
	input wire spi_sck,
	input wire spi_mosi,
	output wire spi_miso,
	input wire spi_cs,

	output wire probe,

    output wire led_1,
    output wire led_2,
    output wire led_3,
    output wire led_4,
    output wire led_5,
    output wire led_6,

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

wire clk_220k;
wire clk_44k;

downsampler inst_downsampler
(
    .het_I_in(het_I),
    .het_Q_in(het_Q),
    .clk_70M(clk_70M),

    .clk_220k(),
    .clk_44k(clk_44k)
);


// ########################### TEST AM DEMOD ########################

wire [16:0]am_demod_out;
wire [15:0]downsamp_I;
wire [15:0]downsamp_Q;

assign downsamp_I = inst_downsampler.fir_2_I_out[15:0];
assign downsamp_Q = inst_downsampler.fir_2_Q_out[15:0];

cordic_fullser_angmag
#(
    .STAGES(16),                       
    .ANG_MSB(15),                 
    .IN_MSB(15)                   
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


// ########################### SD DAC ##############################

//wire signed [23:0]test_wire;
//assign test_wire = inst_downsampler.fir_2_I_out;

SD_DAC inst_test_dac
(
    .DACout(probe),
    .DACin(am_demod_out[15:0]),
    .Clk(clk_70M),
    .en(1)
);




endmodule