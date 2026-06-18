module spi_interface
(
    input wire spi_cs,
    input wire spi_mosi,
    output wire spi_miso,
    output wire spi_sck,

    input wire clk_27M,

    output reg [31:0]f0_word_out,
    input wire [7:0]s_meter_value_in
);


reg [31:0]f0_shreg;

always @ (posedge spi_sck)
begin
    if(~spi_cs) f0_shreg <= {f0_shreg[30:0], spi_mosi};
end

always @ (posedge spi_cs) f0_word <= f0_shreg;


endmodule

/*
spi_interface inst_spi
(
    .spi_cs(),
    .spi_mosi(),
    .spi_miso(),
    .spi_sck(),

    .f0_word_out,
    .s_meter_value_in
);
*/