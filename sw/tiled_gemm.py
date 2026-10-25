#!/usr/bin/env python3
"""Software tile driver for rectangular GEMM, with stationary reuse across tiles.

The RTL accepts one square tile. This driver demonstrates host orchestration,
zero padding and host accumulation; it is not an RTL DMA or tiled controller.
"""
from triflow_model import Dataflow,TriFlowModel,gemm,wrap

def tiled_gemm(a,b,n=4,mode=Dataflow.WS,data_w=8,acc_w=32):
    gemm(a,b)  # validate dimensions
    mode=Dataflow(mode); m=len(a); k=len(b); p=len(b[0])
    model=TriFlowModel(n,data_w,acc_w); out=[[0]*p for _ in range(m)]; runs=[]
    def tile(mat,r,c):
        return [[mat[r+i][c+j] if r+i<len(mat) and c+j<len(mat[0]) else 0 for j in range(n)] for i in range(n)]
    def execute(i,q,j,load_a=True,load_b=True):
        if load_a: model.load_a(tile(a,i,q))
        if load_b: model.load_b(tile(b,q,j))
        run=model.run(mode,reuse=True); runs.append(run)
        for r in range(min(n,m-i)):
            for c in range(min(n,p-j)): out[i+r][j+c]=wrap(out[i+r][j+c]+run.output[r][c],acc_w)
    if mode==Dataflow.WS:
        for q in range(0,k,n):
            for j in range(0,p,n):
                for i in range(0,m,n): execute(i,q,j,load_b=(i==0))
    elif mode==Dataflow.IS:
        for i in range(0,m,n):
            for q in range(0,k,n):
                for j in range(0,p,n): execute(i,q,j,load_a=(j==0))
    else:
        for i in range(0,m,n):
            for j in range(0,p,n):
                for q in range(0,k,n): execute(i,q,j)
    return out,runs

def main():
    a=[[(i*3+j)%11-5 for j in range(7)] for i in range(9)]
    b=[[(i+2*j)%9-4 for j in range(10)] for i in range(7)]
    ref=gemm(a,b,32)
    for mode in Dataflow:
        out,runs=tiled_gemm(a,b,mode=mode)
        assert out==ref
        print(f'{mode.name}: 9x7 @ 7x10 PASS; tiles={len(runs)}, preload={sum(x.preload_cycles for x in runs)}, modeled cycles={sum(x.total_cycles for x in runs)} (excludes host transfers)')
if __name__=='__main__': main()
