# Host and result protocol

All transactions use the rising edge of `clk`. Drive testbench/host values
before that edge. `rst_n` is asynchronous and active low.

## Load then launch

1. Wait for `load_ready=1`. Present `load_we=1`, A/B selection, a valid row/column,
   and one signed operand. Each rising edge with ready accepts one write.
2. Load the remaining cells. Hold `load_we=0` before submitting a command.
3. Present `start=1`, a legal mode, `reuse_stationary`, and `stream_enable`.
   Sample acceptance on a rising edge with `cmd_ready=1`; then deassert start.
4. The core latches its command. Clear consumes one enabled edge. WS/IS either
   preload N² elements or take a validated reuse hit. Compute takes 3N−2
   enabled edges. Asserting pause freezes the active phase without changing
   resident registers or losing in-flight link values.
5. The final compute edge captures the final C values and enters DONE. Core
   `done` is high for that complete cycle. Counters and all C values are valid.
6. On the following edge the controller returns IDLE. If streaming was requested,
   the streamer becomes valid. No new command is accepted while it is active.

A mode-3 request made when ready is rejected and produces `command_error`.
It does not clear results or counters. An out-of-range ready host write also
pulses the error signal and leaves buffers/residency unchanged. Busy requests
are ignored and are not treated as accepted protocol errors.

## Write/start conflict

`load_we=1` forces `cmd_ready=0`. A valid host write therefore wins and the
command must be retried after dropping `load_we`. This avoids sampling a
reuse decision on the same edge as an invalidating host write.

## Resident reuse

| Event | Weight resident flag | Input resident flag |
| --- | --- | --- |
| Reset | Invalid | Invalid |
| Accepted B host write | Invalid | Hold |
| Accepted A host write | Hold | Invalid |
| Finished WS preload | Valid | Hold |
| Finished IS preload | Hold | Valid |
| OS job, transaction clear, pause | Hold | Hold |

The tracker marks validity only when the final preload write occurs. A warm
request with an invalid matching flag automatically reloads the operand; the
host need not recover from a cache-miss error. Reuse is explicit and off by
default in the compatibility wrapper. There is no content-addressed comparison.

## Result stream and overlap

Every edge with `result_valid && result_ready` transfers exactly one entry.
Coordinates run `(0,0), (0,1), ... (N−1,N−1)`. `result_last` accompanies the final
entry. While ready is low, valid, data, coordinates, and last remain stable.
After the final handshake `stream_done` pulses for one cycle and busy drops.

The streamer reads the C register bank directly. New compute is blocked until
it finishes, so the bank cannot be overwritten while a sample is held.
Operand A/B writes are allowed once the controller has returned idle, even
while C is stalled. Such writes invalidate the corresponding stationary
operand for the next command. Reset aborts both computation and streaming.

No stream is produced for a command whose latched `stream_enable` is zero.
Direct indexed result reads are available in both cases; software should
consume a complete matrix only after done, until the next command's clear.

## Simple wrapper

`triflow_top` ties pause/reuse/streaming off. Its registered done pulse occurs
one edge after core matrix completion, when the controller is idle, matching
the original example's load-after-done usage. Its counters describe only the
clear/preload/compute phases. Wait for wrapper done before beginning the next
write sequence; no additional ready port is exposed on this legacy interface.
