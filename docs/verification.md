# Verification strategy

The release reports 29 passing RTL configurations and 795 checked core GEMMs.
The module/package-to-test mapping is generated in `reports/summary.json`.

Each module has a dedicated bench. The array bench manually drives all
boundary operands instead of instantiating the scheduler or collector, so it
can expose mapping/interconnect errors independently. The collector bench
uses manufactured distinct local/edge values and checks exactly one retirement
per output. The integration bench computes mathematical GEMM in a separate
signed scoreboard, truncating only to the configured accumulator width.

The core sweep covers:

- N=1/2/3/4/8, including non-power-of-two bounds and the minimum address width.
- DATA_W=4/8 and ACC_W=8/12/16/32, including deliberate modular overflow.
- Gating enabled/disabled and deterministic seeds 42, 43, and 141.
- Zero, identity, full minimum-signed, sparse random, and dense random tiles.
- Every dataflow, cold/miss/hit reuse, explicit opt-out, and interleaved modes.
- Writes invalidating one resident operand while preserving the other.
- Frozen active phases, counter identities, latched configuration, busy writes/starts.
- Invalid commands/addresses, load/start priority, backpressure stability/order/last.
- A/B writes during result drain and reset interruption in clear/preload/compute/drain.

All benches use bounded watchdogs. Python model tests separately compare
physical-register stepping against a direct mathematical oracle and exercise
rectangular tiled host orchestration. Strict RTL lint covers four parameter
sets and the wrapper. Default-core Verilator simulation supplements Icarus.

The runner routes N=1 to Verilator because of an Icarus 12 singleton-array-port
elaboration assertion, not an RTL simulation failure. Other tested sizes run
with Icarus. The build logs retain simulator diagnostics.

Reports are deterministic in stimuli, not in elapsed wall time or VCD dates.
`reports/summary.json` records hashes of RTL and testbench sources used for the
release. This suite is not formal equivalence, CDC analysis, gate-level timing,
code coverage closure, or silicon validation.
