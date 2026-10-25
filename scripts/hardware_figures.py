#!/usr/bin/env python3
"""RTL-grounded editable hardware schematics; stdlib SVG, optional CairoSVG PNG."""
from __future__ import annotations
import argparse, html, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
INK='#202832'; GRAY='#66717d'; LIGHT='#cad1d7'; BLUE='#2468a0'; TEAL='#087f79'; ORANGE='#b46c16'
REG='#edf3f8'; SUM='#fff4e4'; RES='#eaf6f3'
class Circuit:
    def __init__(self,w,h,title,subtitle=''):
        self.w=w;self.h=h;self.text_boxes=[]
        self.p=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img"><title>{html.escape(title)}</title>']
        self.p.append('<defs>')
        for i,color in enumerate([INK,GRAY,BLUE,TEAL,ORANGE]):
            self.p.append(f'<marker id="arr{i}" viewBox="0 0 9 7" refX="8" refY="3.5" markerWidth="8" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L9 3.5 L0 7 Z" fill="{color}"/></marker>')
        self.p.append('</defs>');self.rect(0,0,w,h,fill='white',stroke='none')
        self.text(34,38,title,24,weight=700)
        if subtitle:self.text(34,68,subtitle,16,color=GRAY)
        self.wire([(34,87),(w-34,87)],color=LIGHT,width=1,arrow=False)
    def text(self,x,y,t,size=17,color=INK,weight=400,anchor='start',mono=False,back=False):
        t=str(t);font='DejaVu Sans Mono' if mono else 'DejaVu Sans'
        if back:
            width=len(t)*size*.58
            left=x if anchor=='start' else x-width/2 if anchor=='middle' else x-width
            self.rect(left-4,y-size, width+8,size+5,'white','none')
        self.p.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{font},Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{color}">{html.escape(t)}</text>')
        self.text_boxes.append((x,y,t,size,anchor,mono))
    def rect(self,x,y,w,h,fill='white',stroke=INK,width=1.7,dash=False):
        self.p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"'+(' stroke-dasharray="7 5"' if dash else '')+'/>')
    def poly(self,pts,fill='white',stroke=INK,width=1.7):
        self.p.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>')
    def wire(self,pts,color=INK,width=2,arrow=True,control=False):
        colors=[INK,GRAY,BLUE,TEAL,ORANGE];idx=colors.index(color) if color in colors else 0
        self.p.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"'+(' stroke-dasharray="6 4"' if control else '')+(f' marker-end="url(#arr{idx})"' if arrow else '')+'/>')
    def dot(self,x,y,color=INK,r=3.5):self.p.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}"/>')
    def circle(self,x,y,r,txt='',color=INK,fill='white'):
        self.p.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{color}" stroke-width="2"/>')
        if txt:self.text(x,y+9,txt,30,color,anchor='middle')
    def bus(self,x,y,label,color=INK,vertical=False,above=True):
        self.wire([(x-5,y+7),(x+5,y-7)],color,1.5,False)
        self.text(x+10,y-10 if above else y+26,label,14,color,back=True)
    def box(self,x,y,w,h,title,lines=(),fill='white',color=INK):
        self.rect(x,y,w,h,fill,color);self.text(x+w/2,y+30,title,19,color,700,'middle')
        for i,t in enumerate(lines):self.text(x+w/2,y+58+25*i,t,16,GRAY,anchor='middle')
    def reg(self,x,y,w,h,name,width_label='W',enable=None,resident=False):
        fill=RES if resident else REG
        self.rect(x,y,w,h,fill,INK,1.7)
        self.text(x+w/2,y+27,name,18,weight=700,anchor='middle',mono=True)
        self.text(x+w/2,y+49,width_label,14,color=GRAY,anchor='middle')
        self.poly([(x+10,y+h),(x+17,y+h-10),(x+24,y+h)],fill,INK,1.2)
        if enable:self.text(x+w/2,y+h+20,'CE: '+enable,13,GRAY,anchor='middle')
    def mux(self,x,y,w,h,labels=(),select='',color=INK):
        self.poly([(x,y),(x+w,y+20),(x+w,y+h-20),(x,y+h)],'white',color)
        ys=[y+h*(i+1)/(len(labels)+1) for i in range(len(labels))]
        for yy,t in zip(ys,labels):self.text(x+8,yy+5,t,12,color,mono=True)
        if select:
            self.wire([(x+w/2,y+h-10),(x+w/2,y+h+8)],GRAY,1.2,False,control=True)
            self.text(x+w/2,y+h+25,select,13,GRAY,anchor='middle')
        return ys,(x+w,y+h/2)
    def bank(self,x,y,w,h,name,bits,color=BLUE):
        self.rect(x,y,w,h,REG,INK)
        self.text(x+w/2,y+28,name,20,weight=700,anchor='middle')
        for j in range(3):
            for i in range(5):self.rect(x+20+i*(w-40)/5,y+45+j*13,(w-40)/5,13,'white',LIGHT,1)
        self.text(x+w/2,y+h-17,bits,15,GRAY,anchor='middle')
        self.poly([(x+10,y+h),(x+17,y+h-10),(x+24,y+h)],REG,INK,1.2)
    def note(self,x,y,t,size=15):self.text(x,y,t,size,GRAY)
    def save(self,name,png=False):
        path=ROOT/'assets'/name;path.parent.mkdir(exist_ok=True)
        path.write_text('\n'.join(self.p+['</svg>']))
        if png:
            import cairosvg
            cairosvg.svg2png(url=str(path),write_to=str(path.with_suffix('.png')),output_width=self.w*1.5)
        # Keep a machine-readable inventory for visual QA; nothing is a bitmap label.
        return path

