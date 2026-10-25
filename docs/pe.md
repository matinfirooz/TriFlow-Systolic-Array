# Shared processing element

![PE](../assets/pe.svg)

Two operand muxes and one addend mux select a single `signed_mac`.
OS selects incoming A/B and local accumulator; WS incoming A/resident weight
and northern sum; IS resident input/incoming B and western sum.

The product is exactly `2*DATA_W` bits and is explicitly sign-extended before
ACC_W addition. Overflow wraps. The exhaustive INT4 MAC bench compares gating
on and off for every operand pair and both enable values, using varied addends
that exercise wrap. The integrated suite also exercises all-minimum signed
matrices with narrow accumulators and full-range randomized INT8 operands.

`step` gates link/state updates. An invalid MAC slot contributes zero but link
forwarding remains aligned with the wavefront. In WS/IS a zero product must
still forward the addend; disabling the whole partial-sum register on zero
would corrupt reductions and is deliberately avoided.

`clear` dominates step for transient state while resident preload writes are
independent. At core level these controls are never active in conflicting
phases. Reset clears all state. Resident validity belongs to the core tracker;
submodule users must supply valid preload data before selecting WS/IS.

The Yosys structural report proves one generic multiplier and one generic
adder remain after `proc; opt`. It does not establish a clock, power, silicon
area, or equivalence to a mapped gate netlist. A mode mux on a shared datapath
can affect timing; physical evaluation is the appropriate next experiment.
