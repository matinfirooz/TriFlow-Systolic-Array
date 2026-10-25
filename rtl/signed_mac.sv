`timescale 1ns/1ps
`default_nettype none
// One signed multiplier, one adder; zero isolation does not skip time slots.
module signed_mac #(
    parameter integer DATA_W=8, ACC_W=32,
    parameter bit ZERO_GATE=1'b1
)(
    input wire enable,
    input wire signed [DATA_W-1:0] lhs, rhs,
    input wire signed [ACC_W-1:0] addend,
    output wire signed [ACC_W-1:0] sum,
    output wire nonzero_op
);
    wire use_product = enable && (!ZERO_GATE || ((lhs!=0) && (rhs!=0)));
    wire signed [DATA_W-1:0] x = use_product ? lhs : {DATA_W{1'b0}};
    wire signed [DATA_W-1:0] y = use_product ? rhs : {DATA_W{1'b0}};
    wire signed [2*DATA_W-1:0] product = x*y;
    wire signed [ACC_W-1:0] extended = {{(ACC_W-2*DATA_W){product[2*DATA_W-1]}},product};
    assign sum = addend+extended; // Two's-complement wrap at ACC_W.
    assign nonzero_op = enable && (lhs!=0) && (rhs!=0);
    initial if (DATA_W<2 || ACC_W<2*DATA_W)
        $fatal(1,"Require DATA_W>=2 and ACC_W>=2*DATA_W");
endmodule
`default_nettype wire
