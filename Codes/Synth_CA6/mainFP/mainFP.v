`timescale 1ns/1ns

`timescale 1ns/1ns

module MULTDP ( input clk, rst, loadA, loadB, loadP, shiftA, initP, BSel,
				input [22:0] ABus, BBus, output [24:0] result, output A0);
				
	reg  [23:0] Areg, Breg, Preg;
	wire [23:0] B_AND;
	wire [24:0] AddBus;
	//B Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			Breg <= 0;
		else
			if (loadB)
				Breg <= {1'b1, BBus};
	end
	//P Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			Preg <= 0;
		else begin
			if (initP)
				Preg <= 0;
			else
				if (loadP)
					Preg <= AddBus [24:1];
		end
	end
	//A Shift Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			Areg <= 0;
		else begin
			if (loadA)
				Areg <= {1'b1, ABus};
			else
				if (shiftA)
					Areg <= {AddBus[0], Areg [23:1]};
		end
	end
	
	assign B_AND = BSel ? Breg : 0;
	assign AddBus = B_AND + Preg;
	assign result = {Preg[15:0], Areg[23:15]};
	assign A0 = Areg[0];
	
endmodule

module MULTCU ( input clk, rst, startMul, A0,
				output reg loadA, shiftA, loadB, loadP, initP, BSel, doneMul);
	
	wire Co;
	reg Init_cnt, Inc_cnt;
	reg [1:0] pstate, nstate;
	reg [4:0] count;
	parameter [1:0] Idle  =  0,
					init  =  1,
					load  =  2,
					shift =  3;
	
	always @(pstate, startMul, A0, Co) begin
		nstate = 0;
		{loadA, shiftA, loadB, loadP, initP, BSel, doneMul} = 7'b0;
		{Init_cnt, Inc_cnt} = 2'b0;
		
		case (pstate)
			Idle:  begin nstate = startMul ? init : Idle; doneMul = 1'b1; end
			init:  begin nstate = startMul ? init : load; Init_cnt = 1'b1; initP = 1'b1; end
			load:  begin nstate = shift; loadA = 1'b1; loadB = 1'b1; end
			shift: begin nstate = Co ? Idle : shift; loadP = 1'b1;
						 shiftA = 1'b1; Inc_cnt = 1'b1; BSel = A0; end
		endcase
	end
	
	always @(posedge clk, posedge rst) begin
		if (rst)
			pstate <= Idle;
		else
			pstate <= nstate;
	end
	
	always @(posedge clk, posedge rst) begin
		if(rst) count <= 0;
		else
			if (Init_cnt) count <= 0;
			else
				if (Inc_cnt) count <= count + 1;
	end
	
	assign Co = & count;
endmodule

module seqmult (input clk, rst, startMul, input [22:0] A, B,
				 output [24:0] result, output doneMul);

	wire A0;
	wire loadA, shiftA, loadB, loadP, initP, BSel;
	MULTDP dp(clk, rst, loadA, loadB, loadP, shiftA, initP, BSel, A, B, result, A0);
	MULTCU cu(clk, rst, startMul, A0, loadA, shiftA, loadB, loadP, initP, BSel, doneMul);

endmodule

module mainFPDP (input clk, rst, loadA, loadB, startMul,
				 input [31:0] A, B, output [31:0] result, output doneMul);
				
	reg  [31:0] Areg, Breg;
	wire  [24:0] out;
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
	
	seqmult seqmult1(clk, rst, startMul, Areg[22:0], Breg[22:0], out[24:0], doneMul);
	
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

module mainFP (input clk, rst, startFP, input [31:0] A, B,
				 output [31:0] result, output doneFP);
	
	wire loadA, loadB, startMul, doneMul;
	mainFPDP dp(clk, rst, loadA, loadB, startMul, A, B, result, doneMul);
	mainFPCU cu(clk, rst, startFP, doneMul, loadA, loadB, startMul, doneFP);

endmodule