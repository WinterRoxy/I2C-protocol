`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:07:29 07/07/2024 
// Design Name: 
// Module Name:    I2C_controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module I2C_controller(
	input [6:0] addr,
	input [7:0] data_in,
	input start, reset, clk, r_w_en, //0 : write, 1: read
	inout SDA,
	output [2:0] STATE_reg,
	output SCL,
	output [7:0] reg_temp_1
    );
localparam [2:0] 	BEGIN = 3'b000,
					START = 3'b001,
					ADDR  = 3'b010,
					DATA  = 3'b011,
					ACK   = 3'b100,
					STOP  = 3'b101;
reg [3:0] count = 8, count_4 = 8, count_2 = 8;
reg [7:0] reg_temp;
reg [2:0] state = BEGIN;
reg sda_dir = 1'b1;
reg sda_reg = 1'b1;
reg scl_reg = 1'b1;
wire [7:0] addr_;
assign reg_temp_1 = reg_temp;
assign SCL = (state == BEGIN || state == START || state == STOP)? scl_reg : ~clk;
assign SDA = (sda_dir)? sda_reg : 1'bz;//1 : write, 0: read
assign addr_ = {addr, r_w_en};
assign STATE_reg = state;
	always@(posedge clk or posedge reset) begin
		if(reset)begin
			state <= BEGIN;
		end
		else begin
			case(state)
				BEGIN: begin
							sda_dir <= 1'b1;
							if(start)begin
								state <= START;
								sda_reg <= 1'b0;
							end
							else begin
								state <= BEGIN;
							end
						end
				START: begin
							scl_reg <= 1'b1;
							state <= ADDR;
							sda_reg <= addr_[count - 1'b1];
							count <= count - 1'b1;
						 end
				ADDR: begin
								sda_reg <= addr_[count - 1'b1];
								count <= count - 1'b1;
								if(count == 0)begin
									count <= 8;
									state <= ACK;
									sda_dir <= 1'b0;
								end	
						end
				ACK: begin
							if(~SDA)begin
								state <= DATA;
								if(~r_w_en) begin
									sda_dir <= 1'b1;
									sda_reg <= data_in[count_4 - 1'b1];
									count_4 <= count_4 - 1'b1;
								end
								else begin
									sda_dir <= 1'b0;
								end
							end
							else begin
								state <= STOP;
								sda_reg <= 1'b0;
								sda_dir <= 1'b1;
							end
						end
				DATA: begin
							if(r_w_en) begin
								reg_temp [count_2 - 1] <= SDA;
								count_2 <= count_2 - 1'b1;
								if(count_2 == 1)begin
									count_2 <= 8;
									sda_dir <= 1'b0;
									state <= ACK;
								end
							end
							else if (~r_w_en) begin
								sda_reg <= data_in[count_4 - 1];
								count_4 <= count_4 - 1'b1;
								if(count_4 == 0)begin
									count_4 <= 8;
									sda_dir <= 1'b0;
									state <= ACK;
								end
							end
						end
				STOP: begin
					scl_reg <= 1;
					sda_reg <= 1;
					state <= BEGIN;
				end							
		  endcase
	  end
	 end
endmodule

