module spi_interface        // MODE 3
(
    input wire spi_cs,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_sck,

    input wire clk_27M,

    output reg [31:0]f0_word_out,
    output wire [1:0]modulation_out,
    output wire [1:0]bandwidth_out,
    input wire [7:0]s_meter_value_in
);

reg [7:0]mode_ctrl;
reg [7:0]mode_ctrl_shreg;
reg [31:0]f0_shreg;
reg [7:0]s_meter_shreg;

assign modulation_out[1:0] = mode_ctrl[1:0];
assign bandwidth_out[1:0] = mode_ctrl[3:2];

always @ (posedge spi_sck)
begin
    if(~spi_cs)
    begin
        f0_shreg <= {f0_shreg[30:0], spi_mosi};
        mode_ctrl_shreg <= {mode_ctrl_shreg[6:0], f0_shreg[31]};
    end
end

always @ (posedge spi_cs)
begin
    f0_word_out <= f0_shreg;
    mode_ctrl <= mode_ctrl_shreg;
end

always @(negedge spi_sck or posedge spi_cs)
begin
    if (spi_cs) s_meter_shreg <= s_meter_value_in;
    else
    begin
        s_meter_shreg <= {s_meter_shreg[6:0], 1'b0};
        spi_miso <= s_meter_shreg[7];
    end
end

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