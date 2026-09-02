module bass_booster
(
    input wire signed [23:0]in,
    output reg signed [23:0]out,
    input wire clk_44k
);

localparam TAU_BITS = 5;

reg signed [23+TAU_BITS:0]itgr;
wire signed [23:0]itgr_out;
assign itgr_out = itgr >>> TAU_BITS;


always @ (posedge clk_44k)
begin 
    itgr <= itgr + in - itgr_out;
    out <= in + (itgr_out <<< 0);
end 


endmodule