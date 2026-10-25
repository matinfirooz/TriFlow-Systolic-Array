`timescale 1ns/1ps
`include "test_utils.svh"
module tb_matrix_buffer;
    `CLOCK
    `WATCHDOG
    reg rst_n=0, we=0;
    reg [1:0] wr_row=0, wr_col=0, rd_row=0, rd_col=0;
    reg signed [7:0] wr_data=0;
    wire signed [7:0] rd_data;
    wire signed [7:0] matrix [0:2][0:2];
    matrix_buffer #(.N(3)) dut(.*);
    initial begin
        tick; `CHECK(rd_data===0,"buffer reset")
        @(negedge clk); rst_n=1;
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            @(negedge clk); we=1; wr_row=2'(r); wr_col=2'(c); wr_data=8'(-30+10*r+c); tick;
        end
        @(negedge clk); we=0;
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            rd_row=2'(r); rd_col=2'(c); #1;
            `CHECK(int'(rd_data)==-30+10*r+c && rd_data===matrix[r][c],"buffer readback")
        end
        @(negedge clk); we=1; wr_row=3; wr_col=0; wr_data=99; rd_row=3; #1;
        `CHECK(rd_data===0,"invalid read returns zero")
        tick; @(negedge clk); we=0; rd_row=0; rd_col=0; #1;
        `CHECK(rd_data===-8'sd30,"invalid write ignored")
        rst_n=0; #1; `CHECK(rd_data===0,"asynchronous reset")
        $display("PASS tb_matrix_buffer"); $finish;
    end
endmodule
