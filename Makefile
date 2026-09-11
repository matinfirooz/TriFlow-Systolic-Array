IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3

RTL = \
	rtl/triflow_pkg.sv \
	rtl/matrix_buffer.sv \
	rtl/result_buffer.sv \
	rtl/triflow_pe.sv \
	rtl/triflow_array.sv \
	rtl/result_collector.sv \
	rtl/triflow_controller.sv \
	rtl/triflow_top.sv

TB = tb/tb_triflow_top.sv

.PHONY: all test-sw sim schedule clean

all: test-sw

test-sw:
	$(PYTHON) sw/golden.py

schedule:
	$(PYTHON) sw/schedule_demo.py

sim:
	$(IVERILOG) -g2012 -Wall -o triflow_sim $(RTL) $(TB)
	$(VVP) triflow_sim

clean:
	rm -f triflow_sim triflow.vcd
