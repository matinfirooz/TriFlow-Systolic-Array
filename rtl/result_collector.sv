`timescale 1ns/1ps
`default_nettype none
// Decode current-cycle sums before the rising edge. Never capture stale flops.
module result_collector #(
    parameter integer N=4, ACC_W=32, CYCLE_W=$clog2(3*N+1)
)(
    input wire enable,
    input wire [1:0] mode,
    input wire [CYCLE_W-1:0] cycle,
    input wire signed [ACC_W-1:0] os_now [0:N-1][0:N-1],
    input wire signed [ACC_W-1:0] ws_bottom_now [0:N-1],
    input wire signed [ACC_W-1:0] is_right_now [0:N-1],
    output wire [N*N-1:0] write_mask,
    output wire signed [ACC_W-1:0] write_data [0:N-1][0:N-1]
);
    for(genvar r=0;r<N;r=r+1) begin:g_row
        for(genvar c=0;c<N;c=c+1) begin:g_col
            assign write_mask[r*N+c]=enable && mode<3 && int'(cycle)==r+c+N-1;
            assign write_data[r][c]=(mode==0)?os_now[r][c]:
                                   (mode==1)?ws_bottom_now[c]:(mode==2)?is_right_now[r]:'0;
        end
    end
endmodule
`default_nettype wire
