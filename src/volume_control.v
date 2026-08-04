module volume_control
(
    input wire unsigned [4:0]volume_5bit_in,
    input wire signed [15:0]audio_in,
    output reg [15:0]audio_out,
    input wire clk_44k
);


reg unsigned [9:0]volume_square;
reg signed [10:0]volume_signed;
reg signed[25:0]mult;


always @ (posedge clk_44k)
begin
    
    volume_square = volume_5bit_in * volume_5bit_in;
    volume_signed[9:0] <= volume_square[9:0];
    volume_signed[10] <= 0;

    mult <= audio_in * volume_signed;
    audio_out[15:0] <= mult[25:10];

end


endmodule