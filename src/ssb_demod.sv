module ssb_demod
(
    input wire signed [23:0]in_I,
    input wire signed [23:0]in_Q,
    output reg signed [23:0]ssb_out,
    input wire clk_44k,
    input wire clk_70M,

    input wire ssb_flip
);

localparam COMP_DELAY = 514;

reg [23:0]fifo[0:COMP_DELAY-1];

reg signed [23:0]fifo_out;
wire signed [23:0]hilbert_out;
reg signed [24:0]sum;

logic [23:0]fifo_in;
logic [23:0]hilbert_in;

always_comb
begin
    if(ssb_flip)
    begin
        fifo_in = in_Q;
        hilbert_in = in_I;
    end
    else
    begin
        fifo_in = in_I;
        hilbert_in = in_Q;
    end    
end

fir
#(
	.ORDER(1022),
	.IN_MSB(23),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(1),
	.ROM_FILE("src/fir_coeffs/fir_hilbert.txt"),
	.SAMP_SKIP(0)
)
inst_hilbert
(
	.clk_H(clk_70M),
	.samp_clk(clk_44k),
	.in_1(hilbert_in),
	.in_2(0),
    .out_1(hilbert_out),
	.out_2()
);

always @ (posedge clk_44k)
begin

    for(int i=1; i<COMP_DELAY; i++) fifo[i] <= fifo[i-1];
    fifo[0] <= fifo_in;
    fifo_out <= fifo[COMP_DELAY-1];

    sum <= hilbert_out + fifo_out;
    ssb_out <= sum[24:1];

end


endmodule