def pe(png=False):
    s=Circuit(1840,1160,'(b) Reconfigurable processing element — register-transfer datapath',
              'W = DATA_W; P = ACC_W.  A single signed multiplier and adder are shared by OS, WS, and IS.')
    s.rect(42,118,1755,698,stroke=LIGHT,dash=True);s.text(62,145,'triflow_pe',16,GRAY,mono=True)
    # Resident registers and their actual preload controls.
    s.reg(270,177,160,68,'input_reg','W',resident=True)
    s.reg(270,557,160,68,'weight_reg','W',resident=True)
    s.text(75,174,'preload_data',17,TEAL,mono=True)
    s.wire([(75,190),(220,190),(220,211),(270,211)],TEAL)
    s.wire([(220,211),(220,591),(270,591)],TEAL);s.dot(220,211,TEAL);s.bus(165,190,'W',TEAL,above=False)
    s.text(350,166,'WE: preload_input',13,GRAY,anchor='middle')
    s.text(350,650,'WE: preload_weight',13,GRAY,anchor='middle')
    # Primary incoming nets and operand mode muxes.
    s.text(75,302,'a_west',18,BLUE,mono=True)
    s.wire([(75,315),(470,315),(470,292),(560,292)],BLUE);s.bus(460,315,'W',BLUE,above=False)
    s.text(75,462,'b_north',18,TEAL,mono=True)
    s.wire([(75,475),(500,475),(500,452),(560,452)],TEAL);s.bus(460,475,'W',TEAL,above=False)
    s.mux(560,250,78,128,['A','I'],'IS / else',BLUE)
    s.mux(560,410,78,128,['B','W'],'WS / else',TEAL)
    s.wire([(430,211),(505,211),(505,335),(560,335)],TEAL)
    s.wire([(430,591),(525,591),(525,495),(560,495)],TEAL)
    # signed_mac's zero isolation is two operand muxes controlled together.
    s.mux(760,264,66,100,['D','0'],'use_product',BLUE)
    s.mux(760,424,66,100,['D','0'],'use_product',TEAL)
    s.wire([(638,314),(700,314),(700,297),(760,297)],BLUE)
    s.wire([(638,474),(700,474),(700,457),(760,457)],TEAL)
    s.text(720,336,'0',16,BLUE);s.wire([(738,331),(760,331)],BLUE)
    s.text(720,496,'0',16,TEAL);s.wire([(738,491),(760,491)],TEAL)
    s.rect(685,184,655,384,fill='none',stroke=LIGHT,dash=True);s.text(705,207,'signed_mac',16,GRAY,mono=True)
    s.text(1015,247,'signed W × W',17,weight=700,anchor='middle')
    s.circle(1030,405,35,'×')
    s.wire([(826,314),(1030,314),(1030,370)],BLUE)
    s.wire([(826,474),(950,474),(950,405),(995,405)],TEAL)
    s.box(1120,366,90,78,'SEXT',['2W → P'])
    s.wire([(1065,405),(1120,405)],INK);s.bus(1090,405,'2W',INK)
    s.circle(1270,405,35,'+')
    s.wire([(1210,405),(1235,405)],INK)
    # ACC/PSUM addend selection and the local OS feedback loop.
    s.mux(810,625,80,160,['ACC','N','W'],'mode',ORANGE)
    s.text(570,700,'psum_north',17,ORANGE,mono=True)
    s.wire([(570,705),(810,705)],ORANGE);s.bus(750,705,'P',ORANGE)
    s.text(570,757,'psum_west',17,ORANGE,mono=True)
    s.wire([(570,762),(785,762),(785,745),(810,745)],ORANGE)
    s.wire([(890,705),(1270,705),(1270,440)],ORANGE);s.bus(1150,705,'P',ORANGE)
    # One combinational sum is observed by the collector and selected registers.
    s.wire([(1305,405),(1380,405)],ORANGE);s.dot(1380,405,ORANGE)
    s.wire([(1380,405),(1380,225),(1510,225)],ORANGE)
    s.reg(1510,190,190,70,'acc_reg','P','step & OS')
    s.reg(1510,365,190,70,'psum_south','P','step')
    s.reg(1510,540,190,70,'psum_east','P','step')
    s.mux(1420,350,60,100,['S','0'],'WS',ORANGE)
    s.mux(1420,525,60,100,['S','0'],'IS',ORANGE)
    s.wire([(1380,405),(1380,383),(1420,383)],ORANGE);s.dot(1380,383,ORANGE)
    s.text(1390,423,'0',14,ORANGE);s.wire([(1405,417),(1420,417)],ORANGE)
    s.wire([(1480,400),(1510,400)],ORANGE)
    s.wire([(1380,405),(1380,558),(1420,558)],ORANGE)
    s.text(1390,598,'0',14,ORANGE);s.wire([(1405,592),(1420,592)],ORANGE)
    s.wire([(1480,575),(1510,575)],ORANGE)
    s.wire([(1380,485),(1760,485)],ORANGE);s.dot(1380,485,ORANGE)
    s.text(1590,473,'sum_now → collector',16,ORANGE,anchor='middle',back=True)
    s.wire([(1700,225),(1750,225),(1750,675),(940,675),(940,605),(755,605),(755,665),(810,665)],ORANGE)
    s.text(1460,654,'OS accumulator feedback',15,ORANGE,anchor='middle',back=True)
    # Forwarding registers are separate physical state from the MAC reduction.
    s.text(60,853,'Registered operand forwarding',20,weight=700)
    for base,name,out,select,color in [(0,'a_west','a_east','OS or WS',BLUE),(870,'b_north','b_south','OS or IS',TEAL)]:
        s.text(75+base,945,name,18,color,mono=True)
        s.wire([(75+base,960),(245+base,960),(245+base,943),(285+base,943)],color)
        s.mux(285+base,910,65,100,['D','0'],select,color)
        s.text(245+base,983,'0',15,color);s.wire([(260+base,977),(285+base,977)],color)
        s.reg(430+base,925,180,70,out,'W','step')
        s.wire([(350+base,960),(430+base,960)],color);s.wire([(610+base,960),(760+base,960)],color)
        s.bus(675+base,960,'W',color)
    s.note(60,1080,'Register triangles denote clk. clear resets accumulators and forwarding/partial-sum registers; resident A/B registers hold.')
    s.note(60,1110,'use_product = step & mac_valid & legal_mode & (!ZERO_GATE | (lhs ≠ 0 & rhs ≠ 0)); a zero product still forwards the addend.')
    s.save('pe.svg',png)

