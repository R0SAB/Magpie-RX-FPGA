
module agc
(
    input  wire signed [23:0] audio_in,
    output reg  signed [23:0] audio_out,

    input wire clk_44k,
    input wire clk_70M,

    input wire mode,
    input wire am_squelch
);


// Gain parameters

localparam integer GAIN_TAU_BITS  = 10;
localparam integer GAIN_FRAC_BITS = 18;
localparam integer ATTACK_BITS    = 4;


// Clock edge detector

reg [1:0] clk_44k_eg;


// Signal detector

reg signed [23:0] abs_out;

logic signed [23:0] target;


// 20-bit gain, 30-bit integrator

reg signed [19+GAIN_TAU_BITS:0] gain_itgr;

wire signed [19:0] gain;

assign gain = gain_itgr >>> GAIN_TAU_BITS;


// Maximum gain

localparam signed [19+GAIN_TAU_BITS:0] GAIN_MAX_ITGR =
    30'sd524287 <<< GAIN_TAU_BITS;


// Gain error

wire signed [31:0] error;

assign error = target - abs_out;


// Asymmetric gain integrator

wire signed [31:0] gain_itgr_next;

assign gain_itgr_next =
    gain_itgr +
    ((error < 0) ?
        (error <<< ATTACK_BITS) :
        error);


// Target level

always_comb
begin
    if (mode == 1'b0)
        target = 24'sd5000;
    else if (am_squelch)
        target = 24'sd12000;
    else
        target = 24'sd3000;
end


// 20 x 24 = 44 bits

reg signed [43:0] multiplier;


// Scaled audio

wire signed [43:0] scaled_audio;

assign scaled_audio = multiplier >>> GAIN_FRAC_BITS;


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


        // Gain integrator with saturation

        if (gain_itgr_next < 0)
            gain_itgr <= 0;

        else if (gain_itgr_next > GAIN_MAX_ITGR)
            gain_itgr <= GAIN_MAX_ITGR;

        else
            gain_itgr <= gain_itgr_next;


        // 20-bit gain x 24-bit audio

        multiplier <= gain * audio_in;


        // Output saturation

        if (scaled_audio > 44'sd8388607)
            audio_out <= 24'sh7FFFFF;

        else if (scaled_audio < -44'sd8388608)
            audio_out <= 24'sh800000;

        else
            audio_out <= scaled_audio[23:0];

    end

end

endmodule