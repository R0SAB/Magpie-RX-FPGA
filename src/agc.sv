module agc
(
    input wire signed [23:0] mag_in,

    input  wire signed [23:0] audio_in,
    output reg  signed [23:0] audio_out,

    input wire clk_44k,
    input wire clk_70M,

    input wire mode,            // 0 - SSB, 1 - AM
    input wire am_squelch
);


// --------------------------------------------------
// Gain parameters
// --------------------------------------------------

localparam integer GAIN_TAU_BITS  = 8;
localparam integer GAIN_FRAC_BITS = 16;
localparam integer ATTACK_BITS    = 3;

localparam integer AUDIO_DELAY    = 1024;


localparam TARGET_SSB = 6000;
localparam TARGET_AM = 10000;
localparam TARGET_AM_SQ = 2000;

// --------------------------------------------------
// Hang AGC parameters
// --------------------------------------------------

localparam integer AUDIO_SAMPLE_RATE = 44100;
localparam integer HANG_TIME_MS      = 200;

localparam integer HANG_SAMPLES =
    AUDIO_SAMPLE_RATE * HANG_TIME_MS / 1000;


// Hang timer

reg [$clog2(HANG_SAMPLES+1)-1:0] hang_timer = '0;


// --------------------------------------------------
// Clock edge detector
// --------------------------------------------------

reg [1:0] clk_44k_eg = 2'b00;


// --------------------------------------------------
// Signal detector
// --------------------------------------------------

reg signed [23:0] abs_out = 24'sd0;

logic signed [23:0] target;


// --------------------------------------------------
// 20-bit gain, (20 + GAIN_TAU_BITS)-bit signed integrator
// --------------------------------------------------

reg signed [19+GAIN_TAU_BITS:0] gain_itgr = '0;

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
// Gain slew-rate limits (applied to BOTH directions)
// --------------------------------------------------

// Maximum change relative to the current gain per 44.1 kHz sample.
// Rise: about 64 ms per +6 dB normally, 1.03 s during SSB hang.
// Fall: about 2 ms per -6 dB in SSB, 16 ms in AM.
// Rise timing assumes gain above the rise reference floor.
// These are MAXIMUM rates; the original error integrator may be slower.
localparam integer GAIN_RISE_RATE_BITS = 12;
localparam integer GAIN_RISE_RATE_BITS_HANG = 16;
wire [7:0] gain_fall_rate_bits = (mode == 0) ? 7 : 10;

// A floor for the RISE limiter only. Without it, starting from
// gain_itgr == 0 would take extremely long. This is in gain units
// (before the GAIN_TAU_BITS scaling), not audio sample units.
localparam integer GAIN_RISE_REF_FLOOR = 256;
localparam signed [19+GAIN_TAU_BITS:0] RISE_REF_FLOOR_ITGR =
    GAIN_RISE_REF_FLOOR <<< GAIN_TAU_BITS;

// Accelerate gain reduction in both SSB and AM.
wire signed [31:0] gain_step_raw =
    (error < 0) ? (error <<< ATTACK_BITS) : error;

wire signed [19+GAIN_TAU_BITS:0] rise_reference =
    (gain_itgr < RISE_REF_FLOOR_ITGR)
        ? RISE_REF_FLOOR_ITGR : gain_itgr;

logic signed [31:0] gain_step_up_max;

always_comb
begin
    gain_step_up_max =
        $signed(rise_reference) >>> GAIN_RISE_RATE_BITS;

    if ((mode == 1'b0) && (hang_timer != 0))
        gain_step_up_max =
            $signed(rise_reference) >>> GAIN_RISE_RATE_BITS_HANG;
end

// The fall limiter uses the ACTUAL gain, without the rise floor.
// This prevents an excessively large negative step at low gain.
wire signed [31:0] gain_step_down_raw_max =
    $signed(gain_itgr) >>> gain_fall_rate_bits;

wire signed [31:0] gain_step_down_max =
    (gain_step_down_raw_max > 0)
        ? gain_step_down_raw_max : 32'sd1;

wire signed [31:0] gain_step_limited =
    (gain_step_raw > gain_step_up_max) ? gain_step_up_max :
    (gain_step_raw < -gain_step_down_max) ? -gain_step_down_max :
    gain_step_raw;

// All terms are signed and 32-bit, before the saturation checks.
wire signed [31:0] gain_itgr_next =
    $signed(gain_itgr) + gain_step_limited;


// --------------------------------------------------
// Target level
// --------------------------------------------------

always_comb
begin

    if (mode == 1'b0)
        target = TARGET_SSB;

    else if (am_squelch)
        target = TARGET_AM;

    else
        target = TARGET_AM_SQ;

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

reg signed [43:0] multiplier_agc = 44'sd0;

wire signed [43:0] scaled_audio_agc;

assign scaled_audio_agc =
    multiplier_agc >>> GAIN_FRAC_BITS;


// Internal AGC audio output

reg signed [23:0] audio_agc = 24'sd0;


// --------------------------------------------------
// Delayed audio output path
// --------------------------------------------------

reg signed [43:0] multiplier_out = 44'sd0;

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
        // Gain increase is also always allowed, but its rate is reduced
        // while the hang timer is active in SSB.

        if (gain_itgr_next < 0)
            gain_itgr <= 0;

        else if (gain_itgr_next > GAIN_MAX_ITGR)
            gain_itgr <= GAIN_MAX_ITGR;

        else
            gain_itgr <= gain_itgr_next;


        // ------------------------------------------
        // AGC control path
        // ------------------------------------------

        multiplier_agc <= gain * mag_in;


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