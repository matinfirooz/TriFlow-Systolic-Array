#!/usr/bin/env python3
"""Extract an actual VCD transaction and render a compact timing figure."""
from __future__ import annotations
import argparse,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
NAMES=['clk','start','cmd_ready','busy','pause','done','result_valid','result_ready','result_last','stream_done',
       'active_dataflow','state_debug','perf_compute_cycles','perf_stall_cycles','perf_mac_ops']
INTERNAL=['compute_enable','accepted','compute_cycle']

def extract(path):
    scope=[];codes={};widths={};events={};header=True;now=0
    for line in path.read_text().splitlines():
        line=line.strip()
        if header:
            words=line.split()
            if words[:1]==['$scope']:scope.append(words[2])
            elif words[:1]==['$upscope']:scope.pop()
            elif words[:1]==['$var']:
                full='.'.join(scope+[words[4]]);name=None
                if scope==['tb_triflow_core'] and words[4] in NAMES:name=words[4]
                if scope==['tb_triflow_core','dut'] and words[4] in INTERNAL:name=words[4]
                if name:codes[words[3]]=name;widths[name]=int(words[2]);events[name]=[]
            elif words[:1]==['$enddefinitions']:header=False
            continue
        if not line:continue
        if line[0]=='#':now=int(line[1:]);continue
        if line[0] in '01xz':value,code=line[0],line[1:]
        elif line[0]=='b':value,code=line[1:].split()
        else:continue
        if code in codes:events[codes[code]].append((now,value))
    return widths,events

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--input',default='build/triflow.vcd');args=ap.parse_args()
    widths,events=extract(ROOT/args.input)
    first_accept=next(t for t,v in events['accepted'] if v=='1')
    end=next(t for t,v in events['stream_done'] if v=='1' and t>first_accept)+20000
    begin=max(0,first_accept-10000)
    selected={}
    for name,seq in events.items():
        init='x'
        for t,v in seq:
            if t<=begin:init=v
        selected[name]=[(0,init)]+[(t-begin,v) for t,v in seq if begin<t<=end]
    output=ROOT/'reports/sample_trace.vcd';lines=['$timescale 1ps $end','$scope module triflow_sample $end']
    ids={name:chr(33+i) for i,name in enumerate(selected)}
    for name in selected:lines.append(f'$var wire {widths[name]} {ids[name]} {name} $end')
    lines+=['$upscope $end','$enddefinitions $end'];by_time={}
    for name,seq in selected.items():
        for t,v in seq:by_time.setdefault(t,[]).append((name,v))
    for t,values in sorted(by_time.items()):
        lines.append('#'+str(t))
        for name,v in values:lines.append((v+ids[name]) if widths[name]==1 else ('b'+v+' '+ids[name]))
    output.write_text('\n'.join(lines)+'\n')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.family':'DejaVu Sans','svg.fonttype':'none','font.size':10})
    signals=['clk','start','cmd_ready','busy','pause','compute_enable','done','result_valid','result_ready','result_last','stream_done']
    fig,axes=plt.subplots(len(signals),1,figsize=(14,7),sharex=True,gridspec_kw={'hspace':.12})
    for ax,name in zip(axes,signals):
        seq=selected[name];xs=[t/10000-1 for t,v in seq];ys=[int(v,2) if not any(c in v for c in 'xz') else 0 for t,v in seq]
        xs.append((end-begin)/10000-1);ys.append(ys[-1]);color='#d98722' if name=='pause' else '#079b89' if name.startswith('result') or name=='stream_done' else '#306bea'
        ax.step(xs,ys,where='post',color=color,lw=1.6);ax.fill_between(xs,0,ys,step='post',color=color,alpha=.08)
        ax.set_ylim(-.2,1.2);ax.set_yticks([]);ax.set_ylabel(name,rotation=0,ha='right',va='center',labelpad=10,color='#26364c')
        ax.spines[['top','right','left']].set_visible(False);ax.spines['bottom'].set_color('#dde5ef');ax.grid(axis='x',color='#e8edf4',lw=.7)
        ax.tick_params(axis='x',length=0)
    axes[-1].set_xlabel('Clock cycles relative to the first OS command request (10 ns period)')
    axes[-1].set_xlim(-1,(end-begin)/10000-1)
    fig.suptitle('Actual RTL trace: global pauses and result backpressure',x=.16,ha='left',fontsize=18,fontweight='bold',color='#14243b')
    fig.text(.16,.925,'N=4, INT8 → INT32 · busy start pulses are intentionally ignored by the testbench',fontsize=10,color='#5b6d83')
    fig.subplots_adjust(left=.16,right=.98,top=.88,bottom=.08)
    for ext in ['svg','png']:fig.savefig(ROOT/'assets'/('waveform.'+ext),dpi=150,facecolor='white')
    plt.close(fig);print('Rendered actual waveform and reports/sample_trace.vcd')
if __name__=='__main__':main()
