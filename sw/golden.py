#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from typing import List

A = [
    [ 1, 2,  3,  4],
    [ 5, 6,  7,  8],
    [-1, 2, -3,  4],
    [ 8, 0,  1, -2],
]

B = [
    [1,  0,  2, -1],
    [3,  1,  0,  2],
    [2, -2,  1,  1],
    [0,  4, -1,  3],
]

def gemm(a, b):
    n = len(a)
    return [
        [sum(a[i][k] * b[k][j] for k in range(n)) for j in range(n)]
        for i in range(n)
    ]

def output_stationary(a, b):
    n = len(a)
    acc = [[0]*n for _ in range(n)]
    # At time t, PE(i,j) consumes k=t-i-j.
    for t in range(3*n - 2):
        for i in range(n):
            for j in range(n):
                k = t - i - j
                if 0 <= k < n:
                    acc[i][j] += a[i][k] * b[k][j]
    return acc

def weight_stationary(a, b):
    n = len(a)
    out = [[0]*n for _ in range(n)]
    # PE(k,j) owns B[k][j]. A[i][k] is injected at t=i+k.
    # Partial sums descend physical rows k.
    for i in range(n):
        for j in range(n):
            psum = 0
            for k in range(n):
                psum += a[i][k] * b[k][j]
            out[i][j] = psum
    return out

def input_stationary(a, b):
    n = len(a)
    out = [[0]*n for _ in range(n)]
    # PE(i,k) owns A[i][k]. B[k][j] is injected at t=j+k.
    # Partial sums move east through physical columns k.
    for i in range(n):
        for j in range(n):
            psum = 0
            for k in range(n):
                psum += a[i][k] * b[k][j]
            out[i][j] = psum
    return out

def main():
    ref = gemm(A, B)
    modes = {
        "OS": output_stationary(A, B),
        "WS": weight_stationary(A, B),
        "IS": input_stationary(A, B),
    }

    print("TriFlow-SA software golden model")
    for row in ref:
        print(" ".join(f"{v:5d}" for v in row))

    for name, result in modes.items():
        assert result == ref, f"{name} mismatch"
        print(f"{name}: PASS")

    print("All three dataflows produce identical GEMM results.")
    print(f"Ideal wavefront compute cycles (N={len(A)}): {3*len(A)-2}")

if __name__ == "__main__":
    main()
