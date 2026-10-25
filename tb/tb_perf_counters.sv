`timescale 1ns/1ps
`include "test_utils.svh"
module tb_perf_counters;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,accepted=0,busy=0,done=0,pause=0,preload_enable=0,compute_enable=0;
    reg [3:0] active_mask=0,nonzero_mask=0;
    wire [31:0] total_cycles,compute_cycles,preload_cycles,stall_cycles,mac_ops,nonzero_ops;
    perf_counters #(.N(2)) dut(.*);
    initial begin
        tick; `CHECK(total_cycles===0,"counter reset")
        @(negedge clk); rst_n=1; accepted=1; tick;
        @(negedge clk); accepted=0; busy=1; tick; // clear
        @(negedge clk); preload_enable=1; tick; tick;
        @(negedge clk); preload_enable=0; pause=1; tick; tick; tick;
        @(negedge clk); pause=0; compute_enable=1; active_mask=4'b1111; nonzero_mask=4'b0101; tick;
        @(negedge clk); active_mask=4'b0010; nonzero_mask=0; tick;
        `CHECK(total_cycles==8 && compute_cycles==2 && preload_cycles==2 && stall_cycles==3,"phase counters")
        `CHECK(mac_ops==5 && nonzero_ops==2,"actual MAC event counts")
        @(negedge clk); done=1; compute_enable=0; tick;
        `CHECK(total_cycles==8,"done excluded")
        @(negedge clk); busy=0; done=0; tick; `CHECK(total_cycles==8,"idle holds")
        @(negedge clk); accepted=1; tick; `CHECK(mac_ops==0 && total_cycles==0,"per-command reset")
        $display("PASS tb_perf_counters"); $finish;
    end
endmodule
