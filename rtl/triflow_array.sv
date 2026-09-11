module triflow_array #(
    parameter int N = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input logic clk,
    input logic rst_n,
    input logic clear,
    input logic [1:0] mode,

    // Direct one-PE-per-cycle preload port.
    input logic preload_valid,
    input logic preload_is_weight,
    input logic [$clog2(N)-1:0] preload_row,
    input logic [$clog2(N)-1:0] preload_col,
    input logic signed [DATA_W-1:0] preload_data,

    // Boundary injections.
    input logic signed [DATA_W-1:0] a_left [0:N-1],
    input logic signed [DATA_W-1:0] b_top  [0:N-1],

    // "Current-cycle" final sums used by the controller for result capture.
    output logic signed [ACC_W-1:0] os_now [0:N-1][0:N-1],
    output logic signed [ACC_W-1:0] ws_bottom_now [0:N-1],
    output logic signed [ACC_W-1:0] is_right_now  [0:N-1],

    output logic signed [ACC_W-1:0] os_acc [0:N-1][0:N-1]
);
    logic signed [DATA_W-1:0] a_link [0:N-1][0:N];
    logic signed [DATA_W-1:0] b_link [0:N][0:N-1];

    logic signed [ACC_W-1:0] psum_v [0:N][0:N-1];
    logic signed [ACC_W-1:0] psum_h [0:N-1][0:N];

    logic signed [ACC_W-1:0] os_sum [0:N-1][0:N-1];
    logic signed [ACC_W-1:0] ws_sum [0:N-1][0:N-1];
    logic signed [ACC_W-1:0] is_sum [0:N-1][0:N-1];

    genvar r, c;

    generate
        for (r = 0; r < N; r = r + 1) begin : G_BOUND_A
            always_comb a_link[r][0] = a_left[r];
            always_comb psum_h[r][0] = '0;
        end

        for (c = 0; c < N; c = c + 1) begin : G_BOUND_B
            always_comb b_link[0][c] = b_top[c];
            always_comb psum_v[0][c] = '0;
        end
    endgenerate

    generate
        for (r = 0; r < N; r = r + 1) begin : G_ROW
            for (c = 0; c < N; c = c + 1) begin : G_COL
                logic pw, pi;

                always_comb begin
                    pw = preload_valid && preload_is_weight &&
                         (preload_row == r) && (preload_col == c);
                    pi = preload_valid && !preload_is_weight &&
                         (preload_row == r) && (preload_col == c);
                end

                triflow_pe #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear(clear),
                    .mode(mode),

                    .preload_weight(pw),
                    .preload_input(pi),
                    .preload_data(preload_data),

                    .a_west(a_link[r][c]),
                    .b_north(b_link[r][c]),
                    .a_east(a_link[r][c+1]),
                    .b_south(b_link[r+1][c]),

                    .psum_north(psum_v[r][c]),
                    .psum_west (psum_h[r][c]),
                    .psum_south(psum_v[r+1][c]),
                    .psum_east (psum_h[r][c+1]),

                    .acc_value(os_acc[r][c]),
                    .os_sum_now(os_sum[r][c]),
                    .ws_sum_now(ws_sum[r][c]),
                    .is_sum_now(is_sum[r][c])
                );

                always_comb os_now[r][c] = os_sum[r][c];
            end
        end
    endgenerate

    generate
        for (c = 0; c < N; c = c + 1) begin : G_WS_OUT
            always_comb ws_bottom_now[c] = ws_sum[N-1][c];
        end
        for (r = 0; r < N; r = r + 1) begin : G_IS_OUT
            always_comb is_right_now[r] = is_sum[r][N-1];
        end
    endgenerate
endmodule
