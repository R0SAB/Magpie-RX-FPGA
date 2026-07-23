module heterodyne
(
    input wire signed [13:0]adc_in,
    input wire [31:0]f0,
    input wire clk_70M,

    output wire signed [15:0]I_out,
    output wire signed [15:0]Q_out
);

reg [31:0]f0_reg;
reg [31:0]ph_acc;
wire [15:0]phase;
assign phase[15:0] = ph_acc[31:16];
reg signed [13:0]adc_abs;
reg [15:0]cordic_phase;

always @ (posedge clk_70M)          // Phase accumulator; absolute value of ADC and phase for CORDIC
begin
    f0_reg <= f0;

    ph_acc <= ph_acc + f0_reg;

    if(adc_in < 0)
    begin
        adc_abs <= -adc_in;
        cordic_phase <= phase + (1 << 15);
    end
    else
    begin
        adc_abs <= adc_in;
        cordic_phase <= phase;
    end
end


cordic_pipeline_sincos              // CORDIC - both carrier generator and I/Q mixer
#(
.STAGES(16),                
.PHASE_MSB(15),             
.OUT_MSB(15)                
)
inst_cordic_f0
(
.phase_in(cordic_phase),                   
.start_length({adc_abs[13:0], 2'b00}),               
.clk_H(clk_70M),
.sin_out(Q_out),
.cos_out(I_out)
);




endmodule