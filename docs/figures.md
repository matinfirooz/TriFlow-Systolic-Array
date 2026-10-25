# Hardware figure guide

The figures use register-transfer hardware symbols: clocked register banks,
trapezoidal muxes, multiplier/adder symbols, explicit feedback, bus-width marks,
and separate operand, partial-sum, and control wires. They are editable vector
SVGs, with 1.5× PNG previews. All labels remain editable text.

## Figure index

| Panel | Figure | SVG | PNG |
| --- | --- | --- | --- |
| (a) | Top-level datapath and distributed control | [architecture.svg](../assets/architecture.svg) | [architecture.png](../assets/architecture.png) |
| (b) | Shared PE MAC, resident state, feedback, and forwarding | [pe.svg](../assets/pe.svg) | [pe.png](../assets/pe.png) |
| (c) | OS / WS / IS physical dataflow mappings | [dataflows.svg](../assets/dataflows.svg) | [dataflows.png](../assets/dataflows.png) |
| (d) | Controller state registers, counters, compares, and pause gates | [control_timing.svg](../assets/control_timing.svg) | [control_timing.png](../assets/control_timing.png) |
| (e) | Collector, C registers, read muxes, and stream state | [result_path.svg](../assets/result_path.svg) | [result_path.png](../assets/result_path.png) |
| (f) | Separate registered operand and partial-sum mesh links | [array_links.svg](../assets/array_links.svg) | [array_links.png](../assets/array_links.png) |

The measured latency and actual-waveform figures are retained separately;
they are measurement plots rather than circuit diagrams.

## Notation and RTL correspondence

- `W = DATA_W`, `P = ACC_W`, and `N` is the mesh dimension.
- Blue wires carry A operands; teal wires carry B operands or resident data;
  orange wires carry partial sums/results. Dashed gray wires carry control.
- Slashes and labels on buses indicate width. A filled dot denotes a junction;
  crossings without a dot are separate signals.
- A triangle on a register denotes its clock. `CE` is the update enable, and
  `WE` denotes a resident write. These symbols describe RTL behavior rather
  than instantiating a particular cell-library flip-flop.
- The top-level mesh is drawn as 4×4. The link detail is a 2×2 fragment whose
  connections repeat over the parameterized mesh.
- The dataflow panel simplifies the inside of each PE. Use the PE panel for
  the complete mode-selected MAC, zero isolation, feedback, and forwarding.

| Schematic state | RTL state |
| --- | --- |
| `state_q` | `triflow_controller.state` |
| `mode_q` | `triflow_controller.mode_q` |
| `reuse_q` / `reuse_used` | `triflow_controller.reuse_used` |
| `index_q` | `result_streamer.index` |
| `busy_q` | `result_streamer.busy` |
| `C[i,j]` | `result_buffer.mem[i][j]` |
| `input_reg`, `weight_reg`, `acc_reg` | Same named registers in `triflow_pe` |
| `A_E`, `B_S`, `P_E`, `P_S` | `a_east`, `b_south`, `psum_east`, `psum_south` |

`_q` is used in schematic labels to identify stored state. Grouped blocks
can contain more than one RTL register or a repeated network of muxes.

## Important capture and gating details

The collector receives the current combinational PE sum. In WS/IS the final
bottom/right tap is taken **before** the link output flop; the registered
partial-sum link is used between neighboring PEs. The PE panel shows these
separate paths. OS feeds its stored accumulator back into the shared adder.

A zero product still forwards the incoming addend in WS/IS. The PE diagram
therefore isolates multiplier operands, rather than disabling a partial-sum
flop on every zero. Inactive-direction output sums are explicitly selected to
zero before their registers. Global step and clear keep the fabric aligned.

The result figure shows a per-cell slice repeated across C. Several masks
can assert on the same edge. Its stream index holds under backpressure, and
its busy next-state logic preserves valid until the final ready handshake.
A new compute command cannot overwrite C while the requested stream drains.

These are RTL architecture schematics, not a placed/routed layout or a
technology-mapped gate netlist. No arithmetic or RTL behavior changed in this
figure-only revision; the recorded RTL verification remains applicable.

## Regenerate and edit

```bash
python3 -m pip install -r requirements-dev.txt
python3 scripts/make_figures.py --png
# Or directly:
python3 scripts/hardware_figures.py --png
```

The circuit generator is [hardware_figures.py](../scripts/hardware_figures.py).
The common chart helper remains in [make_figures.py](../scripts/make_figures.py).
The SVGs can also be edited in a vector editor without regenerating them.
