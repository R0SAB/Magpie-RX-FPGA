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
reg [7:0]s_meter_test;
reg [31:0]div;

always @ (posedge clk_27M)
begin
    if(div < 5400000) div <= div + 1;
    else
    begin
        div <= 0;

        if(s_meter_test < 15) s_meter_test <= s_meter_test + 1;
        else s_meter_test <= 0;
    end
end


spi_interface inst_spi
(
    .spi_cs(spi_cs),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_sck(spi_sck),

    .f0_word_out(f0),
    .s_meter_value_in(s_meter_test)
);


reg[31:0]ph_acc;

always @ (posedge clk_65M) ph_acc <= ph_acc + f0;
assign probe = ph_acc[31];



endmodule