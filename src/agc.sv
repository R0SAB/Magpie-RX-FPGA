module agc
(
    input wire signed [23:0]audio_in,
    output reg signed [23:0]audio_out,
    input wire clk_44k,
    input wire clk_70M,

    input wire mode,       // 0 - qPeak; 1 - Mean
    output reg [7:0]s_meter_out
);


reg [1:0]clk_44k_eg;

reg signed [23:0]detector;
reg signed [23:0]detector_qpeak;
wire [23:0]target;
assign target = 5000;

reg signed [30:0]itgr;
wire signed [15:0]itgr_output;
assign itgr_output[15:0] = itgr[30:15];

reg signed [35:0]multiplier;

reg signed [23:0]detector_s;
reg signed [35:0]itgr_s;
wire signed [23:0]itgr_s_out;
assign itgr_s_out = itgr_s[35:12];

wire [15:0]s_mask;
localparam S_SHIFT = 5;
assign s_mask = itgr_s_out[15+S_SHIFT:0+S_SHIFT];


always @ (posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if(clk_44k_eg == 2'b01)
    begin

        if(audio_out[23]) detector <= -audio_out;
        else detector <= audio_out;

        if(audio_in[23]) detector_s <= -audio_in;
        else detector_s <= audio_in;

        if(detector_qpeak < detector) detector_qpeak <= detector_qpeak + (detector - detector_qpeak);
        else detector_qpeak <= detector_qpeak - (detector_qpeak >>> 7);

        itgr_s <= itgr_s + detector_s - itgr_s_out;
        
        if(mode) itgr <= itgr + target - detector;
        else  itgr <= itgr + target - detector_qpeak;

        multiplier <= itgr_output * audio_in;
        audio_out[23:0] <= multiplier[35:12];

        if(itgr > (1 <<< 28)) itgr <= (1 <<< 28);


    end

    if(itgr_s > (1<<<(15+12+S_SHIFT+1))) itgr_s <= (1<<<(15+12+S_SHIFT+1));

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
        default: s_meter_out <= 15;
    endcase


end



endmodule