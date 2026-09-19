module agc
(
    input wire signed [23:0]audio_in,
    output reg signed [23:0]audio_out,
    input wire clk_44k,
    input wire clk_70M,

    input wire mode,       // 0 - qPeak; 1 - Mean
    input wire am_squelch,
    output reg carrier_present_out
);

typedef enum integer {MOD_SSB = 0, MOD_AM = 1} modulation_enum;

reg [1:0]clk_44k_eg;

reg signed [23:0]abs_out;
reg signed [23:0]detector_qpeak;
logic signed [23:0]target;

localparam GAIN_TAU_BITS = 10;

reg signed [15+GAIN_TAU_BITS:0]gain_itgr;
wire signed [15:0]gain;
assign gain[15:0] = gain_itgr >>> GAIN_TAU_BITS;

wire signed [15+GAIN_TAU_BITS:0]gain_itgr_next;
assign gain_itgr_next = gain_itgr + target - detector_qpeak;

always_comb
begin
    if(mode == MOD_SSB) target = 5000;
    else
    if(mode == MOD_AM)
    begin
        if(am_squelch) target = 10000;
        else target = 2000;
    end
end

reg signed [39:0]multiplier;


always @ (posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if(clk_44k_eg == 2'b01)
    begin

        if(audio_out[23]) abs_out <= -audio_out;
        else abs_out <= audio_out;

        if(detector_qpeak < abs_out) detector_qpeak <= detector_qpeak + (abs_out - detector_qpeak);
        else detector_qpeak <= detector_qpeak - (detector_qpeak >>> 7);
        
        //gain_itgr <= gain_itgr + target - detector_qpeak;
        //if(gain_itgr > ('b11 <<< 27)) gain_itgr <= ('b11 <<< 27);

        if(gain_itgr_next < (1 <<< (15+GAIN_TAU_BITS-2))) gain_itgr <= gain_itgr_next;

        multiplier <= gain * audio_in;
        audio_out[23:0] <= multiplier[39:16];

    end

end



endmodule