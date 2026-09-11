module triflow_pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clear,

    input  logic [1:0] mode,

    // Direct preload path used by WS / IS modes.
    input  logic preload_weight,
    input  logic preload_input,
    input  logic signed [DATA_W-1:0] preload_data,

    // Systolic operand links.
    input  logic signed [DATA_W-1:0] a_west,
    input  logic signed [DATA_W-1:0] b_north,
    output logic signed [DATA_W-1:0] a_east,
    output logic signed [DATA_W-1:0] b_south,

    // Partial-sum links for WS and IS.
    input  logic signed [ACC_W-1:0] psum_north,
    input  logic signed [ACC_W-1:0] psum_west,
    output logic signed [ACC_W-1:0] psum_south,
    output logic signed [ACC_W-1:0] psum_east,

    // Observability / result capture.
    output logic signed [ACC_W-1:0] acc_value,
    output logic signed [ACC_W-1:0] os_sum_now,
    output logic signed [ACC_W-1:0] ws_sum_now,
    output logic signed [ACC_W-1:0] is_sum_now
);
    localparam logic [1:0] DF_OS = 2'd0;
    localparam logic [1:0] DF_WS = 2'd1;
    localparam logic [1:0] DF_IS = 2'd2;

    logic signed [DATA_W-1:0] weight_reg;
    logic signed [DATA_W-1:0] input_reg;
    logic signed [ACC_W-1:0]  acc_reg;

    logic signed [(2*DATA_W)-1:0] prod_os;
    logic signed [(2*DATA_W)-1:0] prod_ws;
    logic signed [(2*DATA_W)-1:0] prod_is;

    always_comb begin
        prod_os = $signed(a_west) * $signed(b_north);
        prod_ws = $signed(a_west) * $signed(weight_reg);
        prod_is = $signed(input_reg) * $signed(b_north);

        os_sum_now = $signed(acc_reg) + $signed(prod_os);
        ws_sum_now = $signed(psum_north) + $signed(prod_ws);
        is_sum_now = $signed(psum_west)  + $signed(prod_is);

        acc_value = acc_reg;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= '0;
            input_reg  <= '0;
            acc_reg    <= '0;
            a_east     <= '0;
            b_south    <= '0;
            psum_south <= '0;
            psum_east  <= '0;
        end else begin
            if (preload_weight)
                weight_reg <= preload_data;
            if (preload_input)
                input_reg <= preload_data;

            if (clear) begin
                acc_reg    <= '0;
                a_east     <= '0;
                b_south    <= '0;
                psum_south <= '0;
                psum_east  <= '0;
            end else begin
                case (mode)
                    DF_OS: begin
                        a_east  <= a_west;
                        b_south <= b_north;
                        acc_reg <= os_sum_now;
                        psum_south <= '0;
                        psum_east  <= '0;
                    end

                    DF_WS: begin
                        a_east     <= a_west;
                        b_south    <= '0;
                        psum_south <= ws_sum_now;
                        psum_east  <= '0;
                    end

                    DF_IS: begin
                        a_east    <= '0;
                        b_south   <= b_north;
                        psum_east <= is_sum_now;
                        psum_south<= '0;
                    end

                    default: begin
                        a_east     <= '0;
                        b_south    <= '0;
                        psum_south <= '0;
                        psum_east  <= '0;
                    end
                endcase
            end
        end
    end
endmodule
