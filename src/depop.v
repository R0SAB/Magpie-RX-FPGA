module depop
(
    input wire clk_44k,
    output wire signed [15:0]bias_out
);

reg signed [15:0]cnt;

always @ (posedge clk_44k)
begin 
    if(cnt < 32767) cnt <= cnt + 1;
end

assign bias_out = 16'd32767 - cnt;

endmodule