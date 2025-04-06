`timescale 1ns/1ps
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
module I2C_controller (
    input clk,
    input reset,
    input start,
    input r_w,           // 0 = WRITE, 1 = READ
    input [6:0] addr,
    input [7:0] data_in,   // For write: new data for each byte; for read, this input is ignored.
    input [7:0] NUM_BYTES, // Number of data bytes to transmit (only used in write mode)
    output reg SCL,
    inout SDA,
    output reg done,
    output reg [3:0] state_reg,   // For debugging/monitoring (4-bit state)
    output reg [7:0] data_out     // For read: received data.
);

    // State definitions (4-bit encoding)
    localparam IDLE           = 4'd0,
               START_ST       = 4'd1,
               SEND_ADDR      = 4'd2,
               WAIT_ACK_ADDR  = 4'd3,
               SEND_DATA      = 4'd4,  // Write mode
               WAIT_ACK_DATA  = 4'd5,  // Write mode
               READ_DATA      = 4'd6,  // Read mode
               SEND_NACK      = 4'd7,  // Read mode: send NACK after reading
               STOP_ST        = 4'd8;  // STOP condition

    reg [3:0] state;
    reg phase;         // 0: SCL low, 1: SCL high
    reg [3:0] bit_cnt; // Counts from 7 downto 0
    reg [7:0] shift_reg;  // Shift register for transmitting/receiving a byte
    reg [1:0] stop_cnt;   // For generating STOP condition delays
    reg [7:0] byte_count; // Count number of data bytes transmitted (write mode)

    // Internal signals for SDA control:
    reg sda_out;
    reg sda_oe;
    assign SDA = sda_oe ? sda_out : 1'bz;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            phase      <= 0;
            SCL        <= 1;
            sda_out    <= 1;
            sda_oe     <= 1;
            bit_cnt    <= 4'd7;
            stop_cnt   <= 0;
            byte_count <= 0;
            done       <= 0;
            data_out   <= 8'd0;
        end else begin
            // Toggle phase every clock (creates two phases per bit)
            phase <= ~phase;
            case (state)
                IDLE: begin
                    SCL       <= 1;
                    sda_out   <= 1;
                    sda_oe    <= 1;
                    bit_cnt   <= 7;
                    done      <= 0;
                    byte_count<= 0;
                    if (start)
                        state <= START_ST;
                end

                // START condition: drive SDA from high to low while SCL is high.
                START_ST: begin
                    if (!phase) begin
                        SCL     <= 1;
                        sda_out <= 1;
                        sda_oe  <= 1;
                    end else begin
                        sda_out <= 0;
                    end
                    if (phase) begin
                        state <= SEND_ADDR;
                        if (r_w == 0)
                            shift_reg <= {addr, 1'b0}; // Write mode
                        else
                            shift_reg <= {addr, 1'b1}; // Read mode
                        bit_cnt <= 7;
                    end
                end

                // SEND_ADDR: Transmit address byte.
                SEND_ADDR: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_out <= shift_reg[bit_cnt];
                        sda_oe <= 1;
                    end else begin
                        SCL <= 1;
                        if (bit_cnt == 0)
                            state <= WAIT_ACK_ADDR;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                // WAIT_ACK_ADDR: Release SDA and sample ACK from slave.
                WAIT_ACK_ADDR: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_oe <= 0;
                    end else begin
                        SCL <= 1;
                        if (SDA !== 1'b0) begin
                            // NACK received -> abort transaction.
                            state <= STOP_ST;
                        end else begin
                            // ACK received.
                            if (r_w == 0) begin
                                state <= SEND_DATA;
                                shift_reg <= data_in;  // Load first data byte for write.
                                bit_cnt <= 7;
                            end else begin
                                state <= READ_DATA;
                                bit_cnt <= 7;
                            end
                        end
                    end
                end

                // SEND_DATA: (Write mode) Transmit data byte.
                SEND_DATA: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_out <= shift_reg[bit_cnt];
                        sda_oe <= 1;
                    end else begin
                        SCL <= 1;
                        if (bit_cnt == 0)
                            state <= WAIT_ACK_DATA;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                // WAIT_ACK_DATA: (Write mode) Release SDA and sample ACK.
                WAIT_ACK_DATA: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_oe <= 0;
                    end else begin
                        SCL <= 1;
                        if (SDA !== 1'b0) begin
                            state <= STOP_ST;
                        end else begin
                            if (byte_count < NUM_BYTES - 1) begin
                                byte_count <= byte_count + 1;
                                state <= SEND_DATA;
                                shift_reg <= data_in;  // Load next data byte.
                                bit_cnt <= 7;
                            end else begin
                                state <= STOP_ST;
                            end
                        end
                    end
                end

                // READ_DATA: (Read mode) Master releases SDA and samples 8 data bits.
                READ_DATA: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_oe <= 0;
                    end else begin
                        SCL <= 1;
                        shift_reg[bit_cnt] <= SDA;
                        if (bit_cnt == 0) begin
                            data_out <= shift_reg; // Latch received byte.
                            state <= SEND_NACK;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // SEND_NACK: (Read mode) Master drives NACK (SDA = 1) to signal end of reading.
                SEND_NACK: begin
                    if (!phase) begin
                        SCL <= 0;
                        sda_out <= 1;
                        sda_oe <= 1;
                    end else begin
                        SCL <= 1;
                        state <= STOP_ST;
                    end
                end

                // STOP_ST: Generate STOP condition.
                STOP_ST: begin
                    case (stop_cnt)
                        2'd0: begin
                            SCL <= 0;
                            sda_out <= 0;
                            sda_oe <= 1;
                            stop_cnt <= stop_cnt + 1;
                        end
                        2'd1: begin
                            SCL <= 1;
                            sda_out <= 0;
                            sda_oe <= 1;
                            stop_cnt <= stop_cnt + 1;
                        end
                        2'd2: begin
                            SCL <= 1;
                            sda_out <= 1;
                            sda_oe <= 1;
                            stop_cnt <= 0;
                            done <= 1;
                            state <= IDLE;
                        end
                    endcase
                end

                default: state <= IDLE;
            endcase
            state_reg <= state;
        end
    end

endmodule
