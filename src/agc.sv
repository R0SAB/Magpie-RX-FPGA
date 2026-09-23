
module agc
(
    input  wire signed [23:0] audio_in,
    output reg  signed [23:0] audio_out,

    input wire clk_44k,
    input wire clk_70M,

    input wire mode,
    input wire am_squelch
);


// --------------------------------------------------
// Gain parameters
// --------------------------------------------------

localparam integer GAIN_TAU_BITS  = 10;
localparam integer GAIN_FRAC_BITS = 18;
localparam integer ATTACK_BITS    = 4;

localparam integer AUDIO_DELAY    = 1024;


// --------------------------------------------------
// Hang AGC parameters
// --------------------------------------------------

localparam integer AUDIO_SAMPLE_RATE = 44100;
localparam integer HANG_TIME_MS      = 100;

localparam integer HANG_SAMPLES =
    AUDIO_SAMPLE_RATE * HANG_TIME_MS / 1000;


// Hang timer

reg [$clog2(HANG_SAMPLES+1)-1:0] hang_timer = '0;


// --------------------------------------------------
// Clock edge detector
// --------------------------------------------------

reg [1:0] clk_44k_eg;


// --------------------------------------------------
// Signal detector
// --------------------------------------------------

reg signed [23:0] abs_out;

logic signed [23:0] target;


// --------------------------------------------------
// 20-bit gain, 30-bit integrator
// --------------------------------------------------

reg signed [19+GAIN_TAU_BITS:0] gain_itgr;

wire signed [19:0] gain;

assign gain = gain_itgr >>> GAIN_TAU_BITS;


// Maximum gain

localparam signed [19+GAIN_TAU_BITS:0] GAIN_MAX_ITGR =
    30'sd524287 <<< GAIN_TAU_BITS;


// --------------------------------------------------
// Gain error
// --------------------------------------------------

wire signed [31:0] error;

assign error = target - abs_out;


// --------------------------------------------------
// Asymmetric gain integrator
// --------------------------------------------------

wire signed [31:0] gain_itgr_next;

assign gain_itgr_next =
    gain_itgr +
    ((error < 0) ?
        (error <<< ATTACK_BITS) :
        error);


// --------------------------------------------------
// Target level
// --------------------------------------------------

always_comb
begin

    if (mode == 1'b0)
        target = 24'sd5000;

    else if (am_squelch)
        target = 24'sd10000;

    else
        target = 24'sd2000;

end


// --------------------------------------------------
// Audio delay line
// --------------------------------------------------

reg signed [23:0] audio_fifo [0:AUDIO_DELAY-1];

wire signed [23:0] audio_delayed;

assign audio_delayed = audio_fifo[AUDIO_DELAY-1];


// --------------------------------------------------
// AGC control path
// --------------------------------------------------

reg signed [43:0] multiplier_agc;

wire signed [43:0] scaled_audio_agc;

assign scaled_audio_agc =
    multiplier_agc >>> GAIN_FRAC_BITS;


// Internal AGC audio output

reg signed [23:0] audio_agc;


// --------------------------------------------------
// Delayed audio output path
// --------------------------------------------------

reg signed [43:0] multiplier_out;

wire signed [43:0] scaled_audio_out;

assign scaled_audio_out =
    multiplier_out >>> GAIN_FRAC_BITS;


// --------------------------------------------------
// Main process
// --------------------------------------------------

integer i;

always @(posedge clk_70M)
begin

    clk_44k_eg <= {clk_44k_eg[0], clk_44k};

    if (clk_44k_eg == 2'b01)
    begin

        // ------------------------------------------
        // Audio delay line
        // ------------------------------------------

        for (i = AUDIO_DELAY-1; i > 0; i = i-1)
        begin
            audio_fifo[i] <= audio_fifo[i-1];
        end

        audio_fifo[0] <= audio_in;


        // ------------------------------------------
        // AGC signal detector
        // ------------------------------------------

        if (audio_agc == 24'sh800000)
            abs_out <= 24'sh7FFFFF;

        else if (audio_agc[23])
            abs_out <= -audio_agc;

        else
            abs_out <= audio_agc;


        // ------------------------------------------
        // Hang AGC timer
        // ------------------------------------------

        // Restart timer on negative error

        if (error < 0)
        begin
            hang_timer <= HANG_SAMPLES;
        end

        // Countdown on non-negative error

        else if (hang_timer != 0)
        begin
            hang_timer <= hang_timer - 1'b1;
        end


        // ------------------------------------------
        // Gain integrator with saturation
        // ------------------------------------------

        // Gain reduction is always allowed.
        // Gain increase is allowed only when
        // the hang timer has expired.

        if ((error < 0) || (hang_timer == 0))
        begin

            if (gain_itgr_next < 0)
                gain_itgr <= 0;

            else if (gain_itgr_next > GAIN_MAX_ITGR)
                gain_itgr <= GAIN_MAX_ITGR;

            else
                gain_itgr <= gain_itgr_next;

        end


        // ------------------------------------------
        // AGC control path
        // ------------------------------------------

        multiplier_agc <= gain * audio_in;


        // Internal audio saturation

        if (scaled_audio_agc > 44'sd8388607)
            audio_agc <= 24'sh7FFFFF;

        else if (scaled_audio_agc < -44'sd8388608)
            audio_agc <= 24'sh800000;

        else
            audio_agc <= scaled_audio_agc[23:0];


        // ------------------------------------------
        // Delayed audio output path
        // ------------------------------------------

        multiplier_out <= gain * audio_delayed;


        // Output saturation

        if (scaled_audio_out > 44'sd8388607)
            audio_out <= 24'sh7FFFFF;

        else if (scaled_audio_out < -44'sd8388608)
            audio_out <= 24'sh800000;

        else
            audio_out <= scaled_audio_out[23:0];

    end

end

endmodule