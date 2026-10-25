#!/usr/bin/env python3
"""Bounded Icarus regression. Every RTL module/package has a named bench."""
from __future__ import annotations
import argparse, json, os, pathlib, shutil, subprocess, sys, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(cmd, log, timeout=60):
    result=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    log.write(result.stdout)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(map(str,cmd))}\n{result.stdout[-6000:]}")
    return result.stdout

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--quick',action='store_true'); ap.add_argument('--waves',action='store_true')
    ap.add_argument('--only'); ap.add_argument('--seed',type=int,default=42)
    ap.add_argument('--simulator',choices=['auto','iverilog','verilator'],default='auto'); args=ap.parse_args()
    iv=os.environ.get('IVERILOG','iverilog'); vvp=os.environ.get('VVP','vvp')
    for tool in [iv,vvp]:
        if not shutil.which(tool): raise SystemExit(f"Missing {tool}. Install Icarus Verilog; see README.")
    build=ROOT/'build'; build.mkdir(exist_ok=True); (ROOT/'reports').mkdir(exist_ok=True)
    jobs=[]
    for tb in sorted((ROOT/'tb').glob('tb_*.sv')):
        if tb.stem!='tb_triflow_core': jobs.append((tb.stem,tb.stem,{}))
    configs=[(4,8,32,1,args.seed)] if args.quick else [
        (1,4,8,1,args.seed),(2,4,8,1,args.seed),(3,4,8,1,args.seed),(4,4,8,1,args.seed),
        (4,8,32,1,args.seed),(8,8,32,1,args.seed),(3,8,16,1,args.seed),
        (4,4,12,0,args.seed),(4,8,32,0,args.seed),(4,8,32,1,args.seed+1),(4,4,16,1,args.seed+99)]
    for n,dw,aw,gate,seed in configs:
        label=f'core_n{n}_d{dw}_a{aw}_g{gate}_s{seed}'
        jobs.append((label,'tb_triflow_core',dict(N=n,DATA_W=dw,ACC_W=aw,ZERO_GATE=gate,SEED=seed,TRIALS=5)))
    if not args.quick:
        for n,dw in [(1,4),(3,8),(8,4)]: jobs.append((f'top_n{n}_d{dw}','tb_triflow_top',dict(N=n,DATA_W=dw)))
    if args.only: jobs=[j for j in jobs if args.only in j[0] or args.only==j[1]]
    if not jobs: raise SystemExit('No matching test')
    results=[]; start=time.monotonic()
    for label,top,params in jobs:
        logfile=build/(label+'.log'); binary=build/(label+'.vvp')
        use_verilator=args.simulator=='verilator' or (args.simulator=='auto' and params.get('N')==1)
        if use_verilator:
            vl=os.environ.get('VERILATOR','verilator')
            if not shutil.which(vl): raise SystemExit('N=1 regression requires Verilator (Icarus 12 has a singleton-array elaboration bug). See README.')
            binary=build/(label+'.bin')
            cmd=[vl,'--binary','--timing','-j','2','-Wno-fatal','-I'+str(ROOT/'tb'),'--top-module',top,'--Mdir',str(build/('obj_'+label)),'-o',str(binary),'--prefix','V'+label,'-f','rtl/files.f']
            cmd += [f'-G{k}={v}' for k,v in params.items()]
        else:
            cmd=[iv,'-g2012','-Wall','-I','tb','-s',top,'-o',str(binary),'-c','rtl/files.f']
            cmd += [f'-P{top}.{k}={v}' for k,v in params.items()]
        cmd += [f'tb/{top}.sv']
        try:
            with logfile.open('w') as log:
                run(cmd,log,timeout=180)
                extra=[f'+metrics=build/{label}.csv'] if top=='tb_triflow_core' else []
                if args.waves and top=='tb_triflow_core' and params.get('N')==4 and params.get('DATA_W')==8 and params.get('ZERO_GATE')==1 and params.get('SEED')==args.seed: extra+=['+waves']
                if args.waves and use_verilator and '+waves' in extra: extra.remove('+waves')
                output=run(([str(binary)] if use_verilator else [vvp,str(binary)])+extra,log)
                if 'PASS' not in output: raise RuntimeError('No PASS marker')
            results.append(dict(test=label,top=top,parameters=params,simulator='verilator' if use_verilator else 'iverilog',status='PASS'))
            print(f'PASS {label}',flush=True)
        except Exception as exc:
            results.append(dict(test=label,top=top,parameters=params,status='FAIL',error=str(exc)))
            print(str(exc),file=sys.stderr)
            break
    report=dict(tool=run([iv,'-V'],__import__('io').StringIO()).splitlines()[0],seed=args.seed,elapsed_seconds=round(time.monotonic()-start,3),passed=sum(r['status']=='PASS' for r in results),failed=sum(r['status']=='FAIL' for r in results),results=results)
    report_name='quick_verification' if args.quick else 'verification'
    if args.only: report_name+='_subset'
    if args.simulator!='auto': report_name+='_'+args.simulator
    report_path=ROOT/'reports'/(report_name+'.json')
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f"{report['passed']} passed, {report['failed']} failed; {report_path.relative_to(ROOT)}")
    return bool(report['failed'])
if __name__=='__main__': raise SystemExit(main())