def architecture(png=False):
    s=Circuit(1880,1240,'(a) TriFlow-SA — top-level hardware architecture',
              'W = DATA_W; P = ACC_W; N = array dimension.  Register banks, boundary muxes, PE mesh, and control are explicit.')
    s.rect(110,132,1660,792,fill='none',stroke=LIGHT,dash=True)
    s.text(130,158,'triflow_core',16,GRAY,mono=True)
    # Host programming guard and demultiplexed writes.
    s.box(145,345,155,138,'Host guard',['bounds / busy','load_sel'],fill='white')
    s.text(20,310,'load_data',17,BLUE,mono=True);s.wire([(20,330),(115,330),(115,389),(145,389)],BLUE);s.bus(90,330,'W',BLUE,above=False)
    s.text(20,510,'row / col',16,GRAY);s.wire([(20,520),(120,520),(120,444),(145,444)],GRAY,1.4,control=True)
    s.bank(365,240,220,140,'A register bank','N² × W bits',BLUE)
    s.bank(365,505,220,140,'B register bank','N² × W bits',TEAL)
    s.wire([(300,389),(325,389),(325,310),(365,310)],BLUE)
    s.wire([(300,429),(325,429),(325,575),(365,575)],TEAL)
    s.text(342,288,'we_A',13,GRAY,anchor='end');s.text(342,604,'we_B',13,GRAY,anchor='end')
    # Parallel boundary tap networks, shown as actual muxes.
    s.rect(675,265,185,357,'white',INK);s.text(767,292,'Boundary muxes',18,weight=700,anchor='middle')
    s.mux(728,327,65,98,['Ar','Ac'],'mode',BLUE)
    s.mux(728,482,65,98,['Bc','Br'],'mode',TEAL)
    s.text(767,250,'invalid slots → 0',14,GRAY,anchor='middle')
    s.wire([(585,310),(630,310),(630,360),(728,360)],BLUE);s.dot(630,310,BLUE)
    s.wire([(630,360),(650,360),(650,392),(728,392)],BLUE);s.dot(630,360,BLUE)
    s.wire([(585,575),(635,575),(635,515),(728,515)],TEAL);s.dot(635,575,TEAL)
    s.wire([(635,575),(650,575),(650,547),(728,547)],TEAL)
    # Aggregate boundary ports route to row/column fan-out inside the array.
    s.wire([(793,376),(925,376),(925,400),(970,400)],BLUE);s.bus(881,376,'N·W',BLUE)
    s.text(884,416,'a_left',15,BLUE,mono=True,anchor='middle',back=True)
    s.wire([(793,531),(895,531),(895,210),(1330,210),(1330,280)],TEAL);s.bus(1020,210,'N·W',TEAL)
    s.text(1350,235,'b_top',15,TEAL,mono=True)
    s.rect(970,280,390,391,'white',INK);s.text(1165,308,'N × N PE mesh',20,weight=700,anchor='middle')
    # Grid ports and four-by-four physical instance sketch.
    for r in range(4):
        y=350+r*70
        s.wire([(992,y+20),(1020,y+20)],BLUE,1.5)
        for c in range(4):
            x=1020+c*78;s.rect(x,y,56,42,REG,INK,1.2);s.text(x+28,y+26,f'{r},{c}',13,anchor='middle',mono=True)
            if c<3:s.wire([(x+56,y+20),(x+78,y+20)],BLUE,1.4)
            if r<3:s.wire([(x+28,y+42),(x+28,y+70)],TEAL,1.4)
    s.wire([(992,370),(992,580)],BLUE,1.7,False)
    s.wire([(970,400),(992,400)],BLUE,1.7,False);s.dot(992,400,BLUE)
    s.wire([(1048,330),(1282,330)],TEAL,1.7,False)
    s.wire([(1330,280),(1330,330),(1282,330)],TEAL,1.7,False);s.dot(1282,330,TEAL)
    for c in range(4):s.wire([(1048+c*78,330),(1048+c*78,350)],TEAL,1.5)
    s.note(994,650,'one shared MAC / PE',16)
    # Resident preload data and one-hot write decoder.
    s.box(675,740,230,132,'Preload select',['A / B → data','row, col → PE WE'])
    s.wire([(630,310),(615,310),(615,780),(675,780)],BLUE)
    s.wire([(635,575),(640,575),(640,831),(675,831)],TEAL)
    s.wire([(905,802),(1105,802),(1105,671)],TEAL);s.bus(1010,802,'W',TEAL)
    s.text(1118,757,'preload_data',14,TEAL,mono=True)
    s.wire([(905,842),(1220,842),(1220,671)],GRAY,1.4,control=True)
    s.text(1232,809,'preload WE',14,GRAY)
    # Mode-specific result taps have different physical origins.
    s.box(1470,280,205,312,'Result collector',[],fill='white')
    s.mux(1545,345,62,170,['OS','IS','WS'],'mode',ORANGE)
    s.wire([(1360,387),(1545,387)],ORANGE);s.text(1384,360,'os_now',15,ORANGE,mono=True,back=True)
    s.bus(1445,387,'N²·P',ORANGE)
    s.wire([(1360,430),(1545,430)],ORANGE);s.text(1384,419,'is_right',15,ORANGE,mono=True,back=True)
    s.wire([(1280,671),(1405,671),(1405,472),(1545,472)],ORANGE)
    s.text(1415,533,'ws_bottom',14,ORANGE,mono=True,back=True)
    s.bank(1470,665,205,137,'C register bank','N² × P bits',ORANGE)
    s.wire([(1607,430),(1710,430),(1710,630),(1572,630),(1572,665)],ORANGE)
    s.bus(1650,630,'N²·P',ORANGE)
    s.text(1500,644,'per-cell write mask',14,GRAY)
    s.box(1470,837,205,65,'Read muxes',[],fill='white')
    s.wire([(1572,802),(1572,837)],ORANGE)
    s.wire([(1675,857),(1835,857)],ORANGE);s.text(1690,843,'result_data',14,ORANGE,mono=True)
    s.wire([(1675,886),(1835,886)],ORANGE);s.text(1690,913,'stream_data',14,ORANGE,mono=True)
    s.note(127,888,'A/B/C are flop banks with parallel taps; no SRAM macro is implied.',16)
    # Distributed control bus and actual control-state holders.
    s.box(145,1010,260,126,'Residency flags',['weight_valid / input_valid','accepted A/B writes invalidate'])
    s.box(535,1010,390,126,'Controller + command registers',['state_q, mode_q, reuse_q','preload_index, compute_cycle'])
    s.box(1090,1010,310,126,'Performance counters',['cycles / stalls / useful MACs','nonzero products'])
    s.box(1470,1010,205,126,'Stream index',['valid / ready','row-major read'])
    s.wire([(405,1060),(535,1060)],GRAY,1.5,control=True);s.text(466,1047,'reuse_hit',13,GRAY,anchor='middle')
    s.wire([(735,1010),(735,968),(1572,968),(1572,1010)],GRAY,1.5,control=True)
    s.wire([(735,968),(490,968),(490,645)],GRAY,1.5,control=True);s.dot(735,968,GRAY)
    for x,top in [(1000,671)]:
        s.wire([(x,968),(x,top)],GRAY,1.4,control=True);s.dot(x,968,GRAY)
    s.wire([(940,968),(940,635),(835,635),(835,622)],GRAY,1.4,control=True)
    s.dot(940,968,GRAY)
    s.wire([(1440,968),(1440,610),(1505,610),(1505,592)],GRAY,1.4,control=True)
    s.dot(1440,968,GRAY)
    s.text(790,951,'mode[1:0] · clear · preload_enable · compute_enable · cycle',15,GRAY,back=True)
    s.wire([(1320,671),(1320,936),(1245,936),(1245,1010)],GRAY,1.4,control=True)
    s.text(1295,988,'PE events',13,GRAY,anchor='middle',back=True)
    s.wire([(1572,902),(1572,968)],GRAY,1.4,False,control=True)
    s.note(36,1194,'Solid buses: operands / partial sums / results. Dashed wires: control and status. Register triangles denote the clock.',16)
    s.save('architecture.svg',png)

