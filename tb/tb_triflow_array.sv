`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_array;
    `CLOCK
    `WATCHDOG
    localparam N=3;
    reg rst_n=0,clear=0,step=0,preload_valid=0,preload_is_weight=0;
    reg [1:0] mode=0,preload_row=0,preload_col=0;
    reg [8:0] mac_valid=0;
    reg signed [7:0] preload_data=0,a_left [0:2],b_top [0:2];
    wire signed [31:0] os_now [0:2][0:2],ws_bottom_now [0:2],is_right_now [0:2];
    wire [8:0] nonzero_ops;
    integer A [0:2][0:2],B [0:2][0:2],G [0:2][0:2];
    integer idx,got;
    triflow_array #(.N(3)) dut(.*);
    initial begin
        for(integer r=0;r<N;r=r+1) begin
            a_left[r]=0; b_top[r]=0;
            for(integer c=0;c<N;c=c+1) begin A[r][c]=r*3-c-2; B[r][c]=c*2-r+1; end
        end
        for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
            G[r][c]=0; for(integer k=0;k<N;k=k+1) G[r][c]=G[r][c]+A[r][k]*B[k][c];
        end
        tick; @(negedge clk); rst_n=1;
        for(integer m=0;m<3;m=m+1) begin
            @(negedge clk); mode=2'(m); step=0; clear=1; tick;
            @(negedge clk); clear=0;
            if(m!=0) begin
                for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                    preload_valid=1; preload_is_weight=(m==1); preload_row=2'(r); preload_col=2'(c);
                    preload_data=8'((m==1)?B[r][c]:A[r][c]); tick; @(negedge clk);
                end
            end
            preload_valid=0;
            for(integer t=0;t<7;t=t+1) begin
                step=1;
                for(integer r=0;r<N;r=r+1) begin
                    idx=t-r; a_left[r]=0; b_top[r]=0;
                    if(idx>=0 && idx<N) begin
                        if(m==0) begin a_left[r]=8'(A[r][idx]); b_top[r]=8'(B[idx][r]); end
                        if(m==1) a_left[r]=8'(A[idx][r]);
                        if(m==2) b_top[r]=8'(B[r][idx]);
                    end
                    for(integer c=0;c<N;c=c+1) mac_valid[r*N+c]=(t>=r+c && t<r+c+N);
                end
                #1;
                for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) if(t==r+c+N-1) begin
                    got=(m==0)?os_now[r][c]:(m==1)?ws_bottom_now[c]:is_right_now[r];
                    `CHECK(got==G[r][c],"array output wavefront")
                end
                tick; @(negedge clk);
                step=0; tick; @(negedge clk); // An inserted global pause between every step.
            end
        end
        $display("PASS tb_triflow_array: all modes with pauses"); $finish;
    end
endmodule
