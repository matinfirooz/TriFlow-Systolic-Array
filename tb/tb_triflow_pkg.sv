`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_pkg;
    import triflow_pkg::*;
    initial begin
        `CHECK(DF_OUTPUT_STATIONARY==0 && DF_WEIGHT_STATIONARY==1 && DF_INPUT_STATIONARY==2,"mode encodings")
        `CHECK(index_width(1)==1 && index_width(3)==2 && index_width(8)==3,"index widths")
        `CHECK(compute_cycles(1)==1 && compute_cycles(4)==10,"cycle formula")
        `CHECK(ST_IDLE==0 && ST_DONE==4,"state encodings")
        $display("PASS tb_triflow_pkg"); $finish;
    end
endmodule
