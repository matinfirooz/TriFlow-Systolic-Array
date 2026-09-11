# Reconfigurable Processing Element

Each PE contains:

- one resident weight register
- one resident input register
- one output accumulator
- east/west activation links
- north/south B-data links
- vertical partial-sum links
- horizontal partial-sum links
- one multiplier
- three mode-selectable accumulation paths

Conceptually:

```text
                    b_north
                       |
             +---------+----------+
             |                    |
             v                    v
          OS multiply          IS multiply
             ^                    ^
             |                    |
a_west ------+                 input_reg

a_west ---> WS multiply <--- weight_reg

OS: acc_reg      += a_west * b_north
WS: psum_south    = psum_north + a_west * weight_reg
IS: psum_east     = psum_west  + input_reg * b_north
```

Only the selected mode updates its relevant datapath state.
