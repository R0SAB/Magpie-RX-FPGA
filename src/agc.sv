module agc
(
    input  wire signed [23:0] audio_in,
    output reg  signed [23:0] audio_out,

    input wire clk_44k,
    input wire clk_70M,

    input wire mode,       // 0 - qPeak; 1 - Mean
    input wire am_squelch,

    output reg carrier_present_out
);


// Gain parameters

localparam integer GAIN_TAU_BITS  = 10;
localparam integer GAIN_FRAC_BITS = 18;


// Clock edge detector

reg [1:0] clk_44k_eg;


// Signal detector

reg signed [23:0] abs_out;
reg signed [23:0] detector_qpeak;

logic signed [23:0] target;


// 20-bit gain, 30-bit integrator

reg signed [19+GAIN_TAU_BITS:0] gain_itgr;

wire signed [19:0] gain;

assign gain = gain_itgr >>> GAIN_TAU_BITS;


// Maximum gain:
// 524287 / 262144 = 1.999996

localparam signed [29:0] GAIN_MAX_ITGR =
    30'sd524287 <<< GAIN_TAU_BITS;


// Extended integrator calculation

wire signed [31:0] gain_itgr_next;

assign gain_itgr_next =
    gain_itgr + target - detector_qpeak;


// Target level

always_comb
begin
    if (mode == 1'b0)
        target = 24'sd5000;
    else if (am_squelch)
        target = 24'sd10000;
    else
        target = 24'sd2000;
end


// 20 x 24 = 44 bits

reg signed [43:0] multiplier;


always @(posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if (clk_44k_eg == 2'b01)
    begin

        // Absolute value

        if (audio_out == 24'sh800000)
            abs_out <= 24'sh7FFFFF;
        else if (audio_out[23])
            abs_out <= -audio_out;
        else
            abs_out <= audio_out;


        // Quasi-peak detector

        if (detector_qpeak < abs_out)
            detector_qpeak <= abs_out;
        else
            detector_qpeak <=
                detector_qpeak -
                (detector_qpeak >>> 7);


        // Gain integrator with saturation

        if (gain_itgr_next < 0)
            gain_itgr <= 0;

        else if (gain_itgr_next > GAIN_MAX_ITGR)
            gain_itgr <= GAIN_MAX_ITGR;

        else
            gain_itgr <= gain_itgr_next;


        // 20-bit gain x 24-bit audio

        multiplier <= gain * audio_in;


        // Output saturation, Q2.18

        if (multiplier[43:42] != {2{multiplier[41]}})
        begin
            if (multiplier[43])
                audio_out <= 24'sh800000;
            else
                audio_out <= 24'sh7FFFFF;
        end
        else
        begin
            audio_out <= multiplier[41:18];
        end

    end

end

endmodule