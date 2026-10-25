#!/usr/bin/env python3
"""Strict Verilator RTL lint at representative sizes and precisions."""
import json,os,pathlib,shutil,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    vl=os.environ.get('VERILATOR','verilator')
    if not shutil.which(vl):raise SystemExit('Verilator is required for make lint')
    results=[]
    for n,dw,aw in [(1,4,8),(3,4,12),(4,8,32),(8,8,32)]:
        cmd=[vl,'--lint-only','--timing','-Wall','--top-module','triflow_core','-f','rtl/files.f',f'-GN={n}',f'-GDATA_W={dw}',f'-GACC_W={aw}']
        r=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
        label=f'N={n} DATA_W={dw} ACC_W={aw}'
        results.append(dict(configuration=label,status='PASS' if r.returncode==0 else 'FAIL',output=r.stdout))
        print(results[-1]['status'],label)
    # Check wrapper-specific wiring as well as the extended core.
    r=subprocess.run([vl,'--lint-only','--timing','-Wall','--top-module','triflow_top','-f','rtl/files.f'],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    results.append(dict(configuration='legacy wrapper',status='PASS' if r.returncode==0 else 'FAIL',output=r.stdout))
    version=subprocess.check_output([vl,'--version'],text=True).strip()
    (ROOT/'reports').mkdir(exist_ok=True);(ROOT/'reports/lint.json').write_text(json.dumps(dict(tool=version,results=results),indent=2)+'\n')
    if any(r['status']=='FAIL' for r in results):
        for r in results:
            if r['status']=='FAIL':print(r['configuration'],r['output'])
        return 1
    print('PASS legacy wrapper; strict RTL lint has no warnings')
    return 0
if __name__=='__main__':raise SystemExit(main())
