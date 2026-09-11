# Suggested Experiments

The repository is intentionally structured so it can grow into a research
portfolio rather than remain only a demo.

## 1. Dataflow latency

Compare:

```text
OS total cycles
WS preload + compute cycles
IS preload + compute cycles
```

Then repeat multiple tiles without reloading the stationary operand.

This demonstrates why a stationary dataflow is useful: the preload cost can be
amortized over reuse.

## 2. Buffer traffic

Instrument logical reads from A/B buffers and compare traffic across modes.

Possible metrics:

- A-buffer reads
- B-buffer reads
- resident-register writes
- partial-sum hops
- output writes

## 3. Array scaling

Synthesize:

- 2x2
- 4x4
- 8x8
- 16x16

Measure:

- area
- frequency
- dynamic power
- cycles
- energy / GEMM

## 4. Precision

Compare:

- INT8 x INT8 -> INT32
- INT4 x INT4 -> INT24
- BF16

## 5. Approximate arithmetic

Swap the multiplier or adder inside `triflow_pe.sv` and measure:

- MAE / RMSE
- accuracy impact
- area
- delay
- power
- energy

## 6. Real neural-network mapping

Map:

- CNN convolution via im2col
- MLP / linear layers
- Transformer Q/K/V projections
- attention QK^T
- attention PV

Different workloads prefer different reuse patterns, which is exactly why
runtime-selectable dataflow is interesting.
