module downsampler
(
    input wire signed [15:0]het_I_in,
    input wire signed [15:0]het_Q_in,
    input wire clk_70M,

    output reg clk_441k,
    output reg clk_44k

);

// ###################### FREQ DIVIDERS #########################

reg [7:0]div_441k;
reg [7:0]div_44k;

always @ (posedge clk_70M)
begin
    if(div_441k < 159) div_441k <= div_441k + 1;
    else div_441k <= 0;
    
    if(div_441k == 0) clk_441k <= 1;
    else clk_441k <= 0;
end

always @ (posedge clk_441k)
begin
    if(div_44k < 9) div_44k <= div_44k + 1;
    else div_44k <= 0;
    
    if(div_44k == 0) clk_44k <= 1;
    else clk_44k <= 0;
end


// ########################### CIC #############################

wire signed [19:0]cic_I_out;
wire signed [19:0]cic_Q_out;

CIC_decim
#(
    .ORDER(3),
    .DELAY(320),
    .IN_MSB(15),
    .OUT_MSB(19)
)
inst_cic_I
( 
    .in(het_I_in),  
    .samp_clk_L(clk_441k),
    .samp_clk_H(clk_70M),				 
    .out(cic_I_out)
);


CIC_decim
#(
    .ORDER(3),
    .DELAY(320),
    .IN_MSB(15),
    .OUT_MSB(19)
)
inst_cic_Q
( 
    .in(het_Q_in),  
    .samp_clk_L(clk_441k),
    .samp_clk_H(clk_70M),				 
    .out(cic_Q_out)
);

// ########################## FIR DECIM #############################

wire signed [23:0]decim_I_out;
wire signed [23:0]decim_Q_out;

fir
#(
	.ORDER(150),
	.IN_MSB(19),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(4),
	.ROM_FILE("src/fir_coeffs/fir_decim.txt"),
	.SAMP_SKIP(0)
)
inst_fir_1
(
	.clk_H(clk_70M),
	.samp_clk(clk_441k),
	.in_1(cic_I_out),
	.in_2(cic_Q_out),
    .out_1(decim_I_out),
	.out_2(decim_Q_out)
);




endmodule