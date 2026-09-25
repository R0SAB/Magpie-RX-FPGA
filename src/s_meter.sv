module s_meter
(
    input  wire signed [23:0] amplitude_in,
    output reg         [7:0]  s_meter_out,
    input  wire                clk_44k
);

localparam S_SHIFT       = 4;
localparam S_METER_DELAY = 3000;

localparam signed [35:0] ITGR_MAX =
    (36'sd1 <<< (15 + 12 + S_SHIFT + 1)) - 36'sd1;

// Amplitude detector

reg signed [23:0] detector;

// Integrator

reg  signed [35:0] itgr;
reg  signed [35:0] itgr_next;

wire signed [23:0] itgr_out;

assign itgr_out = itgr[35:12];

always @*
begin
    itgr_next = itgr + detector - itgr_out;

    if (itgr_next > ITGR_MAX)
        itgr_next = ITGR_MAX;
    else if (itgr_next < 36'sd0)
        itgr_next = 36'sd0;
end

// Logarithmic S-meter scale

wire [15:0] s_mask;

assign s_mask = itgr_out[15+S_SHIFT:S_SHIFT];

reg [7:0] s_meter_raw;

// Display damping

reg [15:0] s_meter_delay;

// Main process

always @(posedge clk_44k)
begin

    // Amplitude detector

    if (amplitude_in[23])
        detector <= -amplitude_in;
    else
        detector <= amplitude_in;

    // Integrator

    itgr <= itgr_next;

    // Logarithmic amplitude conversion

    casex (s_mask)

        16'b1xxxxxxxxxxxxxxx: s_meter_raw <= 8'd15;
        16'b01xxxxxxxxxxxxxx: s_meter_raw <= 8'd14;
        16'b001xxxxxxxxxxxxx: s_meter_raw <= 8'd13;
        16'b0001xxxxxxxxxxxx: s_meter_raw <= 8'd12;
        16'b00001xxxxxxxxxxx: s_meter_raw <= 8'd11;
        16'b000001xxxxxxxxxx: s_meter_raw <= 8'd10;
        16'b0000001xxxxxxxxx: s_meter_raw <= 8'd9;
        16'b00000001xxxxxxxx: s_meter_raw <= 8'd8;
        16'b000000001xxxxxxx: s_meter_raw <= 8'd7;
        16'b0000000001xxxxxx: s_meter_raw <= 8'd6;
        16'b00000000001xxxxx: s_meter_raw <= 8'd5;
        16'b000000000001xxxx: s_meter_raw <= 8'd4;
        16'b0000000000001xxx: s_meter_raw <= 8'd3;
        16'b00000000000001xx: s_meter_raw <= 8'd2;
        16'b000000000000001x: s_meter_raw <= 8'd1;
        16'b0000000000000001: s_meter_raw <= 8'd0;

        default: s_meter_raw <= 8'd0;

    endcase

    // Fast attack, slow decay

    if (s_meter_out < s_meter_raw)
    begin
        s_meter_out   <= s_meter_raw;
        s_meter_delay <= 16'd0;
    end
    else if (s_meter_out > s_meter_raw)
    begin
        if (s_meter_delay == S_METER_DELAY - 1)
        begin
            s_meter_out   <= s_meter_out - 8'd1;
            s_meter_delay <= 16'd0;
        end
        else
        begin
            s_meter_delay <= s_meter_delay + 16'd1;
        end
    end
    else
    begin
        s_meter_delay <= 16'd0;
    end

end

endmodule