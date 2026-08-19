module cordic_fullser_angmag                           // Конвейерный модуль для расчёта синуса и косинуса из входной фазы. Семпл за такт; задержка - на единицу больше числа ступеней
#(
parameter STAGES = 20,                  // Количество ступеней          
parameter ANG_MSB = 20,                 // Разрядность выходной фазы
parameter IN_MSB = 20                   // Разрядность входных синуса и косинуса
)
(
    input wire signed [IN_MSB:0]sin_in,     // Входные синус и косинус
    input wire signed [IN_MSB:0]cos_in,
    output reg signed [ANG_MSB:0]ang_out,       // Выходная фаза, знаковая, диапазон от минус пи до пи
    output reg [IN_MSB+1:0]mag_out,             // Выходная длина вектора, на бит больше синуса и косинуса (см. формулу усиления амплитуды вектора)
    input wire samp_clk,
    input wire clk_H
);

wire [ANG_MSB-1:0]atan_full[0:31];                             // Таблица значений арктангенсов от atan(2^0) до atan(2^-31), отнормирована к полной шкале 32 бит для первого значения (пи/4)
localparam ATAN_SHIFT = (32-ANG_MSB+2);

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


reg [1:0]samp_clk_eg = 0;


reg signed[IN_MSB+1:0]cos_buf = 0;                       // Память промежуточных значений синуса и косинуса
reg signed[IN_MSB+1:0]sin_buf = 0;
reg sign = 0;                                           // Знак приращения угла следующей итерации для каждой ступени
reg signed [IN_MSB+1:0]sin_shift = 0;                    // Сдвинутые синус и косинус для каждой ступени
reg signed [IN_MSB+1:0]cos_shift = 0;

reg signed [31:0]angle_buf = 0;             // Память для ошибки угла (угол обратной связи - feedback angle)
reg signed [31:0]angle_unwrapped = 0;
wire signed [ANG_MSB:0]angle_trunc;
assign angle_trunc = angle_unwrapped[31:31-ANG_MSB];
wire [1:0]quadrant;                                             // Квадрант, в котором находится входная фаза
reg [1:0]quadrant_buf;
                               
assign quadrant = {cos_in[IN_MSB], sin_in[IN_MSB]};                  // Квадрант - старшие два бита фазы



reg [5:0]shift_cnt = 0;
reg [5:0]stage = 0;
reg shift_inh = 0;

always @ *                                                        // Комбинационная схема определения знака приращения угла для каждой ступени и комбинационные фиксированные сдвиги промежуточных значений синуса и косинуса
begin
        if(sin_buf < 0) sign <= 0;                       // Условие сходимости - угол устремляется к нулю
        else sign <= 1;
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

        case(quadrant_buf)                                                                // Выходное значение фазы - разворачивается из первого квадранта в исходный, в зависимости от задержанного сигнала квадранта
        2'd0: angle_unwrapped <= angle_buf;                       // Поворот не требуется
        2'd2: angle_unwrapped <= angle_buf + (2**(31-1));    // +пи/2
        2'd3: angle_unwrapped <= angle_buf - (2**(31));      // -пи
        2'd1: angle_unwrapped <= angle_buf - (2**(31-1));    // -пи-2
        endcase

        ang_out <= angle_trunc;

        mag_out <= cos_buf;

        case(quadrant)                                                                  // В зависимости от квадранта - входные синус и косинус меняются местами, а также меняются их знаки, - для поворота входного вектора в первый квадрант
        2'd0: begin cos_buf <= cos_in;  sin_buf <=  sin_in; cos_shift <= cos_in;  sin_shift <=  sin_in; end
        2'd2: begin cos_buf <= sin_in;  sin_buf <= -cos_in; cos_shift <= sin_in;  sin_shift <= -cos_in; end
        2'd3: begin cos_buf <= -cos_in; sin_buf <= -sin_in; cos_shift <= -cos_in; sin_shift <= -sin_in; end
        2'd1: begin cos_buf <= -sin_in; sin_buf <=  cos_in; cos_shift <= -sin_in; sin_shift <=  cos_in; end
        endcase

        angle_buf <= 0;
        //sin_buf <= sin_in;
        //cos_buf <= cos_in;
        //sin_shift <= sin_in;
        //cos_shift <= cos_in;
        
        quadrant_buf <= quadrant;
    end
    else
    begin
        if(shift_cnt == (stage))
        begin
            stage <= stage + 1'd1;
            shift_cnt <= 0;
            shift_inh <= 1;

            if(~sign)
            begin
                angle_buf <= angle_buf - atan_full[stage];

                cos_buf <= cos_buf - sin_shift;
                sin_buf <= sin_buf + cos_shift;
            end
            else
            begin
                angle_buf <= angle_buf + atan_full[stage];

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
                sin_shift <= (sin_shift + 1) >>> 1;
                cos_shift <= (cos_shift + 1) >>> 1;
            end
        end
    end



end



endmodule