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
	
	MULT_TOP seqmult(clk, rst, startMul, Areg[22:0], Breg[22:0], out[24:0], doneMul);
	
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

module in_wrapperDP ( input clk, rst, loadx, loady,
					input [31:0] inBus, output [31:0] xin, yin);
				
	reg  [23:0] xreg, yreg;
	//x Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			xreg <= 0;
		else
			if (loadx)
				xreg <= inBus;
	end
	//y Register
	always @(posedge clk, posedge rst) begin
		if (rst)
			yreg <= 0;
		else
			if (loady)
				yreg <= inBus;
	end
	
	assign xin = xreg;
	assign yin = yreg;
	
endmodule

module in_wrapperCU ( input clk, rst, inReady,
					  output reg loadx, loady, inAccepted, startFP);
	
	reg [2:0] pstate, nstate;
	parameter [2:0] Idle    = 0,
					x       = 1,
					acceptx = 2,
					Idle2   = 3,
					y 		= 4,
					accepty = 5;
	
	always @(pstate, inReady) begin
		nstate = 0;
		{loadx, loady, inAccepted, startFP} = 4'b0;
		
		case (pstate)
			Idle:   begin nstate = inReady ? x : Idle; inAccepted = 1'b0; end
			x:      begin nstate = acceptx; loadx = 1'b1; end
			acceptx:begin nstate = inReady ? acceptx : Idle2; inAccepted = 1'b1; end
			Idle2:  begin nstate = inReady ? y : Idle2; inAccepted = 1'b0; end
			y:      begin nstate = accepty; loady = 1'b1; end
			accepty:begin nstate = inReady ? accepty : Idle; inAccepted = 1'b1; startFP = 1'b1; end
		endcase
	end
	
	always @(posedge clk, posedge rst) begin
		if (rst)
			pstate <= Idle;
		else
			pstate <= nstate;
	end

endmodule

module in_wrapper_TOP (input clk, rst, inReady, input [31:0] inBus,
				 output [31:0] xin, yin, output inAccepted, startFP);

	wire loadx, loady;
	in_wrapperDP dp(clk, rst, loadx, loady, inBus, xin, yin);
	in_wrapperCU cu(clk, rst, inReady, loadx, loady, inAccepted, startFP);

endmodule

module out_wrapperDP ( input clk, rst, loadout,
					   input [31:0] result, output [31:0] outBus);
	
	reg [31:0] outreg;
	//out Register
	always @(posedge clk, posedge rst) begin
		if (loadout)
			outreg <= result;
	end
	assign outBus = outreg;
	
endmodule

module out_wrapperCU ( input clk, rst, doneFP, resultAccepted,
					   output reg loadout, resultReady);
	
	reg [1:0] pstate, nstate;
	parameter [1:0] Idle   = 0,
					load   = 1,
					accept = 2,
					finish = 3;
	
	always @(pstate, doneFP, resultAccepted) begin
		nstate = 0;
		{loadout, resultReady} = 2'b0;
		
		case (pstate)
			Idle:   begin nstate = doneFP ? load : Idle; end
			load:   begin nstate = accept; loadout = 1'b1; end
			accept: begin nstate = resultAccepted ? finish : accept; resultReady = 1'b1; end
			finish: begin nstate = resultAccepted ? finish : Idle; resultReady = 1'b0; end
		endcase
	end
	
	always @(posedge clk, posedge rst) begin
		if (rst)
			pstate <= Idle;
		else
			pstate <= nstate;
	end

endmodule

module out_wrapper_TOP (input clk, rst, doneFP, resultAccepted, input [31:0] result,
				 output [31:0] outBus, output resultReady);

	wire loadout;
	out_wrapperDP dp(clk, rst, loadout, result, outBus);
	out_wrapperCU cu(clk, rst, doneFP, resultAccepted, loadout, resultReady);

endmodule

module complete_TOP(input clk, rst, inReady, resultAccepted, input [31:0] inBus, output [31:0] outBus, output inAccepted, resultReady);
	wire [31:0] xin, yin, result;
	wire startFP, doneFP;
	in_wrapper_TOP in_wrapper(clk, rst, inReady, inBus, xin, yin, inAccepted, startFP);
	mainFP_TOP mainFP(clk, rst, startFP, xin, yin, result, doneFP);
	out_wrapper_TOP out_wrapper(clk, rst, doneFP, resultAccepted, result, outBus, resultReady);
endmodule

module complete_TB ();
	reg clk = 0;
	reg rst = 0;
	reg inReady = 0;
	reg resultAccepted = 0;
	reg [31:0] inBus;
	wire inAccepted;
	wire resultReady;
	wire [31:0] outBus;
	
	complete_TOP my_ic(clk, rst, inReady, resultAccepted, inBus, outBus, inAccepted, resultReady);
	
	always #50 clk <= ~clk;
	initial begin
		#30 rst = 1;
		#30 rst = 0;
		#130 inBus = 50;
		#100 inReady = 1;
		#100 inReady = 0;
		#130 inBus = 60;
		#100 inReady = 1;
		#100 inReady = 0;
		#500 resultAccepted = 1;
		#100 resultAccepted = 0;
		#500 $stop;
	end
endmodule