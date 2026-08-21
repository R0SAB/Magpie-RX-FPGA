module lo_sync
(
    input wire signed [17:0]in_I,
    input wire signed [17:0]in_Q,
    input wire clk_44k,
    input wire clk_70M,
    output wire signed [23:0]sync_car_cos,
    output wire signed [23:0]sync_car_sin    
);


localparam FREQ_TAU_BITS = 12;
localparam PHASE_INJECT_BITS = 4;

wire signed [23:0]narrow_I;
wire signed [23:0]narrow_Q;
wire signed [23:0]phase_ref;

fir
#(
	.ORDER(510),
	.IN_MSB(17),
	.OUT_MSB(23),
	.TAPS_MSB(23),
	.GAIN_BITS(6),
	.ROM_FILE("src/fir_coeffs/fir_0k2_lpf_511.txt"),
	.SAMP_SKIP(0)
)
inst_fir_narrow
(
	.clk_H(clk_70M),
	.samp_clk(clk_44k),
	.in_1(in_I),
	.in_2(in_Q),
    .out_1(narrow_I),
	.out_2(narrow_Q)
);


cordic_fullser_angmag
#(
    .STAGES(24),                       
    .ANG_MSB(23),                 
    .IN_MSB(23)                   
)
inst_cordic_phase_ref
(
    .sin_in(narrow_I),
    .cos_in(narrow_Q),
    .ang_out(phase_ref),
    .mag_out(),
    .samp_clk(clk_44k),
    .clk_H(clk_70M)
);


reg signed [23:0]ph_acc;
wire signed [16:0]f0;                   // Band (p-p) is 44.1 kHz / (23-16) = 345 Hz
reg signed [1+16+FREQ_TAU_BITS:0]itgr;
assign f0 = itgr[16+FREQ_TAU_BITS:FREQ_TAU_BITS];

wire signed [23:0]phase_diff;
assign phase_diff = phase_ref - ph_acc;
reg signed [23:0]phase_diff_prev;
wire signed [23:0]freq_diff;
assign freq_diff = phase_diff - phase_diff_prev;

wire signed [1+16+FREQ_TAU_BITS:0]itgr_next;
assign itgr_next = itgr + freq_diff;

always @ (posedge clk_44k)
begin

    ph_acc <= ph_acc + f0 + (phase_diff >>> (24-PHASE_INJECT_BITS));

    if(itgr_next > (1 <<< (16+FREQ_TAU_BITS))) itgr <= (1 <<< (16+FREQ_TAU_BITS));
    else
    if(itgr_next < -(1 <<< (16+FREQ_TAU_BITS))) itgr <= -(1 <<< (16+FREQ_TAU_BITS));
    else
    itgr <= itgr_next;

    phase_diff_prev <= phase_diff;

end


wire unsigned [23:0]phase_cordic;
assign phase_cordic = {~ph_acc[23], ph_acc[22:0]};


cordic_fullser_sincos                           
#(
    .STAGES(24),                                  
    .PHASE_MSB(23),                               
    .OUT_MSB(23)                                  
)
inst_cordic_sync
(
    .phase_in(phase_cordic),                   
    .start_length(24'd4934475),     // 2^23 / 1.7            
    .samp_clk(clk_44k),
    .clk_H(clk_70M),
    .sin_out(sync_car_sin),
    .cos_out(sync_car_cos)
);



endmodule