def dataflows(png=False):
    s=Circuit(1840,925,'(c) Dataflow mapping on the same physical PE mesh',
              'Blue: A operand; teal: B operand; orange: partial sum.  Resident state is inside each PE; all inter-PE hops are registered.')
    for m,(title,color) in enumerate([('Output-stationary',BLUE),('Weight-stationary',TEAL),('Input-stationary',ORANGE)]):
        x=30+m*610
        s.rect(x,125,580,670,fill='none',stroke=LIGHT)
        s.text(x+290,160,title,24,weight=700,anchor='middle')
        s.text(x+290,195,['PE(i,j) owns acc[i,j]','PE(k,j) owns B[k,j]','PE(i,k) owns A[i,k]'][m],18,color,anchor='middle')
        gx=x+112;gy=290;pitch=132;cw=94;ch=96
        # PE contents: resident flop and explicit multiply/add symbols.
        for r in range(3):
            for c in range(3):
                px=gx+c*pitch;py=gy+r*pitch
                s.rect(px,py,cw,ch,'white',INK,1.5)
                s.circle(px+25,py+25,12,'',INK);s.text(px+25,py+30,'×',18,anchor='middle')
                s.circle(px+68,py+25,12,'',INK);s.text(px+68,py+30,'+',18,anchor='middle')
                s.wire([(px+37,py+25),(px+56,py+25)],INK,1.2)
                s.rect(px+13,py+55,68,27,RES if m else REG,INK,1.1)
                tag=f'C{r}{c}' if m==0 else f'B{r}{c}' if m==1 else f'A{r}{c}'
                s.text(px+47,py+74,tag,14,color,700,'middle',mono=True)
                s.poly([(px+17,py+82),(px+22,py+76),(px+27,py+82)],RES if m else REG,INK,1)
                if m==0:
                    s.wire([(px+68,py+37),(px+68,py+55)],ORANGE,1.1)
                    s.wire([(px+81,py+69),(px+88,py+69),(px+88,py+43),(px+68,py+43),(px+68,py+37)],ORANGE,1.1)
                else:
                    s.wire([(px+13,py+69),(px+6,py+69),(px+6,py+9),(px+25,py+9),(px+25,py+13)],TEAL,1.1)

                # Rows carry A (OS/WS) or psum (IS). Columns carry B or psum (WS).
                hc=ORANGE if m==2 else BLUE;vc=ORANGE if m==1 else TEAL
                if c<2:s.wire([(px+cw,py+30),(px+pitch,py+30)],hc,2)
                if r<2:s.wire([(px+49,py+ch),(px+49,py+pitch)],vc,2)
        # Boundary injection; a single boundary label identifies each lane.
        for r in range(3):
            py=gy+r*pitch
            if m in (0,1):
                label=f'A[{r},k]' if m==0 else f'A[i,{r}]';hc=BLUE
            else:label='0';hc=ORANGE
            s.text(x+13,py+18,label,14,hc,mono=True)
            s.wire([(x+17,py+30),(gx,py+30)],hc,2)
            if m==2:
                xx=gx+2*pitch+cw
                s.wire([(xx,py+30),(x+563,py+30)],ORANGE,2)
                s.text(x+563,py+15,f'C[{r},j]',13,ORANGE,anchor='end',mono=True)
        for c in range(3):
            px=gx+c*pitch+49
            if m==1:label='0';vc=ORANGE
            else:label=f'B[k,{c}]' if m==0 else f'B[{c},j]';vc=TEAL
            s.text(px,252,label,14,vc,anchor='middle',mono=True)
            s.wire([(px,263),(px,gy)],vc,2)
            if m==1:
                s.wire([(px,gy+2*pitch+ch),(px,704)],ORANGE,2)
                s.text(px,728,f'C[i,{c}]',14,ORANGE,anchor='middle',mono=True)
        s.text(x+290,763,['A/B: W bits; local acc: P bits','A: W bits; south psum: P bits','B: W bits; east psum: P bits'][m],17,GRAY,anchor='middle')
    s.note(35,841,'Matching products align at t = i + j + k. OS completes locally; WS retires at the bottom edge; IS retires at the right edge.',18)
    s.note(35,878,'Internal multiply/add drawings show a shared MAC abstraction; exact operand muxes, state enables, and output-zero muxes are in the PE datapath.',16)
    s.save('dataflows.svg',png)

