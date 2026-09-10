#!/usr/bin/env python3
"""Print cycle-by-cycle injection schedules for the three TriFlow-SA modes."""

def show(n=4):
    print("OUTPUT-STATIONARY")
    for t in range(3*n-2):
        a = [f"A[{i},{t-i}]" if 0 <= t-i < n else "-" for i in range(n)]
        b = [f"B[{t-j},{j}]" if 0 <= t-j < n else "-" for j in range(n)]
        print(f"t={t:2d}  A_left={a}  B_top={b}")

    print("\nWEIGHT-STATIONARY")
    for t in range(3*n-2):
        a = [f"A[{t-k},{k}]" if 0 <= t-k < n else "-" for k in range(n)]
        print(f"t={t:2d}  A_left={a}")

    print("\nINPUT-STATIONARY")
    for t in range(3*n-2):
        b = [f"B[{k},{t-k}]" if 0 <= t-k < n else "-" for k in range(n)]
        print(f"t={t:2d}  B_top={b}")

if __name__ == "__main__":
    show()
