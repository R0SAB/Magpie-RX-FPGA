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


wire clk_65M;
assign clk_65M = adc_dry;


wire [31:0]f0;
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


reg[31:0]ph_acc;

always @ (posedge clk_65M) ph_acc <= ph_acc + f0;
assign probe = ph_acc[31];


assign led_1 = (modulation == 0) ? 0 : 1;
assign led_2 = (modulation == 1) ? 0 : 1;
assign led_3 = (modulation == 2) ? 0 : 1;
assign led_4 = (bandwidth  == 0) ? 0 : 1;
assign led_5 = (bandwidth  == 1) ? 0 : 1;
assign led_6 = (bandwidth  == 2) ? 0 : 1;


endmodule