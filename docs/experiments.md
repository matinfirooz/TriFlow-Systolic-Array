# Experiments and evidence

## Reproduce the included checks

```bash
make test
python3 scripts/run_tests.py --only core_n4_d8_a32_g1_s42 --simulator verilator
make synth-pe
make results
make waves
```

`make results` re-runs RTL, validates every measured CSV row, and rebuilds the
combined measurements and latency chart. `requirements-dev.txt` is needed for
PNG and waveform rendering, not the numerical model or RTL test runner.

## What was measured

| Artifact | Evidence | Scope |
| --- | --- | --- |
| `verification.json` | 29 simulator configurations | Functional RTL checks |
| `verification_subset_verilator.json` | Default-core independent simulation | Second simulator |
| `lint.json` | Strict Verilator results | RTL lint, no warnings in tested sets |
| `rtl_metrics.csv` | 795 testbench-emitted command rows | Clear/preload/compute/stall/MAC counters |
| `reuse_latency.csv` | No-stall WS cold and warm rows | Controller latency excluding host/drain |
| `pe_structure.json` | Generic Yosys cell counts | Current 1 multiplier/adder vs uploaded 3/3 |
| `sample_trace.vcd` | Actual first OS transaction and drain | Compact signal subset |
| `summary.json` | Module/test map and SHA-256 source hashes | Traceability |

At N=4 cold WS/IS takes 27 controller clocks and reuse takes 11. This is a
2.45× controller-latency ratio, not an end-to-end speedup. OS also takes 11
under the same no-pause square-tile register-buffer interface. The array still
executes 10 compute steps in every case. Host writes and result drain can
dominate application latency.

The original PE is synthesized from the supplied ZIP for the baseline
operator report. To repeat it, supply that original ZIP using
`python3 scripts/synth_pe.py --baseline-zip PATH`. The ordinary `make synth-pe`
checks the new PE only. Yosys does not synthesize the full unpacked-array
core through its basic Verilog frontend in this workflow.

## Next implementation experiments

For credible mapped comparisons, use the same precision, accumulator width,
array size, buffer implementation, target library, clock constraints, output
loads and input switching traces. Report OS/WS/IS separately, cold and warm
latencies, host traffic, and workload reuse. Compare zero isolation enabled
and disabled after mapping; fewer nonzero products do not themselves prove a
power saving. Repeated place-and-route seeds and timing-clean netlists are
needed before making a physical PPA claim.

A useful memory experiment replaces flop banks with explicit SRAM banking and
arbitration, then counts bandwidth-induced pauses. A useful throughput
experiment adds a second C bank and verifies ownership across simultaneous
compute/drain. These are proposed follow-on changes, not implemented features
in this release.
