module soft_clip (
    input  logic               samp_clk,
    input  logic signed [15:0] audio_in,
    output logic signed [15:0] audio_out
);

    // Модуль входного сигнала
    logic signed [16:0] x_ext;
    logic        [16:0] abs_in;

    assign x_ext  = {audio_in[15], audio_in};
    assign abs_in = x_ext[16] ? -x_ext : x_ext;


    // Стадия 1
    logic [16:0] abs_d1;
    logic [12:0] q_d1;
    logic        sign_d1;

    // Стадия 2
    logic [25:0] square_d2;
    logic [16:0] abs_d2;
    logic        sign_d2;

    // Стадия 3
    logic [15:0] limited;

    assign limited = (abs_d2 <= 17'd24576)
                   ? abs_d2[15:0]
                   : 16'd28672 - square_d2[25:14];


    always_ff @(posedge samp_clk) begin

        // 1. Подготовка
        abs_d1  <= abs_in;
        sign_d1 <= audio_in[15];

        q_d1 <= (abs_in > 17'd24576)
              ? (17'd32768 - abs_in)
              : 13'd0;


        // 2. Синхронный умножитель
        square_d2 <= q_d1 * q_d1;

        abs_d2  <= abs_d1;
        sign_d2 <= sign_d1;


        // 3. Выходной регистр
        audio_out <= sign_d2
                   ? -$signed(limited)
                   :  $signed(limited);

    end

endmodule