module fir
#(
	parameter ORDER = 20,
	parameter IN_MSB = 15,
	parameter OUT_MSB = 15,
	parameter TAPS_MSB = 15,
	parameter GAIN_BITS = 0,
	parameter ROM_FILE = "file.txt",
	parameter SAMP_SKIP = 0
)
(
	input wire clk_H,
	input wire samp_clk,
	input wire signed [IN_MSB:0]in_1,
	input wire signed [IN_MSB:0]in_2,
	output reg signed [OUT_MSB:0]out_1,
	output reg signed [OUT_MSB:0]out_2
	
);


localparam ORDER_BITS = $clog2(ORDER+2);

reg [ORDER_BITS:0]fsm_cnt = 0;

reg signed [TAPS_MSB:0]rom[0:ORDER];
reg signed [TAPS_MSB:0]rom_aux[0:ORDER];
reg [ORDER_BITS-1:0]rom_addr = 0;

reg signed [IN_MSB:0]ram_1[0:ORDER];
reg signed [IN_MSB:0]ram_2[0:ORDER];
reg [ORDER_BITS-1:0]ram_addr = 0;
reg wren = 0;
reg signed [IN_MSB:0]in_buf_1 = 0;
reg signed [IN_MSB:0]in_buf_2 = 0;

reg signed [IN_MSB:0]ram_read_1 = 0;
reg signed [IN_MSB:0]ram_read_2 = 0;
reg signed [TAPS_MSB:0]rom_read = 0;

reg signed [IN_MSB+TAPS_MSB:0]mult_1 = 0;
reg signed [IN_MSB+TAPS_MSB:0]mult_2 = 0;
reg signed [IN_MSB+TAPS_MSB+GAIN_BITS:0]acc_1 = 0;
reg signed [IN_MSB+TAPS_MSB+GAIN_BITS:0]acc_2 = 0;
reg signed [IN_MSB+TAPS_MSB+GAIN_BITS:0]round_1 = 0;
reg signed [IN_MSB+TAPS_MSB+GAIN_BITS:0]round_2 = 0;

reg [1:0]samp_clk_eg = 0;

reg [7:0]skip_div;


always @ (posedge clk_H)
begin
	
	samp_clk_eg <= samp_clk_eg << 1;			// samp_clk edge detection
	samp_clk_eg[0] <= samp_clk;

	if(samp_clk_eg == 2'b01) fsm_cnt <= 0;			// FSM counter
	else
	if(~&fsm_cnt) fsm_cnt <= fsm_cnt + 1'd1;


	if(samp_clk_eg == 2'b01) rom_addr <= 0;				// ROM address counter
	else
	if(rom_addr < ORDER) rom_addr <= rom_addr + 1'd1;


	if(fsm_cnt < ORDER)									// RAM address counter
	begin
		if(ram_addr < ORDER) ram_addr <= ram_addr + 1'd1;
		else ram_addr <= 0;
	end

	if(fsm_cnt == ORDER+1) wren <= 1;						// Write Enable of RAM
	else wren <= 0;


	if(samp_clk_eg == 2'b01)
	begin
		if(skip_div < (SAMP_SKIP)) skip_div <= skip_div + 1'd1;
		else skip_div <= 0;

		if(skip_div == 0)
		begin
			in_buf_1 <= in_1;					// Buffer of input sample and RAM read/write operation
			in_buf_2 <= in_2;
		end
		else
		begin
			in_buf_1 <= 0;					// Buffer of input sample and RAM read/write operation
			in_buf_2 <= 0;
		end
	end

	if(wren)
	begin
		ram_1[ram_addr] <= in_buf_1;
		ram_2[ram_addr] <= in_buf_2;
	end
	else 
	begin
		ram_read_1 <= ram_1[ram_addr];
		ram_read_2 <= ram_2[ram_addr];
	end


	rom_read <= rom[rom_addr];								// Read operation of ROM


	if(samp_clk_eg == 2'b01)													// Accumulator operation and output sample
	begin
		round_1 <= acc_1 + (1<<<(TAPS_MSB+GAIN_BITS-OUT_MSB-1));
		round_2 <= acc_2 + (1<<<(TAPS_MSB+GAIN_BITS-OUT_MSB-1));
		out_1[OUT_MSB:0] <= round_1[IN_MSB+TAPS_MSB+GAIN_BITS : IN_MSB+TAPS_MSB+GAIN_BITS-OUT_MSB];
		out_2[OUT_MSB:0] <= round_2[IN_MSB+TAPS_MSB+GAIN_BITS : IN_MSB+TAPS_MSB+GAIN_BITS-OUT_MSB];
	end

	if(fsm_cnt == 1)
	begin
		acc_1 <= 0;
		acc_2 <= 0;
	end
	else
	if(fsm_cnt < ORDER + 3)
	begin
		acc_1 <= acc_1 + mult_1;
		acc_2 <= acc_2 + mult_2;
	end

								
	mult_1 <= ram_read_1 * rom_read;										// Multiplier operation
	mult_2 <= ram_read_2 * rom_read;




end




// ########################## ROM INIT ####################

        
initial $readmemb(ROM_FILE, /*rom_aux*/rom); 
/*
genvar lol;

generate
    for(lol=0; lol<ORDER+1; lol=lol+1)
    begin:kek
		  always @ * rom[lol] <= rom_aux[lol];
    end
endgenerate
*/



endmodule




/*

fir_simple_2ch
#(
	.IN_MSB(),
	.OUT_MSB(),
	.TAPS_MSB(),
	.ORDER(),
	.GAIN_BITS(),
	.ROM_FILE("file.txt")
)
inst_fir_test
(
	.clk_H(),
	.samp_clk(),
	.in_1(),
	.in_2(),
	.out_1(),
	.out_2()
);

*/
