`timescale 1ns/1ps
`include "test_utils.svh"
module tb_signed_mac;
    reg enable=1;
    reg signed [3:0] lhs, rhs;
    reg signed [7:0] addend;
    wire signed [7:0] sum, plain;
    wire nonzero_op;
    reg signed [7:0] expected;
    signed_mac #(.DATA_W(4),.ACC_W(8)) dut(.*);
    signed_mac #(.DATA_W(4),.ACC_W(8),.ZERO_GATE(0)) no_gate(
        .enable(enable),.lhs(lhs),.rhs(rhs),.addend(addend),.sum(plain),.nonzero_op());
    initial begin
        for(integer en=0;en<2;en=en+1)
            for(integer a=-8;a<8;a=a+1)
                for(integer b=-8;b<8;b=b+1) begin
                    enable=1'(en); lhs=4'(a); rhs=4'(b); addend=8'(a*21-b*13);
                    expected=8'(int'(addend)+(en?a*b:0)); #1;
                    `CHECK(sum===expected && plain===expected,"exhaustive signed MAC / wrap / gate equivalence")
                    `CHECK(nonzero_op==((en!=0)&&(a!=0)&&(b!=0)),"nonzero flag")
                end
        $display("PASS tb_signed_mac: 512 exhaustive enabled/disabled INT4 pairs"); $finish;
    end
endmodule
