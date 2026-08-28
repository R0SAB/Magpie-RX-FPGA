module frac_pwm #(
    parameter integer COUNTER_BITS = 5
)(
    input  wire               clk,

    // Signed input: -32768 ... +32767
    input  wire signed [15:0] din,

    output reg                pwm
);

    localparam integer PWM_LEVELS = (1 << COUNTER_BITS);
    localparam integer FRAC_BITS  = 16 - COUNTER_BITS;

    // 5-bit PWM counter: 0 ... 31
    reg [COUNTER_BITS-1:0] pwm_cnt;

    // 11-bit fractional accumulator
    reg [FRAC_BITS-1:0] frac_acc;

    // PWM level: 0 ... 32
    reg [COUNTER_BITS:0] pwm_level;

    reg [15:0] din_unsigned;
    reg [COUNTER_BITS-1:0] base_level;
    reg [FRAC_BITS-1:0] frac_part;

    reg [FRAC_BITS:0] frac_sum;

    always @* begin
        // Signed -32768...32767
        // -> unsigned 0...65535
        din_unsigned = din + 16'sh8000;

        // Integer part
        base_level = din_unsigned[15:FRAC_BITS];

        // Fractional part
        frac_part = din_unsigned[FRAC_BITS-1:0];
    end

    always @(posedge clk) begin

        // PWM output
        if (pwm_cnt < pwm_level)
            pwm <= 1'b1;
        else
            pwm <= 1'b0;

        // PWM counter
        if (pwm_cnt == PWM_LEVELS-1) begin

            pwm_cnt <= {COUNTER_BITS{1'b0}};

            // Fractional accumulation
            frac_sum = {1'b0, frac_acc} +
                       {1'b0, frac_part};

            frac_acc <= frac_sum[FRAC_BITS-1:0];

            // Add fractional carry to PWM level
            if (frac_sum[FRAC_BITS])
                pwm_level <= base_level + 1'b1;
            else
                pwm_level <= base_level;

        end
        else begin
            pwm_cnt <= pwm_cnt + 1'b1;
        end

    end

endmodule