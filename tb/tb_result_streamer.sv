`timescale 1ns/1ps
`include "test_utils.svh"
module tb_result_streamer;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,launch=0,ready=0;
    reg signed [15:0] results [0:2][0:2];
    wire busy,done,valid,last;
    wire [1:0] row,col;
    wire signed [15:0] data;
    integer idx;
    result_streamer #(.N(3),.ACC_W(16)) dut(.*);
    initial begin
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) results[r][c]=16'(-100+r*10+c);
        tick; `CHECK(!valid && !done,"stream reset")
        @(negedge clk); rst_n=1; launch=1; tick;
        @(negedge clk); launch=0;
        for(idx=0;idx<9;idx=idx+1) begin
            `CHECK(valid && int'(row)==idx/3 && int'(col)==idx%3,"row-major index")
            `CHECK(data===results[idx/3][idx%3] && last==(idx==8),"stream data/last")
            ready=0; tick; tick;
            `CHECK(valid && int'(row)==idx/3 && int'(col)==idx%3 && data===results[idx/3][idx%3],"hold under backpressure")
            @(negedge clk); ready=1; tick;
            @(negedge clk); ready=0;
        end
        `CHECK(!valid && done && !busy,"last handshake")
        tick; `CHECK(!done,"stream done pulse")
        @(negedge clk); launch=1; tick; @(negedge clk); rst_n=0; #1;
        `CHECK(!valid && !busy,"reset aborts stream")
        $display("PASS tb_result_streamer"); $finish;
    end
endmodule
