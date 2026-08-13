module sd_dac_chatgpt (
    input  wire               clk,
    input  wire signed [15:0] in,
    output reg                out
);

    reg [15:0] acc;

    wire [15:0] level;
    wire [16:0] sum;

    // Signed two's complement -> offset binary
    // -32768 -> 16'h0000
    //      0 -> 16'h8000
    //  32767 -> 16'hFFFF
    assign level = {~in[15], in[14:0]};

    assign sum = {1'b0, acc} + {1'b0, level};

    always @(posedge clk) begin
        acc <= sum[15:0];
        out <= sum[16];
    end

endmodule