def controller(png=False):
    s=Circuit(1660,1030,'(d) Command controller — state, counters, and output gating',
              'Dashed signals are enables, mode, and terminal flags.  pause holds the active state and counters and suppresses datapath updates.')
    # Next-state logic and state register with feedback.
    s.box(250,225,340,295,'Next-state logic',['IDLE → CLEAR','CLEAR → PRELOAD / COMPUTE','PRELOAD → COMPUTE','COMPUTE → DONE','DONE → IDLE'])
    s.text(35,251,'start & ready',16,mono=True);s.wire([(35,265),(250,265)],GRAY,1.5,control=True)
    s.text(35,323,'dataflow[1:0]',16,mono=True);s.wire([(35,337),(250,337)],GRAY,1.5,control=True)
    s.text(35,395,'reuse_hit',16,mono=True);s.wire([(35,409),(250,409)],GRAY,1.5,control=True)
    s.text(35,473,'pause',16,mono=True);s.wire([(35,487),(250,487)],GRAY,1.5,control=True)
    s.reg(730,235,190,80,'state_q','3 bits')
    s.wire([(590,275),(730,275)],INK);s.bus(665,275,'3',INK)
    s.wire([(920,275),(1020,275)],INK);s.dot(975,275)
    s.wire([(975,275),(975,158),(420,158),(420,225)],INK,1.7)
    s.text(700,146,'state feedback',15,GRAY,anchor='middle',back=True)
    s.reg(730,405,190,94,'mode_q','2 bits + reuse_used')
    s.wire([(590,450),(730,450)],GRAY,1.5,control=True)
    s.box(1020,225,210,295,'Phase decode',['CLEAR','PRELOAD','COMPUTE','DONE / IDLE'])
    s.wire([(920,452),(990,452),(990,470),(1020,470)],GRAY,1.5,control=True)
    # Explicit AND gating is shared in concept, repeated for each phase output.
    s.text(1300,183,'!pause',16,GRAY,mono=True)
    s.wire([(1300,195),(1300,490)],GRAY,1.4,False,control=True)
    for yy,label in [(272,'clear'),(367,'preload_enable'),(462,'compute_enable')]:
        s.wire([(1230,yy-10),(1340,yy-10)],GRAY,1.5,control=True)
        s.wire([(1300,yy+10),(1340,yy+10)],GRAY,1.4,control=True);s.dot(1300,yy+10,GRAY)
        # ANSI AND: square left face, semicircular right face.
        s.p.append(f'<path d="M1340,{yy-25} L1370,{yy-25} A25,25 0 0 1 1370,{yy+25} L1340,{yy+25} Z" fill="white" stroke="{INK}" stroke-width="1.7"/>')
        s.wire([(1395,yy),(1620,yy)],GRAY,1.6,control=True)
        s.text(1450,yy-12,label,16,GRAY,mono=True,back=True)
    # Counter datapath, increment, terminal comparisons, and CE return.
    s.reg(250,645,270,86,'preload_index','max(1, ceil(log₂ N²)) bits','preload_enable')
    s.reg(250,813,270,86,'compute_cycle','ceil(log₂(3N+1)) bits','compute_enable')
    for yy in [688,856]:
        s.circle(643,yy,24,'+')
        s.wire([(520,yy),(619,yy)],INK)
        s.text(643,yy-37,'1',17,anchor='middle')
        s.wire([(643,yy-28),(643,yy-24)],INK,1.2)
        s.wire([(667,yy),(695,yy),(695,yy+85),(215,yy+85),(215,yy),(250,yy)],INK,1.7)
    s.box(845,645,260,86,'Terminal compare',['preload_index = N² − 1'])
    s.box(845,813,260,86,'Terminal compare',['compute_cycle = 3N − 3'])
    s.wire([(565,688),(565,621),(820,621),(820,688),(845,688)],INK,1.5)
    s.wire([(565,856),(565,789),(820,789),(820,856),(845,856)],INK,1.5)
    s.dot(565,688);s.dot(565,856)
    s.wire([(1105,688),(1160,688),(1160,567),(570,567),(570,520)],GRAY,1.5,control=True)
    s.wire([(1105,856),(1190,856),(1190,593),(535,593),(535,520)],GRAY,1.5,control=True)
    s.text(1240,690,'Counters hold when pause = 1.',17,GRAY)
    s.text(1240,725,'accept resets cycle indices.',17,GRAY)
    s.text(1240,760,'mode is latched per command.',17,GRAY)
    s.note(35,972,'State encodings: IDLE=0, CLEAR=1, PRELOAD=2, COMPUTE=3, DONE=4. Core DONE marks final C capture; the simple top registers notification.',16)
    s.save('control_timing.svg',png)

