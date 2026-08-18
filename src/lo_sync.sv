module lo_sync
(
    input wire signed [23:0]phase_ref,
    input wire clk_44k,
    input wire clk_70M,
    output wire signed [23:0]sync_car_cos,
    output wire signed [23:0]sync_car_sin    
);


reg signed [31:0]ph_acc;
wire signed [23:0]phase_fb;             // Same as phase_ref
assign phase_fb[23:0] = ph_acc[31:8];

localparam TAU_BITS = 10;

wire signed [24:0]f0;       // By 7 bits smaller than ph_acc, giving approx 344 Hz p-p band at 44.1 ksps
reg signed [24+TAU_BITS:0]itgr;
assign f0 = itgr[24+TAU_BITS:TAU_BITS];

wire signed [23:0]phase_err;
assign phase_err = phase_ref - phase_fb;

wire unsigned [23:0]phase_cordic;
assign phase_cordic = {~phase_fb[23], phase_fb[22:0]};

always @ (posedge clk_44k)
begin

    ph_acc <= ph_acc + f0;

    itgr <= itgr + phase_err;


end


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