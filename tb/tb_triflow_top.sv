`timescale 1ns/1ps

module tb_triflow_top;
    localparam int N = 4;
    localparam int DATA_W = 8;
    localparam int ACC_W = 32;

    logic clk = 0;
    logic rst_n = 0;

    logic load_we, load_sel;
    logic [$clog2(N)-1:0] load_row, load_col;
    logic signed [DATA_W-1:0] load_data;

    logic start;
    logic [1:0] dataflow;

    logic [$clog2(N)-1:0] result_row, result_col;
    logic signed [ACC_W-1:0] result_data;

    logic busy, done;
    logic [31:0] perf_total_cycles, perf_compute_cycles;
    logic [31:0] perf_preload_cycles, perf_mac_ops;

    integer A [0:N-1][0:N-1];
    integer B [0:N-1][0:N-1];
    integer G [0:N-1][0:N-1];

    triflow_top #(
        .N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .load_we(load_we), .load_sel(load_sel),
        .load_row(load_row), .load_col(load_col), .load_data(load_data),
        .start(start), .dataflow(dataflow),
        .result_row(result_row), .result_col(result_col), .result_data(result_data),
        .busy(busy), .done(done),
        .perf_total_cycles(perf_total_cycles),
        .perf_compute_cycles(perf_compute_cycles),
        .perf_preload_cycles(perf_preload_cycles),
        .perf_mac_ops(perf_mac_ops)
    );

    always #5 clk = ~clk;

    task automatic write_matrix(input bit sel);
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    @(negedge clk);
                    load_we   = 1'b1;
                    load_sel  = sel;
                    load_row  = r;
                    load_col  = c;
                    load_data = sel ? B[r][c] : A[r][c];
                end
            end
            @(negedge clk);
            load_we = 1'b0;
        end
    endtask

    task automatic check_results(input [1:0] mode, input string name);
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    result_row = r;
                    result_col = c;
                    #1;
                    if ($signed(result_data) !== G[r][c]) begin
                        $display("FAIL %s C[%0d][%0d]: got=%0d expected=%0d",
                                 name, r, c, $signed(result_data), G[r][c]);
                        $fatal(1);
                    end
                end
            end
            $display("PASS %-18s cycles=%0d compute=%0d preload=%0d MACs=%0d",
                     name, perf_total_cycles, perf_compute_cycles,
                     perf_preload_cycles, perf_mac_ops);
        end
    endtask

    task automatic run_mode(input [1:0] mode, input string name);
        begin
            @(negedge clk);
            dataflow = mode;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            while (!done)
                @(posedge clk);

            #1;
            check_results(mode, name);
            @(posedge clk);
        end
    endtask

    integer r, c, k;
    initial begin
        $dumpfile("triflow.vcd");
        $dumpvars(0, tb_triflow_top);

        load_we = 0;
        load_sel = 0;
        load_row = 0;
        load_col = 0;
        load_data = 0;
        start = 0;
        dataflow = 0;
        result_row = 0;
        result_col = 0;

        A[0][0]=  1; A[0][1]= 2; A[0][2]= 3; A[0][3]= 4;
        A[1][0]=  5; A[1][1]= 6; A[1][2]= 7; A[1][3]= 8;
        A[2][0]= -1; A[2][1]= 2; A[2][2]=-3; A[2][3]= 4;
        A[3][0]=  8; A[3][1]= 0; A[3][2]= 1; A[3][3]=-2;

        B[0][0]=1; B[0][1]= 0; B[0][2]= 2; B[0][3]=-1;
        B[1][0]=3; B[1][1]= 1; B[1][2]= 0; B[1][3]= 2;
        B[2][0]=2; B[2][1]=-2; B[2][2]= 1; B[2][3]= 1;
        B[3][0]=0; B[3][1]= 4; B[3][2]=-1; B[3][3]= 3;

        for (r = 0; r < N; r = r + 1)
            for (c = 0; c < N; c = c + 1) begin
                G[r][c] = 0;
                for (k = 0; k < N; k = k + 1)
                    G[r][c] = G[r][c] + A[r][k] * B[k][c];
            end

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        write_matrix(1'b0);
        write_matrix(1'b1);

        run_mode(2'd0, "OUTPUT-STATIONARY");
        run_mode(2'd1, "WEIGHT-STATIONARY");
        run_mode(2'd2, "INPUT-STATIONARY");

        $display("All TriFlow-SA dataflows PASS.");
        $finish;
    end
endmodule
