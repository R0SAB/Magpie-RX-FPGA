module ovr_detector
(
    input wire signed [13:0]adc_in,
    output reg ovr_out,
    input wire clk_70M
);

reg signed [13:0]adc_reg;
wire ovr;
assign ovr = ((adc_reg == 14'd8191 || adc_reg == -14'd8192));

reg [23:0]ovr_delay;
localparam OVR_DELAY = 14000000;


always @ (posedge clk_70M)
begin

    adc_reg <= adc_in;

    if(ovr) ovr_delay <= OVR_DELAY;
    else
    if(ovr_delay > 0) ovr_delay <= ovr_delay - 1;

    if(ovr_delay > 0) ovr_out <= 1;
    else ovr_out <= 0;

end



endmodule