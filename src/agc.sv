module agc
(
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

// DC time constant: 2^12 / 44100 = approximately 92.9 ms.
localparam integer DC_TAU_BITS    = 7;

localparam integer AUDIO_DELAY    = 1024;


localparam TARGET_SSB = 6000;
localparam TARGET_AM = 3000;
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
// Fall: about 2 ms per -6 dB in SSB, 8 ms in AM.
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

// Accelerate gain reduction in SSB.
wire signed [31:0] gain_step_raw = (error < 0 && mode == 0) ? (error <<< ATTACK_BITS) : error;

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
// Combined AC/DC level detector (both modes)
// --------------------------------------------------

// Fractional accumulator: DC = dc_itgr / 2^DC_TAU_BITS.
// Updated once per audio sample, like the existing integrators.
reg signed [23+DC_TAU_BITS:0] dc_itgr = '0;
wire signed [23:0] dc_level;
assign dc_level = dc_itgr >>> DC_TAU_BITS;

wire signed [23+DC_TAU_BITS:0] audio_dc_ext;
wire signed [23+DC_TAU_BITS:0] dc_level_ext;
assign audio_dc_ext = {{DC_TAU_BITS{audio_agc[23]}}, audio_agc};
assign dc_level_ext = {{DC_TAU_BITS{dc_level[23]}}, dc_level};

// Subtract in 25 bits: opposite full-scale values must not wrap.
wire signed [24:0] ac_level;
wire signed [24:0] dc_level_wide;
assign dc_level_wide = {dc_level[23], dc_level};
assign ac_level = $signed({audio_agc[23], audio_agc}) - dc_level_wide;

// Unsigned magnitudes also represent abs(-2^23) correctly.
wire [24:0] ac_abs;
wire [24:0] dc_abs;
wire [24:0] dc_abs_scaled;
wire [24:0] combined_level;
assign ac_abs = ac_level[24] ? $unsigned(-ac_level) : $unsigned(ac_level);
assign dc_abs = dc_level_wide[24]
    ? $unsigned(-dc_level_wide) : $unsigned(dc_level_wide);
assign dc_abs_scaled = dc_abs >> 2;
assign combined_level = (ac_abs > dc_abs_scaled) ? ac_abs : dc_abs_scaled;


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

        dc_itgr <= dc_itgr + audio_dc_ext - dc_level_ext;

        // Preserve the positive range of the signed feedback signal.
        if (combined_level > 25'd8388607)
            abs_out <= 24'sh7FFFFF;
        else
            abs_out <= combined_level[23:0];


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