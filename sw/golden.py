#!/usr/bin/env python3
"""Original demo matrices, now checked with a physical register-level model."""
from triflow_model import Dataflow,TriFlowModel,gemm
A=[[1,2,3,4],[5,6,7,8],[-1,2,-3,4],[8,0,1,-2]]
B=[[1,0,2,-1],[3,1,0,2],[2,-2,1,1],[0,4,-1,3]]
def main():
    ref=gemm(A,B,32); model=TriFlowModel(); model.load_a(A); model.load_b(B)
    for row in ref: print(' '.join(f'{x:5d}' for x in row))
    for mode in Dataflow:
        run=model.run(mode)
        assert run.output==ref
        print(f'{mode.name}: PASS, total={run.total_cycles}, compute={run.compute_cycles}, preload={run.preload_cycles}, MACs={run.mac_ops}')
    for mode in [Dataflow.WS,Dataflow.IS]:
        run=model.run(mode,reuse=True); assert run.output==ref and run.preload_cycles==0
        print(f'{mode.name} warm: PASS, total={run.total_cycles}')
if __name__=='__main__': main()
