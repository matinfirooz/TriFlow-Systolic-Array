#!/usr/bin/env python3
"""Yosys structural check of the PE, without claiming mapped ASIC PPA."""
from __future__ import annotations
import argparse,collections,json,os,pathlib,shutil,subprocess,tempfile,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def synth(sources, output_prefix, top='triflow_pe'):
    yosys=os.environ.get('YOSYS','yosys')
    if not shutil.which(yosys): raise SystemExit('Yosys is required for the optional synth-pe target.')
    # Yosys filenames are quoted; reject characters that could break its command syntax.
    paths=[str(pathlib.Path(x).resolve()) for x in sources]
    if any(any(c in x for c in ['"',';','\n','\r']) for x in paths): raise ValueError('Unsupported filename')
    netlist=ROOT/'build'/(output_prefix+'.json'); netlist.parent.mkdir(exist_ok=True)
    command='read_verilog -sv '+' '.join('"'+x+'"' for x in paths)
    command+='; hierarchy -check -top '+top+'; flatten; proc; opt; check; write_json "'+str(netlist)+'"; stat'
    result=subprocess.run([yosys,'-Q','-T','-p',command],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    report=ROOT/'reports'/(output_prefix+'.log'); report.parent.mkdir(exist_ok=True); report.write_text(result.stdout)
    if result.returncode: raise RuntimeError(result.stdout[-4000:])
    data=json.loads(netlist.read_text())['modules'][top]
    counts=dict(sorted(collections.Counter(c['type'] for c in data['cells'].values()).items()))
    return dict(top=top,cell_counts=counts,multipliers=counts.get('$mul',0),adders=counts.get('$add',0),scope='Generic RTL operators after proc/opt; not area, frequency or power')
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--baseline-zip'); args=ap.parse_args()
    results={'current':synth([ROOT/'rtl/signed_mac.sv',ROOT/'rtl/triflow_pe.sv'],'pe_structure')}
    if results['current']['multipliers']!=1 or results['current']['adders']!=1: raise SystemExit('Shared MAC structure check failed')
    if args.baseline_zip:
        with zipfile.ZipFile(args.baseline_zip) as z:
            names=[n for n in z.namelist() if n.endswith('/rtl/triflow_pe.sv')]
            if len(names)!=1: raise ValueError('Could not resolve exactly one baseline PE')
            with tempfile.TemporaryDirectory(prefix='triflow-baseline-') as tmp:
                path=pathlib.Path(tmp)/'triflow_pe.sv';path.write_bytes(z.read(names[0]))
                results['uploaded_baseline']=synth([path],'baseline_pe_structure')
    (ROOT/'reports/pe_structure.json').write_text(json.dumps(results,indent=2)+'\n')
    for name,r in results.items(): print(f"{name}: multipliers={r['multipliers']}, adders={r['adders']} (generic RTL operators)")
if __name__=='__main__': main()
