module cordic_pipeline_sincos                           // Конвейерный модуль для расчёта синуса и косинуса из входной фазы. Семпл за такт; задержка - на единицу больше числа ступеней
#(
parameter STAGES = 14,                                  // Количество ступеней
parameter PHASE_MSB = 16,                               // Старший бит фазы (беззнаковый, диапазон от 0 до 2*пи)
parameter OUT_MSB = 13                                  // Старший разряд выходов синуса и косинуса (дополнительный код)
)
(
    input wire [PHASE_MSB:0]phase_in,                   // Входная фаза - полная окружность от 0 до 2*пи, беззнаковая
    input wire [OUT_MSB:0]start_length,                 // Начальная длина вектора - должна быть меньше максимального значения выходов синуса и косинуса на усиление для заданного количества ступеней (см. формулу усиления амплитуды вектора)
    input wire clk_H,
    output reg signed [OUT_MSB:0]sin_out,
    output reg signed [OUT_MSB:0]cos_out
);

wire [31:0]atan_full[0:31];                             // Таблица значений арктангенсов от atan(2^0) до atan(2^-31), отнормирована к полной шкале 32 бит для первого значения (пи/4)

assign atan_full[0] = 32'd4294967295;
assign atan_full[1] = 32'd2535467245;
assign atan_full[2] = 32'd1339671259;
assign atan_full[3] = 32'd680038049;
assign atan_full[4] = 32'd341338648;
assign atan_full[5] = 32'd170835723;
assign atan_full[6] = 32'd85438707;
assign atan_full[7] = 32'd42721961;
assign atan_full[8] = 32'd21361306;
assign atan_full[9] = 32'd10680694;
assign atan_full[10] = 32'd5340352;
assign atan_full[11] = 32'd2670177;
assign atan_full[12] = 32'd1335088;
assign atan_full[13] = 32'd667544;
assign atan_full[14] = 32'd333772;
assign atan_full[15] = 32'd166886;
assign atan_full[16] = 32'd83443;
assign atan_full[17] = 32'd41722;
assign atan_full[18] = 32'd20861;
assign atan_full[19] = 32'd10430;
assign atan_full[20] = 32'd5215;
assign atan_full[21] = 32'd2608;
assign atan_full[22] = 32'd1304;
assign atan_full[23] = 32'd652;
assign atan_full[24] = 32'd326;
assign atan_full[25] = 32'd163;
assign atan_full[26] = 32'd81;
assign atan_full[27] = 32'd41;
assign atan_full[28] = 32'd20;
assign atan_full[29] = 32'd10;
assign atan_full[30] = 32'd5;
assign atan_full[31] = 32'd3;



reg signed[OUT_MSB:0]cos_buf[0:STAGES-1];                       // Память промежуточных значений синуса и косинуса
reg signed[OUT_MSB:0]sin_buf[0:STAGES-1];
reg [STAGES-2:0]sign;                                           // Знак приращения угла следующей итерации для каждой ступени
reg signed [OUT_MSB:0]sin_shift[0:STAGES-1];                    // Сдвинутые синус и косинус для каждой ступени
reg signed [OUT_MSB:0]cos_shift[0:STAGES-1];

reg signed [PHASE_MSB-1:0]angle_fb_buf[0:STAGES-1];             // Память для ошибки угла (угол обратной связи - feedback angle)
wire [1:0]quadrant;                                             // Квадрант, в котором находится входная фаза
reg [1:0]quadrant_buf[0:STAGES-1];                              // Память квадрантов, FIFO без отводов, для перевода рассчитанных синуса и косинуса из первого квадранта в исходные в конце конвейера


wire signed [PHASE_MSB-1:0]cordic_angle;                            // Аргумент кордика - входная фаза, усечённая до диапазона пи/4 (отбрасыванием двух старших разрядов)
assign cordic_angle[PHASE_MSB-2:0] = phase_in[PHASE_MSB-2:0];       
assign cordic_angle[PHASE_MSB-1] = 0;                               // Разрядность аргумента (и памяти ошибки угла) на бит больше - для избежания переполнения около нуля
assign quadrant = phase_in[PHASE_MSB:PHASE_MSB-1];                  // Квадрант - старшие два бита фазы

integer i = 0;
integer k = 0;

always @ *                                                          // Комбинационная схема определения знака приращения угла для каждой ступени и комбинационные фиксированные сдвиги промежуточных значений синуса и косинуса
begin
    for(i=0; i<STAGES-1; i=i+1)
    begin
        if(angle_fb_buf[i] > 0) sign[i] <= 1;                       // Условие сходимости - угол устремляется к нулю
        else sign[i] <= 0;

        sin_shift[i] <= sin_buf[i] >>> i;
        cos_shift[i] <= cos_buf[i] >>> i;
    end
end



always @ (posedge clk_H)
begin
    
    angle_fb_buf[0] <= cordic_angle;                                // Запись угла в начало памяти ошибки угла

    quadrant_buf[0] <= quadrant;                                    // Запись квадранта в начало памяти

    cos_buf[0] <= start_length;                                     // Параметры начального вектора - синус равен нулю, а косинус - произвольному значению (ограничение см. в списке портов)
    sin_buf[0] <= 0;

    for(k=0; k<STAGES-1; k=k+1)                                     // В зависимости от знака приращения угла, для каждой ступени, - коррекция угла и синуса с косинусом. Значения арктангенсов перенормированы с учётом разрядности входной фазы, путём фиксированного для всех ступеней сдвига
    begin
        quadrant_buf[k+1] <= quadrant_buf[k];

        if(sign[k])
            begin
                angle_fb_buf[k+1] <= angle_fb_buf[k] - (atan_full[k] >>> (32-PHASE_MSB+2));

                cos_buf[k+1] <= cos_buf[k] - sin_shift[k];
                sin_buf[k+1] <= sin_buf[k] + cos_shift[k];
            end
            else
            begin
                angle_fb_buf[k+1] <= angle_fb_buf[k] + (atan_full[k] >>> (32-PHASE_MSB+2));

                cos_buf[k+1] <= cos_buf[k] + sin_shift[k];
                sin_buf[k+1] <= sin_buf[k] - cos_shift[k];
            end
    end
    
    case(quadrant_buf[STAGES-1])
        2'd0: begin cos_out <= cos_buf[STAGES-1]; sin_out <= sin_buf[STAGES-1]; end             // Разворачивание конечных значений синуса и косинуса из первого квадранта в исходные, согласно задержанному сигналу квадранта
        2'd1: begin cos_out <= -sin_buf[STAGES-1]; sin_out <= cos_buf[STAGES-1]; end
        2'd2: begin cos_out <= -cos_buf[STAGES-1]; sin_out <= -sin_buf[STAGES-1]; end
        2'd3: begin cos_out <= sin_buf[STAGES-1]; sin_out <= -cos_buf[STAGES-1]; end
    endcase
    

end


endmodule