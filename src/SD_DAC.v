//This is a Delta-Sigma Digital to Analog Converter
module SD_DAC(DACout, DACin, Clk, en);
output DACout; // This is the average output that feeds low pass filter
reg DACout; // for optimum performance, ensure that this ff is in IOB
input [15:0] DACin; // DAC input (excess 2**MSBI)
input Clk;
input en;
reg [17:0] DeltaAdder; // Output of Delta adder
reg [17:0] SigmaAdder; // Output of Sigma adder
reg [17:0] SigmaLatch; // Latches output of Sigma adder
reg [17:0] DeltaB; // B input of Delta adder
always @(SigmaLatch) DeltaB = {SigmaLatch[17], SigmaLatch[17]} << (16);
always @(DACin or DeltaB) DeltaAdder = DACin + DeltaB;
always @(DeltaAdder or SigmaLatch) SigmaAdder = DeltaAdder + SigmaLatch;
always @(posedge Clk)
begin
if(en) begin
	SigmaLatch <= SigmaAdder;
	DACout <= SigmaLatch[17];
end
end 
endmodule
