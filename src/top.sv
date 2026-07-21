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



wire clk_70M;              // ########### MAIN CLOCK 70.56 MHz ###############
assign clk_70M = adc_dry;


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

wire [14:0]het_I;
wire [14:0]het_Q;

heterodyne inst_heterodyne
(
    .adc_in(adc_in),
    .f0(f0),
    .clk_70M(clk_70M),

    .I_out(het_I),
    .Q_out(het_Q)
);


// ########################### SD DAC ##############################

SD_DAC inst_test_dac
(
    .DACout(probe),
    .DACin({het_I, 1'b0} + (1 << 15)),
    .Clk(clk_70M),
    .en(1)
);

endmodule