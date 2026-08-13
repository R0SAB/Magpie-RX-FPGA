module mcu_ss_generator
(
    input wire clk_H,           // 199.8 MHz
    output reg ss_clk_out       // 8 MHz + 1/32
);

reg [8:0]f_sweep;      // 199.8 MHz/2^15 = 6.1 kHz
wire [19:0]f0;
assign f0 = 20'd42000;  // 2^20/125M*8M
reg [19:0]ph_acc;       // ~32x f_sweep
reg [19:0]f;

wire sweep_top;
wire sweep_bottom;
assign sweep_top = (&f_sweep) ? 1:0;
assign sweep_bottom = (~|f_sweep) ? 1:0;

reg dir;

always @ (posedge sweep_top or posedge sweep_bottom)
begin
    if(sweep_top) dir <= 0;
    else
    if(sweep_bottom) dir <= 1;
end

always @ (posedge ss_clk_out)
begin
    if(dir == 1) f_sweep <= f_sweep + 1;
    else f_sweep <= f_sweep - 1;
end

always @ (posedge clk_H)
begin

    

    f <= f0 + (f_sweep >> 2);
    ph_acc <= ph_acc - f;
    ss_clk_out <= ph_acc[19];

end


endmodule