`timescale 1ns/1ps
`default_nettype none
// Per-command counters, saturated only by natural 32-bit wrapping.
module perf_counters #(
    parameter integer N=4
)(
    input wire clk, rst_n, accepted, busy, done, pause,
    input wire preload_enable, compute_enable,
    input wire [N*N-1:0] active_mask, nonzero_mask,
    output reg [31:0] total_cycles, compute_cycles, preload_cycles, stall_cycles,
    output reg [31:0] mac_ops, nonzero_ops
);
    integer active_count, nonzero_count;
    always @* begin
        active_count=0; nonzero_count=0;
        for(integer i=0;i<N*N;i=i+1) begin
            active_count=active_count+int'(active_mask[i]);
            nonzero_count=nonzero_count+int'(nonzero_mask[i]);
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            total_cycles<=0; compute_cycles<=0; preload_cycles<=0;
            stall_cycles<=0; mac_ops<=0; nonzero_ops<=0;
        end else if(accepted) begin
            total_cycles<=0; compute_cycles<=0; preload_cycles<=0;
            stall_cycles<=0; mac_ops<=0; nonzero_ops<=0;
        end else begin
            if(busy && !done) total_cycles<=total_cycles+1;
            if(busy && !done && pause) stall_cycles<=stall_cycles+1;
            if(preload_enable) preload_cycles<=preload_cycles+1;
            if(compute_enable) begin
                compute_cycles<=compute_cycles+1;
                mac_ops<=mac_ops+32'(active_count);
                nonzero_ops<=nonzero_ops+32'(nonzero_count);
            end
        end
    end
endmodule
`default_nettype wire
