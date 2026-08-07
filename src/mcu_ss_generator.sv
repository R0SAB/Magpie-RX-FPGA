module mcu_ss_generator
(
    input wire clk_H,           // 125 MHz
    output reg ss_clk_out       // 8 MHz + 1/32
);

reg [12:0]f_sweep;      // 125 MHz/2^11 = 15.25 kHz
wire [19:0]f0;
assign f0 = 20'd72000;  // 2^20/125M*8M
reg [19:0]ph_acc;       // ~32x f_sweep
reg [19:0]f;

wire sweep_top;
wire sweep_bottom;
assign sweep_top = (f_sweep == 13'b1_1111_1111_1111) ? 1:0;
assign sweep_bottom = (f_sweep == 13'b0) ? 1:0;

reg dir;

always @ (posedge sweep_top or posedge sweep_bottom)
begin
    if(sweep_top) dir <= 0;
    else
    if(sweep_bottom) dir <= 1;
end

always @ (posedge clk_H)
begin

    if(dir == 1) f_sweep <= f_sweep + 1;
    else f_sweep <= f_sweep - 1;
    
    f <= f0 + (f_sweep);
    ph_acc <= ph_acc + f;
    ss_clk_out <= ph_acc[19];

end


endmodule