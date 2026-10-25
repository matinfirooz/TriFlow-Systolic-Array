`timescale 1ns/1ps
`default_nettype none
// Row-major result stream. Data/coordinates/last remain stable under backpressure.
module result_streamer #(
    parameter integer N=4, ACC_W=32,
    parameter integer IDX_W=(N>1)?$clog2(N):1,
    parameter integer COUNT_W=(N*N>1)?$clog2(N*N):1
)(
    input wire clk, rst_n, launch, ready,
    input wire signed [ACC_W-1:0] results [0:N-1][0:N-1],
    output reg busy, done,
    output wire valid, last,
    output wire [IDX_W-1:0] row, col,
    output wire signed [ACC_W-1:0] data
);
    reg [COUNT_W-1:0] index;
    assign valid=busy;
    assign row=IDX_W'(int'(index)/N);
    assign col=IDX_W'(int'(index)%N);
    assign data=busy ? results[row][col] : '0;
    assign last=busy && int'(index)==N*N-1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin index<='0; busy<=0; done<=0; end
        else begin
            done<=0;
            if(!busy && launch) begin index<='0; busy<=1; end
            else if(busy && ready) begin
                if(int'(index)==N*N-1) begin busy<=0; done<=1; end
                else index<=index+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
