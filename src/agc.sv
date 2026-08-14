module agc
(
    input wire signed [23:0]audio_in,
    output reg signed [23:0]audio_out,
    input wire clk_44k,
    input wire clk_70M,

    input wire mode       // 0 - qPeak; 1 - Mean
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

always @ (posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if(clk_44k_eg == 2'b01)
    begin

        if(audio_out[23]) detector <= -audio_out;
        else detector <= audio_out;

        if(detector_qpeak < detector) detector_qpeak <= detector_qpeak + (detector - detector_qpeak);
        else detector_qpeak <= detector_qpeak - (detector_qpeak >>> 7);

        if(mode) itgr <= itgr + target - detector;
        else  itgr <= itgr + target - detector_qpeak;

        multiplier <= itgr_output * audio_in;
        audio_out[23:0] <= multiplier[35:12];

        if(itgr > (1 <<< 28)) itgr <= (1 <<< 28);

    end

end



endmodule