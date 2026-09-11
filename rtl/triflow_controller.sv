module triflow_controller #(
    parameter int N = 4,
    parameter int DATA_W = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [1:0] dataflow,

    input  logic signed [DATA_W-1:0] matrix_a [0:N-1][0:N-1],
    input  logic signed [DATA_W-1:0] matrix_b [0:N-1][0:N-1],

    output logic array_clear,
    output logic [1:0] array_mode,

    output logic preload_valid,
    output logic preload_is_weight,
    output logic [$clog2(N)-1:0] preload_row,
    output logic [$clog2(N)-1:0] preload_col,
    output logic signed [DATA_W-1:0] preload_data,

    output logic signed [DATA_W-1:0] a_left [0:N-1],
    output logic signed [DATA_W-1:0] b_top  [0:N-1],

    output logic collector_clear,
    output logic collector_enable,
    output logic [$clog2(3*N+1)-1:0] collector_cycle,

    output logic busy,
    output logic done,

    output logic [31:0] perf_total_cycles,
    output logic [31:0] perf_compute_cycles,
    output logic [31:0] perf_preload_cycles,
    output logic [31:0] perf_mac_ops
);
    localparam logic [1:0] DF_OS = 2'd0;
    localparam logic [1:0] DF_WS = 2'd1;
    localparam logic [1:0] DF_IS = 2'd2;

    localparam logic [2:0] ST_IDLE    = 3'd0;
    localparam logic [2:0] ST_CLEAR   = 3'd1;
    localparam logic [2:0] ST_PRELOAD = 3'd2;
    localparam logic [2:0] ST_COMPUTE = 3'd3;
    localparam logic [2:0] ST_DONE    = 3'd4;

    localparam int COMPUTE_LAST = (3*N) - 3;
    localparam int COUNT_W = (N*N <= 2) ? 1 : $clog2(N*N + 1);
    localparam int CYCLE_W = $clog2(3*N+1);

    logic [2:0] state;
    logic [1:0] mode_q;
    logic [COUNT_W-1:0] preload_idx;
    logic [CYCLE_W-1:0] compute_cycle;

    integer r, c;
    integer dynamic_idx;

    assign busy = (state != ST_IDLE) && (state != ST_DONE);
    assign array_mode = mode_q;
    assign collector_enable = (state == ST_COMPUTE);
    assign collector_cycle = compute_cycle;

    always_comb begin
        array_clear = (state == ST_CLEAR);
        collector_clear = (state == ST_CLEAR);

        preload_valid = 1'b0;
        preload_is_weight = 1'b0;
        preload_row = '0;
        preload_col = '0;
        preload_data = '0;

        for (r = 0; r < N; r = r + 1)
            a_left[r] = '0;
        for (c = 0; c < N; c = c + 1)
            b_top[c] = '0;

        if (state == ST_PRELOAD) begin
            preload_valid = 1'b1;
            preload_row = preload_idx / N;
            preload_col = preload_idx % N;

            if (mode_q == DF_WS) begin
                preload_is_weight = 1'b1;
                preload_data = matrix_b[preload_idx / N][preload_idx % N];
            end else begin
                preload_is_weight = 1'b0;
                preload_data = matrix_a[preload_idx / N][preload_idx % N];
            end
        end

        if (state == ST_COMPUTE) begin
            case (mode_q)
                DF_OS: begin
                    // A[i][k] enters row i at t=i+k.
                    for (r = 0; r < N; r = r + 1) begin
                        dynamic_idx = $signed({1'b0,compute_cycle}) - r;
                        if ((dynamic_idx >= 0) && (dynamic_idx < N))
                            a_left[r] = matrix_a[r][dynamic_idx];
                    end
                    // B[k][j] enters col j at t=j+k.
                    for (c = 0; c < N; c = c + 1) begin
                        dynamic_idx = $signed({1'b0,compute_cycle}) - c;
                        if ((dynamic_idx >= 0) && (dynamic_idx < N))
                            b_top[c] = matrix_b[dynamic_idx][c];
                    end
                end

                DF_WS: begin
                    // PE(k,j) owns B[k][j]. Stream A[i][k] along row k.
                    for (r = 0; r < N; r = r + 1) begin
                        dynamic_idx = $signed({1'b0,compute_cycle}) - r;
                        if ((dynamic_idx >= 0) && (dynamic_idx < N))
                            a_left[r] = matrix_a[dynamic_idx][r];
                    end
                end

                DF_IS: begin
                    // PE(i,k) owns A[i][k]. Stream B[k][j] down col k.
                    for (c = 0; c < N; c = c + 1) begin
                        dynamic_idx = $signed({1'b0,compute_cycle}) - c;
                        if ((dynamic_idx >= 0) && (dynamic_idx < N))
                            b_top[c] = matrix_b[c][dynamic_idx];
                    end
                end

                default: begin end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            mode_q <= DF_OS;
            preload_idx <= '0;
            compute_cycle <= '0;
            done <= 1'b0;
            perf_total_cycles <= 0;
            perf_compute_cycles <= 0;
            perf_preload_cycles <= 0;
            perf_mac_ops <= 0;
        end else begin
            done <= 1'b0;

            if ((state != ST_IDLE) && (state != ST_DONE))
                perf_total_cycles <= perf_total_cycles + 1;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        mode_q <= dataflow;
                        preload_idx <= '0;
                        compute_cycle <= '0;
                        perf_total_cycles <= 0;
                        perf_compute_cycles <= 0;
                        perf_preload_cycles <= 0;
                        perf_mac_ops <= N*N*N;
                        state <= ST_CLEAR;
                    end
                end

                ST_CLEAR: begin
                    if (mode_q == DF_OS)
                        state <= ST_COMPUTE;
                    else
                        state <= ST_PRELOAD;
                end

                ST_PRELOAD: begin
                    perf_preload_cycles <= perf_preload_cycles + 1;
                    if (preload_idx == N*N-1) begin
                        preload_idx <= '0;
                        compute_cycle <= '0;
                        state <= ST_COMPUTE;
                    end else begin
                        preload_idx <= preload_idx + 1'b1;
                    end
                end

                ST_COMPUTE: begin
                    perf_compute_cycles <= perf_compute_cycles + 1;
                    if (compute_cycle == COMPUTE_LAST[CYCLE_W-1:0]) begin
                        state <= ST_DONE;
                    end else begin
                        compute_cycle <= compute_cycle + 1'b1;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
