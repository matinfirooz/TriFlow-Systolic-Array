`timescale 1ns/1ps
`default_nettype none
module triflow_array #(
    parameter integer N=4, DATA_W=8, ACC_W=32,
    parameter integer IDX_W=(N>1)?$clog2(N):1,
    parameter bit ZERO_GATE=1'b1
)(
    input wire clk, rst_n, clear, step,
    input wire [1:0] mode,
    input wire [N*N-1:0] mac_valid,
    input wire preload_valid, preload_is_weight,
    input wire [IDX_W-1:0] preload_row, preload_col,
    input wire signed [DATA_W-1:0] preload_data,
    input wire signed [DATA_W-1:0] a_left [0:N-1],
    input wire signed [DATA_W-1:0] b_top [0:N-1],
    output wire signed [ACC_W-1:0] os_now [0:N-1][0:N-1],
    output wire signed [ACC_W-1:0] ws_bottom_now [0:N-1],
    output wire signed [ACC_W-1:0] is_right_now [0:N-1],
    output wire [N*N-1:0] nonzero_ops
);
    // Exactly one driver per link; no procedural drivers on interconnect arrays.
    wire signed [DATA_W-1:0] a [0:N-1][0:N], b [0:N][0:N-1];
    wire signed [ACC_W-1:0] pv [0:N][0:N-1], ph [0:N-1][0:N];
    wire signed [ACC_W-1:0] sums [0:N-1][0:N-1];
    for(genvar r=0;r<N;r=r+1) begin:g_row
        assign a[r][0]=a_left[r]; assign b[0][r]=b_top[r];
        assign pv[0][r]='0; assign ph[r][0]='0;
        assign ws_bottom_now[r]=sums[N-1][r]; assign is_right_now[r]=sums[r][N-1];
        for(genvar c=0;c<N;c=c+1) begin:g_col
            wire selected=preload_valid && int'(preload_row)==r && int'(preload_col)==c;
            wire signed [ACC_W-1:0] unused_acc;
            assign os_now[r][c]=sums[r][c];
            triflow_pe #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_pe(
                .clk(clk),.rst_n(rst_n),.clear(clear),.step(step),.mac_valid(mac_valid[r*N+c]),.mode(mode),
                .preload_weight(selected && preload_is_weight),.preload_input(selected && !preload_is_weight),
                .preload_data(preload_data),.a_west(a[r][c]),.b_north(b[r][c]),
                .a_east(a[r][c+1]),.b_south(b[r+1][c]),.psum_north(pv[r][c]),.psum_west(ph[r][c]),
                .psum_south(pv[r+1][c]),.psum_east(ph[r][c+1]),.acc_value(unused_acc),
                .sum_now(sums[r][c]),.nonzero_op(nonzero_ops[r*N+c]));
        end
    end
endmodule
`default_nettype wire
