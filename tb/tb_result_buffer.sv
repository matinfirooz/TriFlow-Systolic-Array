`timescale 1ns/1ps
`include "test_utils.svh"
module tb_result_buffer;
    `CLOCK
    `WATCHDOG
    reg rst_n=0, clear=0;
    reg [8:0] write_mask=0;
    reg signed [15:0] write_data [0:2][0:2];
    reg [1:0] rd_row=0, rd_col=0;
    wire signed [15:0] rd_data, matrix [0:2][0:2];
    result_buffer #(.N(3),.ACC_W(16)) dut(.*);
    initial begin
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) write_data[r][c]=16'(r*100-c);
        tick; `CHECK(rd_data===0,"result reset")
        @(negedge clk); rst_n=1; write_mask=9'b101010101; tick;
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            rd_row=2'(r); rd_col=2'(c); #1;
            `CHECK(rd_data===(write_mask[r*3+c]?write_data[r][c]:16'sd0),"masked multiwrite")
        end
        @(negedge clk); clear=1; write_mask='1; tick;
        `CHECK(rd_data===0,"clear dominates write")
        @(negedge clk); clear=0; write_mask=0; rd_row=3; #1;
        `CHECK(rd_data===0,"invalid result address")
        $display("PASS tb_result_buffer"); $finish;
    end
endmodule
