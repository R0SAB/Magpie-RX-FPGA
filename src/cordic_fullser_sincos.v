module cordic_fullser_sincos                           // Конвейерный модуль для расчёта синуса и косинуса из входной фазы. Семпл за такт; задержка - на единицу больше числа ступеней
#(
parameter STAGES = 14,                                  // Количество ступеней
parameter PHASE_MSB = 16,                               // Старший бит фазы (беззнаковый, диапазон от 0 до 2*пи)
parameter OUT_MSB = 13                                  // Старший разряд выходов синуса и косинуса (дополнительный код)
)
(
    input wire [PHASE_MSB:0]phase_in,                   // Входная фаза - полная окружность от 0 до 2*пи, беззнаковая
    input wire [OUT_MSB:0]start_length,                 // Начальная длина вектора - должна быть меньше максимального значения выходов синуса и косинуса на усиление для заданного количества ступеней (см. формулу усиления амплитуды вектора)
    input wire samp_clk,
    input wire clk_H,
    output reg signed [OUT_MSB:0]sin_out,
    output reg signed [OUT_MSB:0]cos_out
);

wire [PHASE_MSB-2:0]atan_full[0:31];                             // Таблица значений арктангенсов от atan(2^0) до atan(2^-31), отнормирована к полной шкале 32 бит для первого значения (пи/4)
localparam ATAN_SHIFT = (32-PHASE_MSB+2);

assign atan_full[0] = 32'd4294967295 >>> ATAN_SHIFT;
assign atan_full[1] = 32'd2535467245 >>> ATAN_SHIFT;
assign atan_full[2] = 32'd1339671259 >>> ATAN_SHIFT;
assign atan_full[3] = 32'd680038049 >>> ATAN_SHIFT;
assign atan_full[4] = 32'd341338648 >>> ATAN_SHIFT;
assign atan_full[5] = 32'd170835723 >>> ATAN_SHIFT;
assign atan_full[6] = 32'd85438707 >>> ATAN_SHIFT;
assign atan_full[7] = 32'd42721961 >>> ATAN_SHIFT;
assign atan_full[8] = 32'd21361306 >>> ATAN_SHIFT;
assign atan_full[9] = 32'd10680694 >>> ATAN_SHIFT;
assign atan_full[10] = 32'd5340352 >>> ATAN_SHIFT;
assign atan_full[11] = 32'd2670177 >>> ATAN_SHIFT;
assign atan_full[12] = 32'd1335088 >>> ATAN_SHIFT;
assign atan_full[13] = 32'd667544 >>> ATAN_SHIFT;
assign atan_full[14] = 32'd333772 >>> ATAN_SHIFT;
assign atan_full[15] = 32'd166886 >>> ATAN_SHIFT;
assign atan_full[16] = 32'd83443 >>> ATAN_SHIFT;
assign atan_full[17] = 32'd41722 >>> ATAN_SHIFT;
assign atan_full[18] = 32'd20861 >>> ATAN_SHIFT;
assign atan_full[19] = 32'd10430 >>> ATAN_SHIFT;
assign atan_full[20] = 32'd5215 >>> ATAN_SHIFT;
assign atan_full[21] = 32'd2608 >>> ATAN_SHIFT;
assign atan_full[22] = 32'd1304 >>> ATAN_SHIFT;
assign atan_full[23] = 32'd652 >>> ATAN_SHIFT;
assign atan_full[24] = 32'd326 >>> ATAN_SHIFT;
assign atan_full[25] = 32'd163 >>> ATAN_SHIFT;
assign atan_full[26] = 32'd81 >>> ATAN_SHIFT;
assign atan_full[27] = 32'd41 >>> ATAN_SHIFT;
assign atan_full[28] = 32'd20 >>> ATAN_SHIFT;
assign atan_full[29] = 32'd10 >>> ATAN_SHIFT;
assign atan_full[30] = 32'd5 >>> ATAN_SHIFT;
assign atan_full[31] = 32'd3 >>> ATAN_SHIFT;


