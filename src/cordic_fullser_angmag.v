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

wire signed [31:0] atan_full [0:31];

assign atan_full[0]  = 32'sd536870912;  // atan(2^0)
assign atan_full[1]  = 32'sd316933406;  // atan(2^-1)
assign atan_full[2]  = 32'sd167458907;  // atan(2^-2)
assign atan_full[3]  = 32'sd85004756;   // atan(2^-3)
assign atan_full[4]  = 32'sd42667331;   // atan(2^-4)
assign atan_full[5]  = 32'sd21354465;   // atan(2^-5)
assign atan_full[6]  = 32'sd10679838;   // atan(2^-6)
assign atan_full[7]  = 32'sd5340245;    // atan(2^-7)
assign atan_full[8]  = 32'sd2670163;    // atan(2^-8)
assign atan_full[9]  = 32'sd1335087;    // atan(2^-9)
assign atan_full[10] = 32'sd665817;     // atan(2^-10)
assign atan_full[11] = 32'sd332912;     // atan(2^-11)
assign atan_full[12] = 32'sd166456;     // atan(2^-12)
assign atan_full[13] = 32'sd83228;      // atan(2^-13)
assign atan_full[14] = 32'sd41614;      // atan(2^-14)
assign atan_full[15] = 32'sd20807;      // atan(2^-15)
assign atan_full[16] = 32'sd10404;      // atan(2^-16)
assign atan_full[17] = 32'sd5202;       // atan(2^-17)
assign atan_full[18] = 32'sd2601;       // atan(2^-18)
assign atan_full[19] = 32'sd1301;       // atan(2^-19)
assign atan_full[20] = 32'sd650;        // atan(2^-20)
assign atan_full[21] = 32'sd325;        // atan(2^-21)
assign atan_full[22] = 32'sd163;        // atan(2^-22)
assign atan_full[23] = 32'sd81;         // atan(2^-23)
assign atan_full[24] = 32'sd41;         // atan(2^-24)
assign atan_full[25] = 32'sd20;         // atan(2^-25)
assign atan_full[26] = 32'sd10;         // atan(2^-26)
assign atan_full[27] = 32'sd5;          // atan(2^-27)
assign atan_full[28] = 32'sd3;          // atan(2^-28)
assign atan_full[29] = 32'sd1;          // atan(2^-29)
assign atan_full[30] = 32'sd1;          // atan(2^-30)
assign atan_full[31] = 32'sd0;          // atan(2^-31)


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