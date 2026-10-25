`timescale 1ns/1ps
`default_nettype none
// Multiwrite register bank: a wavefront may retire several cells per edge.
module result_buffer #(
    parameter integer N=4, ACC_W=32,
    parameter integer IDX_W=(N>1)?$clog2(N):1
)(
    input wire clk, rst_n, clear,
    input wire [N*N-1:0] write_mask,
    input wire signed [ACC_W-1:0] write_data [0:N-1][0:N-1],
    input wire [IDX_W-1:0] rd_row, rd_col,
    output wire signed [ACC_W-1:0] rd_data,
    output wire signed [ACC_W-1:0] matrix [0:N-1][0:N-1]
);
    reg signed [ACC_W-1:0] mem [0:N-1][0:N-1];
    for(genvar r=0;r<N;r=r+1) begin:g_row
        for(genvar c=0;c<N;c=c+1) begin:g_col
            assign matrix[r][c]=mem[r][c];
            always @(posedge clk or negedge rst_n)
                if(!rst_n) mem[r][c]<='0;
                else if(clear) mem[r][c]<='0;
                else if(write_mask[r*N+c]) mem[r][c]<=write_data[r][c];
        end
    end
    assign rd_data=(int'(rd_row)<N && int'(rd_col)<N)?mem[rd_row][rd_col]:'0;
endmodule
`default_nettype wire
