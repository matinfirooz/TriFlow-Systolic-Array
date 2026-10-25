`timescale 1ns/1ps
`default_nettype none
module triflow_pe #(
    parameter integer DATA_W=8, ACC_W=32,
    parameter bit ZERO_GATE=1'b1
)(
    input wire clk, rst_n, clear, step, mac_valid,
    input wire [1:0] mode,
    input wire preload_weight, preload_input,
    input wire signed [DATA_W-1:0] preload_data, a_west, b_north,
    output reg signed [DATA_W-1:0] a_east, b_south,
    input wire signed [ACC_W-1:0] psum_north, psum_west,
    output reg signed [ACC_W-1:0] psum_south, psum_east,
    output wire signed [ACC_W-1:0] acc_value, sum_now,
    output wire nonzero_op
);
    reg signed [DATA_W-1:0] weight_reg, input_reg;
    reg signed [ACC_W-1:0] acc_reg;
    wire signed [DATA_W-1:0] lhs=(mode==2)?input_reg:a_west;
    wire signed [DATA_W-1:0] rhs=(mode==1)?weight_reg:b_north;
    wire signed [ACC_W-1:0] base=(mode==1)?psum_north:(mode==2)?psum_west:acc_reg;
    signed_mac #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_mac(
        .enable(step && mac_valid && mode<3),.lhs(lhs),.rhs(rhs),.addend(base),
        .sum(sum_now),.nonzero_op(nonzero_op));
    assign acc_value=acc_reg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            weight_reg<='0; input_reg<='0; acc_reg<='0;
            a_east<='0; b_south<='0; psum_south<='0; psum_east<='0;
        end else begin
            // Clear preserves residency. Reset discards it.
            if(preload_weight) weight_reg<=preload_data;
            if(preload_input) input_reg<=preload_data;
            if(clear) begin
                acc_reg<='0; a_east<='0; b_south<='0; psum_south<='0; psum_east<='0;
            end else if(step) begin
                a_east<=(mode==0 || mode==1)?a_west:'0;
                b_south<=(mode==0 || mode==2)?b_north:'0;
                psum_south<=(mode==1)?sum_now:'0;
                psum_east<=(mode==2)?sum_now:'0;
                if(mode==0) acc_reg<=sum_now;
            end
        end
    end
endmodule
`default_nettype wire
