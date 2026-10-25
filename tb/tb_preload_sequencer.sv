`timescale 1ns/1ps
`include "test_utils.svh"
module tb_preload_sequencer;
    reg enable=1;
    reg [1:0] mode=1;
    reg [3:0] index=0;
    reg signed [7:0] matrix_a [0:2][0:2], matrix_b [0:2][0:2];
    wire valid,is_weight;
    wire [1:0] row,col;
    wire signed [7:0] data;
    preload_sequencer #(.N(3)) dut(.*);
    initial begin
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            matrix_a[r][c]=8'(r*10+c); matrix_b[r][c]=8'(-r*10-c-1);
        end
        for(integer m=0;m<4;m=m+1) for(integer i=0;i<16;i=i+1) begin
            mode=2'(m); index=4'(i); #1;
            `CHECK(valid==((m==1||m==2)&&i<9),"preload range/mode")
            if(valid) begin
                `CHECK(int'(row)==i/3 && int'(col)==i%3,"preload address order")
                `CHECK(data===((m==1)?matrix_b[i/3][i%3]:matrix_a[i/3][i%3]),"stationary operand select")
            end else begin `CHECK(data===0,"invalid preload isolation") end
        end
        enable=0; mode=1; index=0; #1; `CHECK(!valid && data==0,"disabled preload")
        $display("PASS tb_preload_sequencer"); $finish;
    end
endmodule
