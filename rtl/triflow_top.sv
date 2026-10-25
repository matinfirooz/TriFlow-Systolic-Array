`timescale 1ns/1ps
`default_nettype none
// Original top-level port names retained. New features use triflow_core directly.
module triflow_top #(
    parameter integer N=4, DATA_W=8, ACC_W=32,
    parameter integer IDX_W=(N>1)?$clog2(N):1
)(
    input wire clk, rst_n, load_we, load_sel,
    input wire [IDX_W-1:0] load_row, load_col,
    input wire signed [DATA_W-1:0] load_data,
    input wire start,
    input wire [1:0] dataflow,
    input wire [IDX_W-1:0] result_row, result_col,
    output wire signed [ACC_W-1:0] result_data,
    output wire busy,
    output reg done,
    output wire [31:0] perf_total_cycles, perf_compute_cycles, perf_preload_cycles, perf_mac_ops
);
    wire core_done;
    wire unused_load_ready;
    wire unused_cmd_ready;
    wire unused_command_error;
    wire unused_result_valid;
    wire unused_result_last;
    wire unused_stream_done;
    wire unused_resident_weight_valid;
    wire unused_resident_input_valid;
    wire unused_reuse_used;
    wire [IDX_W-1:0] unused_stream_row;
    wire [IDX_W-1:0] unused_stream_col;
    wire [ACC_W-1:0] unused_stream_data;
    wire [2-1:0] unused_active_dataflow;
    wire [32-1:0] unused_perf_stall_cycles;
    wire [32-1:0] unused_perf_nonzero_ops;
    wire [3-1:0] unused_state_debug;

    // Match the original wrapper: done is pulsed once the controller is idle.
    always @(posedge clk or negedge rst_n)
        if(!rst_n) done<=0;
        else done<=core_done;
    triflow_core #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W)) u_core(
        .clk(clk),.rst_n(rst_n),.load_we(load_we),.load_sel(load_sel),
        .load_row(load_row),.load_col(load_col),.load_data(load_data),.load_ready(unused_load_ready),
        .start(start),.dataflow(dataflow),.reuse_stationary(1'b0),.pause(1'b0),.stream_enable(1'b0),
        .cmd_ready(unused_cmd_ready),.command_error(unused_command_error),.result_row(result_row),.result_col(result_col),.result_data(result_data),
        .result_ready(1'b1),.result_valid(unused_result_valid),.result_last(unused_result_last),.stream_row(unused_stream_row),.stream_col(unused_stream_col),.stream_data(unused_stream_data),
        .stream_done(unused_stream_done),.busy(busy),.done(core_done),.active_dataflow(unused_active_dataflow),.resident_weight_valid(unused_resident_weight_valid),
        .resident_input_valid(unused_resident_input_valid),.reuse_used(unused_reuse_used),.perf_total_cycles(perf_total_cycles),
        .perf_compute_cycles(perf_compute_cycles),.perf_preload_cycles(perf_preload_cycles),
        .perf_stall_cycles(unused_perf_stall_cycles),.perf_mac_ops(perf_mac_ops),.perf_nonzero_ops(unused_perf_nonzero_ops),.state_debug(unused_state_debug));
endmodule
`default_nettype wire
