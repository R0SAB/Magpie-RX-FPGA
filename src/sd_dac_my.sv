module sd_dac_my
(
    input wire signed [15:0]in,
    output wire out,
    input wire clk
);


localparam TAU_BITS = 8;

reg signed [15+TAU_BITS:0]itgr;
assign out = itgr[15+TAU_BITS];
wire signed [15:0]level;
assign level = out ? -30000 : 30000;


always @ (posedge clk)
begin

    itgr <= itgr + in - level;

end


endmodule