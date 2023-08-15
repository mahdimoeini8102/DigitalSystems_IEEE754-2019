`timescale 1ns/1ns

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

module out_wrapper_TB ();
	reg clk = 0;
	reg rst = 0;
	reg doneFP = 0;
	reg resultAccepted = 0;
	reg [31:0] result;
	wire[31:0] outBus, outBus_s;
	wire resultReady, resultReady_s;
	
	out_wrapper_TOP my_ic(clk, rst, doneFP, resultAccepted, result, outBus, resultReady);
	out_wrapper     synth(clk, rst, doneFP, resultAccepted, result, outBus_s, resultReady_s);
	
	always #5 clk <= ~clk;
	initial begin
		#300 rst = 1;
		#300 rst = 0;
		#1300 result = 20;
		#1000 doneFP = 1;
		#1000 doneFP = 0;
		#3000 resultAccepted = 1'b1;
		#3000 resultAccepted = 1'b0;
		#3000 result = 40;
		#1000 doneFP = 1;
		#5000 resultAccepted = 1'b1;
		#5000 $stop;
	end
endmodule