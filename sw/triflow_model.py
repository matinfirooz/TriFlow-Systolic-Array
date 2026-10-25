"""Bit-accurate register-level TriFlow reference; Python standard library only."""
from __future__ import annotations
from dataclasses import dataclass
from enum import IntEnum
from typing import Iterable

class Dataflow(IntEnum):
    OS=0
    WS=1
    IS=2

def wrap(value: int, width: int) -> int:
    if width < 1: raise ValueError("width must be positive")
    value &= (1 << width)-1
    return value-(1 << width) if value & (1 << (width-1)) else value

def gemm(a, b, acc_w=None):
    """Independent mathematical oracle; supports rectangular operands."""
    if not a or not b or not a[0] or not b[0]: raise ValueError("empty matrix")
    k=len(a[0]); n=len(b[0])
    if any(len(row)!=k for row in a) or len(b)!=k or any(len(row)!=n for row in b):
        raise ValueError("incompatible or ragged matrices")
    c=[[sum(a[i][q]*b[q][j] for q in range(k)) for j in range(n)] for i in range(len(a))]
    return [[wrap(x,acc_w) for x in row] for row in c] if acc_w else c

@dataclass(frozen=True)
class Run:
    output: list[list[int]]
    mode: Dataflow
    reuse_used: bool
    total_cycles: int
    compute_cycles: int
    preload_cycles: int
    stall_cycles: int
    mac_ops: int
    nonzero_ops: int
    trace: list[dict]

class TriFlowModel:
    def __init__(self, n=4, data_w=8, acc_w=32):
        if n<1 or data_w<2 or acc_w<2*data_w: raise ValueError("require N>=1, DATA_W>=2, ACC_W>=2*DATA_W")
        self.n=n; self.data_w=data_w; self.acc_w=acc_w
        self.a=[[0]*n for _ in range(n)]; self.b=[[0]*n for _ in range(n)]
        self.weight_valid=False; self.input_valid=False
        self.weights=[[0]*n for _ in range(n)]; self.inputs=[[0]*n for _ in range(n)]

    def _validate(self,matrix):
        n=self.n
        if len(matrix)!=n or any(len(row)!=n for row in matrix): raise ValueError("tile shape must be N x N")
        lo=-(1 << (self.data_w-1)); hi=(1 << (self.data_w-1))-1
        if any(not isinstance(x,int) or x<lo or x>hi for row in matrix for x in row):
            raise ValueError("operand outside signed DATA_W range")
        return [list(row) for row in matrix]

    def load_a(self,matrix):
        self.a=self._validate(matrix); self.input_valid=False

    def load_b(self,matrix):
        self.b=self._validate(matrix); self.weight_valid=False

    def run(self, mode=Dataflow.OS, reuse=False, pause_at: Iterable[int]=()) -> Run:
        mode=Dataflow(mode); n=self.n
        hit=bool(reuse and ((mode==Dataflow.WS and self.weight_valid) or (mode==Dataflow.IS and self.input_valid)))
        pre=0 if mode==Dataflow.OS or hit else n*n
        if mode==Dataflow.WS and not hit:
            self.weights=[row[:] for row in self.b]; self.weight_valid=True
        if mode==Dataflow.IS and not hit:
            self.inputs=[row[:] for row in self.a]; self.input_valid=True
        ae=[[0]*n for _ in range(n)]; bs=[[0]*n for _ in range(n)]
        pv=[[0]*n for _ in range(n)]; ph=[[0]*n for _ in range(n)]
        acc=[[0]*n for _ in range(n)]; out=[[0]*n for _ in range(n)]
        trace=[]; ops=0; nonzero=0
        pauses=list(pause_at)
        if any(t<0 or t>=3*n-2 for t in pauses): raise ValueError("pause index outside compute wavefront")
        for t in range(3*n-2):
            left=[0]*n; top=[0]*n
            for lane in range(n):
                q=t-lane
                if 0<=q<n:
                    if mode==Dataflow.OS: left[lane]=self.a[lane][q]; top[lane]=self.b[q][lane]
                    elif mode==Dataflow.WS: left[lane]=self.a[q][lane]
                    else: top[lane]=self.b[lane][q]
            next_a=[[0]*n for _ in range(n)]; next_b=[[0]*n for _ in range(n)]
            next_pv=[[0]*n for _ in range(n)]; next_ph=[[0]*n for _ in range(n)]
            next_acc=[row[:] for row in acc]; retired=[]; active=0
            for r in range(n):
                for c in range(n):
                    av=left[r] if c==0 else ae[r][c-1]
                    bv=top[c] if r==0 else bs[r-1][c]
                    lhs=self.inputs[r][c] if mode==Dataflow.IS else av
                    rhs=self.weights[r][c] if mode==Dataflow.WS else bv
                    if mode==Dataflow.OS: base=acc[r][c]
                    elif mode==Dataflow.WS: base=0 if r==0 else pv[r-1][c]
                    else: base=0 if c==0 else ph[r][c-1]
                    valid=0<=t-r-c<n
                    total=wrap(base+(lhs*rhs if valid else 0),self.acc_w)
                    if valid:
                        ops+=1; active+=1; nonzero+=int(lhs!=0 and rhs!=0)
                    if mode!=Dataflow.IS: next_a[r][c]=av
                    if mode!=Dataflow.WS: next_b[r][c]=bv
                    if mode==Dataflow.OS: next_acc[r][c]=total
                    elif mode==Dataflow.WS: next_pv[r][c]=total
                    else: next_ph[r][c]=total
                    if mode==Dataflow.OS and t==r+c+n-1:
                        out[r][c]=total; retired.append([r,c,total])
                    elif mode==Dataflow.WS and r==n-1:
                        i=t-c-(n-1)
                        if 0<=i<n: out[i][c]=total; retired.append([i,c,total])
                    elif mode==Dataflow.IS and c==n-1:
                        j=t-r-(n-1)
                        if 0<=j<n: out[r][j]=total; retired.append([r,j,total])
            ae,bs,pv,ph,acc=next_a,next_b,next_pv,next_ph,next_acc
            trace.append(dict(cycle=t,a_left=left,b_top=top,active_pes=active,retired=retired,pauses_before=pauses.count(t)))
        comp=3*n-2
        return Run(out,mode,hit,1+pre+comp+len(pauses),comp,pre,len(pauses),ops,nonzero,trace)
