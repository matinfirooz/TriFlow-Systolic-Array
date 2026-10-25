`timescale 1ns/1ps
`default_nettype none
module preload_sequencer #(
    parameter integer N=4, DATA_W=8,
    parameter integer IDX_W=(N>1)?$clog2(N):1,
    parameter integer COUNT_W=(N*N>1)?$clog2(N*N):1
)(
    input wire enable,
    input wire [1:0] mode,
    input wire [COUNT_W-1:0] index,
    input wire signed [DATA_W-1:0] matrix_a [0:N-1][0:N-1],
    input wire signed [DATA_W-1:0] matrix_b [0:N-1][0:N-1],
    output wire valid, is_weight,
    output wire [IDX_W-1:0] row, col,
    output wire signed [DATA_W-1:0] data
);
    assign valid=enable && int'(index)<N*N && ((mode==1)||(mode==2));
    assign is_weight=(mode==1);
    assign row=IDX_W'(int'(index)/N);
    assign col=IDX_W'(int'(index)%N);
    assign data=valid ? ((mode==1)?matrix_b[row][col]:matrix_a[row][col]) : '0;
endmodule
`default_nettype wire
