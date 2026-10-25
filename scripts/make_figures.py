#!/usr/bin/env python3
"""Editable architecture figures. SVG output needs only Python's standard library."""
from __future__ import annotations
import argparse,html,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
NAVY='#14243b'; INK='#26364c'; MUTED='#5b6d83'; BLUE='#306bea'; TEAL='#079b89'; ORANGE='#d98722'; LINE='#cdd8e6'; PALE='#f4f7fb'
class SVG:
    def __init__(self,w,h,title):
        self.w=w;self.h=h;self.parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img"><title>{html.escape(title)}</title>',f'<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto-start-reverse"><path d="M0,0 L8,4 L0,8 Z" fill="context-stroke"/></marker></defs>',f'<rect width="{w}" height="{h}" fill="white"/>']
    def rect(self,x,y,w,h,fill='white',stroke=LINE,rx=14):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="1.6"/>')
    def text(self,x,y,txt,size=20,color=INK,weight=400,anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" font-family="DejaVu Sans,Arial,sans-serif" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" fill="{color}">{html.escape(str(txt))}</text>')
    def line(self,points,color=MUTED,width=2.3,arrow=True,dash=False):
        pts=' '.join(f'{x},{y}' for x,y in points)
        self.parts.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"'+(' stroke-dasharray="6 5"' if dash else '')+(' marker-end="url(#arrow)"' if arrow else '')+'/>')
    def block(self,x,y,w,h,title,lines=(),accent=BLUE):
        self.rect(x,y,w,h);self.rect(x,y,5,h,accent,accent,2); self.text(x+20,y+34,title,22,NAVY,700)
        for i,s in enumerate(lines):self.text(x+20,y+65+i*26,s,17,MUTED)
    def save(self,name,png=False):
        path=ROOT/'assets'/name;path.parent.mkdir(exist_ok=True);path.write_text('\n'.join(self.parts+['</svg>']))
        if png:
            import cairosvg
            cairosvg.svg2png(url=str(path),write_to=str(path.with_suffix('.png')),output_width=self.w)
    def header(self,kicker,title,subtitle):
        self.text(48,43,kicker.upper(),16,BLUE,700);self.text(48,91,title,38,NAVY,700);self.text(48,125,subtitle,19,MUTED)

# Keep SVG above as the chart helper; the circuit figures use hardware symbols.
from hardware_figures import architecture, pe, dataflows, controller as control, result_path, array_links

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--png',action='store_true'); args=ap.parse_args()
    for fn in [architecture, pe, dataflows, control, result_path, array_links]: fn(args.png)
    print('Generated 6 hardware schematics: architecture, PE, dataflows, controller, result path, and array links')
if __name__=='__main__': main()
