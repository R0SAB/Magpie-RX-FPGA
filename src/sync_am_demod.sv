module sync_am_demod
(
    input wire signed [23:0]bb_I_in,
    input wire signed [23:0]bb_Q_in,
    input wire signed [23:0]sync_car_cos_in,
    input wire signed [23:0]sync_car_sin_in,
    input wire clk_44k,
    output reg signed [23:0]sync_am_out
);

reg signed [23:0]delay[0:255];
reg signed [23:0]delay_out;
reg signed [23:0]sync_I;
reg signed [46:0]sync_mult_I;
reg signed [23:0]sync_Q;
reg signed [46:0]sync_mult_Q;
reg signed [24:0]sync_sum;

localparam SYNC_CAR_DELAY = 256;

reg signed [23:0]sync_cos_fifo[0:SYNC_CAR_DELAY-1];
reg signed [23:0]sync_sin_fifo[0:SYNC_CAR_DELAY-1];
reg signed [23:0]sync_car_cos_dly;
reg signed [23:0]sync_car_sin_dly;

always @ (posedge clk_44k)
begin

    sync_car_cos_dly <= sync_cos_fifo[SYNC_CAR_DELAY-1];
    sync_car_sin_dly <= sync_sin_fifo[SYNC_CAR_DELAY-1];
    for(int i=1; i<SYNC_CAR_DELAY; i++)
    begin
        sync_cos_fifo[i] <= sync_cos_fifo[i-1];
        sync_sin_fifo[i] <= sync_sin_fifo[i-1];
    end
    sync_cos_fifo[0] <= sync_car_cos_in;
    sync_sin_fifo[0] <= sync_car_sin_in;

    sync_mult_I <= bb_I_in * sync_car_sin_dly;
    sync_mult_Q <= bb_Q_in * sync_car_cos_dly;

    sync_I <= sync_mult_I[46:23];
    sync_Q <= sync_mult_Q[46:23];

    sync_sum <= sync_I + sync_Q;
    sync_am_out <= sync_sum[23:0];

end


endmodule