`timescale 1ns/1ns

module mainFPDP (input clk, rst, loadA, loadB, startMul,
				 input [31:0] A, B, output [31:0] result, output doneMul);
				
	reg  [31:0] Areg, Breg;
	reg  [24:0] out;
	wire [7:0] add1, add2;
	//B Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			Breg <= 0;
		else
			if (loadB)
				Breg <= B;
	end
	//A Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			Areg <= 0;
		else
			if (loadA)
				Areg <= A;
	end
	
	xor xor_sign(result[31], Areg[31], Breg[31]);
	
	MULT_TOP seqmult(clk, rst, startMul, Areg[22:0], Breg[22:0], out, doneMul);
	
	assign add1 = Areg[30:23] + Breg[30:23];
	assign add2 = add1 + 8'b10000001;
	assign result[30:23] = add2 + out[24];
	assign result[22:0] = out[24] ? out[23:1] : out[22:0];
endmodule

module mainFPCU ( input clk, rst, startFP, doneMul,
				output reg loadA, loadB, startMul, doneFP);
	
	reg [2:0] pstate, nstate;
	parameter [2:0] Idle  =  0,
					init  =  1,
					A     =  2,
					B     =  3,
					calc  =  4;
	
	always @(pstate, startFP) begin
		nstate = 0;
		{loadA, loadB, startMul, doneFP} = 4'b0;
		
		case (pstate)
			Idle:  begin nstate = startFP ? init : Idle; doneFP = 1'b1; end
			init:  begin nstate = startFP ? init : A; end
			A:     begin nstate = B; loadA = 1'b1; end
			B:	   begin nstate = calc; loadB = 1'b1; end
			calc:  begin nstate = doneMul ? Idle : calc; startMul = 1'b1; end
		endcase
	end
	
	always @(posedge clk, posedge rst) begin
		if (rst)
			pstate <= Idle;
		else
			pstate <= nstate;
	end
endmodule

module mainFP_TOP (input clk, rst, startFP, input [31:0] A, B,
				 output [31:0] result, output doneFP);
	
	wire loadA, loadB, startMul, doneMul;
	mainFPDP dp(clk, rst, loadA, loadB, startMul, A, B, result, doneMul);
	mainFPCU cu(clk, rst, startFP, doneMul, loadA, loadB, startMul, doneFP);

endmodule

module mainFP_TB ();
	reg clk = 0;
	reg rst = 0;
	reg startFP = 0;
	reg [31:0] A;
	reg [31:0] B;
	wire[31:0] result, result_s;
	wire doneFP, doneFP_s;
	
	mainFP_TOP my_ic(clk, rst, startFP, A, B, result, doneFP);
	mainFP     synth(clk, rst, startFP, A, B, result_s, doneFP_s);
	
	always #50 clk <= ~clk;
	initial begin
		#300 rst = 1;
		#300 rst = 0;
		#1300 A = 32'b10000011110000000000000000000000;
		#1300 B = 32'b01110000010000000000000000000000;
		#300  startFP = 1;
		#1300 startFP = 0;
		#5000 $stop;
	end
endmodule