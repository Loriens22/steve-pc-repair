"""All game geometry is authored here in Blender. No asset libraries."""
import bpy, math, random, os, json
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = ROOT+'/assets/models'
random.seed(98)
M={}
def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for d in list(bpy.data.materials): bpy.data.materials.remove(d)
    M.clear()
def mat(name, color, rough=.6, metal=0, emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough; bs.inputs['Metallic'].default_value=metal
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1); bs.inputs['Emission Strength'].default_value=emission
    M[name]=m; return m
def palette():
    for n,c,r,m,e in [
        ('plaster',(.62,.58,.45),.95,0,0),('ivory',(.83,.78,.63),.7,0,0),
        ('navy',(.025,.085,.12),.65,0,0),('blue',(.09,.29,.39),.6,0,0),
        ('steel',(.22,.27,.27),.28,.75,0),('chrome',(.58,.62,.59),.18,.85,0),
        ('black',(.013,.022,.023),.48,0,0),('rubber',(.032,.034,.029),.9,0,0),
        ('orange',(.92,.35,.08),.48,0,0),('wood',(.31,.145,.07),.75,0,0),
        ('wood_light',(.61,.36,.17),.8,0,0),('green',(.19,.37,.16),.7,0,0),
        ('mint',(.35,.94,.61),.35,0,1.2),('amber',(1,.65,.21),.35,0,1.2),
        ('cyan',(.15,.74,.86),.3,0,1.2),('red',(.89,.095,.07),.4,0,1),
        ('white',(.95,.88,.69),.5,0,0),('screen',(.024,.09,.095),.18,.2,0),
        ('skin',(.66,.41,.26),.85,0,0),('skin_ellis',(.82,.61,.46),.85,0,0),
        ('hair',(.13,.09,.07),.9,0,0),('hair_ellis',(.65,.67,.63),.9,0,0),
        ('fur',(.84,.48,.17),.95,0,0),('fur_dark',(.32,.16,.07),.95,0,0),
        ('purple',(.33,.2,.42),.75,0,0),('road',(.055,.071,.077),.98,0,0),
        ('concrete',(.26,.32,.32),.94,0,0),('glass',(.07,.16,.18),.16,.3,0),
        ('paper',(.8,.77,.63),.94,0,0),('brick',(.43,.21,.135),.94,0,0),
        ('gold',(.83,.53,.14),.24,.7,0),('neon',(.65,.93,.78),.4,0,2.5)
    ]: mat(n,c,r,m,e)
def pos(p): return (p[0],-p[2],p[1])
def finish(o,n,m,parent=None):
    o.name=n; o.data.materials.append(M[m])
    if parent:
        world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    return o
def box(n,p,s,m,bevel=.035,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos(p));o=bpy.context.object
    o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Machined edges','BEVEL');mod.width=min(bevel,min(s)/3);mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(o,n,m,parent)
def sphere(n,p,s,m,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=pos(p));o=bpy.context.object
    o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,n,m,parent)
def cyl(n,p,r,d,m,rot=None,parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d,location=pos(p));o=bpy.context.object
    if rot:o.rotation_euler=rot
    mod=o.modifiers.new('Soft rim','BEVEL');mod.width=.018;mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,n,m,parent)
def line(n,a,b,r,m,parent=None):
    av=Vector(pos(a));bv=Vector(pos(b));v=bv-av
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=v.length,location=(av+bv)/2);o=bpy.context.object
    o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return finish(o,n,m,parent)
def text(n,p,value,size,m,rot=None):
    c=bpy.data.curves.new(n,'FONT');c.body=value;c.size=size;c.extrude=.0015;c.align_x='CENTER'
    o=bpy.data.objects.new(n,c);bpy.context.collection.objects.link(o);o.location=pos(p)
    o.rotation_euler=rot or (math.pi/2,0,0);o.data.materials.append(M[m])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False);return o
def torus(n,p,r,th,m,rot=None,parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=th,major_segments=20,minor_segments=8,location=pos(p));o=bpy.context.object
    if rot:o.rotation_euler=rot
    return finish(o,n,m,parent)
