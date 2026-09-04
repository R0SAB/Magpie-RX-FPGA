module spdif_tx
#(
parameter CLK_H = 90
)
(
input wire [15:0]L_in,
input wire [15:0]R_in,
input wire samp_clk_in,
input wire clk_H,
output reg spdif_out =0
);


reg [15:0]ph_acc = 0;
wire [14:0]f0 = 2**16/CLK_H*5.6448;

reg[1:0]ph_acc_eg = 0;

reg [5:0]sub_frame_div = 0;
reg [7:0]frame_div = 0;

wire [7:0]y = 8'b00011101;
wire [7:0]x = 8'b00011011;
wire [7:0]z = 8'b00010111;
reg [7:0]preamb = 0;

reg bit_clk = 0;
reg data = 0;

reg [27:0]shreg;

reg [1:0]samp_clk_in_eg = 0;

reg [15:0]L_buf = 0;
reg [15:0]R_buf = 0;

always @ (posedge clk_H)
begin

    samp_clk_in_eg <= samp_clk_in_eg << 1;
    samp_clk_in_eg[0] <= samp_clk_in;

    if(samp_clk_in_eg == 2'b01)
    begin
        ph_acc <= 16'd0;
        L_buf <= L_in;
        R_buf <= R_in;
    end
    else ph_acc <= ph_acc + f0;

    ph_acc_eg <= ph_acc_eg << 1;
    ph_acc_eg[0] <= ph_acc[15];

    if(ph_acc_eg == 2'b01)
    begin
        sub_frame_div <= sub_frame_div + 1;
        
        if(&sub_frame_div)
        begin
            if(frame_div < 8'd191) frame_div <= frame_div + 1'd1;
            else frame_div <= 8'd0;
            
            if(frame_div == 8'd191) preamb <= z;
            else
            if(frame_div[0]) preamb <= y;
            else
            preamb <= x;

            bit_clk <= 0;
        end
        else
        begin
            preamb <= preamb << 1;
            bit_clk <= ~bit_clk;
        end

    if(sub_frame_div < 8) spdif_out <= ~preamb[7];
    else spdif_out <= ~data;


    if(sub_frame_div == 0)
    begin
        if(frame_div == 0 || ~frame_div[0]) shreg <= {^{3'b000, L_buf, 8'b0000_0000}, 3'b000, L_buf, 8'b0000_0000};
        else shreg <= {^{3'b000, R_buf, 8'b0000_0000}, 3'b000, R_buf, 8'b0000_0000};
    end
    else
    if(bit_clk && sub_frame_div > 7) shreg <= shreg >> 1;

     if(sub_frame_div == 7) data <= 0;
     else
     if(bit_clk || shreg[0]) data <= ~data;

    end


end


endmodule
