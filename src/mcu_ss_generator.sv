module mcu_ss_generator
(
    input wire clk_H,           // 199.8 MHz
    output reg ss_clk_out       // 8 MHz + 1/32
);

wire [19:0]f0;
assign f0 = 20'd42000;  // 2^20/199.8M*8M
reg [19:0]ph_acc;
reg [19:0]f;

reg [19:0]lfsr;
wire lfsr_fb;
assign lfsr_fb = (lfsr[19]^lfsr[2]) || ~|lfsr;

always @ (posedge clk_H)
begin

    lfsr <= {lfsr[18:0], lfsr_fb};

    f <= f0 + lfsr[12:0];
    ph_acc <= ph_acc - f;
    ss_clk_out <= ph_acc[19];

end


endmodule