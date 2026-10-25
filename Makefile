PYTHON ?= python3
.PHONY: all test test-sw test-rtl quick sim lint golden tiled-demo schedule waves figures results synth-pe bundle clean
all: test
test: test-sw test-rtl lint
test-sw:
	$(PYTHON) -m unittest discover -s tests -v
	$(PYTHON) sw/golden.py
	$(PYTHON) sw/tiled_gemm.py
test-rtl:
	$(PYTHON) scripts/run_tests.py
quick: test-sw
	$(PYTHON) scripts/run_tests.py --quick
sim:
	$(PYTHON) scripts/run_tests.py --quick
lint:
	$(PYTHON) scripts/lint.py
golden:
	$(PYTHON) sw/golden.py
tiled-demo:
	$(PYTHON) sw/tiled_gemm.py
schedule:
	$(PYTHON) sw/schedule_demo.py
waves:
	$(PYTHON) scripts/run_tests.py --quick --waves
	$(PYTHON) scripts/waveform_preview.py
figures:
	$(PYTHON) scripts/make_figures.py --png
results: test-rtl
	$(PYTHON) scripts/collect_results.py --png
synth-pe:
	$(PYTHON) scripts/synth_pe.py
bundle:
	$(PYTHON) scripts/package.py
clean:
	$(PYTHON) scripts/clean.py
