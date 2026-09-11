module result_buffer #(
    parameter int N = 4,
    parameter int ACC_W = 32
) (
    input  logic clk,
    input  logic clear,

    input  logic we,
    input  logic [$clog2(N)-1:0] wr_row,
    input  logic [$clog2(N)-1:0] wr_col,
    input  logic signed [ACC_W-1:0] wr_data,

    input  logic [$clog2(N)-1:0] rd_row,
    input  logic [$clog2(N)-1:0] rd_col,
    output logic signed [ACC_W-1:0] rd_data,

    output logic signed [ACC_W-1:0] matrix [0:N-1][0:N-1]
);
    integer r, c;

    always_ff @(posedge clk) begin
        if (clear) begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1)
                    matrix[r][c] <= '0;
        end else if (we) begin
            matrix[wr_row][wr_col] <= wr_data;
        end
    end

    always_comb begin
        rd_data = matrix[rd_row][rd_col];
    end
endmodule
