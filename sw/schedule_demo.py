#!/usr/bin/env python3
"""Print actual boundary tokens and retired values; optionally export JSON."""
import argparse,json
from triflow_model import Dataflow,TriFlowModel

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('-n',type=int,default=4); ap.add_argument('--json'); args=ap.parse_args()
    model=TriFlowModel(args.n,data_w=8)
    model.load_a([[(i+j)%7-3 for j in range(args.n)] for i in range(args.n)])
    model.load_b([[(2*i+j)%5-2 for j in range(args.n)] for i in range(args.n)])
    payload={}
    for mode in Dataflow:
        run=model.run(mode); payload[mode.name]=run.trace
        print(mode.name)
        for row in run.trace: print(f"t={row['cycle']:2d} A={row['a_left']} B={row['b_top']} active={row['active_pes']} retire={row['retired']}")
    if args.json:
        from pathlib import Path
        Path(args.json).write_text(json.dumps(payload,indent=2)+'\n')
if __name__=='__main__': main()
