/*
Обычный децимирующий CIC.
Полностью синхронный по samp_clk_H ("высокому" семпловому клоку).
При синтезе втоматически рассчитывает необходимую разрядность интеграторов и гребёнок.
Забирает входные семплы по samp_clk_H и выводит выходные по фронту samp_clk_L плюс такт samp_clk_H 
*/


module CIC_decim
#(
parameter ORDER = 3,
parameter DELAY = 54,
parameter IN_MSB = 15,
parameter OUT_MSB = 20
)
( 
input wire signed [IN_MSB:0]in,  
input wire samp_clk_L,
input wire samp_clk_H,				 
output wire [OUT_MSB:0]out 
);


localparam GAIN_BITS = $clog2(DELAY**ORDER);


reg signed [IN_MSB+GAIN_BITS:0]itgr[0:ORDER-1];  

reg signed [IN_MSB+GAIN_BITS:0]comb[0:ORDER-1][0:2];


integer a;

initial begin
    for (a=0; a<ORDER; a=a+1)
    begin
        comb[a][0] = 0;
        comb[a][1] = 0;
        comb[a][2] = 0;
        itgr[a] = 0;
    end
end


reg signed [IN_MSB+GAIN_BITS:0]buffer = 0;
reg signed [IN_MSB+GAIN_BITS:0]sum = 0;
    
assign out[OUT_MSB:0] = sum[IN_MSB+GAIN_BITS:IN_MSB+GAIN_BITS-OUT_MSB];

always @ *
begin
sum <= buffer + (1<<<(IN_MSB+GAIN_BITS-OUT_MSB-1));
end

reg [1:0]samp_clk_L_eg = 2'd0;

integer i = 0;
integer k = 0;

always @ (posedge samp_clk_H)
begin   

        samp_clk_L_eg <= samp_clk_L_eg << 1;
        samp_clk_L_eg[0] <= samp_clk_L;

    if(samp_clk_L_eg == 2'b01)
    begin

			comb[0][0] <= itgr[ORDER-1];
			comb[0][1] <= comb[0][0];
			comb[0][2] <= comb[0][1];


        for(i=1; i<ORDER; i=i+1)
        begin
            comb[i][0] <= comb[i-1][0] - comb[i-1][2];
            comb[i][1] <= comb[i][0];
            comb[i][2] <= comb[i][1];
        end

        buffer <= comb[ORDER-1][0] - comb[ORDER-1][2];
	end	
		
		itgr[0] <= itgr[0] + in;


        for(k=1; k<ORDER; k=k+1)
        begin
            itgr[k] <= itgr[k] + itgr[k-1];
        end

end

endmodule
