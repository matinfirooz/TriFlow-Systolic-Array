module triflow_top #(
    parameter int N = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input logic clk,
    input logic rst_n,

    // Host programming interface.
    input logic load_we,
    input logic load_sel, // 0=A, 1=B
    input logic [$clog2(N)-1:0] load_row,
    input logic [$clog2(N)-1:0] load_col,
    input logic signed [DATA_W-1:0] load_data,

    input logic start,
    input logic [1:0] dataflow,

    input logic [$clog2(N)-1:0] result_row,
    input logic [$clog2(N)-1:0] result_col,
    output logic signed [ACC_W-1:0] result_data,

    output logic busy,
    output logic done,

    output logic [31:0] perf_total_cycles,
    output logic [31:0] perf_compute_cycles,
    output logic [31:0] perf_preload_cycles,
    output logic [31:0] perf_mac_ops
);
    logic signed [DATA_W-1:0] A [0:N-1][0:N-1];
    logic signed [DATA_W-1:0] B [0:N-1][0:N-1];

    logic signed [DATA_W-1:0] dummy_a, dummy_b;

    matrix_buffer #(.N(N), .DATA_W(DATA_W)) u_abuf (
        .clk(clk),
        .we(load_we && !load_sel && !busy),
        .wr_row(load_row), .wr_col(load_col), .wr_data(load_data),
        .rd_row('0), .rd_col('0), .rd_data(dummy_a),
        .matrix(A)
    );

    matrix_buffer #(.N(N), .DATA_W(DATA_W)) u_bbuf (
        .clk(clk),
        .we(load_we && load_sel && !busy),
        .wr_row(load_row), .wr_col(load_col), .wr_data(load_data),
        .rd_row('0), .rd_col('0), .rd_data(dummy_b),
        .matrix(B)
    );

    logic array_clear;
    logic [1:0] array_mode;
    logic preload_valid, preload_is_weight;
    logic [$clog2(N)-1:0] preload_row, preload_col;
    logic signed [DATA_W-1:0] preload_data;
    logic signed [DATA_W-1:0] a_left [0:N-1];
    logic signed [DATA_W-1:0] b_top  [0:N-1];

    logic collector_clear, collector_enable;
    logic [$clog2(3*N+1)-1:0] collector_cycle;

    logic signed [ACC_W-1:0] os_now [0:N-1][0:N-1];
    logic signed [ACC_W-1:0] ws_bottom_now [0:N-1];
    logic signed [ACC_W-1:0] is_right_now  [0:N-1];
    logic signed [ACC_W-1:0] os_acc [0:N-1][0:N-1];
    logic signed [ACC_W-1:0] results [0:N-1][0:N-1];

    triflow_controller #(
        .N(N),
        .DATA_W(DATA_W)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n),
        .start(start), .dataflow(dataflow),
        .matrix_a(A), .matrix_b(B),

        .array_clear(array_clear),
        .array_mode(array_mode),

        .preload_valid(preload_valid),
        .preload_is_weight(preload_is_weight),
        .preload_row(preload_row),
        .preload_col(preload_col),
        .preload_data(preload_data),

        .a_left(a_left),
        .b_top(b_top),

        .collector_clear(collector_clear),
        .collector_enable(collector_enable),
        .collector_cycle(collector_cycle),

        .busy(busy), .done(done),
        .perf_total_cycles(perf_total_cycles),
        .perf_compute_cycles(perf_compute_cycles),
        .perf_preload_cycles(perf_preload_cycles),
        .perf_mac_ops(perf_mac_ops)
    );

    triflow_array #(
        .N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) u_array (
        .clk(clk), .rst_n(rst_n),
        .clear(array_clear),
        .mode(array_mode),

        .preload_valid(preload_valid),
        .preload_is_weight(preload_is_weight),
        .preload_row(preload_row),
        .preload_col(preload_col),
        .preload_data(preload_data),

        .a_left(a_left),
        .b_top(b_top),

        .os_now(os_now),
        .ws_bottom_now(ws_bottom_now),
        .is_right_now(is_right_now),
        .os_acc(os_acc)
    );

    result_collector #(
        .N(N), .ACC_W(ACC_W)
    ) u_results (
        .clk(clk), .rst_n(rst_n),
        .clear(collector_clear),
        .enable(collector_enable),
        .mode(array_mode),
        .cycle(collector_cycle),

        .os_now(os_now),
        .ws_bottom_now(ws_bottom_now),
        .is_right_now(is_right_now),

        .rd_row(result_row),
        .rd_col(result_col),
        .rd_data(result_data),
        .results(results)
    );
endmodule
