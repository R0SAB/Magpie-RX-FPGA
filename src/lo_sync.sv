module lo_sync
(
    input wire signed [23:0]phase_ref,
    input wire clk_44k,
    input wire clk_70M,
    output wire signed [23:0]sync_car_cos,
    output wire signed [23:0]sync_car_sin    
);


localparam FREQ_TAU_BITS = 14;
localparam PHASE_INJECT_BITS = 3;


reg signed [23:0]ph_acc;
wire signed [16:0]f0;                   // Band (p-p) is 44.1 kHz / (23-16) = 345 Hz
reg signed [16+FREQ_TAU_BITS:0]itgr;
assign f0 = itgr[16+FREQ_TAU_BITS:FREQ_TAU_BITS];

wire signed [23:0]phase_diff;
assign phase_diff = phase_ref - ph_acc;
reg signed [23:0]phase_diff_prev;
wire signed [23:0]freq_diff;
assign freq_diff = phase_diff - phase_diff_prev;



always @ (posedge clk_44k)
begin

    ph_acc <= ph_acc + f0;

    itgr <= itgr + freq_diff + (phase_diff >>> (24-PHASE_INJECT_BITS));

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

