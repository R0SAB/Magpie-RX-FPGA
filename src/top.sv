module top
(
	input wire clk_27M,
	
	input wire spi_sck,
	input wire spi_mosi,
	output wire spi_miso,
	input wire spi_cs,

	output wire probe
);


wire clk_65M;

test_pll inst_pll
(
    .clkout(clk_65M),
    .clkin(clk_27M)
);


wire [31:0]f0;

spi_interface inst_spi
(
    .spi_cs(spi_cs),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_sck(spi_sck),

    .f0_word_out(f0),
    .s_meter_value_in
);


reg[31:0]ph_acc;

always @ (posedge clk_65M) ph_acc <= ph_acc + f0;
assign probe = ph_acc[31];



endmodule