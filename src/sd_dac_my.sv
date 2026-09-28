module sd_dac_my
(
    input  logic               clk,
    input  logic signed [15:0] in,
    output logic               out
);

    logic [15:0] acc;
    logic [15:0] in_unsigned;
    logic [16:0] sum;

    // Signed PCM -> unsigned offset binary:
    // -32768 ->     0
    //      0 -> 32768
    // +32767 -> 65535
    assign in_unsigned = {~in[15], in[14:0]};

    // 17-bit addition is important: bit 16 is the DAC output.
    assign sum = {1'b0, acc} + {1'b0, in_unsigned};

    always_ff @(posedge clk) begin
        acc <= sum[15:0];
        out <= sum[16];
    end

    initial begin
        acc = 16'd0;
        out = 1'b0;
    end

endmodule