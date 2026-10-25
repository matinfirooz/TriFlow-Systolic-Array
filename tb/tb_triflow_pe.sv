`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_pe;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,clear=0,step=0,mac_valid=1;
    reg [1:0] mode=0;
    reg preload_weight=0,preload_input=0;
    reg signed [3:0] preload_data=0,a_west=0,b_north=0;
    wire signed [3:0] a_east,b_south;
    reg signed [7:0] psum_north=0,psum_west=0;
    wire signed [7:0] psum_south,psum_east,acc_value,sum_now;
    wire nonzero_op;
    triflow_pe #(.DATA_W(4),.ACC_W(8)) dut(.*);
    initial begin
        tick; `CHECK(acc_value===0,"PE reset")
        @(negedge clk); rst_n=1; step=1; a_west=-8; b_north=-8;
        tick; `CHECK(acc_value===8'sd64 && a_east===-4'sd8,"OS accumulation/link")
        tick; `CHECK(acc_value===-8'sd128,"accumulator wrap")
        @(negedge clk); step=0; a_west=3; b_north=2; tick;
        `CHECK(acc_value===-8'sd128 && a_east===-4'sd8 && !nonzero_op,"global hold")
        @(negedge clk); preload_weight=1; preload_data=-3; tick;
        @(negedge clk); preload_weight=0; preload_input=1; preload_data=7; clear=1; tick;
        `CHECK(acc_value===0 && psum_south===0,"clear while preload")
        @(negedge clk); preload_input=0; clear=0; step=1; mode=1; a_west=-4; psum_north=-7;
        #1; `CHECK(sum_now===8'sd5,"WS current sum")
        tick; `CHECK(psum_south===8'sd5,"WS resident survives clear")
        @(negedge clk); mode=2; b_north=-2; psum_west=5; tick;
        `CHECK(psum_east===-8'sd9,"IS resident multiply")
        @(negedge clk); mac_valid=0; psum_west=11; tick;
        `CHECK(psum_east===8'sd11 && !nonzero_op,"invalid product bypass")
        @(negedge clk); mode=3; tick;
        `CHECK(a_east===0 && b_south===0 && psum_east===0 && psum_south===0,"illegal mode inert")
        $display("PASS tb_triflow_pe"); $finish;
    end
endmodule
