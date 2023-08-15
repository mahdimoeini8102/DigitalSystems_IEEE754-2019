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

module MULT_TOP (input clk, rst, startMul, input [22:0] A, B,
				 output [24:0] result, output doneMul);

	wire A0;
	wire loadA, shiftA, loadB, loadP, initP, BSel;
	MULTDP dp(clk, rst, loadA, loadB, loadP, shiftA, initP, BSel, A, B, result, A0);
	MULTCU cu(clk, rst, startMul, A0, loadA, shiftA, loadB, loadP, initP, BSel, doneMul);

endmodule

module MULT_TB ();
	reg clk = 0;
	reg rst = 0;
	reg startMul = 0;
	reg [22:0] A;
	reg [22:0] B;
	wire[24:0] result, result_s;
	wire doneMul, doneMul_s;
	
	MULT_TOP my_ic(clk, rst, startMul, A, B, result, doneMul);
	seqmult  synth(clk, rst, startMul, A, B, result_s, doneMul_s);
	
	always #5 clk <= ~clk;
	initial begin
		#300 rst = 1;
		#300 rst = 0;
		#1300 A = 23'b10000000000000000000000;
		#1300 B = 23'b10000000000000000000000;
		#300  startMul = 1;
		#1300 startMul = 0;
		#50000 $stop;
	end
endmodule