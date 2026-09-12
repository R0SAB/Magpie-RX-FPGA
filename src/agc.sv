module agc
(
    input wire signed [23:0]audio_in,
    output reg signed [23:0]audio_out,
    input wire clk_44k,
    input wire clk_70M,

    input wire mode,       // 0 - qPeak; 1 - Mean
    output reg carrier_present_out
);

typedef enum integer {MOD_SSB = 0, MOD_AM = 1} modulation_enum;

reg [1:0]clk_44k_eg;

reg signed [23:0]abs_in;
reg signed [23:0]abs_out;
reg signed [23:0]detector_qpeak;
logic signed [23:0]target;

localparam DC_TAU_BITS = 11;
localparam MEAN_TAU_BITS = 11;
localparam GAIN_TAU_BITS = 15;

reg signed [23+DC_TAU_BITS:0]dc_itgr;
wire signed [23:0]dc_level;
assign dc_level = dc_itgr >>> DC_TAU_BITS;

reg signed [23+MEAN_TAU_BITS:0]mean_itgr;
wire signed [23:0]mean_level;
assign mean_level = mean_itgr >>> MEAN_TAU_BITS;

reg signed [15+GAIN_TAU_BITS:0]gain_itgr;
wire signed [15:0]gain;
assign gain[15:0] = gain_itgr >>> GAIN_TAU_BITS;

wire carrier_present;
assign carrier_present = (dc_level > (mean_level >>> 4)) ? 1 : 0;

always_comb
begin
    if(mode == MOD_SSB) target = 5000;
    else
    if(mode == MOD_AM)
    begin
        if(carrier_present) target = 10000;
        else target = 2000;
    end
end


reg signed [35:0]multiplier;

reg [15:0]carrier_present_mm;
localparam CARRIER_DELAY = 10000;


always @ (posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if(clk_44k_eg == 2'b01)
    begin

        if(audio_in[23]) abs_in <= -audio_in;
        else abs_in <= audio_in;

        if(audio_out[23]) abs_out <= -audio_out;
        else abs_out <= audio_out;

        if(detector_qpeak < abs_out) detector_qpeak <= detector_qpeak + (abs_out - detector_qpeak);
        else detector_qpeak <= detector_qpeak - (detector_qpeak >>> 7);
        
        mean_itgr <= mean_itgr + abs_in - mean_level;
        dc_itgr <= dc_itgr + audio_in - dc_level;
        gain_itgr <= gain_itgr + target - detector_qpeak;
        if(gain_itgr > ('b11 <<< 27)) gain_itgr <= ('b11 <<< 27);

        multiplier <= gain * audio_in;
        audio_out[23:0] <= multiplier[35:12];

        if(~carrier_present) carrier_present_mm <= 0;
        else
        if(carrier_present_mm < CARRIER_DELAY) carrier_present_mm <= carrier_present_mm + 1;

        if(carrier_present_mm == CARRIER_DELAY) carrier_present_out <= 1;
        else carrier_present_out <= 0;

    end

end



endmodule