module downsampler
(
    input wire signed [14:0]het_I_in,
    input wire signed [14:0]het_Q_in,
    input wire clk_70M,

    output reg clk_882k,
    output reg clk_220k,
    output reg clk_44k

);

// ###################### FREQ DIVIDERS #########################

reg [7:0]div_882k;
reg [7:0]div_220k;
reg [7:0]div_44k;

always @ (posedge clk_70M)
begin
    if(div_882k < 79) div_882k <= div_882k + 1;
    else div_882k <= 0;
    
    if(div_882k == 0) clk_882k <= 1;
    else clk_882k <= 0;
end

always @ (posedge clk_882k)
begin
    if(div_220k < 3) div_220k <= div_220k + 1;
    else div_220k <= 0;
    
    if(div_220k == 0) clk_220k <= 1;
    else clk_220k <= 0;
end

always @ (posedge clk_220k)
begin
    if(div_44k < 5) div_44k <= div_44k + 1;
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
    .DELAY(160),
    .IN_MSB(14),
    .OUT_MSB(19)
)
inst_cic_I
( 
    .in(het_I_in),  
    .samp_clk_L(clk_882k),
    .samp_clk_H(clk_70M),				 
    .out(cic_I_out)
);


CIC_decim
#(
    .ORDER(3),
    .DELAY(160),
    .IN_MSB(14),
    .OUT_MSB(19)
)
inst_cic_Q
( 
    .in(het_Q_in),  
    .samp_clk_L(clk_882k),
    .samp_clk_H(clk_70M),				 
    .out(cic_Q_out)
);

// ########################## FIR 1 #############################

wire signed [21:0]fir_1_I_out;
wire signed [21:0]fir_1_Q_out;

fir
#(
	.ORDER(70),
	.IN_MSB(19),
	.OUT_MSB(21),
	.TAPS_MSB(23),
	.GAIN_BITS(4),
	.ROM_FILE("src/fir_coeffs/decim_fir1.txt"),
	.SAMP_SKIP(0)
)
inst_fir_1
(
	.clk_H(clk_70M),
	.samp_clk(clk_882k),
	.in_1(cic_I_out),
	.in_2(cic_Q_out),
    .out_1(fir_1_I_out),
	.out_2(fir_1_Q_out)
);



// ########################## FIR 1 #############################

wire signed [23:0]fir_2_I_out;
wire signed [23:0]fir_2_Q_out;

fir
#(
	.ORDER(300),
	.IN_MSB(21),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(4),
	.ROM_FILE("src/fir_coeffs/decim_fir2.txt"),
	.SAMP_SKIP(0)
)
inst_fir_2
(
	.clk_H(clk_70M),
	.samp_clk(clk_220k),
	.in_1(fir_1_I_out),
	.in_2(fir_1_Q_out),
    .out_1(fir_2_I_out),
	.out_2(fir_2_Q_out)
);


endmodule