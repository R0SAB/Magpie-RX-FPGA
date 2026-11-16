module agc_feedforward #(
    parameter integer DELAY_SAMPLES = 1024, // Must be >= 1.
    parameter logic [19:0] GAIN_MAX = 20'd524287 // Positive signed Q16.
)(
    input  wire signed [23:0] audio_in,
    output reg  signed [23:0] audio_out = 24'sd0,
    input  wire               clk_44k,
    input  wire               clk_H
);

    // FPGA power-up register initialization is used, as in the original AGC.
    // There is no runtime reset port.
    localparam integer GAIN_FRAC_BITS = 16;

    // --------------------------------------------------
    // Sample clock edge detection, all processing on clk_H
    // --------------------------------------------------
    reg samp_clk_meta = 1'b0;
    reg [1:0] samp_clk_eg = 2'b00;
    wire samp_ce = (samp_clk_eg == 2'b01);

    always @(posedge clk_H) begin
        samp_clk_meta <= clk_44k;
        samp_clk_eg <= {samp_clk_eg[0], samp_clk_meta};
    end

    // --------------------------------------------------
    // Configuration and combined AC/DC input level detector
    // --------------------------------------------------
    reg [23:0] target = 24'd5000;
    wire [23:0] input_level;

    localparam integer DC_TAU_BITS = 7;
    localparam integer DC_ATTEN_BITS = 2;
    localparam integer LEVEL_TAU_BITS = 12;
    // Positive level errors are multiplied by 2^ATTACK_BITS.
    // Valid range: 0 <= ATTACK_BITS <= LEVEL_TAU_BITS.
    // 0 gives symmetric smoothing; LEVEL_TAU_BITS gives immediate rise.
    localparam integer ATTACK_BITS = 3;

    // Signed DC estimate BEFORE gain multiplication.
    reg signed [23+DC_TAU_BITS:0] dc_itgr = '0;
    wire signed [23:0] dc_level = dc_itgr >>> DC_TAU_BITS;
    wire signed [23+DC_TAU_BITS:0] audio_dc_ext =
        {{DC_TAU_BITS{audio_in[23]}}, audio_in};
    wire signed [23+DC_TAU_BITS:0] dc_level_ext =
        {{DC_TAU_BITS{dc_level[23]}}, dc_level};

    // A 25-bit subtraction preserves full-scale polarity reversals.
    wire signed [24:0] dc_wide = {dc_level[23], dc_level};
    wire signed [24:0] ac_level =
        $signed({audio_in[23], audio_in}) - dc_wide;
    wire [24:0] ac_abs = ac_level[24]
        ? $unsigned(-ac_level) : $unsigned(ac_level);
    wire [24:0] dc_abs = dc_wide[24]
        ? $unsigned(-dc_wide) : $unsigned(dc_wide);
    wire [24:0] dc_scaled = (dc_abs >> DC_ATTEN_BITS) - (dc_abs >> (DC_ATTEN_BITS+2));
    wire [24:0] combined_level =
        (ac_abs > dc_scaled) ? ac_abs : dc_scaled;

    // |audio_in - dc_level| <= 2^24 - 1, so all 24 unsigned bits fit.
    wire [23:0] level_sample = combined_level[23:0];
    reg [23+LEVEL_TAU_BITS:0] level_itgr = '0;
    assign input_level = level_itgr >> LEVEL_TAU_BITS;

    // Extend BEFORE subtraction and shifting. Keep the sum signed too.
    localparam integer LEVEL_CALC_BITS = 26 + LEVEL_TAU_BITS;
    wire signed [LEVEL_CALC_BITS-1:0] level_error =
        $signed({{(LEVEL_CALC_BITS-24){1'b0}}, level_sample}) -
        $signed({{(LEVEL_CALC_BITS-24){1'b0}}, input_level});
    wire signed [LEVEL_CALC_BITS-1:0] level_step = (level_error > 0)
        ? (level_error <<< ATTACK_BITS) : level_error;
    wire signed [LEVEL_CALC_BITS-1:0] level_next =
        $signed({2'b00, level_itgr}) + level_step;
    localparam logic signed [LEVEL_CALC_BITS-1:0] LEVEL_MAX_ITGR =
        {2'b00, 24'hFFFFFF, {LEVEL_TAU_BITS{1'b0}}};

    always @(posedge clk_H) begin
        if (samp_ce) begin
            dc_itgr <= dc_itgr + audio_dc_ext - dc_level_ext;

            if (level_next < 0)
                level_itgr <= '0;
            else if (level_next > LEVEL_MAX_ITGR)
                level_itgr <= LEVEL_MAX_ITGR[23+LEVEL_TAU_BITS:0];
            else
                level_itgr <= level_next[23+LEVEL_TAU_BITS:0];
        end
    end

    // Division captures the previous registered level on this sample edge.

    // --------------------------------------------------
    // Unsigned sequential division: (target << 16) / input_level
    // --------------------------------------------------
    localparam logic [39:0] MAX_QUOTIENT = {20'b0, GAIN_MAX};
    reg [23:0] divisor_reg = '0;
    reg [23:0] remainder_reg = '0;
    reg [39:0] quotient_reg = '0;
    reg [5:0] bits_left = '0;
    reg div_busy = 1'b0;

    // Finished result is buffered until the following sample edge.
    reg signed [19:0] gain_pending = 20'sd0;
    reg gain_ready_eg = 1'b0;
    reg signed [19:0] gain = 20'sd0;

    logic [24:0] trial_remainder;
    logic [24:0] remainder_next;
    logic [39:0] quotient_next;

    always_comb begin
        trial_remainder = {remainder_reg, quotient_reg[39]};
        remainder_next = trial_remainder;
        quotient_next = {quotient_reg[38:0], 1'b0};
        if (trial_remainder >= {1'b0, divisor_reg}) begin
            remainder_next = trial_remainder - {1'b0, divisor_reg};
            quotient_next[0] = 1'b1;
        end
    end

    always @(posedge clk_H) begin
        gain_ready_eg <= 1'b0;

        if (div_busy) begin
            remainder_reg <= remainder_next[23:0];
            quotient_reg <= quotient_next;
            bits_left <= bits_left - 1'b1;

            if (bits_left == 6'd1) begin
                gain_pending <= (quotient_next > MAX_QUOTIENT)
                    ? GAIN_MAX : quotient_next[19:0];
                div_busy <= 1'b0;
                gain_ready_eg <= 1'b1;
            end
        end else if (samp_ce) begin
            if (input_level == 24'd0) begin
                gain_pending <= GAIN_MAX;
                gain_ready_eg <= 1'b1;
            end else begin
                divisor_reg <= input_level;
                remainder_reg <= '0;
                quotient_reg <= {target, 16'b0};
                bits_left <= 6'd40;
                div_busy <= 1'b1;
            end
        end

        // Requires >40 clk_H cycles between sample events.
        // If division has not finished, the previous completed gain is kept.
        if (samp_ce)
            gain <= gain_pending;
    end

    // --------------------------------------------------
    // Shift-register audio delay
    // --------------------------------------------------
    localparam integer FILL_BITS = $clog2(DELAY_SAMPLES + 1);
    localparam logic [FILL_BITS-1:0] FULL_COUNT = FILL_BITS'(DELAY_SAMPLES);

    reg signed [23:0] audio_fifo [0:DELAY_SAMPLES-1];
    reg [FILL_BITS-1:0] fifo_fill = '0;
    reg signed [23:0] audio_delayed = 24'sd0;
    integer i;

    always @(posedge clk_H) begin
        if (samp_ce) begin
            for (i = DELAY_SAMPLES - 1; i > 0; i = i - 1)
                audio_fifo[i] <= audio_fifo[i-1];

            audio_fifo[0] <= audio_in;

            if (fifo_fill == FULL_COUNT)
                audio_delayed <= audio_fifo[DELAY_SAMPLES-1];
            else begin
                audio_delayed <= 24'sd0;
                fifo_fill <= fifo_fill + 1'b1;
            end
        end
    end

    // --------------------------------------------------
    // Signed multiplier, Q16 scaling, saturating output
    // --------------------------------------------------
    reg signed [43:0] multiplier = 44'sd0;
    wire signed [43:0] scaled_audio = multiplier >>> GAIN_FRAC_BITS;

    // After a sample edge, gain and audio_delayed update together.
    // Their product is registered on the NEXT clk_H edge, not a sample later.
    always @(posedge clk_H)
        multiplier <= gain * audio_delayed;

    // Commit the preceding interval's product only on sample events.
    // Total audio latency = DELAY_SAMPLES + 1 sample periods.
    always @(posedge clk_H) begin
        if (samp_ce) begin
            if (scaled_audio > 44'sd8388607)
                audio_out <= 24'sh7FFFFF;
            else if (scaled_audio < -44'sd8388608)
                audio_out <= 24'sh800000;
            else
                audio_out <= scaled_audio[23:0];
        end
    end

endmodule
