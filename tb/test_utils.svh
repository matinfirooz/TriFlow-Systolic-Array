`ifndef TRIFLOW_TEST_UTILS
`define TRIFLOW_TEST_UTILS
`define CHECK(COND, MSG) if ((COND) !== 1'b1) $fatal(1,"%s (%s:%0d)",MSG,`__FILE__,`__LINE__);
`define CLOCK reg clk=0; always #5 clk=~clk; task automatic tick; @(posedge clk); #1; endtask
`define WATCHDOG initial begin #1000000; $fatal(1,"Watchdog expired"); end
`endif
