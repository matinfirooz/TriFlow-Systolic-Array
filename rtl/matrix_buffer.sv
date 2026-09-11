module matrix_buffer #(
    parameter int N = 4,
    parameter int DATA_W = 8
) (
    input  logic clk,
    input  logic we,
    input  logic [$clog2(N)-1:0] wr_row,
    input  logic [$clog2(N)-1:0] wr_col,
    input  logic signed [DATA_W-1:0] wr_data,

    input  logic [$clog2(N)-1:0] rd_row,
    input  logic [$clog2(N)-1:0] rd_col,
    output logic signed [DATA_W-1:0] rd_data,

    output logic signed [DATA_W-1:0] matrix [0:N-1][0:N-1]
);
    integer r, c;

    always_ff @(posedge clk) begin
        if (we)
            matrix[wr_row][wr_col] <= wr_data;
    end

    always_comb begin
        rd_data = matrix[rd_row][rd_col];
    end

    initial begin
        for (r = 0; r < N; r = r + 1)
            for (c = 0; c < N; c = c + 1)
                matrix[r][c] = '0;
    end
endmodule
