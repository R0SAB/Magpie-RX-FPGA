module ovr_s_meter_mux
(
    input wire signed [13:0]adc_in,
    input wire [7:0]s_meter_in,
    output reg [7:0]s_meter_out,
    input wire clk_70M
);

reg signed [13:0]adc_fifo[0:1];
wire ovr;
assign ovr = (/*(adc_fifo[1] == adc_fifo[0]) && */(adc_fifo[0] == 14'd8191 || adc_fifo[0] == -14'd8192));

reg [23:0]ovr_delay;

always @ (posedge clk_70M)
begin

    adc_fifo[1] <= adc_fifo[0];
    adc_fifo[0] <= adc_in;

    if(ovr) ovr_delay <= 14000000;
    else
    if(ovr_delay > 0) ovr_delay <= ovr_delay - 1;

    if(ovr) s_meter_out <= 16;
    else
    if(ovr_delay == 0) s_meter_out <= s_meter_in;

end



endmodule