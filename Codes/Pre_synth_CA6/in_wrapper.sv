`timescale 1ns/1ns

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

module in_wrapper_TB ();
	reg clk = 0;
	reg rst = 0;
	reg inReady = 0;
	reg [31:0] inBus;
	wire[31:0] xin, yin;
	wire inAccepted;
	wire startFP;
	
	in_wrapper_TOP my_ic(clk, rst, inReady, inBus, xin, yin, inAccepted, startFP);
	
	always #5 clk <= ~clk;
	initial begin
		#3 rst = 1;
		#3 rst = 0;
		#13 inBus = 20;
		#10 inReady = 1;
		#30 inReady = 0;
		#30 inBus = 100;
		#10 inReady = 1;
		#30 inReady = 0;
		#500 $stop;
	end
endmodule