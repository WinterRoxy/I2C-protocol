`timescale 1ns/1ps
module tb_i2c_combined;

    // Signal declarations
    reg clk;
    reg reset;
    reg start;
    reg r_w;            
    reg [6:0] addr;
    reg [7:0] data_in;   
    reg [7:0] NUM_BYTES; 
    wire SCL;
    wire done;
    wire [3:0] state_reg;  
    wire [7:0] data_out;    
    tri SDA;
    
    // Instantiate the combined I2C controller.
    I2C_controller uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .r_w(r_w),
        .addr(addr),
        .data_in(data_in),
        .NUM_BYTES(NUM_BYTES),
        .SCL(SCL),
        .SDA(SDA),
        .done(done),
        .state_reg(state_reg),
        .data_out(data_out)
    );

    reg [3:0] slave_bit_cnt;
    reg [7:0] slave_data;
    reg       slave_sda;  

    always @(negedge SCL) begin
        if (reset) begin
            slave_bit_cnt <= 7;
            slave_sda <= 1;
        end
        else if (r_w == 1 && state_reg == 4'd6) begin
            slave_sda <= slave_data[slave_bit_cnt];
            if (slave_bit_cnt > 0)
                slave_bit_cnt <= slave_bit_cnt - 1;
            else
                slave_bit_cnt <= 7;
        end
    end
    
    initial begin
        slave_data =  8'b11001011;
    end

    assign SDA = (state_reg == 4'd3) ? 1'b0 :
                 ((state_reg == 4'd5) && (r_w == 0)) ? 1'b0 :
                 ((r_w == 1) && (state_reg == 4'd6)) ? slave_sda :
                 1'bz;
                 
    // Tạo xung clock: chu kỳ 100 ns (10 MHz)
    initial begin
        clk = 0;
        forever #50 clk = ~clk;
    end
    
    initial begin

        reset = 1;
        start = 0;
        r_w = 0;           
        addr = 7'b1010101;
        data_in = 8'b11001011;   
        NUM_BYTES = 3;     
        slave_bit_cnt = 7;
        #200;
        reset = 0;
        #100;
        

        start = 1;
        #100;
        start = 0;
        wait(done);
        #200;
        

        reset = 1;
        #100;
        reset = 0;
        #100;

        r_w = 1;  // READ
        start = 1;
        #100;
        start = 0;
        wait(done);
        #200;
        $finish;
    end

endmodule
