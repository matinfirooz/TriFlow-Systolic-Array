`timescale 1ns/1ps
`include "test_utils.svh"
module tb_wavefront_scheduler;
    reg enable=1;
    reg [1:0] mode=0;
    reg [3:0] cycle=0;
    reg signed [7:0] matrix_a [0:2][0:2], matrix_b [0:2][0:2];
    wire signed [7:0] a_left [0:2], b_top [0:2];
    wire [8:0] mac_valid;
    integer expected_a,expected_b,k,count;
    wavefront_scheduler #(.N(3)) dut(.*);
    initial begin
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            matrix_a[r][c]=8'(r*10+c+1); matrix_b[r][c]=8'(-r*10-c-1);
        end
        for(integer m=0;m<4;m=m+1) begin
            mode=2'(m); count=0;
            for(integer t=0;t<10;t=t+1) begin
                cycle=4'(t); #1;
                for(integer lane=0;lane<3;lane=lane+1) begin
                    k=t-lane; expected_a=0; expected_b=0;
                    if(k>=0 && k<3) begin
                        if(m==0) begin expected_a=matrix_a[lane][k]; expected_b=matrix_b[k][lane]; end
                        if(m==1) expected_a=matrix_a[k][lane];
                        if(m==2) expected_b=matrix_b[lane][k];
                    end
                    `CHECK(int'(a_left[lane])==expected_a && int'(b_top[lane])==expected_b,"boundary token")
                    for(integer c=0;c<3;c=c+1) begin
                        `CHECK(mac_valid[lane*3+c]==(m<3 && t>=lane+c && t<lane+c+3),"MAC validity")
                        count=count+int'(mac_valid[lane*3+c]);
                    end
                end
            end
            `CHECK(count==((m<3)?27:0),"each logical product appears once")
        end
        enable=0; mode=0; cycle=0; #1;
        `CHECK(mac_valid==0 && a_left[0]==0 && b_top[0]==0,"disabled wavefront")
        $display("PASS tb_wavefront_scheduler"); $finish;
    end
endmodule
