# Changelog

## 2.0.1 — Hardware figure revision, 2026-10-25

- Redraw architecture, PE, dataflow, and controller figures as hardware schematics.
- Add separate result-path and registered mesh-link figures.
- Show muxes, register clock symbols, bus widths, MAC feedback, and current-sum edge taps.
- Add editable SVGs, high-resolution PNGs, a circuit generator, and an RTL notation guide.
- Update README links and the repository package; RTL behavior is unchanged.

## 2.0.0 — 2026-10-25

- Replace three mode-specific arithmetic paths with one shared signed MAC per PE.
- Separate controller, injection scheduler, preload sequencer, residency tracking,
  counters, result retirement, storage, and streaming.
- Add reusable stationary A/B registers with matching host-write invalidation.
- Add atomic pause/resume across clear, preload, compute, links, and collector.
- Add optional row-major ready/valid C streaming with stable stalled outputs.
- Permit A/B host loading during C drain; block a new command until drain ends.
- Preserve original `triflow_top` port names and its registered completion pulse.
- Introduce `triflow_core` for reuse, pause, streaming, and observability.
- Add buffer reset/bounds handling and correct minimum index widths for N=1.
- Replace mixed-driver array wiring with single-driver nets; work around an
  Icarus dynamic-expression elaboration issue with explicit scheduler tap nets.
- Add a named testbench for every RTL module/package, seeded integration sweeps,
  watchdogs, independent arithmetic scoreboards, and Verilator cross-checking.
- Add a physical register-level Python model and rectangular tiled GEMM driver.
- Add generated architecture/PE/dataflow/timing diagrams, actual waveform and
  latency figures, CSV measurements, strict lint, CI, and packaging helpers.

### Compatibility

`triflow_top` keeps the original host interface. Its feature controls are tied
off, and WS/IS preload each time. Extended submodule interfaces have changed;
old direct instantiations of the PE, array, controller, collector, or buffers
must be updated. The extended core's `done` pulse marks final matrix capture;
the simple wrapper registers this pulse one clock later, as in the old host
usage. Counter values exclude this notification clock.

New operand buffers require explicit `rst_n`; reliance on an initialization
block has been removed. Unwritten matrix locations read zero after reset, but
normal software should load every element of a tile before starting a job.

N=1 is verified with Verilator. Icarus 12.0 has a singleton unpacked-array port
elaboration crash; the default test runner routes those cases to Verilator.
