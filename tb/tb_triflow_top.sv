`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_top #(
    parameter integer N=4, DATA_W=8, ACC_W=32
);
    localparam IW=(N>1)?$clog2(N):1;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,load_we=0,load_sel=0,start=0;
    reg [IW-1:0] load_row=0,load_col=0,result_row=0,result_col=0;
    reg signed [DATA_W-1:0] load_data=0;
    reg [1:0] dataflow=0;
    wire signed [ACC_W-1:0] result_data;
    wire busy,done;
    wire [31:0] perf_total_cycles,perf_compute_cycles,perf_preload_cycles,perf_mac_ops;
    integer A[0:N-1][0:N-1],B[0:N-1][0:N-1],sum,guard;
    reg signed [ACC_W-1:0] expected;
    triflow_top #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W)) dut(.*);
    initial begin
        for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin A[r][c]=(r+c)%7-3; B[r][c]=(2*r+c)%5-2; end
        tick; @(negedge clk); rst_n=1;
        for(integer sel=0;sel<2;sel=sel+1)
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                @(negedge clk); load_we=1; load_sel=1'(sel); load_row=IW'(r); load_col=IW'(c);
                load_data=DATA_W'(sel?B[r][c]:A[r][c]);
            end
        tick; @(negedge clk); load_we=0;
        for(integer mode=0;mode<3;mode=mode+1) begin
            @(negedge clk); start=1; dataflow=2'(mode); tick;
            @(negedge clk); start=0; guard=0;
            while(!done) begin tick; guard=guard+1; `CHECK(guard<N*N+3*N+10,"wrapper timeout") end
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                sum=0; for(integer k=0;k<N;k=k+1) sum=sum+A[r][k]*B[k][c];
                expected=ACC_W'(sum); result_row=IW'(r); result_col=IW'(c); #1;
                `CHECK(result_data===expected,"legacy wrapper matrix")
            end
            `CHECK(perf_compute_cycles==3*N-2 && perf_mac_ops==N*N*N,"legacy counters")
            `CHECK(perf_preload_cycles==((mode==0)?0:N*N),"legacy disables reuse")
            while(busy) tick;
            tick;
        end
        $display("PASS tb_triflow_top N=%0d DW=%0d",N,DATA_W); $finish;
    end
endmodule
