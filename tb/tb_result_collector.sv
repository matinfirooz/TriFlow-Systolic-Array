`timescale 1ns/1ps
`include "test_utils.svh"
module tb_result_collector;
    reg enable=1;
    reg [1:0] mode=0;
    reg [3:0] cycle=0;
    reg signed [15:0] os_now [0:2][0:2],ws_bottom_now [0:2],is_right_now [0:2];
    wire [8:0] write_mask;
    wire signed [15:0] write_data [0:2][0:2];
    integer count;
    result_collector #(.N(3),.ACC_W(16)) dut(.*);
    initial begin
        for(integer r=0;r<3;r=r+1) begin
            ws_bottom_now[r]=16'(100+r); is_right_now[r]=16'(-100-r);
            for(integer c=0;c<3;c=c+1) os_now[r][c]=16'(10*r+c);
        end
        for(integer m=0;m<4;m=m+1) begin
            count=0; mode=2'(m);
            for(integer t=0;t<10;t=t+1) begin
                cycle=4'(t); #1;
                for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
                    `CHECK(write_mask[r*3+c]==(m<3 && t==r+c+2),"retirement slot")
                    if(write_mask[r*3+c]) begin
                        count=count+1;
                        `CHECK(write_data[r][c]===((m==0)?os_now[r][c]:(m==1)?ws_bottom_now[c]:is_right_now[r]),"retirement source")
                    end
                end
            end
            `CHECK(count==((m<3)?9:0),"one retirement per output")
        end
        enable=0; mode=0; cycle=2; #1; `CHECK(write_mask==0,"collector disabled")
        $display("PASS tb_result_collector"); $finish;
    end
endmodule
