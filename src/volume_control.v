
module volume_control (
    input  wire signed [15:0] audio_in,
    input  wire        [4:0]  volume_in,
    input  wire               clk_44k,
    input  wire               clk_H,
    output reg  signed [15:0] audio_out = 16'sd0
);

    // Capture input data at the audio sample rate
    reg signed [15:0] audio_sample = 16'sd0;
    reg        [4:0]  volume_sample = 5'd31;
    reg               sample_toggle = 1'b0;

    always @(posedge clk_44k) begin
        audio_sample  <= audio_in;
        volume_sample <= volume_in;
        sample_toggle <= ~sample_toggle;
    end

    // Synchronize the sample event to clk_H domain
    reg toggle_meta = 1'b0;
    reg toggle_sync = 1'b0;
    reg toggle_prev = 1'b0;

    // 24-bit accumulator with 8 fractional bits
    reg signed [23:0] acc = 24'sd0;

    // Iteration counters
    reg [5:0] remaining = 6'd0;
    reg [4:0] step = 5'd0;

    // Use shift by 2 on three steps out of 31
    // All other steps use shift by 3
    wire shift2 = (step == 5'd5)  ||
                  (step == 5'd15) ||
                  (step == 5'd25);

    // Calculate one attenuation step
    wire signed [23:0] acc_next =
        acc - (shift2 ? (acc >>> 2) : (acc >>> 3));

    // Round to 16-bit output resolution
    wire signed [23:0] acc_rounded =
        acc_next + 24'sd128;

    always @(posedge clk_H) begin

        // Synchronize sample toggle
        toggle_meta <= sample_toggle;
        toggle_sync <= toggle_meta;
        toggle_prev <= toggle_sync;

        if (toggle_sync != toggle_prev) begin

            // Start processing a new audio sample
            acc  <= {audio_sample, 8'b0};
            step <= 5'd0;

            // Mute: skip all attenuation steps
            if (volume_sample == 5'd0) begin
                remaining <= 6'd0;
                audio_out <= 16'sd0;
            end else begin
                remaining <= 6'd31 - {1'b0, volume_sample};

                // Maximum volume: bypass attenuation
                if (volume_sample == 5'd31)
                    audio_out <= audio_sample;
            end

        end else if (remaining != 6'd0) begin

            // Perform one attenuation step per clock
            acc       <= acc_next;
            step      <= step + 5'd1;
            remaining <= remaining - 6'd1;

            // Update output after the last iteration
            if (remaining == 6'd1)
                audio_out <= acc_rounded[23:8];

        end
    end

endmodule
