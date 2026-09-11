module result_collector #(
    parameter int N = 4,
    parameter int ACC_W = 32
) (
    input logic clk,
    input logic rst_n,
    input logic clear,
    input logic enable,
    input logic [1:0] mode,
    input logic [$clog2(3*N+1)-1:0] cycle,

    input logic signed [ACC_W-1:0] os_now [0:N-1][0:N-1],
    input logic signed [ACC_W-1:0] ws_bottom_now [0:N-1],
    input logic signed [ACC_W-1:0] is_right_now  [0:N-1],

    input logic [$clog2(N)-1:0] rd_row,
    input logic [$clog2(N)-1:0] rd_col,
    output logic signed [ACC_W-1:0] rd_data,

    output logic signed [ACC_W-1:0] results [0:N-1][0:N-1]
);
    localparam logic [1:0] DF_OS = 2'd0;
    localparam logic [1:0] DF_WS = 2'd1;
    localparam logic [1:0] DF_IS = 2'd2;

    integer i, j;
    integer idx;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    results[i][j] <= '0;
        end else if (enable) begin
            case (mode)
                DF_OS: begin
                    // PE(i,j) sees its final k=N-1 product at:
                    // cycle = i + j + (N-1).
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            if ($signed({1'b0,cycle}) == (i + j + N - 1))
                                results[i][j] <= os_now[i][j];
                        end
                    end
                end

                DF_WS: begin
                    // Physical row k owns B[k][j]. Bottom combinational sum
                    // completes C[i][j] when cycle = i+j+(N-1).
                    for (j = 0; j < N; j = j + 1) begin
                        idx = $signed({1'b0,cycle}) - j - (N - 1);
                        if ((idx >= 0) && (idx < N))
                            results[idx][j] <= ws_bottom_now[j];
                    end
                end

                DF_IS: begin
                    // Physical column k owns A[i][k]. Right-edge combinational
                    // sum completes C[i][j] when cycle = i+j+(N-1).
                    for (i = 0; i < N; i = i + 1) begin
                        idx = $signed({1'b0,cycle}) - i - (N - 1);
                        if ((idx >= 0) && (idx < N))
                            results[i][idx] <= is_right_now[i];
                    end
                end

                default: begin end
            endcase
        end
    end

    always_comb rd_data = results[rd_row][rd_col];
endmodule
