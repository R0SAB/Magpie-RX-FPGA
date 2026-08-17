module s_meter
(
    input wire signed [23:0]amplitude_in,
    output reg [7:0]s_meter_out,
    input wire clk_44k
);

reg signed [23:0]detector;
reg signed [35:0]itgr;
wire signed [23:0]itgr_out;
assign itgr_out = itgr[35:12];

wire [15:0]s_mask;
localparam S_SHIFT = 5;
assign s_mask = itgr_out[15+S_SHIFT:0+S_SHIFT];


always @ (posedge clk_44k)
begin

    if(amplitude_in[23]) detector <= -amplitude_in;
    else detector <= amplitude_in;

    itgr <= itgr + detector - itgr_out;

    if(itgr > (1<<<(15+12+S_SHIFT+1))) itgr <= (1<<<(15+12+S_SHIFT+1));

    casex(s_mask)
        16'b0000000000000001: s_meter_out <= 0;
        16'b000000000000001x: s_meter_out <= 1;
        16'b00000000000001xx: s_meter_out <= 2;
        16'b0000000000001xxx: s_meter_out <= 3;
        16'b000000000001xxxx: s_meter_out <= 4;
        16'b00000000001xxxxx: s_meter_out <= 5;
        16'b0000000001xxxxxx: s_meter_out <= 6;
        16'b000000001xxxxxxx: s_meter_out <= 7;
        16'b00000001xxxxxxxx: s_meter_out <= 8;
        16'b0000001xxxxxxxxx: s_meter_out <= 9;
        16'b000001xxxxxxxxxx: s_meter_out <= 10;
        16'b00001xxxxxxxxxxx: s_meter_out <= 11;
        16'b0001xxxxxxxxxxxx: s_meter_out <= 12;
        16'b001xxxxxxxxxxxxx: s_meter_out <= 13;
        16'b01xxxxxxxxxxxxxx: s_meter_out <= 14;
        16'b1xxxxxxxxxxxxxxx: s_meter_out <= 15;
        default: s_meter_out <= 0;
    endcase

end


endmodule