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
localparam S_SHIFT = 6;
assign s_mask = itgr_out[15+S_SHIFT:0+S_SHIFT];
reg [7:0]s_meter_raw;

reg [15:0]s_meter_delay;
localparam S_METER_DELAY = 4410;

always @ (posedge clk_44k)
begin

    if(amplitude_in[23]) detector <= -amplitude_in;
    else detector <= amplitude_in;

    itgr <= itgr + detector - itgr_out;

    if(itgr > (1<<<(15+12+S_SHIFT+1))) itgr <= (1<<<(15+12+S_SHIFT+1));

    casex(s_mask)
        16'b0000000000000001: s_meter_raw <= 0;
        16'b000000000000001x: s_meter_raw <= 1;
        16'b00000000000001xx: s_meter_raw <= 2;
        16'b0000000000001xxx: s_meter_raw <= 3;
        16'b000000000001xxxx: s_meter_raw <= 4;
        16'b00000000001xxxxx: s_meter_raw <= 5;
        16'b0000000001xxxxxx: s_meter_raw <= 6;
        16'b000000001xxxxxxx: s_meter_raw <= 7;
        16'b00000001xxxxxxxx: s_meter_raw <= 8;
        16'b0000001xxxxxxxxx: s_meter_raw <= 9;
        16'b000001xxxxxxxxxx: s_meter_raw <= 10;
        16'b00001xxxxxxxxxxx: s_meter_raw <= 11;
        16'b0001xxxxxxxxxxxx: s_meter_raw <= 12;
        16'b001xxxxxxxxxxxxx: s_meter_raw <= 13;
        16'b01xxxxxxxxxxxxxx: s_meter_raw <= 14;
        16'b1xxxxxxxxxxxxxxx: s_meter_raw <= 15;
        default: s_meter_out <= 0;
    endcase


    if(s_meter_out < s_meter_raw)
    begin
        s_meter_out <= s_meter_raw;
        s_meter_delay <= 0;
    end
    else
    begin
        if(s_meter_delay < S_METER_DELAY) s_meter_delay <= s_meter_delay + 1;
        if(s_meter_delay == S_METER_DELAY && s_meter_out > 0) s_meter_out <= s_meter_out - 1;
    end


end


endmodule