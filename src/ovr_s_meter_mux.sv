module ovr_s_meter_mux
(
    input wire signed [13:0]adc_in,
    input wire [7:0]s_meter_in,
    output reg [7:0]s_meter_out,
    input wire clk_70M
);

reg signed [13:0]adc_reg;
wire ovr;
assign ovr = ((adc_reg == 14'd8191 || adc_reg == -14'd8192));

reg [23:0]ovr_delay;
localparam OVR_DELAY = 14000000;

reg [3:0]s_meter_cnt;
reg [23:0]s_meter_delay;
localparam S_METER_DELAY = 10000000;


always @ (posedge clk_70M)
begin

    adc_reg <= adc_in;

    if(ovr) ovr_delay <= OVR_DELAY;
    else
    if(ovr_delay > 0) ovr_delay <= ovr_delay - 1;

    if(ovr) s_meter_out <= 16;
    else
    if(ovr_delay == 0)
    begin
        
        if(s_meter_in < 16)
        begin
            if(s_meter_cnt < s_meter_in)
            begin
                s_meter_cnt <= s_meter_in;
                s_meter_delay <= 0;
            end
            else
            begin
                if(s_meter_delay < S_METER_DELAY) s_meter_delay <= s_meter_delay + 1;
                if(s_meter_delay == S_METER_DELAY && s_meter_cnt > 0) s_meter_cnt <= s_meter_cnt - 1;
            end
        end

        s_meter_out <= s_meter_cnt;
    end

end



endmodule