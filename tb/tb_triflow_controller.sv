`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_controller;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,start=0,pause=0,reuse_hit=0;
    reg [1:0] dataflow=0;
    wire ready,accepted,busy,done,clear,preload_enable,compute_enable,preload_done,reuse_used;
    wire [1:0] mode;
    wire [3:0] preload_index,compute_cycle;
    wire [2:0] state_debug;
    integer pre,comp,cl,elapsed;
    triflow_controller #(.N(3)) dut(.*);
    task automatic run(input integer m,input bit hit);
        begin
            @(negedge clk); start=1; dataflow=2'(m); reuse_hit=hit;
            tick; `CHECK(busy && !ready && int'(mode)==m,"command acceptance")
            @(negedge clk); start=0; dataflow=3; reuse_hit=0;
            pre=0; comp=0; cl=0; elapsed=0;
            while(!done) begin
                if(clear) cl=cl+1;
                if(preload_enable) pre=pre+1;
                if(compute_enable) comp=comp+1;
                // Freeze every phase at least once without advancing its index.
                pause=1; #1;
                `CHECK(!clear && !preload_enable && !compute_enable,"paused control outputs")
                tick; @(negedge clk); pause=0; #1;
                tick; elapsed=elapsed+1;
                `CHECK(elapsed<30,"bounded completion")
                @(negedge clk);
            end
            `CHECK(cl==1 && comp==7 && pre==((m==0||hit)?0:9),"exact phase lengths")
            `CHECK(reuse_used==(hit && m!=0),"latched reuse")
            tick; `CHECK(!done && ready,"done pulse / idle")
        end
    endtask
    initial begin
        tick; @(negedge clk); rst_n=1; start=1; dataflow=3;
        tick; `CHECK(ready && !accepted && !busy,"invalid mode rejected")
        @(negedge clk); start=0;
        for(integer m=0;m<3;m=m+1) begin run(m,0); run(m,1); end
        @(negedge clk); start=1; dataflow=1; tick; @(negedge clk); rst_n=0; #1;
        `CHECK(ready && !busy && !done,"reset abort")
        $display("PASS tb_triflow_controller"); $finish;
    end
endmodule