def result_path(png=False):
    s=Circuit(1800,1060,'(e) Result collector, C registers, and ready/valid drain',
              'Wavefront retirement can write several C cells per edge. Indexed host reads and the result stream have separate read-selection networks.')
    # An explicit repeated per-cell slice; the complete bank is parallel.
    s.rect(365,159,660,422,fill='none',stroke=LIGHT,dash=True)
    s.text(695,187,'Repeated for every output cell (i,j)',19,weight=700,anchor='middle')
    s.mux(430,258,100,216,['OS','WS','IS'],'mode',ORANGE)
    for yy,label in [(312,'os_now[i,j]'),(366,'ws_bottom[j]'),(420,'is_right[i]')]:
        s.text(45,yy-15,label,18,ORANGE,mono=True)
        s.wire([(45,yy),(430,yy)],ORANGE);s.bus(305,yy,'P',ORANGE)
    s.reg(690,327,245,80,'C[i,j]','P','write_mask[i,j]')
    s.wire([(530,366),(690,366)],ORANGE)
    # Mask generation is control logic and uses current combinational sums.
    s.box(385,621,585,81,'Retire mask',['enable & legal_mode & (t = i + j + N − 1)'])
    s.wire([(810,621),(810,407)],GRAY,1.5,control=True)
    s.text(595,555,'reset / clear → 0; no write → hold',15,GRAY,anchor='middle')
    # Aggregate all C flop outputs into two independent read muxes.
    s.wire([(935,367),(1070,367),(1070,285),(1190,285)],ORANGE)
    s.wire([(1070,367),(1070,535),(1190,535)],ORANGE);s.dot(1070,367,ORANGE)
    s.bus(1070,460,'N²·P',ORANGE)
    s.mux(1190,215,90,140,['C…'],'host row/col',ORANGE)
    s.mux(1190,465,90,140,['C…'],'stream index',ORANGE)
    s.wire([(1280,285),(1745,285)],ORANGE);s.text(1420,268,'result_data',19,ORANGE,mono=True);s.bus(1650,285,'P',ORANGE)
    s.mux(1380,485,65,100,['D','0'],'busy',ORANGE)
    s.wire([(1280,535),(1320,535),(1320,518),(1380,518)],ORANGE)
    s.text(1345,557,'0',15,ORANGE);s.wire([(1360,552),(1380,552)],ORANGE)
    s.wire([(1445,535),(1745,535)],ORANGE);s.text(1500,518,'stream_data',19,ORANGE,mono=True);s.bus(1650,535,'P',ORANGE)
    s.text(1330,393,'Asynchronous reads from flop state',17,GRAY)
    # Stream index increment and terminal compare.
    s.reg(440,822,250,82,'index_q','max(1, ceil(log₂ N²)) bits','busy & ready')
    s.circle(322,863,26,'+')
    s.text(322,815,'1',18,anchor='middle');s.wire([(322,824),(322,837)],INK,1.5)
    s.wire([(690,863),(740,863),(740,950),(210,950),(210,863),(296,863)],INK,1.8)
    s.wire([(348,863),(440,863)],INK)
    s.dot(740,863)
    s.box(870,822,280,82,'Last-index compare',['index_q = N² − 1'])
    s.wire([(740,863),(870,863)],INK)
    s.wire([(740,863),(740,763),(1235,763),(1235,605)],GRAY,1.5,control=True)
    s.text(960,748,'row = index / N; col = index % N',15,GRAY,anchor='middle',back=True)
    s.reg(1360,822,220,82,'busy_q','1 bit')
    s.box(1270,700,320,88,'Busy next-state',['set: launch; clear: last & ready'])
    s.text(1290,680,'launch = done & stream_q',15,GRAY)
    s.wire([(1430,788),(1325,788),(1325,863),(1360,863)],GRAY,1.5,control=True)
    s.wire([(1150,863),(1240,863),(1240,742),(1270,742)],GRAY,1.5,control=True)
    s.wire([(1580,863),(1745,863)],GRAY,1.5,control=True);s.text(1604,848,'result_valid',16,GRAY,mono=True)
    s.dot(1600,863,GRAY);s.wire([(1600,863),(1600,755),(1590,755)],GRAY,1.5,control=True)
    s.wire([(1150,863),(1220,863),(1220,932),(1437,932)],GRAY,1.5,control=True)
    s.dot(1200,863,GRAY)
    s.circle(1460,932,23,'',GRAY);s.text(1460,940,'&',22,GRAY,anchor='middle')
    s.wire([(1600,863),(1620,863),(1620,978),(1460,978),(1460,955)],GRAY,1.4,control=True)
    s.wire([(1483,932),(1745,932)],GRAY,1.5,control=True)
    s.text(1550,918,'result_last',16,GRAY,mono=True,back=True)
    s.note(35,1007,'A new command is blocked while the stream is busy. ready = 0 holds index, data, coordinates, and last; reset aborts the stream.',17)
    s.save('result_path.svg',png)