def export(name,merge=True):
    if merge:
        # Combine static geometry by material, keeping draw calls low on mobile.
        for m in list(M.values()):
            obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.materials)==1 and o.data.materials[0]==m]
            if len(obs)>1:
                bpy.ops.object.select_all(action='DESELECT')
                for o in obs:o.select_set(True)
                bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=m.name+'_geometry'
    bpy.ops.object.select_all(action='SELECT')
    os.makedirs(ROOT+'/blender',exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/'+name+'.blend')
    bpy.ops.export_scene.gltf(filepath=OUT+'/'+name+'.glb',export_format='GLB',export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    print('CREATED',name,len(bpy.context.scene.objects),'objects')

def pc(x,y,z,kind='crt'):
    if kind=='crt':
        box('CRT housing',(x,y+.34,z),(1.05,.75,.75),'ivory',.1)
        box('CRT bevel',(x,y+.36,z+.395),(.89,.59,.04),'navy')
        box('CRT glass',(x,y+.39,z+.421),(.79,.46,.01),'screen',.01)
        for i in range(5):box('Text scanlines',(x-.05,y+.54-i*.065,z+.43),(.53-(i%3)*.1,.015,.005),'mint',0)
        text('CRT logo',(x+.27,y+.11,z+.44),'98',.085,'black')
        box('CRT neck',(x,y-.08,z),(.27,.21,.28),'ivory')
        box('CRT foot',(x,y-.16,z+.08),(.75,.08,.5),'ivory')
    else:
        box('Monitor',(x,y+.37,z),(1.05,.64,.1),'black')
        box('Monitor LCD',(x,y+.4,z+.056),(.93,.5,.009),'screen',0)
        for i in range(7):box('Terminal lines',(x-.11,y+.59-i*.055,z+.063),(.48+random.random()*.27,.012,.003),'cyan',0)
        box('Monitor neck',(x,y-.02,z),(.08,.24,.1),'steel')
        box('Monitor foot',(x,y-.12,z+.03),(.55,.04,.34),'steel')
    box('Keyboard',(x,y-.17,z+.72),(.86,.045,.29),'ivory',.015)
    for a in range(12):
        for b in range(4):box('Key',(x-.37+a*.066,y-.138,z+.62+b*.065),(.052,.018,.045),'white',.003)
    sphere('Mouse',(x+.72,y-.14,z+.65),(.095,.035,.14),'ivory')
def tower(x,y,z):
    box('PC tower',(x,y+.5,z),(.48,1,.71),'ivory')
    box('Drive bay',(x,y+.76,z+.36),(.39,.15,.024),'steel',.01)
    box('Floppy',(x,y+.55,z+.36),(.31,.075,.025),'black',.008)
    cyl('Power button',(x+.13,y+.3,z+.37),.035,.012,'green',(math.pi/2,0,0))
    for j in range(7):box('Vents',(x,y+.17-j*.015,z+.36),(.28,.006,.016),'black',0)
def table(x,z,w=2,d=1,y=1,m='wood_light'):
    box('Worktop',(x,y,z),(w,.12,d),m)
    for a in [-1,1]:
        for b in [-1,1]:box('Desk leg',(x+a*(w/2-.16),y/2,z+b*(d/2-.1)),(.1,y,.1),'steel')
def plant(x,y,z,sz=1):
    cyl('Terracotta',(x,y+.23*sz,z),.25*sz,.45*sz,'brick')
    cyl('Soil',(x,y+.46*sz,z),.22*sz,.02*sz,'wood')
    for i in range(7):
        ang=i*2.4;sphere('Leaf',(x+math.sin(ang)*.22*sz,y+(.8+random.random()*.35)*sz,z+math.cos(ang)*.22*sz),(.17*sz,.43*sz,.09*sz),'green')
def stool(x,z):
    cyl('Stool',(x,.64,z),.36,.16,'blue')
    cyl('Column',(x,.34,z),.055,.58,'chrome')
    for i in range(5):
        a=i*math.tau/5;line('Spoke',(x,.12,z),(x+math.sin(a)*.4,.12,z+math.cos(a)*.4),.035,'steel')
        sphere('Caster',(x+math.sin(a)*.4,.07,z+math.cos(a)*.4),(.065,.06,.065),'rubber')

def shop():
    reset();palette()
    box('Diorama plinth',(0,-.4,0),(19,.75,15),'navy',.22)
    box('Floor',(0,-.05,0),(18,.1,14),'concrete')
    for x in range(-9,9):
        for z in range(-7,7):
            mm='plaster' if (x+z)%2==0 else 'ivory'
            box('Vinyl tile',(x+.5,.012,z+.5),(.985,.025,.985),mm,.006)
    box('Back wall',(0,1.9,-7),(18,3.8,.18),'plaster')
    box('Left wall',(-9,1.9,0),(.18,3.8,14),'plaster')
    box('Back skirting',(0,.14,-6.87),(18,.23,.12),'wood')
    box('Left skirting',(-8.86,.14,0),(.12,.23,14),'wood')
    for x in [-5,2,6]:
        box('Window recess',(x,2.3,-6.85),(2.4,1.8,.08),'navy')
        box('Window pane',(x,2.3,-6.79),(2.22,1.63,.04),'glass')
        for k in range(8):box('Venetian blinds',(x,3.05-k*.12,-6.73),(2.22,.065,.05),'ivory',.006)
        box('Window sill',(x,1.4,-6.64),(2.6,.14,.38),'ivory')
    # Actual original neon lettering and circuit motif.
    box('Sign backboard',(-2,3.2,-6.78),(4.8,.91,.08),'navy')
    text('Shop sign',(-2,3.32,-6.7),'STEVE\'S',.44,'neon')
    text('Shop subtitle',(-2,2.98,-6.7),'PC REPAIR  /  EST. 1998',.15,'white')
    for x in [-7,-1,5]:
        box('Fluorescent fitting',(x,3.7,-4.4),(2.5,.13,.43),'steel')
        for k in [-.12,.12]:box('Tube',(x,3.61,-4.4+k),(2.3,.08,.08),'white')
    table(-3,-4.9,8,1.65,1.02)
    pc(-5,1.31,-5.1);tower(-3.7,1.09,-5.2)
    pc(-1.5,1.31,-5.1,'lcd')
    box('Solder mat',(-3.3,1.105,-4.9),(1.2,.012,.65),'blue')
    box('Motherboard',(-3.3,1.13,-4.9),(.7,.03,.52),'green',.005)
    box('CPU',(-3.3,1.16,-4.9),(.17,.03,.17),'chrome',.004)
    for j in range(3):box('RAM',(-3.07+j*.07,1.19,-4.9),(.04,.09,.33),'navy',.002)
    for j in range(9):cyl('Capacitor',(-3.58+(j%3)*.07,1.17,-4.75-(j//3)*.06),.018,.07,'steel')
    line('Soldering iron',(-4,1.15,-4.56),(-3.68,1.15,-4.62),.026,'steel')
    box('Soldering station',(-4.05,1.25,-5.35),(.35,.3,.27),'navy')
    # Back pegboard populated with miniature hand tools.
    box('Pegboard',(-4.5,2.21,-6.65),(5.7,1.26,.04),'wood_light')
    for a in range(23):
        for b in range(5):sphere('Peg hole',(-7.15+a*.24,1.77+b*.21,-6.611),(.012,.012,.008),'wood')
    for j in range(13):
        x=-6.95+j*.38;line('Tool shaft',(x,1.9,-6.52),(x,2.42,-6.52),.018,'chrome')
        box('Handle',(x,1.93,-6.52),(.075,.22,.07),'orange' if j%2 else 'blue',.025)
        if j%3==0:torus('Wrench jaw',(x,2.43,-6.52),.075,.018,'chrome',(math.pi/2,0,0))
    # Front counter and the old customer's PC.
    box('Counter base',(-.8, .58,-.75),(7.3,1.16,1.1),'wood')
    box('Counter front',(-.8,.55,-.15),(7.12,.9,.07),'navy')
    for j in range(21):box('Counter battens',(-4.18+j*.338,.55,-.08),(.027,.87,.018),'wood_light',.004)
    box('Counter top',(-.8,1.23,-.75),(7.7,.13,1.4),'wood_light')
    text('Counter lettering',(-.8,.62,-.021),'GOOD PEOPLE. FAIR PRICES.',.16,'white')
    pc(1,1.59,-.62);tower(2.13,1.3,-.85)
    box('Receipt',(.04,1.315,-.27),(.42,.009,.56),'paper',0)
    for j in range(6):box('Receipt ink',(.04,1.322,-.45+j*.048),(.28,.002,.006),'black',0)
    cyl('CMOS battery',(.48,1.33,-.32),.075,.025,'chrome')
    box('Cash register',(-3.7,1.47,-.75),(.64,.44,.54),'ivory')
    box('Register display',(-3.7,1.72,-.65),(.44,.12,.04),'screen')
    text('Register total',(-3.7,1.71,-.62),'2.00',.084,'mint')
    # Briefcase, burn phone, and first class tickets.
    box('Briefcase',(-1.25,1.43,-.75),(1.13,.28,.7),'black',.065)
    for dx in [-.38,.38]:box('Case latch',(-1.25+dx,1.44,-.38),(.12,.09,.03),'gold')
    line('Handle',(-1.48,1.39,-.33),(-1.02,1.39,-.33),.028,'black')
    box('Burn phone',(-1.2,1.584,-.8),(.17,.018,.31),'steel',.015)
    box('Phone light',(-1.2,1.598,-.8),(.13,.004,.23),'cyan',.008)
    box('Ticket',(-1.6,1.59,-.73),(.43,.005,.19),'paper',.005)
    # Left shelving: individually crafted PCs, books, boxes and floppy disks.
    for y in [.25,1,1.8,2.65]:box('Shelf',(-8.25,y,-1.65),(1.14,.1,5.4),'wood_light')
    for z in [-4.2,.95]:box('Shelf upright',(-8.3,1.47,z),(1,.12,.12),'steel');line('Shelf support',(-8.76,.04,z),(-8.76,2.72,z),.04,'steel')
    for j in range(4):tower(-8.23,.3,-3.8+j*1.13)
    for j in range(16):
        zz=-4.02+j*.3;box('Repair box',(-8.24,1.32,zz),(.77,.49,.26),'ivory' if j%2 else 'wood_light')
        box('Box label',(-7.848,1.33,zz),(.01,.12,.16),'paper')
    for j in range(12):box('Book',(-8.2,2.08,-3.5+j*.34),(.65,.45,.12),'blue' if j%3 else 'orange')
    box('Floppy bin',(-8.2,1.99,.42),(.72,.28,.69),'navy')
    for j in range(8):box('Floppy disk',(-8.2,2.1,.2+j*.061),(.55,.48,.04),'black',.008)
    text('Shelf joke',(-8.68,2.89,-1.7),'IT WORKED YESTERDAY',.15,'black',(math.pi/2,0,math.pi/2))
    # Coffee corner, cat bed, customer chairs and pot plants.
    table(5.5,-5.15,3,1.25)
    box('Coffee machine',(5,1.41,-5.2),(.62,.71,.55),'black')
    cyl('Coffee cup',(5.95,1.18,-4.91),.1,.24,'ivory');torus('Cup handle',(6.09,1.2,-4.91),.075,.02,'ivory',(0,math.pi/2,0))
    cyl('Coffee',(5.95,1.29,-4.91),.084,.002,'wood')
    text('Coffee warning',(5.5,2.26,-6.69),'NO CLOUD. JUST COFFEE.',.15,'black')
    for x in [4.8,6.4]:
        box('Waiting seat',(x,.54,2.6),(1.2,.19,.92),'blue')
        box('Seat back',(x,.93,2.22),(1.2,.7,.18),'blue')
        for dx in [-.42,.42]:box('Seat leg',(x+dx,.25,2.6),(.08,.5,.65),'steel')
    table(5.6,4.15,2.4,.8,.5)
    box('Magazine',(5.4,.58,4.12),(.47,.008,.62),'orange');text('Magazine label',(5.4,.59,4.12),'BYTE',.11,'navy',(0,0,0))
    plant(7.4,0,-5.65,1.4);plant(-6.8,0,4.9,1.25)
    sphere('Cat cushion',(-4.9,.19,3.1),(.89,.2,.71),'orange')
    cyl('Cat bowl',(-3.67,.07,3.8),.2,.1,'chrome')
    text('Cat mat',(-4.9,.04,4.2),'BIOS',.24,'navy',(0,0,0))
    stool(-4,-3);stool(-.6,-3.2)
    # Wall clock and calendar: details are original rather than image textures.
    cyl('Wall clock',(7.8,3.0,-6.76),.38,.09,'ivory',(math.pi/2,0,0))
    line('Clock minute',(7.8,3,-6.698),(7.8,3.27,-6.698),.012,'black')
    line('Clock hour',(7.8,3,-6.697),(7.97,2.91,-6.697),.018,'black')
    for j in range(12):
        a=j*math.tau/12;sphere('Clock tick',(7.8+math.sin(a)*.31,3+math.cos(a)*.31,-6.693),(.013,.013,.006),'black')
    box('Calendar',(3.83,2.55,-6.72),(.74,.9,.012),'paper')
    text('Calendar title',(3.83,2.8,-6.69),'OCTOBER',.08,'orange')
    for a in range(7):
        for b in range(4):box('Calendar day',(3.55+a*.095,2.55-b*.1,-6.7),(.038,.028,.003),'navy',0)
    # A nondescript office-park entrance, and Ms Ellis's car outside.
    box('Welcome rug',(7.1,.045,-.6),(2.3,.035,1.5),'navy')
    text('Rug lettering',(7.1,.07,-.6),'WELCOME',.18,'ivory',(0,0,0))
    for z in [-1.9,.5]:box('Door post',(8.75,1.5,z),(.14,3,.14),'steel')
    box('Door header',(8.75,3,-.7),(.14,.15,2.5),'steel')
    box('Door glass',(8.8,1.5,-.74),(.026,2.8,2.3),'glass')
    line('Door handle',(8.87,1.15,-1.35),(8.87,1.15,-.91),.035,'chrome')
    text('Office unit',(8.9,2.3,-.72),'UNIT 04',.17,'white',(math.pi/2,0,math.pi/2))
    box('Walkway',(11,-.03,0),(4.2,.13,14),'concrete')
    for j in range(7):box('Concrete seams',(11,.04,-6+j*2),(4,.007,.02),'road',0)
    box('Parking',(15,-.12,0),(4,.15,15),'road')
    box('Car body',(12.2,.72,3.9),(2, .63,4),'blue',.22)
    box('Car cabin',(12.2,1.28,3.75),(1.81,.7,2.21),'glass',.2)
    box('Car roof',(12.2,1.66,3.72),(1.75,.08,1.8),'blue',.08)
    for x in [11.22,13.18]:
        for z in [2.65,5.1]:
            cyl('Car tyre',(x,.43,z),.39,.18,'rubber',(0,math.pi/2,0))
            cyl('Wheel hub',(x+(-.1 if x<12 else .1),.43,z),.24,.02,'chrome',(0,math.pi/2,0))
    for x in [11.62,12.78]:box('Headlight',(x,.73,5.94),(.42,.19,.025),'white')
    box('License plate',(12.2,.54,5.944),(.75,.13,.02),'paper')
    text('Ellis plate',(12.2,.51,5.966),'ELLIS 93',.08,'navy')
    export('shop')

def vault():
    reset();palette()
    box('Vault plinth',(0,-.5,0),(25,1,21),'navy',.3)
    box('Vault floor',(0,-.06,0),(24,.12,20),'road')
    for x in range(-12,12):
        for z in range(-10,10):
            box('Raised tile',(x+.5,.008,z+.5),(.985,.02,.985),'concrete' if (x+z)%4 else 'steel',.006)
    box('Back wall',(0,2.15,-10),(24,4.3,.25),'navy')
    box('Left wall',(-12,2.15,0),(.25,4.3,20),'navy')
    for x in range(-11,12,3):box('Structural pilaster',(x,2.1,-9.72),(.3,4.2,.35),'steel')
    for z in [-8,-2,4,9]:box('Structural column',(-11.7,2,z),(.45,4,.5),'steel')
    box('Main sign',(1.4,3.5,-9.79),(5.5,.8,.08),'black')
    text('Vault name',(1.4,3.6,-9.73),'MERIDIAN',.48,'cyan')
    text('Vault subtitle',(1.4,3.27,-9.73),'CONTINUITY IS CONTROL',.13,'white')
    # Overhead cable trays stop short of obscuring the playable space.
    for x in [-8,1,8]:
        box('Cable tray',(x,3.85,-4),(1,.13,11),'black')
        for j in range(5):line('Cable run',(x-.38+j*.18,3.97,-9),(x-.38+j*.18,3.97,1),.034,'blue' if j%2 else 'steel')
        for z in [-7,-2]:box('Cold strip',(x,3.67,z),(2.8,.07,.12),'cyan')
    # Four rows of original servers, ventilated rack fronts and status pixels.
    for x in [-7,-3,2,6.5]:
        for z in [-6,-3.5]:
            box('Server rack',(x,1.35,z),(1.62,2.7,1.1),'black',.06)
            for k in range(9):
                yy=.22+k*.273
                box('Rack unit',(x,yy,z+.56),(1.46,.22,.035),'steel',.009)
                for v in range(7):box('Air grille',(x-.48+v*.13,yy,z+.587),(.049,.13,.005),'black',.002)
                for v in range(3):box('Status diode',(x+.44+v*.07,yy+.035,z+.594),(.028,.028,.008),'mint' if k%4 else 'amber',.002)
                box('Server latch',(x-.65,yy,z+.592),(.043,.11,.014),'chrome')
            box('Rack top light',(x,2.79,z),(1.5,.055,.96),'cyan',.02)
            text('Server serial',(x,2.57,z+.602),'MRD-'+str(int((x+10)*17+z+10)),.075,'white')
    # Security console and coolant control.
    table(-9,2.25,3,1.3,1,'steel');pc(-9.6,1.3,2.1,'lcd');pc(-8.3,1.3,2.1,'lcd')
    text('Service sign',(-11.78,2.8,2.2),'AUTHORIZED SERVICE',.18,'amber',(math.pi/2,0,math.pi/2))
    box('Coolant panel',(-11.63,1.5,-3.8),(.21,1.6,1.5),'steel')
    for z in [-4.3,-3.8,-3.3]:
        line('Copper coolant',(-11.3,.15,z),(-11.3,3.5,z),.074,'orange')
        torus('Hand valve',(-11.16,1.5,z),.18,.024,'red',(0,math.pi/2,0))
    # The target core, glowing in its locked cylindrical cradle.
    cyl('Core platform',(2.3,.12,-8.1),1.04,.24,'steel')
    cyl('Core casing',(2.3,1.36,-8.1),.68,2.32,'glass')
    for k in range(8):
        a=k*math.tau/8
        line('Core fins',(2.3+math.sin(a)*.66,.3,-8.1+math.cos(a)*.66),(2.3+math.sin(a)*.66,2.7,-8.1+math.cos(a)*.66),.047,'chrome')
    for yy in [.4,.7,1,1.3,1.6,1.9,2.2,2.5]:torus('Core ring',(2.3,yy,-8.1),.72,.04,'cyan')
    box('Asset processor',(2.3,1.42,-8.1),(.42,1.84,.42),'black')
    for yy in [.6,1,1.4,1.8,2.2]:box('Asset memory',(2.3,yy,-7.85),(.3,.12,.035),'mint')
    text('Core ID',(2.3,3.01,-9.6),'THE WIDOWMAKER',.22,'orange')
    table(2.3,-6.75,1.9,.65,.84,'steel');pc(2.3,1.13,-6.8,'lcd')
    # Partition frame / magnetic security gate.
    for x in [-.2,4.7]:box('Airlock side',(x,1.7,-5.65),(.22,3.4,.24),'steel')
    box('Airlock lintel',(2.25,3.3,-5.65),(5.1,.25,.3),'steel')
    box('Gate controller',(-.3,1.35,-5.44),(.41,.65,.1),'black')
    box('Controller LED',(-.3,1.49,-5.38),(.29,.08,.015),'red')
    # Workshop cart and junk to blend into the night shift.
    box('Service cart',(8.8,.57,4.5),(2.1,1.05,1.02),'blue')
    box('Cart tray',(8.8,1.16,4.5),(2.24,.11,1.1),'steel')
    for xx in [7.95,9.65]:
        for zz in [4.12,4.85]:sphere('Cart wheel',(xx,.13,zz),(.13,.13,.13),'rubber')
    box('Service ID',(8.6,1.24,4.5),(.4,.008,.23),'paper')
    text('Cart serial',(8.8,.66,5.023),'RESET / REPAIR / REPEAT',.09,'white')
    box('Battery package',(9.3,1.25,4.55),(.4,.09,.3),'orange')
    cyl('Battery',(9.3,1.31,4.55),.11,.035,'chrome')
    # Entrance and extraction lift.
    for x in [7.3,10.9]:box('Lift surround',(x,1.85,-9.67),(.23,3.7,.3),'chrome')
    box('Elevator doors',(9.1,1.75,-9.57),(3.35,3.5,.1),'steel')
    box('Lift center seam',(9.1,1.75,-9.49),(.015,3.4,.01),'black')
    text('Lift notice',(9.1,3.85,-9.68),'ROOF ACCESS  /  08',.17,'amber')
    box('Lift button',(11.2,1.4,-9.53),(.18,.3,.05),'black')
    box('Lift button LED',(11.2,1.4,-9.49),(.07,.08,.006),'cyan')
    # Lobby rugs, hazard strips, pipes, extinguishers, paper notes.
    box('Entry rug',(7.8,.045,7.3),(5.2,.04,2.6),'navy')
    text('Entry writing',(7.8,.07,7.3),'MERIDIAN / MAINTENANCE',.22,'ivory',(0,0,0))
    for x in [-10,-5,0,5,10]:
        for z in [5.1]:box('Floor pathway',(x,.038,z),(2.5,.014,.045),'amber',0)
    for x in [-11,11]:
        cyl('Fire extinguisher',(x,.65,6.2),.15,.76,'red')
        box('Extinguisher label',(x,.66,6.36),(.16,.24,.012),'paper')
    for j in range(10):
        xx=random.uniform(-6,3);zz=random.uniform(7,9)
        box('Rain puddle',(xx,.032,zz),(random.uniform(.3,1.5),.003,random.uniform(.2,.6)),'glass',.002)
    # Original distant Tallinn skyline silhouettes beyond the open wall.
    for j in range(13):
        x=-17+j*2.8;h=random.uniform(3,7)
        box('Distant building',(x,h/2,-17),(2.4,h,3),'navy',.02)
        for k in range(int(h)*2):
            for v in range(3):
                if random.random()<.5:box('City window',(x-.72+v*.7,.4+k*.43,-15.48),(.25,.22,.016),'amber',0)
    export('vault')

def character(name):
    reset();palette()
    is_ellis=name=='ellis';is_oleg=name=='oleg';skin='skin_ellis' if is_ellis else 'skin'
    root=bpy.data.objects.new('Character',None);bpy.context.collection.objects.link(root)
    def pivot(n,p):
        e=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(e);e.location=pos(p);e.parent=root;return e
    torso=pivot('Torso',(0,.96,0));head=pivot('Head',(0,1.5,0))
    cloth='purple' if is_ellis else 'navy' if is_oleg else 'blue'
    sphere('Jacket',(0,1.05,0),(.29,.38,.2),cloth,torso)
    box('Collar',(0,1.33,.04),(.32,.08,.26),'ivory' if not is_oleg else 'black',.03,torso)
    if not is_ellis:
        for xx in [-.14,.14]:box('Shirt pocket',(xx,1.12,.198),(.17,.16,.04),cloth,.015,torso)
        for yy in [.94,1.04,1.14,1.24]:sphere('Button',(0,yy,.218),(.014,.014,.008),'gold',torso)
        box('Belt',(0,.85,0),(.52,.085,.35),'black',.035,torso)
        box('Buckle',(0,.85,.185),(.095,.061,.014),'steel',.008,torso)
    if name=='steve':
        box('Name patch',(-.14,1.2,.224),(.19,.066,.012),'paper',.005,torso)
        for j in range(3):line('Belt screwdriver',(.24+j*.025,.85,.11),(.24+j*.025,.62,.11),.013,'chrome',torso)
        box('Tool pouch',(-.28,.76,0),(.1,.24,.17),'wood')
    sphere('Face',(0,1.59,.025),(.225,.267,.2),skin,head)
    sphere('Nose',(0,1.59,.231),(.055,.061,.07),skin,head)
    for x in [-.106,.106]:
        sphere('Ear',(x*2,1.6,.025),(.051,.08,.048),skin,head)
        sphere('Eye white',(x,1.67,.197),(.046,.032,.017),'white',head)
        sphere('Iris',(x,1.665,.213),(.021,.023,.009),'black',head)
        box('Eyebrow',(x,1.73,.199),(.091,.018,.016),'hair_ellis' if is_ellis else 'hair',.003,head)
    line('Mouth',(-.056,1.5,.213),(.056,1.5,.213),.012,'hair',head)
    sphere('Hair cap',(0,1.795,-.023),(.226,.107,.193),'hair_ellis' if is_ellis else 'hair',head)
    if is_ellis:
        sphere('Hair bun',(0,1.8,-.19),(.13,.14,.13),'hair_ellis',head)
        for x in [-.106,.106]:torus('Glasses',(x,1.67,.231),.064,.012,'gold',(math.pi/2,0,0),head)
        line('Bridge',(-.045,1.67,.232),(.045,1.67,.232),.009,'gold',head)
        for xx in [-.07,0,.07]:sphere('Pearl',(xx,1.37,.2),(.018,.02,.014),'white',torso)
        sphere('Skirt',(0,.72,0),(.34,.3,.235),'purple',torso)
    if is_oleg:
        for xx in [-.105,.105]:box('Dark glasses',(xx,1.67,.224),(.175,.075,.025),'black',.012,head)
        box('Tie',(0,1.18,.215),(.061,.21,.024),'black',.01,torso)
    for side,s in [('L',-1),('R',1)]:
        arm=pivot('Arm_'+side,(s*.3,1.26,0))
        sphere('Sleeve',(s*.35,1.06,0),(.105,.23,.11),cloth,arm)
        line('Forearm',(s*.36,.93,0),(s*.37,.77,.055),.073,skin,arm)
        sphere('Hand',(s*.37,.73,.055),(.082,.095,.06),skin,arm)
        leg=pivot('Leg_'+side,(s*.135,.72,0))
        line('Trousers',(s*.135,.73,0),(s*.14,.24,.012),.105,'navy' if is_oleg else 'blue' if not is_ellis else 'skin_ellis',leg)
        box('Shoe',(s*.14,.13,.075),(.23,.19,.36),'black',.075,leg)
        box('Shoe sole',(s*.14,.057,.075),(.24,.04,.37),'rubber',.015,leg)
    export(name,False)

def cat():
    reset();palette()
    sphere('Body',(0,.26,0),(.34,.25,.58),'fur')
    sphere('Head',(0,.46,.48),(.27,.25,.23),'fur')
    for x in [-.175,.175]:
        # Custom triangular ears.
        verts=[pos((x-.085,.6,.47)),pos((x+.085,.6,.47)),pos((x,.86,.43)),pos((x,.64,.29))]
        mesh=bpy.data.meshes.new('Ear');mesh.from_pydata(verts,[],[(0,1,2),(0,3,1),(0,2,3),(1,3,2)]);mesh.update()
        o=bpy.data.objects.new('Ear',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(M['fur'])
        sphere('Paw',(x,.075,.24),(.105,.07,.23),'ivory')
        sphere('Cheek',(x*.6,.39,.67),(.1,.068,.06),'ivory')
        sphere('Eye',(x*.7,.51,.673),(.055,.032,.018),'green')
        box('Pupil',(x*.7,.51,.689),(.008,.042,.006),'black',.002)
        for zz in [-.3,-.05,.17]:box('Tabby stripe',(x*1.86,.31,zz),(.012,.1,.06),'fur_dark')
        for j in range(3):line('Whisker',(x*.7,.39+j*.024,.699),(x*2.2,.36+j*.032,.65),.004,'ivory')
    sphere('Cat nose',(0,.411,.721),(.029,.022,.018),'brick')
    for i in range(9):
        a=i*.19; b=(i+1)*.19
        line('Tail',(.21+math.sin(a)*.24,.3+i*.026,-.46-math.cos(a)*.36),(.21+math.sin(b)*.24,.326+i*.026,-.46-math.cos(b)*.36),.065,'fur_dark' if i%3==0 else 'fur')
    export('bios')

shop();vault()
for n in ['steve','ellis','oleg']:character(n)
cat()
print('Original Blender assets complete')
