`timescale 1ns/1ps
`default_nettype none
// Register-backed storage with parallel taps; not an inferred SRAM macro.
module matrix_buffer #(
    parameter integer N=4, DATA_W=8,
    parameter integer IDX_W=(N>1)?$clog2(N):1
)(
    input wire clk, rst_n, we,
    input wire [IDX_W-1:0] wr_row, wr_col,
    input wire signed [DATA_W-1:0] wr_data,
    input wire [IDX_W-1:0] rd_row, rd_col,
    output wire signed [DATA_W-1:0] rd_data,
    output wire signed [DATA_W-1:0] matrix [0:N-1][0:N-1]
);
    reg signed [DATA_W-1:0] mem [0:N-1][0:N-1];
    for(genvar r=0;r<N;r=r+1) begin:g_row
        for(genvar c=0;c<N;c=c+1) begin:g_col
            assign matrix[r][c]=mem[r][c];
            always @(posedge clk or negedge rst_n)
                if(!rst_n) mem[r][c]<='0;
                else if(we && int'(wr_row)==r && int'(wr_col)==c) mem[r][c]<=wr_data;
        end
    end
    assign rd_data=(int'(rd_row)<N && int'(rd_col)<N)?mem[rd_row][rd_col]:'0;
endmodule
`default_nettype wire
