`timescale 1ns/1ps
`default_nettype none
// Independent A/B residency, invalidated only by matching accepted writes/reset.
module resident_tracker(
    input wire clk, rst_n, a_write, b_write, preload_done,
    input wire [1:0] preload_mode, query_mode,
    input wire reuse_requested,
    output reg weight_valid, input_valid,
    output wire hit
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin weight_valid<=0; input_valid<=0; end
        else begin
            if(preload_done && preload_mode==1) weight_valid<=1;
            if(preload_done && preload_mode==2) input_valid<=1;
            if(a_write) input_valid<=0;
            if(b_write) weight_valid<=0;
        end
    end
    assign hit=reuse_requested && (((query_mode==1) && weight_valid) ||
                                  ((query_mode==2) && input_valid));
endmodule
`default_nettype wire