reg [1:0]samp_clk_eg = 0;


reg signed[OUT_MSB:0]cos_buf = 0;                       // Память промежуточных значений синуса и косинуса
reg signed[OUT_MSB:0]sin_buf = 0;
reg sign = 0;                                           // Знак приращения угла следующей итерации для каждой ступени
reg signed [OUT_MSB:0]sin_shift = 0;                    // Сдвинутые синус и косинус для каждой ступени
reg signed [OUT_MSB:0]cos_shift = 0;

reg signed [PHASE_MSB-1:0]angle_fb_buf;             // Память для ошибки угла (угол обратной связи - feedback angle)
wire [1:0]quadrant;                                             // Квадрант, в котором находится входная фаза
reg [1:0]quadrant_buf;


wire signed [PHASE_MSB-1:0]cordic_angle;                            // Аргумент кордика - входная фаза, усечённая до диапазона пи/4 (отбрасыванием двух старших разрядов)
assign cordic_angle[PHASE_MSB-2:0] = phase_in[PHASE_MSB-2:0];       
assign cordic_angle[PHASE_MSB-1] = 0;                               // Разрядность аргумента (и памяти ошибки угла) на бит больше - для избежания переполнения около нуля
assign quadrant = phase_in[PHASE_MSB:PHASE_MSB-1];                  // Квадрант - старшие два бита фазы



reg [5:0]shift_cnt = 0;
reg [5:0]stage = 0;
reg shift_inh = 0;

always @ *                                                        // Комбинационная схема определения знака приращения угла для каждой ступени и комбинационные фиксированные сдвиги промежуточных значений синуса и косинуса
begin
        if(angle_fb_buf > 0) sign <= 1;                       // Условие сходимости - угол устремляется к нулю
        else sign <= 0;
end


always @ (posedge clk_H)
begin
    
    samp_clk_eg <= samp_clk_eg << 1;
    samp_clk_eg[0] <= samp_clk;

    if(samp_clk_eg == 2'b01)
    begin
        shift_cnt <= 0;
        stage <= 0;
        shift_inh <= 1;

        case(quadrant_buf)
        2'd0: begin cos_out <= cos_buf; sin_out <= sin_buf; end             // Разворачивание конечных значений синуса и косинуса из первого квадранта в исходные, согласно задержанному сигналу квадранта
        2'd1: begin cos_out <= -sin_buf; sin_out <= cos_buf; end
        2'd2: begin cos_out <= -cos_buf; sin_out <= -sin_buf; end
        2'd3: begin cos_out <= sin_buf; sin_out <= -cos_buf; end
        endcase

        angle_fb_buf <= cordic_angle;
        sin_buf <= 0;
        cos_buf <= start_length;
        sin_shift <= 0;
        cos_shift <= start_length;
        
        quadrant_buf <= quadrant;
    end
    else
    begin
        if(shift_cnt == (stage))
        begin
            stage <= stage + 1'd1;
            shift_cnt <= 0;
            shift_inh <= 1;

            if(sign)
            begin
                angle_fb_buf <= angle_fb_buf - atan_full[stage];

                cos_buf <= cos_buf - sin_shift;
                sin_buf <= sin_buf + cos_shift;
            end
            else
            begin
                angle_fb_buf <= angle_fb_buf + atan_full[stage];

                cos_buf <= cos_buf + sin_shift;
                sin_buf <= sin_buf - cos_shift;
            end


        end
        else
        if(stage < STAGES)
        begin
            shift_inh <= 0;

            if(shift_inh)
            begin
                sin_shift <= sin_buf;
                cos_shift <= cos_buf;
            end
            else
            begin
                shift_cnt <= shift_cnt + 1'd1;
                sin_shift <= sin_shift >>> 1;
                cos_shift <= cos_shift >>> 1;
            end
        end
    end



end



endmodule