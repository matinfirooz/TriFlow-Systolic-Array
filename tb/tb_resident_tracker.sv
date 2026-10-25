`timescale 1ns/1ps
`include "test_utils.svh"
module tb_resident_tracker;
    `CLOCK
    `WATCHDOG
    reg rst_n=0, a_write=0, b_write=0, preload_done=0, reuse_requested=1;
    reg [1:0] preload_mode=1, query_mode=1;
    wire weight_valid,input_valid,hit;
    resident_tracker dut(.*);
    initial begin
        tick; `CHECK(!hit && !weight_valid && !input_valid,"empty residency")
        @(negedge clk); rst_n=1; preload_done=1; tick;
        `CHECK(hit && weight_valid,"weight fill")
        @(negedge clk); preload_mode=2; query_mode=2; tick;
        `CHECK(hit && weight_valid && input_valid,"independent resident banks")
        @(negedge clk); preload_done=0; a_write=1; query_mode=1; tick;
        `CHECK(hit && !input_valid,"A write preserves weight residency")
        @(negedge clk); a_write=0; b_write=1; tick;
        `CHECK(!hit && !weight_valid,"B invalidates weights")
        @(negedge clk); preload_done=1; preload_mode=1; tick;
        `CHECK(!weight_valid,"accepted write wins fill conflict")
        @(negedge clk); b_write=0; tick;
        reuse_requested=0; #1; `CHECK(!hit,"reuse opt out")
        query_mode=0; reuse_requested=1; #1; `CHECK(!hit,"OS never uses residency")
        rst_n=0; #1; `CHECK(!weight_valid && !input_valid,"reset invalidates")
        $display("PASS tb_resident_tracker"); $finish;
    end
endmodule
