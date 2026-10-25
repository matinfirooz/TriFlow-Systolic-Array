`timescale 1ns/1ps
`default_nettype none
module triflow_controller #(
    parameter integer N=4,
    parameter integer COUNT_W=(N*N>1)?$clog2(N*N):1,
    parameter integer CYCLE_W=$clog2(3*N+1)
)(
    input wire clk, rst_n, start, pause,
    input wire [1:0] dataflow,
    input wire reuse_hit,
    output wire ready, accepted, busy, done, clear, preload_enable, compute_enable, preload_done,
    output wire [1:0] mode,
    output reg reuse_used,
    output reg [COUNT_W-1:0] preload_index,
    output reg [CYCLE_W-1:0] compute_cycle,
    output wire [2:0] state_debug
);
    import triflow_pkg::*;
    reg [2:0] state;
    reg [1:0] mode_q;
    assign ready=(state==ST_IDLE);
    assign accepted=ready && start && dataflow<3;
    assign busy=(state!=ST_IDLE);
    assign done=(state==ST_DONE);
    assign clear=(state==ST_CLEAR) && !pause;
    assign preload_enable=(state==ST_PRELOAD) && !pause;
    assign compute_enable=(state==ST_COMPUTE) && !pause;
    assign preload_done=preload_enable && int'(preload_index)==N*N-1;
    assign mode=mode_q;
    assign state_debug=state;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=ST_IDLE; mode_q<=0; reuse_used<=0; preload_index<='0; compute_cycle<='0;
        end else begin
            case(state)
                ST_IDLE: if(accepted) begin
                    state<=ST_CLEAR; mode_q<=dataflow;
                    reuse_used<=reuse_hit && dataflow!=0;
                    preload_index<='0; compute_cycle<='0;
                end
                ST_CLEAR: if(!pause) begin
                    if(mode_q==0 || reuse_used) state<=ST_COMPUTE;
                    else state<=ST_PRELOAD;
                end
                ST_PRELOAD: if(!pause) begin
                    if(int'(preload_index)==N*N-1) state<=ST_COMPUTE;
                    else preload_index<=preload_index+1'b1;
                end
                ST_COMPUTE: if(!pause) begin
                    if(int'(compute_cycle)==3*N-3) state<=ST_DONE;
                    else compute_cycle<=compute_cycle+1'b1;
                end
                ST_DONE: state<=ST_IDLE;
                default: state<=ST_IDLE;
            endcase
        end
    end
    initial if(N<1) $fatal(1,"N must be positive");
endmodule
`default_nettype wire
