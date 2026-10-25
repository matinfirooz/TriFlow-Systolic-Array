#!/usr/bin/env python3
"""Collect real RTL CSV rows, validate identities, and render a latency chart."""
from __future__ import annotations
import argparse,csv,hashlib,json,pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from make_figures import SVG,BLUE,TEAL,ORANGE,NAVY,MUTED,LINE

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--png',action='store_true');args=ap.parse_args()
    report=json.loads((ROOT/'reports/verification.json').read_text())
    if report['failed']: raise SystemExit('Full RTL regression must pass first')
    rows=[]
    for job in report['results']:
        if job['top']!='tb_triflow_core':continue
        with (ROOT/'build'/(job['test']+'.csv')).open() as f:
            for item in csv.DictReader(f):
                d={k:int(v) for k,v in item.items()};d['configuration']=job['test']
                n=d['n']
                assert d['compute_cycles']==3*n-2 and d['mac_ops']==n**3
                assert d['total_cycles']==1+d['preload_cycles']+d['compute_cycles']+d['stall_cycles']
                assert 0<=d['nonzero_ops']<=d['mac_ops']
                assert d['preload_cycles'] in (0,n*n)
                rows.append(d)
    if not rows: raise SystemExit('No RTL measurements')
    with (ROOT/'reports/rtl_metrics.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    selected=[]
    for n in sorted({r['n'] for r in rows}):
        group=[r for r in rows if r['n']==n and r['mode']==1 and r['stall_cycles']==0 and r['zero_gate']==1]
        cold=next(r for r in group if r['preload_cycles']==n*n)
        warm=next(r for r in group if r['reuse']==1)
        selected.append(dict(n=n,cold_cycles=cold['total_cycles'],warm_cycles=warm['total_cycles'],preload_saved=n*n,speedup=round(cold['total_cycles']/warm['total_cycles'],6)))
    with (ROOT/'reports/reuse_latency.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(selected[0]));writer.writeheader();writer.writerows(selected)
    s=SVG(1500,780,'Measured RTL controller latency with and without resident weight reuse')
    s.header('TriFlow-SA / measured RTL cycles','Resident reuse removes the preload phase','WS latency · pause = 0 · excludes operand host writes and result-stream drain · same array and wavefront')
    chart_x=130;chart_y=640;chart_h=420;max_y=100;group_w=250
    for value in range(0,101,20):
        y=chart_y-value/max_y*chart_h;s.line([(chart_x,y),(1430,y)],LINE,1,arrow=False);s.text(107,y+6,value,17,MUTED,anchor='end')
    for idx,row in enumerate(selected):
        cx=chart_x+idx*group_w+70
        for offset,key,color in [(-10,'cold_cycles',ORANGE),(72,'warm_cycles',TEAL)]:
            val=row[key];height=val/max_y*chart_h;s.rect(cx+offset,chart_y-height,65,height,color,color,4)
            s.text(cx+offset+32.5,chart_y-height-12,val,23,color,700,'middle')
        s.text(cx+63,680,f"N = {row['n']}",21,NAVY,700,'middle')
        s.text(cx+63,714,f"{row['speedup']:.2f}×",20,TEAL,700,'middle')
    s.rect(950,171,20,18,ORANGE,ORANGE,3);s.text(982,187,'Cold WS',18,MUTED)
    s.rect(1165,171,20,18,TEAL,TEAL,3);s.text(1197,187,'Resident WS',18,MUTED)
    s.text(48,756,'Source: reports/rtl_metrics.csv. Ratios describe controller latency, not end-to-end system throughput.',18,MUTED)
    s.save('reuse_latency.svg',args.png)
    mapping=[]
    for line in (ROOT/'rtl/files.f').read_text().splitlines():
        name=pathlib.Path(line).stem;bench='tb/tb_'+name+'.sv'
        if not (ROOT/bench).is_file():raise SystemExit('Missing unit/integration bench for '+line)
        mapping.append(dict(source=line,testbench=bench))
    summary=dict(rtl_configurations=report['passed'],rtl_matrix_transactions=len(rows),module_and_package_test_map=mapping,
        cross_simulator_report='verification_subset_verilator.json',
        data_scope='Observed simulator cycles and generic operator structure only',
        source_sha256={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for sub in ['rtl','tb'] for f in sorted((ROOT/sub).glob('*')) if f.suffix in {'.sv','.svh','.f'}})
    (ROOT/'reports/summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(f"Collected {len(rows)} RTL GEMM transactions across {report['passed']} passing configurations")
    for row in selected:print(row)
if __name__=='__main__':main()
