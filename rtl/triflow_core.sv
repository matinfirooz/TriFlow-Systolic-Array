`timescale 1ns/1ps
`default_nettype none
// Extended interface. triflow_top preserves the original simple host ports.
module triflow_core #(
    parameter integer N=4, DATA_W=8, ACC_W=32,
    parameter integer IDX_W=(N>1)?$clog2(N):1,
    parameter integer COUNT_W=(N*N>1)?$clog2(N*N):1,
    parameter integer CYCLE_W=$clog2(3*N+1),
    parameter bit ZERO_GATE=1'b1
)(
    input wire clk, rst_n,
    input wire load_we, load_sel,
    input wire [IDX_W-1:0] load_row, load_col,
    input wire signed [DATA_W-1:0] load_data,
    output wire load_ready,
    input wire start,
    input wire [1:0] dataflow,
    input wire reuse_stationary, pause, stream_enable,
    output wire cmd_ready,
    output reg command_error,
    input wire [IDX_W-1:0] result_row, result_col,
    output wire signed [ACC_W-1:0] result_data,
    input wire result_ready,
    output wire result_valid, result_last,
    output wire [IDX_W-1:0] stream_row, stream_col,
    output wire signed [ACC_W-1:0] stream_data,
    output wire stream_done, busy, done,
    output wire [1:0] active_dataflow,
    output wire resident_weight_valid, resident_input_valid, reuse_used,
    output wire [31:0] perf_total_cycles, perf_compute_cycles, perf_preload_cycles,
    output wire [31:0] perf_stall_cycles, perf_mac_ops, perf_nonzero_ops,
    output wire [2:0] state_debug
);
    wire ctrl_ready, accepted, ctrl_busy, stream_busy, clear;
    wire preload_enable, compute_enable, preload_done, cache_hit;
    wire [COUNT_W-1:0] preload_index;
    wire [CYCLE_W-1:0] compute_cycle;
    reg stream_q;
    assign load_ready=rst_n && !ctrl_busy;
    wire legal_write=load_we && load_ready && int'(load_row)<N && int'(load_col)<N;
    // A host write wins a simultaneous write/start. No hidden command queue.
    assign cmd_ready=rst_n && ctrl_ready && !stream_busy && !load_we;
    assign busy=ctrl_busy || stream_busy;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin command_error<=0; stream_q<=0; end
        else begin
            command_error<=(start && cmd_ready && dataflow==3) ||
                (load_we && load_ready && (int'(load_row)>=N || int'(load_col)>=N));
            if(accepted) stream_q<=stream_enable;
        end
    end
    wire signed [DATA_W-1:0] a_matrix [0:N-1][0:N-1], b_matrix [0:N-1][0:N-1];
    wire signed [DATA_W-1:0] unused_a, unused_b;
    matrix_buffer #(.N(N),.DATA_W(DATA_W)) u_abuf(
        .clk(clk),.rst_n(rst_n),.we(legal_write && !load_sel),
        .wr_row(load_row),.wr_col(load_col),.wr_data(load_data),
        .rd_row({IDX_W{1'b0}}),.rd_col({IDX_W{1'b0}}),.rd_data(unused_a),.matrix(a_matrix));
    matrix_buffer #(.N(N),.DATA_W(DATA_W)) u_bbuf(
        .clk(clk),.rst_n(rst_n),.we(legal_write && load_sel),
        .wr_row(load_row),.wr_col(load_col),.wr_data(load_data),
        .rd_row({IDX_W{1'b0}}),.rd_col({IDX_W{1'b0}}),.rd_data(unused_b),.matrix(b_matrix));
    resident_tracker u_resident(
        .clk(clk),.rst_n(rst_n),.a_write(legal_write && !load_sel),.b_write(legal_write && load_sel),
        .preload_done(preload_done),.preload_mode(active_dataflow),.query_mode(dataflow),
        .reuse_requested(reuse_stationary),.weight_valid(resident_weight_valid),
        .input_valid(resident_input_valid),.hit(cache_hit));
    triflow_controller #(.N(N)) u_ctrl(
        .clk(clk),.rst_n(rst_n),.start(start && cmd_ready),.pause(pause),.dataflow(dataflow),
        .reuse_hit(cache_hit),.ready(ctrl_ready),.accepted(accepted),.busy(ctrl_busy),.done(done),
        .clear(clear),.preload_enable(preload_enable),.compute_enable(compute_enable),
        .preload_done(preload_done),.mode(active_dataflow),.reuse_used(reuse_used),
        .preload_index(preload_index),.compute_cycle(compute_cycle),.state_debug(state_debug));
    wire pv, pw;
    wire [IDX_W-1:0] pr, pc;
    wire signed [DATA_W-1:0] pd;
    preload_sequencer #(.N(N),.DATA_W(DATA_W)) u_preload(
        .enable(preload_enable),.mode(active_dataflow),.index(preload_index),
        .matrix_a(a_matrix),.matrix_b(b_matrix),.valid(pv),.is_weight(pw),.row(pr),.col(pc),.data(pd));
    wire signed [DATA_W-1:0] a_left [0:N-1], b_top [0:N-1];
    wire [N*N-1:0] active_mask, nonzero_mask;
    wavefront_scheduler #(.N(N),.DATA_W(DATA_W)) u_schedule(
        .enable(compute_enable),.mode(active_dataflow),.cycle(compute_cycle),
        .matrix_a(a_matrix),.matrix_b(b_matrix),.a_left(a_left),.b_top(b_top),.mac_valid(active_mask));
    wire signed [ACC_W-1:0] os_now [0:N-1][0:N-1], ws_bottom [0:N-1], is_right [0:N-1];
    triflow_array #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_array(
        .clk(clk),.rst_n(rst_n),.clear(clear),.step(compute_enable),.mode(active_dataflow),
        .mac_valid(active_mask),.preload_valid(pv),.preload_is_weight(pw),.preload_row(pr),
        .preload_col(pc),.preload_data(pd),.a_left(a_left),.b_top(b_top),.os_now(os_now),
        .ws_bottom_now(ws_bottom),.is_right_now(is_right),.nonzero_ops(nonzero_mask));
    wire [N*N-1:0] write_mask;
    wire signed [ACC_W-1:0] write_data [0:N-1][0:N-1], results [0:N-1][0:N-1];
    result_collector #(.N(N),.ACC_W(ACC_W)) u_collector(
        .enable(compute_enable),.mode(active_dataflow),.cycle(compute_cycle),.os_now(os_now),
        .ws_bottom_now(ws_bottom),.is_right_now(is_right),.write_mask(write_mask),.write_data(write_data));
    result_buffer #(.N(N),.ACC_W(ACC_W)) u_results(
        .clk(clk),.rst_n(rst_n),.clear(clear),.write_mask(write_mask),.write_data(write_data),
        .rd_row(result_row),.rd_col(result_col),.rd_data(result_data),.matrix(results));
    result_streamer #(.N(N),.ACC_W(ACC_W)) u_stream(
        .clk(clk),.rst_n(rst_n),.launch(done && stream_q),.ready(result_ready),.results(results),
        .busy(stream_busy),.done(stream_done),.valid(result_valid),.last(result_last),
        .row(stream_row),.col(stream_col),.data(stream_data));
    perf_counters #(.N(N)) u_perf(
        .clk(clk),.rst_n(rst_n),.accepted(accepted),.busy(ctrl_busy),.done(done),.pause(pause),
        .preload_enable(preload_enable),.compute_enable(compute_enable),.active_mask(active_mask),
        .nonzero_mask(nonzero_mask),.total_cycles(perf_total_cycles),.compute_cycles(perf_compute_cycles),
        .preload_cycles(perf_preload_cycles),.stall_cycles(perf_stall_cycles),
        .mac_ops(perf_mac_ops),.nonzero_ops(perf_nonzero_ops));
endmodule
`default_nettype wire
