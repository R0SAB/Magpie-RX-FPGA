module dc_remover
(
    input wire signed [23:0]in,
    output reg signed [23:0]out,
    input wire clk_44k
);

localparam TAU_BITS = 11;

reg signed [23+TAU_BITS:0]itgr;
wire signed [23:0]itgr_output;
assign itgr_output = itgr[23+TAU_BITS:TAU_BITS];


always @ (posedge clk_44k)
begin

    itgr <= itgr + in - itgr_output;
    out <= in - itgr_output;

end


endmodule