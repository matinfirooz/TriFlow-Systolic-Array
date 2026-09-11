# TriFlow-SA Architecture

TriFlow-SA is a single physical `N x N` systolic MAC fabric that changes its
stationary operand and partial-sum direction at runtime.

## Mode 0 — Output Stationary (OS)

Physical PE `(i,j)` owns output `C[i][j]`.

```text
A moves east  --->
B moves south  |
               v

PE(i,j):
    acc[i,j] += A[i,k] * B[k,j]
```

Boundary schedule:

```text
A[i][k] enters physical row i at t = i + k
B[k][j] enters physical col j at t = j + k
```

They meet at PE `(i,j)` at:

```text
t = i + j + k
```

The final useful product for that PE occurs at:

```text
t = i + j + (N-1)
```

## Mode 1 — Weight Stationary (WS)

Physical PE `(k,j)` owns weight `B[k][j]`.

```text
A[i,k] ---> PE(k,j)
              |
              v
          partial sum
```

A values move east while partial sums move south.

The injection schedule is:

```text
A[i][k] enters physical row k at t = i + k
```

At PE `(k,j)` the activation and partial sum for the same logical output row
arrive together at:

```text
t = i + j + k
```

The bottom row produces final `C[i][j]`.

## Mode 2 — Input Stationary (IS)

Physical PE `(i,k)` owns input `A[i][k]`.

```text
              B[k,j]
                |
                v
            PE(i,k) ---> partial sum
```

B values move south while partial sums move east.

The schedule is:

```text
B[k][j] enters physical col k at t = j + k
```

Again, matching operands align at:

```text
t = i + j + k
```

The rightmost column produces final `C[i][j]`.

## Why all three use the same wavefront length

For a square `N x N` GEMM, the latest logical result is `(N-1,N-1)`, whose
last multiply is `k=N-1`:

```text
t_last = (N-1) + (N-1) + (N-1) = 3N - 3
```

Counting cycle zero, the compute phase is:

```text
3N - 2 cycles
```

WS and IS additionally pay an `N^2` preload cost in this baseline design,
because one resident operand is written into one PE per cycle.

That deliberate separation makes a useful research experiment:
compare total latency versus steady-state reuse when resident weights/inputs
are kept for multiple GEMM tiles.
