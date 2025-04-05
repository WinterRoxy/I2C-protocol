`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:01:10 07/08/2024
// Design Name:   I2C_controller
// Module Name:   C:/Users/milug/OneDrive/Desktop/ise/I2C_protocol/test_bench.v
// Project Name:  I2C_protocol
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: I2C_controller
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_bench;

	// Inputs
	reg [6:0] addr;
	reg [7:0] data_in;
	reg start;
	reg reset;
	reg clk;
	reg r_w_en;
	wire [2:0] state_reg;
	reg [7:0] data; 
	// Outputs
	wire SCL;
	wire [7:0] reg_temp;
	// Bidirs
	wire SDA;
	reg sda_reg;
	assign SDA = (state_reg == 3'b100 || (state_reg == 3'b011 && r_w_en))? sda_reg : 3'bzzz;

	// Instantiate the Unit Under Test (UUT)
	I2C_controller uut (
		.addr(addr), 
		.data_in(data_in), 
		.start(start), 
		.reset(reset), 
		.clk(clk), 
		.r_w_en(r_w_en), 
		.SDA(SDA), 
		.SCL(SCL),
		.STATE_reg(state_reg),
		.reg_temp_1(reg_temp)
	);
	integer i;
	initial begin
	clk = 1;
	forever begin
			clk = #50 ~clk;
		end
	end
	initial begin
		addr = 0;
		data_in = 0;
		start = 0;
		reset = 0;
		clk = 1;
		r_w_en = 1'b0;
		#50;
		start = 1;
		data_in = 8'b10110100;
		r_w_en = 1'b0;
		addr = 7'b1000111;
		sda_reg = 1'b0;
		#200;
		#1600;
		sda_reg = 1'b1;
		
//		addr = 7'b1110011;
//		data_in = 0;
//		start = 0;
//		reset = 0;
//		clk = 1;
//		sda_reg = 1'b0;
//		r_w_en = 1'b1;
//		data = 8'b11001001;
//		#50;
//		start = 1;
//		#1000;
//		@(posedge clk) begin
//			sda_reg = data[7];
//		end
//		@(posedge clk) begin
//			sda_reg = data[6];
//		end
//		@(posedge clk) begin
//			sda_reg = data[5];
//		end
//		@(posedge clk) begin
//			sda_reg = data[4];
//		end
//		@(posedge clk) begin
//			sda_reg = data[3];
//		end
//		@(posedge clk) begin
//			sda_reg = data[2];
//		end
//		@(posedge clk) begin
//			sda_reg = data[1];
//		end
//		@(posedge clk) begin
//			sda_reg = data[0];
//		end
//		@(posedge clk) begin
//			sda_reg = 1'b1;
//		end
//		sda_reg = 1'b1;
//		start = 0;
	end
      
endmodule

