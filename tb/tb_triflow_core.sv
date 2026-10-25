`timescale 1ns/1ps
`include "test_utils.svh"
module tb_triflow_core #(
    parameter integer N=4, DATA_W=8, ACC_W=32, SEED=42, TRIALS=5,
    parameter bit ZERO_GATE=1'b1
);
    localparam integer IW=(N>1)?$clog2(N):1;
    `CLOCK
    `WATCHDOG
    reg rst_n=0,load_we=0,load_sel=0,start=0,reuse_stationary=0,pause=0,stream_enable=0,result_ready=0;
    reg [IW-1:0] load_row=0,load_col=0,result_row=0,result_col=0;
    reg signed [DATA_W-1:0] load_data=0;
    reg [1:0] dataflow=0;
    wire load_ready,cmd_ready,command_error,result_valid,result_last,stream_done,busy,done;
    wire resident_weight_valid,resident_input_valid,reuse_used;
    wire [1:0] active_dataflow;
    wire [IW-1:0] stream_row,stream_col;
    wire signed [ACC_W-1:0] result_data,stream_data;
    wire [31:0] perf_total_cycles,perf_compute_cycles,perf_preload_cycles,perf_stall_cycles,perf_mac_ops,perf_nonzero_ops;
    wire [2:0] state_debug;
    integer A [0:N-1][0:N-1],B [0:N-1][0:N-1];
    reg signed [ACC_W-1:0] G [0:N-1][0:N-1];
    reg [31:0] rng=32'(SEED);
    integer nz,transactions=0;
    integer metrics;
    string metrics_path;
    triflow_core #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) dut(.*);
    function automatic integer next_rand;
        begin
            rng=rng ^ (rng<<13); rng=rng ^ (rng>>17); rng=rng ^ (rng<<5);
            next_rand=int'(rng & 32'h7fffffff);
        end
    endfunction
    function automatic integer wrap_operand(input integer value);
        reg signed [DATA_W-1:0] q;
        begin q=DATA_W'(value); wrap_operand=int'(q); end
    endfunction
    task automatic golden;
        longint signed sum;
        begin
            nz=0;
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                sum=0;
                for(integer k=0;k<N;k=k+1) begin
                    sum=sum+64'(A[r][k])*64'(B[k][c]);
                    if(A[r][k]!=0 && B[k][c]!=0) nz=nz+1;
                end
                G[r][c]=ACC_W'(sum);
            end
        end
    endtask
    task automatic load_matrix(input bit sel);
        begin
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                @(negedge clk); `CHECK(load_ready,"host write readiness")
                load_we=1; load_sel=sel; load_row=IW'(r); load_col=IW'(c);
                load_data=DATA_W'(sel?B[r][c]:A[r][c]);
            end
            tick; @(negedge clk); load_we=0;
        end
    endtask
    task automatic check_matrix;
        begin
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                result_row=IW'(r); result_col=IW'(c); #1;
                if(result_data!==G[r][c]) $fatal(1,"C[%0d,%0d] mode=%0d N=%0d got=%0d expected=%0d",r,c,active_dataflow,N,result_data,G[r][c]);
            end
        end
    endtask
    task automatic run(input integer mode,input bit reuse_req,input integer expected_preload,input bit stalls,input bit streaming,input bit overlap_write=0);
        integer guard,stall_count,out_idx;
        reg signed [ACC_W-1:0] held_data;
        reg [IW-1:0] held_row,held_col;
        reg held_last,overlap_issued;
        begin
            golden;
            @(negedge clk);
            `CHECK(cmd_ready,"command ready before launch")
            start=1; dataflow=2'(mode); reuse_stationary=reuse_req; stream_enable=streaming;
            tick; `CHECK(busy && int'(active_dataflow)==mode,"accepted command")
            @(negedge clk); start=0; dataflow=3; reuse_stationary=0; stream_enable=!streaming;
            guard=0; stall_count=0;
            while(!done) begin
                pause=stalls && ((guard%4)==1 || (guard%7)==3);
                // Commands and writes issued while the controller is busy must not alter this job.
                start=(guard%5)==2; load_we=(guard%5)==2; load_data='1; load_sel=1;
                if(pause) stall_count=stall_count+1;
                tick; guard=guard+1;
                `CHECK(int'(active_dataflow)==mode && !command_error,"configuration latched while busy")
                `CHECK(guard<10*N*N+50,"completion timeout")
                @(negedge clk);
            end
            pause=0; start=0; load_we=0;
            `CHECK(perf_compute_cycles==3*N-2 && perf_preload_cycles==32'(expected_preload),"compute/preload cycles")
            `CHECK(perf_stall_cycles==32'(stall_count),"pause accounting")
            `CHECK(perf_total_cycles==32'(1+expected_preload+3*N-2+stall_count),"total includes clear and pauses")
            `CHECK(perf_mac_ops==N*N*N && perf_nonzero_ops==32'(nz),"operation counters")
            `CHECK(reuse_used==(reuse_req && mode!=0 && expected_preload==0),"reuse hit latched")
            if(metrics) $fdisplay(metrics,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",N,DATA_W,ACC_W,mode,reuse_used,streaming,perf_total_cycles,perf_compute_cycles,perf_preload_cycles,perf_stall_cycles,perf_mac_ops,perf_nonzero_ops,ZERO_GATE);
            check_matrix;
            if(streaming) begin
                out_idx=0; guard=0; overlap_issued=0;
                while(out_idx<N*N) begin
                    @(negedge clk); result_ready=((next_rand()%4)!=0);
                    if(result_valid) begin
                        if(overlap_write && !overlap_issued) begin
                            `CHECK(load_ready,"operand loading overlaps result drain")
                            A[0][0]=wrap_operand(A[0][0]+3); load_we=1; load_sel=0;
                            load_row=0; load_col=0; load_data=DATA_W'(A[0][0]); overlap_issued=1;
                        end else load_we=0;
                        `CHECK(busy && !cmd_ready,"result bank locked during stream")
                        `CHECK(int'(stream_row)==out_idx/N && int'(stream_col)==out_idx%N,"stream order")
                        `CHECK(stream_data===G[out_idx/N][out_idx%N] && result_last==(out_idx==N*N-1),"stream values/last")
                        held_data=stream_data; held_row=stream_row; held_col=stream_col; held_last=result_last;
                        tick;
                        if(result_ready) out_idx=out_idx+1;
                        else begin
                            `CHECK(result_valid && stream_data===held_data && stream_row===held_row && stream_col===held_col && result_last===held_last,"stream stability under backpressure")
                        end
                    end else tick;
                    guard=guard+1; `CHECK(guard<12*N*N+20,"stream timeout")
                end
                load_we=0;
                `CHECK(stream_done && !busy,"stream completion")
                @(negedge clk); result_ready=0;
            end else begin
                while(busy) tick;
            end
            tick; `CHECK(!done && !stream_done && cmd_ready,"completion pulses")
            transactions=transactions+1;
        end
    endtask
    task automatic abort_at(input integer target_state,input bit streaming);
        integer guard;
        begin
            @(negedge clk); start=1; dataflow=1; stream_enable=streaming; reuse_stationary=0;
            tick; @(negedge clk); start=0; guard=0;
            if(streaming) begin
                while(!result_valid) begin tick; guard=guard+1; `CHECK(guard<10*N*N+50,"wait for stream") end
            end else begin
                while(int'(state_debug)!=target_state) begin tick; guard=guard+1; `CHECK(guard<10*N*N+50,"wait for reset phase") end
            end
            @(negedge clk); rst_n=0; #1;
            `CHECK(!busy && !done && !result_valid && !resident_weight_valid && !resident_input_valid,"reset abort clears transaction and residency")
            tick; @(negedge clk); rst_n=1; tick;
            load_matrix(0); load_matrix(1);
            run(0,0,0,0,0);
        end
    endtask
    initial begin
        metrics=0;
        if($value$plusargs("metrics=%s",metrics_path)) begin
            metrics=$fopen(metrics_path,"w");
            if(!metrics) $fatal(1,"Cannot open metrics output");
            $fdisplay(metrics,"n,data_w,acc_w,mode,reuse,stream,total_cycles,compute_cycles,preload_cycles,stall_cycles,mac_ops,nonzero_ops,zero_gate");
        end
        if($test$plusargs("waves")) begin $dumpfile("build/triflow.vcd"); $dumpvars(0,tb_triflow_core); end
        tick; tick; @(negedge clk); rst_n=1; tick;
        `CHECK(cmd_ready && load_ready && !busy,"reset readiness")
        @(negedge clk); dataflow=3; start=1; tick;
        `CHECK(command_error && !busy,"invalid mode reports error")
        @(negedge clk); start=0; tick; `CHECK(!command_error,"error pulses")
        for(integer trial=0;trial<TRIALS;trial=trial+1) begin
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                case(trial)
                    0: begin A[r][c]=0; B[r][c]=0; end
                    1: begin A[r][c]=(r==c)?1:0; B[r][c]=wrap_operand(next_rand()); end
                    2: begin A[r][c]=-(1<<(DATA_W-1)); B[r][c]=-(1<<(DATA_W-1)); end
                    3: begin A[r][c]=wrap_operand(next_rand()); B[r][c]=(next_rand()%3==0)?0:wrap_operand(next_rand()); end
                    default: begin A[r][c]=wrap_operand(next_rand()); B[r][c]=wrap_operand(next_rand()); end
                endcase
            end
            load_matrix(0); load_matrix(1);
            run(0,0,0,1,1);
            run(1,1,N*N,1,0); run(1,1,0,0,1);
            run(2,1,N*N,1,1); run(2,1,0,0,0);
            run(1,1,0,1,0); // Weight residency survives an intervening IS run.
            run(0,0,0,0,0); // OS must preserve both resident banks.
            run(2,1,0,0,1);
            A[0][0]=wrap_operand(A[0][0]+1); load_matrix(0);
            run(1,1,0,0,0); run(2,1,N*N,0,0);
            B[0][0]=wrap_operand(B[0][0]-1); load_matrix(1);
            run(2,1,0,0,0); run(1,1,N*N,0,0);
            run(1,0,N*N,0,0); // Explicit opt-out forces a fresh preload.
        end
        if(N<(1<<IW)) begin
            @(negedge clk); load_we=1; load_row=IW'(N); load_col=0; load_sel=1; tick;
            `CHECK(command_error && resident_weight_valid,"illegal write rejected without invalidation")
            @(negedge clk); load_we=0; result_row=IW'(N); #1;
            `CHECK(result_data===0,"invalid read is zero")
            run(1,1,0,0,0);
        end
        // Simultaneous load/start: host write wins, start must be retried.
        @(negedge clk); load_we=1; load_sel=0; load_row=0; load_col=0;
        A[0][0]=wrap_operand(A[0][0]+2); load_data=DATA_W'(A[0][0]); start=1; dataflow=0;
        tick; `CHECK(!busy && !cmd_ready,"host write wins start conflict")
        @(negedge clk); load_we=0; start=0; run(0,0,0,0,0);
        run(0,0,0,0,1,1); run(0,0,0,0,0);
        abort_at(1,0); abort_at(2,0); abort_at(3,0); abort_at(0,1);
        if(metrics) $fclose(metrics);
        $display("PASS tb_triflow_core N=%0d DATA_W=%0d ACC_W=%0d gate=%0d seed=%0d transactions=%0d",N,DATA_W,ACC_W,ZERO_GATE,SEED,transactions);
        $finish;
    end
endmodule
