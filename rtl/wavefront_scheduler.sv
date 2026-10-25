`timescale 1ns/1ps
`default_nettype none
// Time t advances only with the entire fabric. The useful mask is t-r-c in [0,N).
module wavefront_scheduler #(
    parameter integer N=4, DATA_W=8, CYCLE_W=$clog2(3*N+1),
    parameter integer IDX_W=(N>1)?$clog2(N):1
)(
    input wire enable,
    input wire [1:0] mode,
    input wire [CYCLE_W-1:0] cycle,
    input wire signed [DATA_W-1:0] matrix_a [0:N-1][0:N-1],
    input wire signed [DATA_W-1:0] matrix_b [0:N-1][0:N-1],
    output wire signed [DATA_W-1:0] a_left [0:N-1],
    output wire signed [DATA_W-1:0] b_top [0:N-1],
    output wire [N*N-1:0] mac_valid
);
    for(genvar r=0;r<N;r=r+1) begin:g_row
        wire signed [31:0] k=int'(cycle)-r;
        wire valid=enable && k>=0 && k<N;
        wire [IDX_W-1:0] idx=IDX_W'(k);
        wire signed [DATA_W-1:0] ar=matrix_a[r][idx];
        wire signed [DATA_W-1:0] ac=matrix_a[idx][r];
        wire signed [DATA_W-1:0] br=matrix_b[r][idx];
        wire signed [DATA_W-1:0] bc=matrix_b[idx][r];
        assign a_left[r]=!valid?{DATA_W{1'b0}}:(mode==0)?ar:(mode==1)?ac:{DATA_W{1'b0}};
        assign b_top[r]=!valid?{DATA_W{1'b0}}:(mode==0)?bc:(mode==2)?br:{DATA_W{1'b0}};
        for(genvar c=0;c<N;c=c+1) begin:g_col
            assign mac_valid[r*N+c]=enable && mode<3 && int'(cycle)>=r+c && int'(cycle)<r+c+N;
        end
    end
endmodule
`default_nettype wire