def array_links(png=False):
    s=Circuit(1750,1190,'(f) Registered mesh links — 2 × 2 fragment of the N × N array',
              'Each neighbor pair has separate W-bit operand links and P-bit partial-sum links. The shown register slices belong to the transmitting PE.')
    xs=[365,1050];ys=[280,730];w=355;h=246
    for r,y in enumerate(ys):
        for c,x in enumerate(xs):
            s.rect(x,y,w,h,'white',INK,1.8);s.text(x+w/2,y+30,f'PE({r},{c})',22,weight=700,anchor='middle')
            s.circle(x+105,y+104,22,'×');s.circle(x+180,y+104,22,'+')
            s.wire([(x+127,y+104),(x+158,y+104)],INK,1.5)
            s.text(x+142,y+152,'shared MAC',15,GRAY,anchor='middle')
            # Output register symbols are placed at the actual E/S boundaries.
            for yy,color,label in [(y+80,BLUE,'A_E'),(y+180,ORANGE,'P_E')]:
                s.rect(x+w-67,yy-18,50,36,REG,INK,1.2);s.text(x+w-42,yy+5,label,11,color,700,'middle',mono=True)
                s.poly([(x+w-63,yy+18),(x+w-58,yy+12),(x+w-53,yy+18)],REG,INK,1)
                s.wire([(x+w-17,yy),(x+w,yy)],color,1.5,False)
            for xx,color,label in [(x+95,TEAL,'B_S'),(x+250,ORANGE,'P_S')]:
                s.rect(xx-30,y+h-45,60,30,REG,INK,1.2);s.text(xx,y+h-25,label,11,color,700,'middle',mono=True)
                s.poly([(xx-25,y+h-15),(xx-20,y+h-21),(xx-15,y+h-15)],REG,INK,1)
                s.wire([(xx,y+h-15),(xx,y+h)],color,1.5,False)
            s.text(x+15,y+176,'CE = step',13,GRAY)
    # Horizontal interconnect, operands and sums on distinct lanes.
    for r,y in enumerate(ys):
        s.text(30,y+68,f'a_left[{r}]',17,BLUE,mono=True);s.wire([(30,y+80),(365,y+80)],BLUE);s.bus(260,y+80,'W',BLUE)
        s.text(30,y+168,'0 (psum_west)',16,ORANGE,mono=True);s.wire([(30,y+180),(365,y+180)],ORANGE);s.bus(260,y+180,'P',ORANGE)
        for yy,col,label,width in [(y+80,BLUE,'a_east → a_west','W'),(y+180,ORANGE,'psum_east → psum_west','P')]:
            s.wire([(720,yy),(1050,yy)],col,2.2);s.text(885,yy-18,label,15,col,anchor='middle',back=True);s.bus(980,yy,width,col,above=False)
    # Vertical interconnect, separate operand/partial-sum lanes.
    for c,x in enumerate(xs):
        s.text(x+95,176,f'b_top[{c}]',17,TEAL,anchor='middle',mono=True)
        s.wire([(x+95,190),(x+95,280)],TEAL);s.bus(x+95,235,'W',TEAL)
        s.text(x+250,176,'0 (psum_north)',16,ORANGE,anchor='middle',mono=True)
        s.wire([(x+250,190),(x+250,280)],ORANGE);s.bus(x+250,235,'P',ORANGE)
        s.wire([(x+95,526),(x+95,730)],TEAL,2.2);s.text(x+112,592,'b_south',14,TEAL,mono=True);s.text(x+112,615,'↓ b_north',14,TEAL)
        s.wire([(x+250,526),(x+250,730)],ORANGE,2.2);s.text(x+267,661,'psum_south',14,ORANGE,mono=True);s.text(x+267,684,'↓ psum_north',14,ORANGE)
    # Physical edge taps, without implying a complete-fragment reduction.
    s.wire([(1252,834),(1695,834)],ORANGE);s.text(1460,818,'is_right_now',16,ORANGE,mono=True)
    s.dot(1430,834,ORANGE);s.wire([(1430,834),(1430,1070)],ORANGE)
    s.text(1450,1055,'ws_bottom_now',16,ORANGE,mono=True)
    s.note(35,1127,'OS selects local accumulator feedback. WS selects the northern partial sum. IS selects the western partial sum.',17)
    s.note(35,1157,'Edge collectors tap the current sum before the link flop. Boundary sums are zero; inactive-direction sums are written with zero. Full PE muxes: panel (b).',16)
    s.save('array_links.svg',png)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--png',action='store_true');args=ap.parse_args()
    for fn in [architecture,pe,dataflows,controller,result_path,array_links]:fn(args.png)
    print('Generated 6 hardware schematics (SVG'+(' + PNG' if args.png else '')+')')
if __name__=='__main__':main()
