"""Original Workshop Sans font and tileable PBR surfaces, generated from mathematics."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from shapely.geometry import LineString
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[1]
T=ROOT/'assets/textures';F=ROOT/'assets/fonts'
T.mkdir(parents=True,exist_ok=True);F.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(1998)

def arc(cx,cy,rx,ry,a=0,b=360):
    return [(cx+rx*math.cos(t),cy+ry*math.sin(t)) for t in np.linspace(math.radians(a),math.radians(b),25)]
def glyphs():
    a=arc
    G={
    'A':[[(.08,0),(.36,1),(.64,0)],[(.17,.34),(.55,.34)]],
    'B':[[(.10,0),(.10,1)],[(.10,1),(.40,1)]+a(.40,.75,.23,.25,90,-90)+[(.10,.5)],[(.10,.5),(.40,.5)]+a(.40,.25,.25,.25,90,-90)+[(.10,0)]],
    'C':[a(.37,.5,.29,.5,48,312)],
    'D':[[(.10,0),(.10,1),(.32,1)]+a(.32,.5,.33,.5,90,-90)+[(.10,0)]],
    'E':[[(.64,1),(.10,1),(.10,0),(.64,0)],[(.10,.5),(.53,.5)]],
    'F':[[(.10,0),(.10,1),(.64,1)],[(.10,.5),(.53,.5)]],
    'G':[a(.37,.5,.29,.5,48,312),[(.62,.28),(.62,.5),(.40,.5)]],
    'H':[[(.10,0),(.10,1)],[(.62,0),(.62,1)],[(.10,.5),(.62,.5)]],
    'I':[[(.16,1),(.56,1)],[(.36,1),(.36,0)],[(.16,0),(.56,0)]],
    'J':[[(.20,1),(.61,1),(.61,.23)]+a(.35,.23,.26,.23,0,-180)],
    'K':[[(.10,0),(.10,1)],[(.63,1),(.10,.46),(.64,0)]],
    'L':[[(.10,1),(.10,0),(.64,0)]],
    'M':[[(.08,0),(.08,1),(.36,.47),(.64,1),(.64,0)]],
    'N':[[(.10,0),(.10,1),(.62,0),(.62,1)]],
    'O':[a(.36,.5,.29,.5)],
    'P':[[(.10,0),(.10,1),(.38,1)]+a(.38,.73,.25,.27,90,-90)+[(.10,.46)]],
    'Q':[a(.36,.5,.29,.5),[(.44,.20),(.70,-.06)]],
    'R':[[(.10,0),(.10,1),(.38,1)]+a(.38,.73,.25,.27,90,-90)+[(.10,.46)],[(.35,.46),(.65,0)]],
    'S':[a(.36,.76,.26,.24,45,270)+a(.36,.25,.28,.25,90,-140)],
    'T':[[(.06,1),(.66,1)],[(.36,1),(.36,0)]],
    'U':[[(.10,1),(.10,.27)]+a(.36,.27,.26,.27,180,360)+[(.62,1)]],
    'V':[[(.08,1),(.36,0),(.64,1)]],
    'W':[[(.06,1),(.18,0),(.36,.55),(.54,0),(.66,1)]],
    'X':[[(.09,1),(.63,0)],[(.09,0),(.63,1)]],
    'Y':[[(.08,1),(.36,.52),(.64,1)],[(.36,.52),(.36,0)]],
    'Z':[[(.08,1),(.64,1),(.08,0),(.64,0)]],
    '0':[a(.36,.5,.27,.5),[(.18,.18),(.54,.82)]],
    '1':[[(.22,.81),(.39,1),(.39,0)],[(.19,0),(.59,0)]],
    '2':[a(.36,.76,.27,.24,180,-35)+[(.10,0),(.63,0)]],
    '3':[a(.33,.75,.29,.25,125,-90)+a(.33,.25,.29,.25,90,-130)],
    '4':[[(.55,0),(.55,1),(.10,.33),(.67,.33)]],
    '5':[[(.62,1),(.13,1),(.13,.54),(.34,.54)]+a(.34,.27,.28,.27,90,-145)],
    '6':[a(.39,.54,.29,.46,60,245),a(.36,.28,.27,.28)],
    '7':[[(.08,1),(.64,1),(.27,0)]],
    '8':[a(.36,.77,.24,.23),a(.36,.27,.28,.27)],
    '9':[a(.33,.46,.29,.46,240,425),a(.36,.72,.27,.28)],
    '.':[[(.34,.01),(.35,.01)]],',':[[(.37,.06),(.31,-.12)]],
    ':':[[(.35,.70),(.36,.70)],[(.35,.12),(.36,.12)]],
    ';':[[(.35,.70),(.36,.70)],[(.37,.06),(.31,-.12)]],
    '-':[[(.14,.43),(.58,.43)]],'_':[[(.04,-.08),(.68,-.08)]],
    '+':[[(.14,.48),(.58,.48)],[(.36,.25),(.36,.71)]],
    '=':[[(.13,.33),(.59,.33)],[(.13,.61),(.59,.61)]],
    '/':[[(.12,-.05),(.59,1.05)]],'\\':[[(.12,1.05),(.59,-.05)]],
    '(':[a(.53,.5,.29,.61,115,245)],')':[a(.19,.5,.29,.61,-65,65)],
    '[':[[(.52,1.07),(.20,1.07),(.20,-.07),(.52,-.07)]],
    ']':[[(.20,1.07),(.52,1.07),(.52,-.07),(.20,-.07)]],
    '<':[[(.60,.88),(.14,.5),(.60,.12)]],'>':[[(.12,.88),(.58,.5),(.12,.12)]],
    '!':[[(.36,1),(.36,.26)],[(.35,.01),(.36,.01)]],
    '?':[a(.34,.79,.25,.21,180,-35)+[(.36,.34)],[(.35,.01),(.36,.01)]],
    "'":[[(.36,1),(.31,.79)]],'"':[[(.27,1),(.23,.79)],[(.48,1),(.44,.79)]],
    '#':[[(.26,1),(.16,0)],[(.56,1),(.46,0)],[(.07,.33),(.63,.33)],[(.09,.69),(.65,.69)]],
    '%':[a(.18,.8,.12,.2),a(.54,.2,.12,.2),[(.1,0),(.62,1)]],
    '*':[[(.36,.3),(.36,.9)],[(.1,.45),(.62,.75)],[(.1,.75),(.62,.45)]],
    '|':[[(.36,-.1),(.36,1.1)]],
    '&':[a(.37,.76,.18,.24,0,300)+a(.35,.27,.25,.27,80,370)+[(.64,.48),(.16,0)]],
    '@':[a(.36,.47,.32,.47,30,340),a(.36,.47,.14,.25),[(.50,.73),(.50,.20),(.64,.20)]],
    '$':[a(.36,.76,.26,.24,45,270)+a(.36,.25,.28,.25,90,-140),[(.36,-.13),(.36,1.13)]],
    '£':[[(.58,.91),(.38,1),(.21,.87),(.21,.16),(.1,0),(.64,0)],[(.08,.45),(.49,.45)]],
    '°':[a(.36,.80,.16,.18)],
    '→':[[(.08,.5),(.65,.5)],[(.40,.77),(.65,.5),(.40,.23)]],
    '•':[a(.36,.48,.08,.09)],
    }
    # Lowercase is a separate, original set with ascenders and descenders.
    G.update({
    'a':[a(.34,.34,.24,.34),[(.58,.68),(.58,0)]],
    'b':[[(.10,1),(.10,0)],a(.34,.34,.24,.34)],
    'c':[a(.34,.34,.25,.34,45,315)],
    'd':[[(.58,1),(.58,0)],a(.34,.34,.24,.34)],
    'e':[[(.1,.34),(.59,.34)]+a(.34,.34,.25,.34,0,315)],
    'f':[[(.50,.98),(.32,1),(.23,.87),(.23,0)],[(.07,.67),(.51,.67)]],
    'g':[a(.34,.34,.24,.34),[(.58,.68),(.58,-.15)]+a(.34,-.15,.24,.18,0,-155)],
    'h':[[(.10,1),(.10,0)],[(.10,.46)]+a(.34,.46,.24,.22,180,0)+[(.58,0)]],
    'i':[[(.36,.68),(.36,0)],[(.35,.95),(.36,.95)]],
    'j':[[(.47,.68),(.47,-.12)]+a(.28,-.12,.19,.20,0,-170),[(.46,.95),(.47,.95)]],
    'k':[[(.12,1),(.12,0)],[(.57,.68),(.12,.30),(.62,0)]],
    'l':[[(.30,1),(.30,.12),(.38,0),(.47,0)]],
    'm':[[(.07,0),(.07,.68)],[(.07,.46)]+a(.23,.46,.16,.22,180,0)+[(.39,0)],[(.39,.46)]+a(.55,.46,.16,.22,180,0)+[(.71,0)]],
    'n':[[(.10,0),(.10,.68)],[(.10,.46)]+a(.34,.46,.24,.22,180,0)+[(.58,0)]],
    'o':[a(.34,.34,.25,.34)],
    'p':[[(.10,-.30),(.10,.68)],a(.34,.34,.24,.34)],
    'q':[[(.58,-.30),(.58,.68)],a(.34,.34,.24,.34)],
    'r':[[(.15,0),(.15,.68)],[(.15,.44),(.28,.65),(.45,.68),(.58,.62)]],
    's':[a(.34,.51,.24,.17,40,270)+a(.34,.17,.24,.17,90,-140)],
    't':[[(.26,.95),(.26,.15),(.36,.01),(.53,.04)],[(.1,.68),(.56,.68)]],
    'u':[[(.1,.68),(.1,.22)]+a(.34,.22,.24,.22,180,360)+[(.58,.68)],[(.58,.2),(.58,0)]],
    'v':[[(.08,.68),(.34,0),(.60,.68)]],
    'w':[[(.06,.68),(.19,0),(.38,.43),(.56,0),(.69,.68)]],
    'x':[[(.1,.68),(.59,0)],[(.1,0),(.59,.68)]],
    'y':[[(.08,.68),(.34,0)],[(.60,.68),(.28,-.30),(.13,-.30)]],
    'z':[[(.1,.68),(.59,.68),(.1,0),(.59,0)]],
    })
    G['’']=G["'"];G['—']=[[ (.03,.43),(.70,.43) ]];G['–']=G['-']
    return G

def make_font(weight=.036,filename="workshop.ttf"):
    G=glyphs();order=['.notdef','space']+['g'+str(ord(c)) for c in G]
    fb=FontBuilder(1000,isTTF=True);fb.setupGlyphOrder(order)
    cmap={32:'space'};out={};metrics={}
    for name in order:
        pen=TTGlyphPen(None)
        ch=next((c for c in G if 'g'+str(ord(c))==name),None)
        if ch:
            shape=unary_union([LineString(p).buffer(weight,cap_style=1,join_style=1,quad_segs=4) for p in G[ch]])
            parts=list(shape.geoms) if shape.geom_type=='MultiPolygon' else [shape]
            for polygon in parts:
                for ring in [polygon.exterior,*polygon.interiors]:
                    points=list(ring.coords)[:-1];pen.moveTo((round(points[0][0]*760+40),round(points[0][1]*760)))
                    for x,y in points[1:]:pen.lineTo((round(x*760+40),round(y*760)))
                    pen.closePath()
            cmap[ord(ch)]=name
        out[name]=pen.glyph();metrics[name]=(620 if name!='space' else 290,0)
    fb.setupCharacterMap(cmap);fb.setupGlyf(out);fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=920,descent=-250)
    fb.setupOS2(sTypoAscender=920,sTypoDescender=-250,usWinAscent=940,usWinDescent=260)
    fb.setupNameTable({'familyName':'Workshop Sans','styleName':'Regular','uniqueFontIdentifier':'STEVE.WorkshopSans.2','fullName':'Workshop Sans Original','psName':'WorkshopSansOriginal'})
    fb.setupPost();fb.setupMaxp();fb.save(F/filename)

def noise(n=512,s=8):
    x=rng.normal(size=(n,n)).astype(np.float32)
    x=gaussian_filter(x,s,mode='wrap');return x/(x.std()+.00001)
def surface(name,color,n=512,rough=.6,style='fine'):
    y,x=np.mgrid[0:n,0:n]/n
    fine=noise(n,.6); mid=noise(n,4);coarse=noise(n,24)
    h=.13*fine+.15*mid+.1*coarse; al=.015*fine+.013*mid+.012*coarse
    if style=='wood':
        grain=np.sin(y*900+coarse*.8+np.sin(x*12)*3)+.3*np.sin(y*3100+mid)
        h=grain*.15+fine*.035;al=grain*.030+coarse*.018
    elif style=='brushed':
        stripe=np.tile(rng.normal(0,1,n)[:,None],(1,n))
        h=stripe*.13+fine*.02;al=stripe*.017+coarse*.008
    elif style=='fabric':
        h=.16*np.sin(x*math.tau*85)*np.sin(y*math.tau*85)+fine*.035;al=.007*fine+.012*coarse
    elif style=='plaster':
        h=.32*fine+.23*mid;al=.015*fine+.025*coarse
    elif style=='skin':
        freckles=np.maximum(0,fine-1.9);al=.011*mid+.016*coarse-freckles*.009
        h=.07*fine+.02*mid
    elif style=='floor':
        joints=np.minimum.reduce([x,1-x,y,1-y])<.006
        al+=joints*(-.13);h-=joints*.5
        fleck=np.maximum(0,fine-1)*.018;al+=fleck
    elif style=='concrete':
        pore=np.maximum(0,-fine-1.2);h-=pore*.25;al-=pore*.014
    elif style=='wet':
        h=.4*fine+.08*mid;al+=.026*mid
        rough=np.clip(.30+.30*np.tanh(coarse),.06,.65)
    rgb=np.clip(np.array(color)[None,None,:]+al[:,:,None],0,1)
    Image.fromarray((rgb*255).astype(np.uint8)).save(T/(name+'_color.png'))
    gx,gy=np.gradient(h);v=np.stack([-gy*1.4,-gx*1.4,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2)[:,:,None]
    Image.fromarray(((v*.5+.5)*255).astype(np.uint8)).save(T/(name+'_normal.png'))
    r=np.clip(np.asarray(rough)+.028*mid,0,1)
    Image.fromarray((r*255).astype(np.uint8)).save(T/(name+'_rough.png'))
    print('PBR',name,n,flush=True)

def placard(name,text,size=(1024,512),background='#e2ded0',foreground='#182023',font_size=48):
    im=Image.new('RGB',size,background);d=ImageDraw.Draw(im);font=ImageFont.truetype(str(F/'workshop.ttf'),font_size)
    d.rounded_rectangle((8,8,size[0]-9,size[1]-9),12,outline=foreground,width=3)
    d.multiline_text((36,30),text,fill=foreground,font=font,spacing=font_size//3)
    im.save(T/(name+'.png'))

make_font()
make_font(.060,"workshop_ui.ttf")
for args in [
 ('plaster',(.70,.69,.64),1024,.90,'plaster'),
 ('vinyl',(.37,.39,.36),1024,.62,'floor'),
 ('oak',(.27,.18,.105),1024,.48,'wood'),
 ('steel',(.43,.46,.47),512,.30,'brushed'),
 ('aluminium',(.66,.68,.69),512,.28,'brushed'),
 ('enamel',(.047,.055,.06),512,.36,'fine'),
 ('plastic',(.55,.53,.46),512,.57,'fine'),
 ('concrete',(.30,.32,.33),1024,.86,'concrete'),
 ('asphalt',(.065,.075,.084),1024,.48,'wet'),
 ('rubber',(.026,.027,.03),512,.82,'fine'),
 ('cloth',(.075,.095,.109),512,.88,'fabric'),
 ('ellis_cloth',(.22,.16,.14),512,.88,'fabric'),
 ('skin',(.63,.43,.34),1024,.49,'skin'),
 ('ellis_skin',(.72,.55,.46),1024,.53,'skin'),
 ('paper',(.81,.79,.72),512,.94,'plaster'),
 ('pcb',(.035,.16,.092),512,.50,'fine')]:surface(*args)
placard('work_order','MERIDIAN / NIGHT MAINTENANCE\nFeed 07 = OPTICAL SECURITY\nBus C3 / keep watchdog powered\nBridge during GREEN diagnostic window\nPump: 3.6A running / 6A starting\nUse T6.3A slow-blow fuse',font_size=38)
placard('coolant_note','CHILLED WATER / CORE LOOP\nSupply: 12 C   Load: 4 kW\nCore needs at least 8 L/min\nPressure: 180 - 220 kPa\nClose bypass before balancing\nTarget temperature: below 20 C',font_size=42)
placard('receipt','STEVE\'S PC REPAIR\nClient: HELEN ELLIS\nCMOS battery CR2032       2.00\nData backup             FREE\nAppointment: THURSDAY\n"Arthur\'s letters are safe."',font_size=42)
placard('bios_idle','STEVE / BENCH DIAGNOSTICS\nATX PWR: DISCONNECTED\nRTC battery: 0.41 V\nCMOS checksum invalid\n1998 hardware. Still repairable.',background='#03110d',foreground='#78bfa1',font_size=42)
placard('bios_fixed','STEVE / BENCH DIAGNOSTICS\nRTC battery: 3.02 V\nMemory test: PASS\nClock: 01 OCT 2026\nBackup: ARTHUR / VERIFIED\nEVERYTHING HAS A FIX.',background='#03110d',foreground='#78bfa1',font_size=42)
placard('archive','MERIDIAN / INDEX M07\nELLIS, HELEN / pension 00000007\n8,014,922 records / sealed export\nATTACH ENCRYPTED DRIVE\nCopy evidence before key destruction',background='#071416',foreground='#72b4b3',font_size=40)
placard('key_console','WIDOWMAKER / ROOT SIGNING KEY\nBattery-backed secure memory\nDUAL SUPPLY: A + B\nDisconnect BOTH feeds\nVerify 0V before tamper seal\nPull cell to zeroize key',background='#141013',foreground='#c8796d',font_size=40)
print('Original font and material library complete.',flush=True)
