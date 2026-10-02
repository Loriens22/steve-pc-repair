"""Original, human-scale first-person environments and characters authored in Blender."""
import bpy,math,json,random,os
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models';T=ROOT/'assets/textures';B=ROOT/'blender'
OUT.mkdir(exist_ok=True);B.mkdir(exist_ok=True)
random.seed(1407);M={};CACHE={};COL=[]
FONT=bpy.data.fonts.load(str(ROOT/'assets/fonts/workshop.ttf'))
def p(v):return (v[0],-v[2],v[1])
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 M.clear();CACHE.clear();COL.clear()
 for m in list(bpy.data.materials):bpy.data.materials.remove(m)
def material(name,color=(1,1,1),rough=.6,metal=0,texture=None,emit=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 n=m.node_tree.nodes;l=m.node_tree.links;bs=n.get('Principled BSDF')
 bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 if texture:
  for suffix,slot in [('color','Base Color'),('rough','Roughness')]:
   im=bpy.data.images.load(str(T/(texture+'_'+suffix+'.png')),check_existing=True)
   if suffix=='rough':im.colorspace_settings.name='Non-Color'
   node=n.new('ShaderNodeTexImage');node.image=im;l.new(node.outputs['Color'],bs.inputs[slot])
  im=bpy.data.images.load(str(T/(texture+'_normal.png')),check_existing=True);im.colorspace_settings.name='Non-Color'
  node=n.new('ShaderNodeTexImage');node.image=im;normal=n.new('ShaderNodeNormalMap')
  normal.inputs['Strength'].default_value={'plastic':.11,'skin':.065,'ellis_skin':.065,'plaster':.20,'cloth':.23,'ellis_cloth':.23,'oak':.20,'steel':.10,'aluminium':.10,'enamel':.13,'concrete':.40,'asphalt':.33,'rubber':.15,'paper':.08,'pcb':.07}.get(texture,.18)
  l.new(node.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],bs.inputs['Normal'])
 if emit:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emit
 M[name]=m;return m
def palette():
 for name,tex,r,metal in [('wall','plaster',.9,0),('floor','vinyl',.6,0),('oak','oak',.5,0),('steel','steel',.3,.95),('aluminium','aluminium',.3,.92),('black','enamel',.4,.35),('plastic','plastic',.57,0),('concrete','concrete',.9,0),('asphalt','asphalt',.3,0),('rubber','rubber',.82,0),('cloth','cloth',.9,0),('ellis_cloth','ellis_cloth',.9,0),('skin','skin',.5,0),('ellis_skin','ellis_skin',.53,0),('paper','paper',.95,0),('pcb','pcb',.48,0)]:material(name,texture=tex,rough=r,metal=metal)
 for name,c,r,mt,e in [
  ('dark',(.008,.012,.014),.8,0,0),('glass',(.07,.095,.105),.065,.05,0),('car',(.12,.028,.024),.23,.55,0),
  ('ivory',(.76,.73,.63),.6,0,0),('white',(.73,.74,.71),.7,0,0),('copper',(.45,.21,.08),.34,.94,0),
  ('brass',(.40,.30,.12),.35,.9,0),('red',(.35,.014,.008),.45,.1,0),('blue',(.018,.075,.13),.5,.2,0),
  ('green',(.026,.17,.06),.75,0,0),('hair',(.032,.023,.018),.91,0,0),('gray_hair',(.39,.38,.35),.86,0,0),
  ('lip',(.39,.18,.145),.58,0,0),('eye',(.64,.65,.56),.14,0,0),('iris',(.12,.17,.11),.24,0,0),
  ('amber',(.9,.28,.028),.4,0,.7),('cyan',(.15,.45,.50),.4,0,.6),('led',(.13,.5,.24),.4,0,.7),
  ('alarm',(.7,.025,.006),.4,0,.9),('lamp',(.78,.68,.49),.4,0,1.6),('fur',(.43,.23,.10),.96,0,0),
  ('fur2',(.13,.075,.043),.99,0,0)]:material(name,c,r,mt,texture=None,emit=e)
 M['glass'].node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.22
 M['glass'].surface_render_method='DITHERED'
def world_matrix(o):
 local=Matrix.LocRotScale(o.location,o.rotation_euler.to_quaternion(),o.scale)
 return world_matrix(o.parent)@o.matrix_parent_inverse@local if o.parent else local
def reparent(o,parent):
 # Compute the transform explicitly: dependency graph updates are deferred for cached objects.
 mx=world_matrix(o);o.parent=parent;o.matrix_parent_inverse=Matrix.Identity(4)
 o.matrix_basis=world_matrix(parent).inverted()@mx
 return o
def group(name,at=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p(at)
 if parent:
  reparent(o,parent)
 return o
def assign(o,name,m,parent=None):
 o.name=name
 if not o.data.materials:o.data.materials.append(M[m])
 if parent:
  reparent(o,parent)
 return o
def uv_planar(o,scale=1):
 uv=o.data.uv_layers.active or o.data.uv_layers.new()
 for face in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(face.normal[i]));a,b=[i for i in range(3) if i!=axis]
  for li in face.loop_indices:
   co=o.data.vertices[o.data.loops[li].vertex_index].co
   uv.data[li].uv=(co[a]/scale,co[b]/scale)
def box(name,at,size,m='steel',bevel=.005,parent=None,collide=False,uvscale=.65):
 key=('box',tuple(round(v,4) for v in size),m,bevel,uvscale)
 if key in CACHE:
  o=bpy.data.objects.new(name,CACHE[key]);bpy.context.collection.objects.link(o);o.location=p(at)
 else:
  bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1])
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  if bevel:
   mod=o.modifiers.new('Physical edge radius','BEVEL');mod.width=min(bevel,min(size)*.23);mod.segments=3
   bpy.ops.object.modifier_apply(modifier=mod.name)
   for f in o.data.polygons:f.use_smooth=True
   mod=o.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
  uv_planar(o,uvscale);o.data.materials.append(M[m]);CACHE[key]=o.data
 assign(o,name,m,parent)
 if collide:COL.append({'p':list(at),'s':list(size)})
 return o
def ellipsoid(name,at,size,m,parent=None,segments=32):
 key=('sphere',segments,m)
 if key in CACHE:
  o=bpy.data.objects.new(name,CACHE[key]);bpy.context.collection.objects.link(o);o.location=p(at)
 else:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=max(16,segments//2),location=p(at));o=bpy.context.object
  for f in o.data.polygons:f.use_smooth=True
  o.data.materials.append(M[m]);CACHE[key]=o.data
 o.scale=(size[0],size[2],size[1]);return assign(o,name,m,parent)
def cylinder(name,at,r,depth,m='steel',axis='y',parent=None,vertices=24):
 key=('cyl',r,depth,m,vertices)
 if key in CACHE:
  o=bpy.data.objects.new(name,CACHE[key]);bpy.context.collection.objects.link(o);o.location=p(at)
 else:
  bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=p(at));o=bpy.context.object
  if r>.005:
   mod=o.modifiers.new('Turned rim','BEVEL');mod.width=min(.002,r*.10,depth*.18);mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
  for f in o.data.polygons:f.use_smooth=True
  o.data.materials.append(M[m]);CACHE[key]=o.data
 if axis=='z':o.rotation_euler.x=math.pi/2
 if axis=='x':o.rotation_euler.y=math.pi/2
 return assign(o,name,m,parent)
def cable(name,points,r=.006,m='rubber',parent=None):
 cv=bpy.data.curves.new(name,'CURVE');cv.dimensions='3D';cv.resolution_u=8;cv.bevel_depth=r;cv.bevel_resolution=2
 sp=cv.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for b,co in zip(sp.bezier_points,points):b.co=p(co);b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cv);bpy.context.collection.objects.link(o);cv.materials.append(M[m]);
 if parent:
  reparent(o,parent)
 return o
def text(name,at,words,size=.05,m='white',rotation=(math.pi/2,0,0),parent=None):
 cv=bpy.data.curves.new(name,'FONT');cv.body=words;cv.font=FONT;cv.size=size;cv.extrude=.00008;cv.align_x='CENTER'
 o=bpy.data.objects.new(name,cv);bpy.context.collection.objects.link(o);o.location=p(at);o.rotation_euler=rotation;cv.materials.append(M[m])
 if parent:
  reparent(o,parent)
 return o
def plate(name,at,size,image,rotation=None,parent=None):
 mn='plate_'+image
 if mn not in M:
  material(mn,rough=.74)
  n=M[mn].node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(T/(image+'.png')),check_existing=True)
  M[mn].node_tree.links.new(n.outputs['Color'],M[mn].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 bpy.ops.mesh.primitive_plane_add(size=1,location=p(at));o=bpy.context.object
 o.scale=(size[0],size[1],1);o.rotation_euler=rotation or (math.pi/2,0,0)
 return assign(o,name,mn,parent)
def screw(name,at,axis='z',r=.004,parent=None):
 o=cylinder(name,at,r,.003,'steel',axis,parent,vertices=12)
 if axis=='z':box('Machined slot',(at[0],at[1],at[2]+.002),(r*1.35,.0012,.001),'dark',0,o if name.startswith('DYN_') else parent)
 return o
def bench(x,z,w=2):
 box('Laminated worktop',(x,.94,z),(w,.045,.72),'oak',.008,collide=True)
 for xx in [-w/2+.08,w/2-.08]:
  box('Welded leg',(x+xx,.45,z),(.042,.88,.60),'steel',.003,collide=True)
  box('Rubber foot',(x+xx,.026,z),(.06,.04,.62),'rubber')
 box('Bench brace',(x,.30,z-.24),(w,.045,.035),'steel')
def keyboard(x,y,z):
 box('Keyboard shell',(x,y,z),(.44,.026,.145),'plastic',.007)
 for row in range(5):
  for j in range(15):
   if row==4 and 4<=j<=9:continue
   box('Key cap',(x-.197+j*.028,y+.020,z-.056+row*.027),(.024,.015,.023),'ivory',.003)
 box('Spacebar',(x-.015,y+.020,z+.052),(.161,.015,.022),'ivory',.003)
 cable('Keyboard cord',[(x+.16,y,z-.07),(x+.22,y-.02,z-.35),(x+.35,y-.04,z-.48)],.003)
def monitor(x,y,z,crt=False,name='SCREEN',image='archive'):
 if crt:
  box('Aged CRT cabinet',(x,y+.16,z-.07),(.365,.31,.35),'plastic',.022)
  box('CRT bezel',(x,y+.17,z+.115),(.335,.26,.015),'dark',.008)
  plate(name,(x,y+.18,z+.126),(.295,.218),image)
  for j in range(16):box('CRT ventilation',(x+.186,y+.08+j*.007,z-.1),(.004,.003,.12),'dark',0)
  cylinder('Power key',(x+.14,y+.045,z+.125),.007,.004,'plastic','z')
  box('CRT foot',(x,y-.016,z-.05),(.27,.036,.26),'plastic',.012)
  text('Original maker',(x,y+.035,z+.128),'WORKSHOP / 98',.014,'white')
 else:
  box('LCD frame',(x,y+.19,z),(.53,.33,.029),'black',.012)
  plate(name,(x,y+.19,z+.016),(.492,.289),image)
  box('Display arm',(x,y-.018,z-.015),(.032,.15,.023),'steel')
  box('Display foot',(x,y-.091,z),(.24,.012,.15),'black')
 keyboard(x,y-.025,z+.33)
def pc():
 x,y,z=-2.20,1.185,-3.0
 box('PC steel shell',(x,y,z),(.425,.43,.195),'plastic',.004)
 # The shell is hollow on the service side; the board sits in front of its dark interior.
 box('Chassis interior',(x,y,z+.106),(.398,.408,.006),'dark',.001)
 box('Mainboard',(x,y,z+.113),(.345,.342,.006),'pcb',.001)
 for dx,dy in [(-.17,-.17),(.17,-.17),(-.17,.17),(.17,.17)]:screw('Board standoff',(x+dx,y+dy,z+.119),r=.003)
 box('CPU ceramic',(x-.042,y+.026,z+.123),(.061,.061,.007),'ivory',.001)
 box('CPU heatsink',(x-.042,y+.026,z+.135),(.078,.071,.016),'aluminium',.001)
 for i in range(16):box('Heatsink fin',(x-.078+i*.0048,y+.026,z+.147),(.0013,.071,.014),'aluminium',.0002)
 for i in range(2):
  box('DIMM socket',(x+.106+i*.028,y+.04,z+.129),(.014,.16,.016),'dark',.001)
  box('RAM stick',(x+.106+i*.028,y+.04,z+.14),(.012,.149,.011),'pcb',.0005)
  for j in range(6):box('Memory IC',(x+.106+i*.028,y-.023+j*.024,z+.15),(.013,.014,.006),'dark',.001)
 for i in range(19):
  xx=x-.13+(i%6)*.042;yy=y-.13+(i//6)*.023
  cylinder('Electrolytic capacitor',(xx,yy,z+.133),.006,.025,'black','z',vertices=16)
  cylinder('Capacitor scored lid',(xx,yy,z+.147),.005,.002,'aluminium','z',vertices=12)
  box('Etched copper track',(xx,yy+.015,z+.118),(.026,.0009,.001),'copper',0)
 bx,by,bz=x-.10,y+.115,z+.130
 cylinder('CR2032 socket',(bx,by,bz),.0145,.008,'dark','z')
 cell=cylinder('DYN_OLD_CELL',(bx,by,bz+.006),.012,.003,'steel','z',vertices=32)
 text('Cell engraving',(bx,by,bz+.008),'CR2032',.005,'dark',parent=cell)
 box('DYN_CELL_CLIP',(bx+.013,by,bz+.006),(.005,.010,.004),'steel',.001)
 panel=box('DYN_PC_PANEL',(x,y,z+.166),(.425,.43,.0025),'plastic',.001)
 for row in range(11):
  for col in range(3):
   box('Stamped case vent',(x-.116+col*.081,y-.117+row*.009,z+.168),(.057,.0022,.0004),'dark',.0001,panel)
 text('Service tag',(x+.017,y+.137,z+.168),'ELLIS / RTC',.012,'dark',parent=panel)
 text('Legacy model plate',(x+.017,y+.114,z+.168),'AT-98 / SERVICE',.008,'dark',parent=panel)
 for yy in [y-.15,y+.05]:
  box('Case folded seam',(x,y+yy-y,z+.170),(.35,.0006,.0002),'ivory',0,panel)
 for i,(dx,dy) in enumerate([(-.187,-.184),(.187,-.184),(-.187,.184),(.187,.184)]):screw('DYN_PC_SCREW_'+str(i),(x+dx,y+dy,z+.176),r=.0045)
 # Visible connector and lead allow genuine power isolation before touching the board.
 box('DYN_PC_PLUG',(-2.84,1.02,-3.04),(.05,.025,.078),'rubber',.006)
 cable('Power lead',[(-2.85,1.0,-3.02),(-2.72,.99,-2.81),(-2.54,1.01,-2.8),(-2.43,1.04,-2.98)],.005)
 box('Bench PSU',(-3.06,1.07,-3.23),(.30,.19,.17),'black',.006)
 for j in range(3):cylinder('Bench jack',(-3.16+j*.063,1.06,-3.137),.009,.004,'red' if j==0 else 'dark','z')
 text('PSU label',(-3.06,1.12,-3.14),'MAINS / 230 V',.023,'paper')
 box('DYN_PC_TEST_PAD',(x+.08,y-.12,z+.121),(.025,.014,.006),'copper',.002)
 monitor(-1.29,.985,-3.10,True,'SHOP_CRT','bios_idle')
 plate('Battery worksheet',(-3.38,.968,-2.89),(.43,.28),'receipt',rotation=(0,0,.15))
def fluorescent(name,at,length=1.2):
 box('Lamp housing',at,(length,.055,.18),'steel',.01)
 for dz in [-.048,.048]:cylinder('Diffuser tube',(at[0],at[1]-.04,at[2]+dz),.014,length-.10,'lamp','x',vertices=16)
def chair(x,z):
 box('Seat frame',(x,.43,z),(.46,.025,.45),'steel')
 box('Seat upholstery',(x,.472,z),(.43,.085,.43),'cloth',.021)
 box('Chair back',(x,.74,z-.20),(.45,.49,.065),'cloth',.021)
 for dx in [-.205,.205]:
  for dz in [-.19,.19]:cylinder('Chair leg',(x+dx,.22,z+dz),.013,.43,'steel')
 COL.append({'p':[x,.46,z-.02],'s':[.47,.92,.49]})
def car(x,z):
 # Lofted body shell, a curved roof, modeled wheel tread and a visible interior.
 stations=[(-1.92,.68,.47),(-1.70,.80,.64),(-.70,.82,.70),(.72,.82,.73),(1.50,.80,.70),(1.91,.71,.53)]
 verts=[];faces=[]
 for zz,w,top in stations:
  for xx,yy in [(-w,.31),(-w,top-.08),(-w*.86,top),(w*.86,top),(w,top-.08),(w,.31)]:verts.append(p((x+xx,yy,z+zz)))
 for i in range(len(stations)-1):
  for k in range(6):faces.append((i*6+k,i*6+(k+1)%6,(i+1)*6+(k+1)%6,(i+1)*6+k))
 faces+=[tuple(range(5,-1,-1)),tuple(range(30,36))]
 mesh=bpy.data.meshes.new('Coachbuilt shell');mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new('Original compact car',mesh);bpy.context.collection.objects.link(o);assign(o,'Original compact car','car')
 mod=o.modifiers.new('Panel edge rounding','BEVEL');mod.width=.035;mod.segments=4
 box('Roof',(x,1.29,z+.12),(1.40,.09,1.51),'car',.04)
 box('Cabin black glass',(x,1.035,z+.16),(1.43,.43,1.56),'glass',.06)
 for dx in [-.74,.74]:
  for zz in [-.58,.88]:cable('Pillar',[(x+dx,.76,z+zz),(x+dx*.88,1.25,z+zz*.84)],.025,'car')
  box('Door crease',(x+dx*.99,.68,z+.12),(.012,.014,1.18),'dark',.002)
  box('Door handle',(x+dx*1.05,.89,z+.45),(.022,.028,.13),'black',.008)
  ellipsoid('Wing mirror',(x+dx*1.16,1.01,z-.61),(.09,.05,.12),'car')
 for dx in [-.8,.8]:
  for dz in [-1.22,1.21]:
   cylinder('Tyre',(x+dx,.33,z+dz),.285,.185,'rubber','x',vertices=48)
   cylinder('Wheel hub',(x+dx*1.12,.33,z+dz),.194,.02,'aluminium','x',vertices=32)
   for k in range(32):
    a=k*math.tau/32
    box('Tread block',(x+dx,.33+math.cos(a)*.285,z+dz+math.sin(a)*.285),(.185,.026,.040),'rubber',.002).rotation_euler.x=-a
   for k in range(6):
    a=k*math.tau/6;cylinder('Lug nut',(x+dx*1.14,.33+math.cos(a)*.074,z+dz+math.sin(a)*.074),.010,.016,'steel','x',vertices=6)
 for dx in [-.54,.54]:
  box('Headlight',(x+dx,.63,z-1.82),(.31,.16,.048),'white',.025)
  box('Tail light',(x+dx,.65,z+1.87),(.25,.15,.022),'red',.012)
 box('Bumper',(x,.36,z-1.92),(1.49,.12,.04),'black',.02)
 text('Registration',(x,.44,z-1.95),'ELL 1933',.045,'paper',rotation=(math.pi/2,0,math.pi))
def shop():
 reset();palette()
 box('Floor slab',(0,-.11,0),(10.6,.22,8.6),'concrete',.01,collide=True)
 box('Cleaned vinyl',(0,-.005,0),(10.35,.022,8.35),'floor',.002,uvscale=.6)
 box('Back wall',(0,1.58,-4.25),(10.6,3.16,.16),'wall',.005,collide=True)
 box('Left wall',(-5.25,1.58,0),(.16,3.16,8.5),'wall',.005,collide=True)
 box('Right wall',(5.25,1.58,0),(.16,3.16,8.5),'wall',.005,collide=True)
 # Front glazing and a real opening, rather than a cutaway diorama.
 box('Front left pier',(-4.64,1.58,4.25),(1.25,3.16,.16),'wall',collide=True)
 box('Front right pier',(4.65,1.58,4.25),(1.2,3.16,.16),'wall',collide=True)
 box('Front header',(0,2.87,4.25),(8.1,.60,.16),'wall',collide=True)
 for xx,w in [(-1.95,4.1),(1.38,1.48)]:
  box('Glazing sill',(xx,.43,4.25),(w,.86,.16),'wall',collide=True)
  box('Window pane',(xx,1.70,4.27),(w,1.69,.012),'glass',.001,collide=True)
  for dx in [-w*.5,w*.5]:box('Window mullion',(xx+dx,1.72,4.245),(.035,1.79,.045),'aluminium')
 box('Door hinge jamb',(2.12,1.3,4.22),(.04,2.6,.055),'aluminium')
 box('Door latch jamb',(3.4,1.3,4.22),(.04,2.6,.055),'aluminium')
 door=group('DYN_SHOP_DOOR',(2.15,0,4.20))
 box('Door lower rail',(2.78,.30,4.20),(1.22,.60,.035),'black',parent=door)
 box('Door glazing',(2.78,1.57,4.20),(1.20,1.91,.016),'glass',parent=door)
 box('Pull handle',(3.24,1.03,4.12),(.016,.29,.025),'steel',parent=door)
 for z in [-4.13,4.13]:box('Skirting',(0,.072,z),(10.45,.14,.035),'oak',.004)
 for x in [-5.13,5.13]:box('Skirting',(x,.072,0),(.035,.14,8.35),'oak',.004)
 box('Ceiling',(0,3.17,0),(10.6,.08,8.6),'wall',.002)
 for x in [-3.4,0,3.4]:
  for z in [-2.4,1.2]:fluorescent('Bench light',(x,3.07,z))
 bench(-2.15,-3.11,4.9);pc()
 bench(3.52,-3.35,2.5)
 monitor(3.70,1.05,-3.45,False,'WORKSHOP_LCD','bios_fixed')
 box('Coffee machine',(2.73,1.18,-3.40),(.25,.43,.30),'black',.017)
 cylinder('Coffee mug',(2.76,1.01,-3.23),.038,.081,'ivory',vertices=32)
 cable('Mug handle',[(2.798,1.066,-3.23),(2.83,1.045,-3.23),(2.798,1.025,-3.23)],.005,'ivory')
 cylinder('Coffee',(2.76,1.054,-3.23),.031,.001,'dark',vertices=32)
 box('ESD bench mat',(-2.2,.969,-3.01),(1.55,.009,.64),'blue',.007)
 cable('Ground wrist lead',[(-2.75,1.0,-2.77),(-2.95,1.00,-2.97),(-2.79,.98,-3.35)],.002,'copper')
 box('Solder station',(-4.01,1.075,-3.33),(.20,.20,.17),'black',.012)
 cable('Iron lead',[(-4.00,1.02,-3.23),(-3.91,.98,-2.86),(-3.60,.98,-3.01)],.003)
 cylinder('Solder reel',(-3.6,1.011,-3.19),.043,.06,'copper','x',vertices=32)
 box('Pegboard',(-2.20,2.12,-4.12),(4.7,1.17,.025),'oak',.002)
 for i in range(18):
  for j in range(5):cylinder('Drilled peg hole',(-4.40+i*.25,1.70+j*.19,-4.1),.0038,.002,'dark','z',vertices=8)
 for i in range(10):
  xx=-4.12+i*.39
  cylinder('Driver grip',(xx,1.89,-4.01),.015,.12,'rubber',vertices=16)
  cylinder('Driver shaft',(xx,2.03,-4.01),.0035,.18,'steel',vertices=12)
  box('Hanging tool clip',(xx,2.11,-4.025),(.032,.018,.02),'steel')
 text('Bench ethic',(-1.9,2.98,-4.13),'STEVE / EVERYTHING HAS A FIX',.12,'dark')
 box('Customer counter',(.65,.48,.0),(3.9,.96,.60),'oak',.006,collide=True)
 box('Counter stone',(.65,.995,.0),(4.02,.065,.74),'concrete',.014)
 for j in range(36):box('Counter grain batten',(-1.17+j*.105,.49,.312),(.018,.89,.012),'oak',.002)
 plate('Fair price receipt',(.17,1.031,.09),(.27,.19),'receipt',rotation=(0,0,-.13))
 case=group('DYN_BRIEFCASE',(-.37,1.10,-.02))
 box('Case lower',(-.37,1.077,-.02),(.43,.075,.31),'black',.02,parent=case)
 lid=group('DYN_CASE_LID',(-.37,1.11,-.175),case)
 box('Case lid',(-.37,1.135,-.02),(.43,.05,.31),'black',.014,parent=lid)
 for xx in [-.52,-.22]:box('Case latch',(xx,1.11,.145),(.04,.031,.012),'steel',.004,parent=case)
 box('Encrypted phone',(-.40,1.12,-.02),(.07,.009,.137),'black',.008,parent=case)
 box('Phone screen',(-.40,1.127,-.02),(.062,.002,.113),'cyan',.004,parent=case)
 box('First class ticket',(-.26,1.12,-.02),(.115,.003,.14),'paper',.001,parent=case)
 text('Ticket face',(-.26,1.123,-.02),'TALLINN\nFIRST CLASS',.014,'dark',rotation=(0,0,0),parent=case)
 text('Oleg transfer',(-.37,1.103,.162),'PAID IN FULL',.017,'paper',parent=case)
 for zz in [-1.1,0,1.1]:
  for yy in [.23,.84,1.48,2.12]:box('Repair shelving',(-4.85,yy,zz),(.52,.038,1.05),'steel')
  for k in range(3):
   box('Customer PC',(-4.80,.49,zz-.32+k*.30),(.36,.46,.24),'plastic',.01)
   box('Drive bay',(-4.61,.57,zz-.32+k*.30),(.003,.026,.14),'dark',.001)
   for yy in [.94,1.57,2.2]:box('Labeled repair box',(-4.79,yy,zz-.31+k*.31),(.36,.14,.28),'paper',.004)
 text('No overcharging',(-4.565,2.48,.0),'PEOPLE BEFORE PARTS',.08,'dark',rotation=(math.pi/2,0,math.pi/2))
 for x in [-.4,.4,1.2]:chair(x,3.23)
 bench(-2.70,2.85,1.0)
 box('BYTE magazine',(-2.70,.977,2.83),(.21,.006,.285),'paper',.001)
 text('BYTE cover',(-2.70,.982,2.88),'BYTE / 1998',.031,'dark',rotation=(0,0,0))
 ellipsoid('Cat basket',(-3.48,.08,1.62),(.47,.10,.34),'cloth')
 cylinder('Cat dish',(-3.02,.033,1.57),.077,.035,'steel',vertices=32)
 box('Calendar',(4.65,1.78,-4.14),(.34,.46,.008),'paper',.001)
 text('Calendar note',(4.65,1.89,-4.126),'OCT / 2026',.028,'dark')
 text('Thursday',(4.65,1.75,-4.125),'THURSDAY',.036,'red')
 text('Calendar cat',(4.65,1.61,-4.125),'FEED BIOS',.027,'dark')
 box('Porch slab',(1.4,-.075,5.8),(12,.15,3.15),'concrete',.008,collide=True)
 box('Parking',(0,-.15,10),(28,.2,9),'asphalt',.01,collide=True)
 for xx in [-7,-3,1,5,9]:box('Parking line',(xx,-.044,9.3),(.10,.002,4.8),'ivory',0)
 car(4.1,8.65)
 for xx in [-8.3,8.3]:
  box('Office park unit',(xx,2.4,11),(5,4.8,8),'concrete',.015)
  for zz in [8,10,12]:box('Office glazing',(xx-(2.51 if xx>0 else -2.51),2,zz),(.008,1.9,1.4),'glass')
 text('Original shop name',(-1.5,2.9,4.35),'STEVE\'S / PC REPAIR',.20,'paper',rotation=(math.pi/2,0,math.pi))
 export('shop')

def export(name,merge=True):
 # Convert curves, preserve moving parts, and combine static surfaces by material.
 for o in list(bpy.context.scene.objects):
  if o.type in ['FONT','CURVE']:
   bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
 if merge:
  groups={}
  for o in bpy.context.scene.objects:
   if o.type=='MESH' and not o.name.startswith('DYN_') and not ('SCREEN' in o.name or o.name in ['SHOP_CRT','WORKSHOP_LCD']):
    chunk=''
    if name in ['shop','facility'] and not o.parent:
     pos=world_matrix(o).translation;chunk='_zone_%d_%d'%(math.floor(pos.x/6),math.floor(pos.y/6))
    key=(o.parent.name if o.parent else '',(o.data.materials[0].name if o.data.materials else '')+chunk)
    groups.setdefault(key,[]).append(o)
  for key,obs in groups.items():
   if len(obs)>1:
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    # A shared primitive must become single-user before joining. Otherwise a joined
    # zone mutates the cached mesh still used by other zones and moving components.
    obs[0].data=obs[0].data.copy()
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=(key[0]+'_' if key[0] else 'STATIC_')+key[1]
 for im in bpy.data.images:
  if im.source=='FILE':
   try:im.pack()
   except Exception:pass
 bpy.ops.wm.save_as_mainfile(filepath=str(B/(name+'.blend')),compress=True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
 (OUT/(name+'_collision.json')).write_text(json.dumps(COL,separators=(',',':')))
 print('CREATED',name,len(bpy.context.scene.objects),'nodes',flush=True)

def wall(name,at,size):return box(name,at,size,'concrete',.005,collide=True,uvscale=2)
def doorway(name,x,z,axis='z',width=1.25,height=2.25,length=4):
 if axis=='z':
  for dx in [-1,1]:wall(name+' pier',(x+dx*(width+(length-width)/2)/2,1.82,z),((length-width)/2,3.64,.16))
  wall(name+' lintel',(x,(height+3.64)/2,z),(width,3.64-height,.16))
 else:
  for dz in [-1,1]:wall(name+' pier',(x,1.82,z+dz*(width+(length-width)/2)/2),(.16,3.64,(length-width)/2))
  wall(name+' lintel',(x,(height+3.64)/2,z),(.16,3.64-height,width))
def steeldoor(name,at,axis='z',w=1.17,h=2.20):
 g=group(name,at)
 if axis=='z':
  box('Steel door leaf',(at[0],at[1]+h/2,at[2]),(w,h,.055),'black',.004,parent=g)
  box('Kickplate',(at[0],at[1]+.22,at[2]+.031),(w-.05,.35,.008),'steel',.002,parent=g)
  box('Door handle',(at[0]+w*.35,at[1]+1.03,at[2]+.082),(.13,.019,.04),'steel',.006,parent=g)
 else:
  box('Steel door leaf',(at[0],at[1]+h/2,at[2]),(.055,h,w),'black',.004,parent=g)
  box('Kickplate',(at[0]+.031,at[1]+.22,at[2]),(.008,.35,w-.05),'steel',.002,parent=g)
  box('Door handle',(at[0]+.07,at[1]+1.03,at[2]+w*.35),(.04,.019,.13),'steel',.006,parent=g)
 return g
def rack(x,z,index):
 box('Server cabinet',(x,1.04,z),(.605,2.08,1.03),'black',.008,collide=True)
 box('Rear grating',(x,1.04,z-.525),(.548,1.96,.008),'dark',.002)
 for dx in [-.272,.272]:
  box('Rack rail',(x+dx,1.06,z+.53),(.025,1.95,.025),'steel',.002)
  for k in range(36):cylinder('Rack bolt',(x+dx,.16+k*.050,z+.549),.0038,.004,'steel','z',vertices=8)
 for j in range(12):
  yy=.17+j*.146
  box('Two-U server',(x,yy,z+.53),(.526,.118,.018),'steel',.004)
  for dx in [-.224,.224]:box('Rack handle',(x+dx,yy,z+.556),(.025,.072,.025),'black',.008)
  for k in range(4):
   box('Hot-swap caddy',(x-.158+k*.089,yy+.008,z+.546),(.077,.063,.013),'black',.002)
   for v in range(4):box('Disk vent',(x-.158+k*.089,yy-.02+v*.012,z+.557),(.053,.003,.001),'dark',0)
   cylinder('Disk activity',(x-.180+k*.089,yy+.043,z+.559),.0015,.001,'led','z',vertices=8)
  text('Rack unit tag',(x+.182,yy-.028,z+.558),'M'+str(index).zfill(2),.018,'white')
 for k in range(3):cable('Network loom',[(x+.32,2.10,z-.30),(x+.33,2.35,z-.20),(x+.36,2.65,z+.24),(x+.37,2.65,z+1.3)],.007,'blue')
def breaker():
 x,y,z=-8.05,1.40,-18.00
 box('Electrical cabinet',(x,y,z),(.95,1.34,.18),'black',.008,collide=True)
 box('Insulated backplane',(x,y,z+.099),(.87,1.24,.006),'ivory',.003)
 for i in range(6):
  xx=x-.33+(i%3)*.33;yy=y+.39-(i//3)*.60
  box('DIN relay',(xx,yy,z+.13),(.21,.24,.065),'plastic',.003)
  box('DYN_BREAKER_'+str(i),(xx,yy-.027,z+.177),(.057,.070,.025),'black',.005)
  text('Bus stencil',(xx,yy+.11,z+.167),['A1 / UPS A','B2 / PUMP','C3 / OPTICS','D4 / LOCKS','E5 / LEAK','F6 / FIRE'][i],.022,'dark')
  for k in [-.07,.07]:
   screw('Terminal screw',(xx+k,yy-.094,z+.170),r=.003)
   cable('Insulated feed',[(xx+k,yy-.10,z+.165),(xx+k,yy-.28,z+.15),(xx+k+.03,yy-.29,z+.14)],.003,'copper' if i==2 else 'rubber')
 text('Cabinet safety',(x,y+.73,z+.13),'LOW VOLTAGE / AUTHORISED SERVICE',.027,'paper')
 for i in range(4):
  xx=x-.30+i*.20
  cylinder('DYN_PROBE_'+str(i),(xx,y-.49,z+.159),.016,.008,'red' if i==1 else 'dark','z',vertices=20)
  text('Probe label',(xx,y-.54,z+.169),str(i+6).zfill(2),.026,'dark')
 box('DYN_LOOP_BRIDGE',(x+.25,y-.14,z+.21),(.047,.045,.061),'blue',.003)
 cylinder('DYN_DIAG_LED',(x+.37,y-.14,z+.223),.008,.004,'led','z')
 plate('Original work order',(-6.67,1.53,-18.089),(.55,.30),'work_order')
 # A separate fused pump service tray has physically labelled, different ratings.
 box('Service cart',(-5.83,.75,-15.69),(1.18,.058,.56),'steel',.003,collide=True)
 for xx in [-6.27,-5.39]:cylinder('Cart upright',(xx,.38,-15.69),.02,.72,'steel')
 for i,rating in enumerate(['T2A','T6.3A','T10A']):
  xx=-6.14+i*.31
  cylinder('DYN_SPARE_FUSE_'+str(i),(xx,.81,-15.66),.011,.067,'glass','x',vertices=20)
  for dx in [-.037,.037]:cylinder('Fuse cap',(xx+dx,.81,-15.66),.012,.013,'steel','x')
  text('Fuse rating',(xx,.784,-15.54),rating,.027,'dark',rotation=(0,0,0))
 box('Service tag',(-5.83,.79,-15.86),(.91,.007,.15),'paper',.001)
 text('Service tag words',(-5.83,.796,-15.89),'SELECT THE CORRECT SLOW-BLOW FUSE',.019,'dark',rotation=(0,0,0))
def cooling():
 # All service controls face the centre aisle and remain separately animatable.
 x,z=8.67,-4.30
 box('Chiller enclosure',(x,.60,z),(1.26,1.19,.82),'black',.007,collide=True)
 for j in range(18):box('Heat exchanger fin',(x-.50+j*.057,.63,z+.43),(.018,.9,.025),'aluminium',.001)
 for xx in [7.74,8.44,9.14]:
  cable('Insulated pipe',[(xx,.20,-5.5),(xx,.20,-4.6),(xx,1.02,-4.37),(xx,1.02,-3.76),(xx,1.65,-3.10)],.035,'rubber')
  cylinder('Brass valve body',(xx,1.02,-3.76),.036,.12,'brass','z',vertices=32)
  cylinder('Valve stem',(xx,1.02,-3.66),.006,.09,'steel','z')
  root=group('DYN_VALVE_'+str([7.74,8.44,9.14].index(xx)),(xx,1.02,-3.615))
  # A cast handwheel with open spokes rather than a flat UI control.
  cable('Wheel rim',[(xx+.09*math.cos(a),1.02+.09*math.sin(a),-3.61) for a in [k*math.tau/16 for k in range(17)]],.009,'blue',root)
  for a in [0,math.tau/3,math.tau*2/3]:cable('Valve spoke',[(xx,1.02,-3.61),(xx+.083*math.cos(a),1.02+.083*math.sin(a),-3.61)],.005,'blue',root)
  text('Valve label',(xx,1.21,-3.61),['SUPPLY','RETURN','BYPASS'][[7.74,8.44,9.14].index(xx)],.035,'paper')
 for xx,label in [(7.75,'kPa'),(8.46,'C')]:
  cylinder('Gauge body',(xx,1.62,-3.75),.087,.052,'steel','z',vertices=48)
  cylinder('Gauge face',(xx,1.62,-3.718),.074,.002,'paper','z',vertices=48)
  for k in range(11):
   a=(-135+k*27)*math.pi/180
   cable('Gauge graduation',[(xx+math.sin(a)*.054,1.62+math.cos(a)*.054,-3.712),(xx+math.sin(a)*.066,1.62+math.cos(a)*.066,-3.712)],.0009,'dark')
  n=group('DYN_GAUGE_'+label,(xx,1.62,-3.706))
  box('Gauge needle',(xx,1.65,-3.706),(.002,.064,.003),'red',.0004,parent=n)
  text('Gauge unit',(xx,1.592,-3.702),label,.027,'dark')
 box('Pump control',(6.26,1.26,-6.82),(.40,.55,.13),'steel',.005)
 box('DYN_PUMP_SWITCH',(6.16,1.35,-6.731),(.074,.071,.03),'black',.007)
 box('DYN_PUMP_FUSE',(6.34,1.13,-6.731),(.069,.14,.025),'dark',.003)
 text('Pump fuse label',(6.26,1.53,-6.731),'230 V / 6.3 A',.032,'paper')
 plate('Cooling protocol',(8.75,2.45,-6.903),(.73,.37),'coolant_note')
 box('Coolant diagnostic screen',(7.37,2.02,-6.85),(.64,.39,.032),'black',.006)
 plate('COOLANT_SCREEN',(7.37,2.02,-6.831),(.593,.341),'coolant_note')
def core():
 x,z=.15,-23.78
 box('HSM rack',(x,1.03,z),(.82,2.07,.96),'black',.007,collide=True)
 for xx in [-.34,.64]:cylinder('Vault bolted rail',(xx,1.02,z+.505),.012,1.92,'steel')
 box('HSM module',(x,1.28,z+.53),(.64,.31,.062),'steel',.008)
 box('Tamper panel back',(x,1.28,z+.566),(.51,.24,.008),'dark',.001)
 box('Secure memory board',(x,1.28,z+.576),(.47,.21,.007),'pcb',.001)
 for i in range(9):box('Secure controller IC',(x-.19+(i%5)*.073,1.21+(i//5)*.10,z+.59),(.054,.041,.011),'dark',.002)
 cylinder('DYN_KEY_CELL',(x+.149,1.315,z+.600),.016,.004,'steel','z',vertices=40)
 text('Root battery',(x+.149,1.315,z+.603),'+ 3V',.008,'dark')
 panel=box('DYN_KEY_PANEL',(x,1.28,z+.633),(.63,.30,.012),'steel',.004)
 for i,xx in enumerate([x-.28,x+.28]):screw('DYN_KEY_SCREW_'+str(i),(xx,1.28,z+.643),r=.0047)
 text('Tamper legend',(x,1.28,z+.642),'WIDOWMAKER / HSM',.041,'dark',parent=panel)
 for i in range(2):
  xx=-2.1+i*.48
  box('UPS isolator',(xx,1.40,-24.02),(.30,.45,.12),'steel',.003)
  box('DYN_UPS_'+str(i),(xx,1.40,-23.94),(.072,.10,.04),'red',.005)
  text('UPS supply',(xx,1.58,-23.947),'SUPPLY '+['A','B'][i],.03,'paper')
 monitor(1.77,1.38,-24.45,False,'KEY_SCREEN','key_console')
 text('Asset plaque',(.18,2.23,-23.25),'WIDOWMAKER',.10,'paper')
def facility():
 reset();palette()
 box('Facility foundation',(-.5,-.11,-8),(25,.22,37),'concrete',.01,collide=True,uvscale=3)
 box('Wet loading alley',(-7,.012,6.2),(10,.018,9.0),'asphalt',.001,uvscale=3)
 for i in range(8):box('Drainage grate',(-4.15,.025,2.85+i*.6),(.40,.012,.45),'steel',.003)
 for xx in [-10.6,10.6]:wall('Exterior perimeter',(xx,1.82,-11.7),(.22,3.64,28.8))
 wall('Back perimeter',(0,1.82,-26.2),(21.2,3.64,.22))
 doorway('Service entrance',-7.85,2.20,'z',1.3,2.28,5.5)
 wall('Front machine-room wall',(2.05,1.82,2.20),(15.1,3.64,.22))
 steeldoor('DYN_ENTRY_DOOR',(-7.85,0,2.20))
 box('Badge reader',(-6.99,1.31,2.33),(.15,.21,.055),'black',.009)
 cylinder('DYN_BADGE_LED',(-6.99,1.36,2.36),.011,.004,'alarm','z')
 text('Service signage',(-7.85,2.59,2.33),'MERIDIAN / NIGHT SERVICE',.075,'paper')
 doorway('Hall partition',-4.76,-5.05,'x',1.35,2.3,14.5)
 steeldoor('DYN_HALL_DOOR',(-4.76,0,-5.05),'x',1.25)
 wall('Hall west north',(-4.76,1.82,-19.13),(.16,3.64,13.95))
 doorway('Power room front',-7.63,-12.3,'z',1.35,2.26,5.72)
 doorway('Ladder bay doorway',-8.82,-18.18,'z',1.22,2.28,3.55)
 wall('Power back east',(-5.42,1.82,-18.18),(1.27,3.64,.16))
 doorway('Cold bay partition',4.72,-3.2,'x',1.30,2.3,7.7)
 wall('Cooling room back',(7.61,1.82,-6.99),(5.73,3.64,.16))
 doorway('Archive partition',4.72,-14.63,'x',1.28,2.3,7.2)
 wall('Archive end',(7.63,1.82,-18.18),(5.75,3.64,.16))
 wall('Archive front',(7.63,1.82,-11.03),(5.75,3.64,.16))
 doorway('Vault interlock',-.24,-19.05,'z',1.44,2.5,9.0)
 steeldoor('DYN_CORE_DOOR',(-.24,0,-19.05),'z',1.36,2.42)
 text('Core interlock',(-.22,2.77,-18.947),'ROOT MEMORY / THERMAL INTERLOCK',.059,'paper')
 cylinder('DYN_CORE_LED',(.74,1.54,-18.93),.018,.008,'alarm','z')
 # Roof slabs form a real ladder aperture in the west maintenance bay.
 box('Roof east slab',(.16,3.89,-17.64),(16.68,.22,17.4),'concrete',.01,collide=True,uvscale=3)
 box('Roof west slab',(-10.09,3.89,-17.64),(1.0,.22,17.4),'concrete',.01,collide=True)
 box('Roof ladder north',(-8.88,3.89,-23.70),(1.40,.22,5.5),'concrete',.01,collide=True)
 box('Roof ladder south',(-8.88,3.89,-14.43),(1.40,.22,10.16),'concrete',.01,collide=True)
 # Roof surface continues over the front rooms; ceiling fixtures give local, plausible light.
 box('Front ceiling',(0,3.83,-3.40),(21.2,.18,11.0),'concrete',.008,collide=True,uvscale=3)
 for x,z in [(-7.7,-1),(-7.7,-8),(-7.7,-15.5),(-1.5,-2),(-1.5,-9),(2.8,-15),(7.0,-2.8),(7.0,-15.5),(.0,-21.3)]:fluorescent('Vault luminaire',(x,3.54,z),1.15)
 for x in [-2.84,-.08,2.68]:
  for z in [-6.42,-11.64]:rack(x,z,round(z*-2+x))
 for z in [-3.6,-8.5,-13.4]:
  cable('Cable tray left',[(-3.86,2.9,z),(3.9,2.9,z)],.034,'black')
  for zz in [z-.14,z+.14]:box('Tray flange',(0,2.87,zz),(8.0,.045,.018),'steel')
  for x in [-3.5,-2.3,-1.1,.1,1.3,2.5,3.7]:box('Tray crossbar',(x,2.88,z),(.035,.03,.35),'steel')
 for x,z in [(-8.77,-4.3),(-5.6,-9),(-3.68,-15.8),(3.83,-1.1)]:
  box('Shipping crate',(x,.52,z),(.75,1.04,.70),'oak',.005,collide=True)
  for xx in [-.31,.31]:box('Crate steel band',(x+xx,.52,z),(.035,1.05,.71),'steel',.001)
 for i in range(3):
  xx=-9.80+i*.13
  cable('Service conduit',[(xx,.11,1.9),(xx,2.84,1.7),(xx,2.90,-18.0)],.023,'steel')
 breaker();cooling();core()
 bench(7.90,-16.97,3.32)
 monitor(7.71,1.05,-17.17,False,'ARCHIVE_SCREEN','archive')
 box('DYN_ARCHIVE_USB',(7.995,1.012,-16.89),(.075,.018,.030),'steel',.003)
 g=group('DYN_EVIDENCE_DRIVE',(7.995,1.028,-16.849))
 box('Evidence drive enclosure',(7.995,1.028,-16.818),(.037,.015,.067),'black',.004,g)
 text('Drive label',(7.995,1.037,-16.818),'AES',.011,'steel',rotation=(0,0,0),parent=g)
 box('Archive file drawer',(6.65,.62,-17.45),(.43,1.23,.45),'steel',.006,collide=True)
 for i in range(5):
  box('Drawer front',(6.65,.15+i*.235,-17.207),(.394,.218,.010),'steel',.001)
  box('File pull',(6.65,.15+i*.235,-17.187),(.15,.017,.017),'dark',.003)
  text('File index',(6.65,.225+i*.235,-17.191),'M'+str(i+5).zfill(2),.019,'dark')
 chair(7.74,-15.96)
 # Original easter eggs reward a technician's curiosity.
 text('Server serial',(-3.99,1.2,-9.0),'SN: ELL-1933-THU',.029,'paper',rotation=(math.pi/2,0,math.pi/2))
 text('Maintenance joke',(-7.55,1.75,-11.98),'HAVE YOU TRIED UNPLUGGING THE OLIGARCH?',.029,'paper')
 box('M07 archive letter',(8.39,.982,-16.79),(.23,.005,.30),'paper',.001)
 text('Ellis file title',(8.39,.986,-16.81),'ELLIS / 07',.030,'dark',rotation=(0,0,0))
 # Ladder through the roof hatch, with both side rails and collision-safe rungs.
 for xx in [-9.23,-8.71]:cylinder('Roof ladder rail',(xx,2.1,-19.94),.025,4.20,'steel')
 for i in range(15):cylinder('Ladder rung',(-8.97,.24+i*.278,-19.925),.016,.55,'steel','x')
 text('Roof escape',(-8.97,2.13,-20.01),'ROOF ACCESS',.053,'paper')
 for x in [-10.57,8.48]:
  for z in [-9.1,-26.25]:cylinder('Roof post',(x,4.55,z),.021,1.15,'steel')
  cable('Roof top rail',[(x,5.06,-9.1),(x,5.06,-26.25)],.021,'steel')
  box('Roof rail barrier',(x,4.55,-17.68),(.035,1.14,17.2),'steel',.005,collide=True)
 for z in [-9.1,-26.25]:box('Roof end barrier',(-1.04,4.55,z),(19.05,1.14,.035),'steel',.005,collide=True)
 for x,z in [(-6.3,-15.7),(-3.0,-21.6),(2.6,-12.7)]:
  box('Roof HVAC',(x,4.57,z),(1.62,1.15,1.55),'black',.012,collide=True)
  for k in range(17):box('HVAC slat',(x,4.15+k*.049,z+.788),(1.38,.012,.022),'aluminium',.001)
  cylinder('Exhaust fan shroud',(x,5.18,z),.43,.12,'steel',vertices=48)
  for k in range(4):
   a=k*math.tau/4;box('Fan blade',(x+.14*math.cos(a),5.25,z+.14*math.sin(a)),(.28,.009,.055),'dark',.004).rotation_euler.z=a
 cylinder('Extraction stanchion',(-9.82,4.42,-10.07),.039,.84,'steel')
 box('Stanchion anchor',(-9.82,4.03,-10.07),(.19,.04,.19),'steel',.005)
 box('Extraction control',(-9.82,4.99,-10.07),(.24,.29,.05),'black',.009)
 cylinder('Extraction button',(-9.82,4.99,-10.037),.034,.012,'green','z')
 text('Extraction plaque',(-9.82,5.19,-10.030),'SERVICE EXIT',.034,'paper')
 # Procedural skyline and illuminated windows, all authored here.
 for i in range(17):
  xx=-28+i*3.9;zz=-35-random.uniform(0,13);h=random.uniform(7,18);w=random.uniform(2.9,4.4)
  box('Tallinn office skyline',(xx,h/2-.3,zz),(w,h,random.uniform(3,6)),'black',.02)
  for yy in range(2,int(h),2):
   for dx in [-.7,.7]:
    if random.random()<.48:box('Office window',(xx+dx,yy,zz+3.01),(.63,1.03,.010),'lamp',.001)
 export('facility')

def loft(name,sections,m,parent=None,fold=.0):
 vertices=[];faces=[];uv=[];n=32
 for j,(cy,cx,cz,rx,rz) in enumerate(sections):
  for k in range(n):
   a=k*math.tau/n;f=fold*math.sin(a*7+j*2.9)*math.sin(math.pi*j/max(1,len(sections)-1))
   vertices.append(p((cx+(rx+f)*math.cos(a),cy,cz+(rz+f)*math.sin(a))));uv.append((k/n,j/max(1,len(sections)-1)))
 for j in range(len(sections)-1):
  for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 faces.extend([tuple(range(n-1,-1,-1)),tuple(range((len(sections)-1)*n,len(sections)*n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();layer=mesh.uv_layers.new()
 for f in mesh.polygons:
  f.use_smooth=True
  for li in f.loop_indices:layer.data[li].uv=uv[mesh.loops[li].vertex_index]
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return assign(o,name,m,parent)
def hand(name,at,parent,glove=False,scale=1):
 m='rubber' if glove else 'skin';x,y,z=at
 g=group(name,at,parent)
 if glove:
  ellipsoid('Gloved palm',(x+.043,y+.018,z+.014),(.030,.044,.022),m,g,40)
  ellipsoid('Glove wrist',(x+.052,y-.033,z+.049),(.024,.032,.038),m,g,32)
  for i in range(4):
   yy=y-.012+i*.018
   cable('Curled finger',[(x+.035,yy,z+.029),(x+.004,yy,z+.037),(x-.017,yy,z+.013),(x-.011,yy,z-.017),(x+.010,yy,z-.018)],.0075,m,g)
   ellipsoid('Glove knuckle',(x+.028,yy,z+.028),(.010,.010,.009),m,g,24)
  cable('Opposing thumb',[(x+.059,y+.032,z+.021),(x+.036,y+.058,z+.027),(x+.008,y+.059,z+.014)],.012,m,g)
  cable('Glove stitched seam',[(x+.064,y-.008,z+.030),(x+.065,y+.028,z+.026),(x+.043,y+.050,z+.027)],.00055,'gray_hair',g)
 else:
  sign=-1 if x<0 else 1
  ellipsoid('Anatomical palm',(x,y,z),(.031*scale,.044*scale,.018*scale),m,g,40)
  ellipsoid('Wrist',(x,y+.055*scale,z-.008*scale),(.023*scale,.029*scale,.020*scale),m,g,32)
  for i in range(4):
   xx=x+(-.023+i*.015)*scale;length=[.058,.070,.064,.049][i]*scale
   ellipsoid('Finger proximal',(xx,y-.036*scale-length*.22,z+.006*scale),(.0072*scale,length*.35,.008*scale),m,g,24)
   ellipsoid('Finger distal',(xx,y-.032*scale-length*.66,z+.011*scale),(.0065*scale,length*.21,.008*scale),m,g,24)
   ellipsoid('Knuckle',(xx,y-.027*scale,z+.013*scale),(.0085*scale,.010*scale,.007*scale),m,g,24)
   ellipsoid('Nail',(xx,y-.031*scale-length*.72,z+.018*scale),(.0048*scale,.007*scale,.001*scale),'ivory',g,16)
  cable('Thumb',[(x-sign*.024*scale,y+.015*scale,z+.007*scale),(x-sign*.043*scale,y-.009*scale,z+.014*scale),(x-sign*.037*scale,y-.032*scale,z+.022*scale)],.011*scale,m,g)
 return g
def person(name,old=False):
 reset();palette();skin='ellis_skin' if old else 'skin';cloth='ellis_cloth' if old else 'cloth'
 h=1.58 if old else 1.82;s=h/1.82
 root=group('Body');torso=group('Torso',(0,1.03*s,0),root)
 loft('Tailored coat',[(.77*s,0,0,.19*s,.095*s),(.88*s,0,-.006,.21*s,.112*s),(1.1*s,0,-.015,.18*s,.105*s),(1.31*s,0,-.02,.235*s,.116*s),(1.47*s,0,-.017,.215*s,.079*s),(1.50*s,0,-.012,.095*s,.068*s)],cloth,torso,.003)
 # Lapels, stitched hems, buttons, a shirt, and a shaped collar.
 mesh=bpy.data.meshes.new('Shaped blouse');mesh.from_pydata([p((xx*s,yy*s,zz*s)) for xx,yy,zz in [(-.063,1.47,.097),(.063,1.47,.097),(.034,1.31,.109),(0,1.17,.113),(-.034,1.31,.109)]],[],[(0,1,2,3,4)]);mesh.update()
 o=bpy.data.objects.new('Shirt opening',mesh);bpy.context.collection.objects.link(o);assign(o,'Shaped blouse','ivory',torso)
 for sign in [-1,1]:
  cable('Lapel seam',[(sign*.035*s,1.48*s,.082*s),(sign*.105*s,1.34*s,.104*s),(sign*.048*s,1.17*s,.112*s)],.0015*s,'dark',torso)
  ellipsoid('Collar',(sign*.051*s,1.478*s,.063*s),(.049*s,.025*s,.028*s),'ivory',torso,24)
 for yy in [1.08,1.20,1.32]:cylinder('Coat button',(0,yy*s,.111*s),.0055*s,.003*s,'dark','z',torso,vertices=16)
 for sign in [-1,1]:
  leg=group('Leg_'+('L' if sign<0 else 'R'),(sign*.09*s,.87*s,0),root)
  loft('Trouser leg',[(.10*s,sign*.091*s,.008,.046*s,.050*s),(.31*s,sign*.10*s,0,.052*s,.052*s),(.51*s,sign*.10*s,-.012,.063*s,.067*s),(.74*s,sign*.09*s,0,.075*s,.082*s),(.91*s,sign*.09*s,0,.089*s,.084*s)],cloth,leg,.003)
  ellipsoid('Leather shoe',(sign*.1*s,.055*s,.057*s),(.061*s,.044*s,.123*s),'rubber',leg,32)
  box('Shoe sole',(sign*.1*s,.02*s,.045*s),(.123*s,.024*s,.24*s),'dark',.012,leg)
  for k in range(5):cable('Shoe lace',[(sign*.10*s-.02*s,.092*s,.022*s+k*.009*s),(sign*.10*s+.02*s,.092*s,.026*s+k*.009*s)],.0008*s,'gray_hair',leg)
  arm=group('Arm_'+('L' if sign<0 else 'R'),(sign*.216*s,1.425*s,-.012),torso)
  loft('Coat sleeve',[(.995*s,sign*.248*s,.019,.039*s,.042*s),(1.09*s,sign*.266*s,0,.052*s,.053*s),(1.25*s,sign*.252*s,-.007,.058*s,.058*s),(1.42*s,sign*.215*s,-.012,.069*s,.065*s)],cloth,arm,.0027)
  cylinder('Shirt cuff',(sign*.249*s,.997*s,.020),.037*s,.038*s,'ivory',parent=arm)
  hand('Hand_'+str(sign),(sign*.247*s,.926*s,.040),arm,False,s*.95)
 # A proportioned, asymmetrical face with actual modeled eyelids and nasal anatomy.
 cy=1.677*s;head=group('Head',(0,cy,0),torso)
 mesh=ellipsoid('Skull',(0,cy,0),(.089*s,.139*s,.099*s),skin,head,64)
 for xx in [-.042*s,.042*s]:ellipsoid('Cheek',(xx,cy-.019*s,.074*s),(.043*s,.044*s,.034*s),skin,head,48)
 ellipsoid('Chin',(0,cy-.085*s,.056*s),(.055*s,.030*s,.035*s),skin,head,40)
 ellipsoid('Nasal bridge',(0,cy+.014*s,.105*s),(.012*s,.036*s,.019*s),skin,head,40)
 ellipsoid('Nose tip',(0,cy-.013*s,.128*s),(.014*s,.013*s,.016*s),skin,head,40)
 for xx in [-.010*s,.010*s]:
  ellipsoid('Nasal wing',(xx,cy-.021*s,.118*s),(.010*s,.008*s,.012*s),skin,head,32)
  ellipsoid('Nostril',(xx,cy-.026*s,.124*s),(.0038*s,.002*s,.004*s),'lip',head,24)
 ellipsoid('Neck',(0,1.528*s,-.013),(.05*s,.065*s,.052*s),skin,head,40)
 for sign in [-1,1]:
  xx=sign*.033*s;yy=cy+.016*s
  eye=group('Eye_'+str(sign),(xx,yy,.097*s),head)
  ellipsoid('Sclera',(xx,yy,.097*s),(.0117*s,.0090*s,.0104*s),'eye',eye,40)
  cylinder('Iris',(xx,yy,.108*s),.0045*s,.001*s,'iris','z',eye,vertices=40)
  cylinder('Pupil',(xx,yy,.109*s),.0021*s,.001*s,'dark','z',eye,vertices=32)
  ellipsoid('Corneal glint',(xx-.001*s,yy+.0025*s,.110*s),(.0008*s,.0008*s,.00025*s),'white',eye,16)
  for a,b in [(5,175),(185,355)]:
   pts=[(xx+.013*s*math.cos(t),yy+.0081*s*math.sin(t),.105*s) for t in [math.radians(a+k*(b-a)/12) for k in range(13)]]
   cable('Eyelid margin',pts,.0017*s,skin,head)
  brow=[(xx-.016*s,yy+.019*s,.099*s),(xx,yy+.023*s,.100*s),(xx+.017*s,yy+.018*s,.092*s)]
  cable('Brow ridge',brow,.0031*s,skin,head)
  for i in range(19):
   bx=xx-.015*s+i*.0017*s;by=yy+.022*s-abs(i-9)*.00045*s
   cable('Individual eyebrow',[(bx,by,.101*s),(bx+sign*.0015*s,by+.003*s,.100*s)],.00035*s,'gray_hair' if old else 'hair',head)
  ex=sign*.089*s
  ellipsoid('Ear',(ex,cy-.02*s,-.003),(.015*s,.032*s,.020*s),skin,head,40)
  cable('Ear helix',[(ex+sign*.006*s,cy+.004*s,.005),(ex+sign*.010*s,cy-.021*s,.012),(ex+sign*.005*s,cy-.043*s,.003)],.0024*s,skin,head)
  if old:
   pts=[(xx+.0205*s*math.cos(a),yy+.0165*s*math.sin(a),.125*s) for a in [k*math.tau/24 for k in range(25)]]
   cable('Spectacle rim',pts,.0009*s,'steel',head)
   ellipsoid('Spectacle lens',(xx,yy,.123*s),(.0198*s,.016*s,.0008*s),'glass',head,32)
   cable('Spectacle temple',[(xx+sign*.020*s,yy,.124*s),(sign*.082*s,yy,.073*s),(sign*.091*s,yy-.009*s,-.013)],.0011*s,'steel',head)
   for j in range(3):
    cable('Age crease',[(xx+sign*.014*s,yy-.005*s-j*.004*s,.103*s),(xx+sign*.029*s,yy-.010*s-j*.005*s,.090*s)],.00055*s,skin,head)
 if old:cable('Spectacle bridge',[(-.012*s,cy+.018*s,.125*s),(0,cy+.022*s,.130*s),(.012*s,cy+.018*s,.125*s)],.0009*s,'steel',head)
 mouthy=cy-.049*s
 ellipsoid('Mouth recess',(0,mouthy,.096*s),(.028*s,.0034*s,.0035*s),'dark',head,32)
 cable('Upper lip',[(-.028*s,mouthy+.002*s,.097*s),(-.009*s,mouthy+.005*s,.102*s),(0,mouthy+.003*s,.104*s),(.009*s,mouthy+.005*s,.102*s),(.028*s,mouthy+.002*s,.097*s)],.0021*s,'lip',head)
 jaw=group('Jaw',(0,mouthy,.097*s),head)
 cable('Lower lip',[(-.025*s,mouthy-.001*s,.098*s),(0,mouthy-.005*s,.105*s),(.025*s,mouthy-.001*s,.098*s)],.0026*s,'lip',jaw)
 ellipsoid('Hair cap',(0,cy+.062*s,.008*s),(.091*s,.083*s,.093*s),'gray_hair' if old else 'hair',head,48)
 for i in range(65):
  a=i*2.39996;rr=.07*s*math.sqrt((i+1)/65);xx=math.cos(a)*rr;zz=math.sin(a)*rr-.015*s
  pts=[(xx+math.sin(j*.6+a)*.004*s,cy+(.142-j*.002)*s,zz-j*.0025*s) for j in range(9)]
  cable('Combed hair strand',pts,.00055*s,'gray_hair' if old else 'hair',head)
 if old:ellipsoid('Hair bun',(0,cy+.027*s,-.096*s),(.049*s,.042*s,.034*s),'gray_hair',head,40)
 else:
  # Oleg's glasses are no longer oversized cartoon shapes.
  for xx in [-.033*s,.033*s]:box('Sunglass lens',(xx,cy+.016*s,.123*s),(.046*s,.029*s,.003*s),'glass',.009,head)
  cable('Glasses bridge',[(-.010*s,cy+.020*s,.123*s),(.010*s,cy+.020*s,.123*s)],.0013*s,'steel',head)
 # Fuse the anatomical volumes into one continuous skin surface, then smooth the joins.
 faceparts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==head and o.data.materials and o.data.materials[0]==M[skin]]
 bpy.ops.object.select_all(action='DESELECT')
 for o in faceparts:o.select_set(True)
 bpy.context.view_layer.objects.active=faceparts[0];bpy.ops.object.join();face=bpy.context.object
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=face.modifiers.new('Original anatomical sculpt','REMESH');mod.mode='VOXEL';mod.voxel_size=.0032*s;mod.use_smooth_shade=True
 print('SCULPT bounds',tuple(face.dimensions),'vertices',len(face.data.vertices),flush=True)
 bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=face.modifiers.new('Soft tissue transitions','SMOOTH');mod.factor=.6;mod.iterations=4;bpy.ops.object.modifier_apply(modifier=mod.name)
 uv_planar(face,.19*s)
 face.name='Continuous sculpted face'
 export(name)
def cat():
 reset();palette();root=group('BIOS')
 ellipsoid('Cat body',(0,.23,0),(.15,.20,.28),'fur',root,48)
 for x in [-.09,.09]:
  for z in [-.17,.17]:ellipsoid('Cat paw',(x,.047,z),(.050,.045,.068),'fur',root,32)
 head=group('Head',(0,.43,.21),root)
 ellipsoid('Cat skull',(0,.43,.21),(.104,.088,.092),'fur',head,48)
 for x in [-.072,.072]:
  ear=loft('Cat ear',[(.47,x,.20,.042,.024),(.52,x*1.15,.19,.024,.014),(.56,x*1.2,.19,.003,.003)],'fur',head)
 for x in [-.038,.038]:
  ellipsoid('Cat eye',(x,.445,.295),(.020,.013,.005),'iris',head,32)
  ellipsoid('Cat pupil',(x,.445,.300),(.003,.011,.002),'dark',head,24)
 for x in [-.024,.024]:ellipsoid('Cat muzzle',(x,.410,.295),(.034,.025,.025),'ivory',head,32)
 ellipsoid('Cat nose',(0,.422,.316),(.011,.006,.007),'lip',head,24)
 for sign in [-1,1]:
  for i in range(4):cable('Whisker',[(sign*.03,.418,.309),(sign*.082,.424+(i-2)*.008,.326),(sign*.15,.433+(i-2)*.012,.315)],.00045,'ivory',head)
 tail=group('Tail',(0,.25,-.20),root)
 cable('Curled tail',[(0,.26,-.2),(.16,.25,-.31),(.24,.37,-.26),(.24,.47,-.13)],.021,'fur',tail)
 for i in range(10):
  z=-.22+i*.044
  cable('Tabby stripe',[(-.12,.29,z),(0,.429,z),(.12,.29,z)],.007,'fur2',root)
 export('bios')
def tools():
 reset();palette()
 root=group('Hands')
 hand('RightHand',(.016,-.044,.008),root,True,1.0)
 cable('Work sleeve',[(.066,-.076,.071),(.068,-.080,.13),(.071,-.068,.23),(.088,-.057,.36)],.048,'cloth',root)
 cylinder('Glove cuff',(.068,-.077,.089),.033,.035,'rubber','z',root,vertices=32)
 cable('Sleeve seam',[(.085,-.049,.12),(.095,-.037,.24),(.112,-.025,.36)],.0008,'gray_hair',root)
 g=group('TOOL_DRIVER')
 cylinder('Insulated grip',(0,.002,0),.014,.089,'rubber',parent=g,vertices=32)
 for i in range(12):
  a=i*math.tau/12;box('Grip flute',(.013*math.cos(a),.002,.013*math.sin(a)),(.002,.071,.002),'black',.0005,g)
 cylinder('Chrome shaft',(0,.12,0),.0031,.156,'steel',parent=g,vertices=20)
 box('Phillips bit',(0,.202,0),(.005,.013,.002),'steel',.0003,g)
 box('Cross bit',(0,.202,0),(.002,.013,.005),'steel',.0003,g)
 g=group('TOOL_METER')
 box('Meter case',(0,.066,0),(.078,.153,.030),'rubber',.010,g)
 box('Meter face',(0,.066,.017),(.066,.138,.008),'black',.007,g)
 box('Meter LCD',(0,.11,.024),(.052,.027,.002),'cyan',.001,g)
 cylinder('Meter dial',(0,.05,.026),.017,.008,'plastic','z',g,vertices=32)
 text('Meter stencil',(0,.137,.026),'STEVE / DMM',.009,'paper',parent=g)
 cable('Probe lead',[(.02,-.012,0),(.062,-.03,.03),(.078,.025,.03),(.08,.14,.015)],.0023,'red',g)
 cylinder('Probe needle',(.08,.17,.015),.0015,.06,'steel',parent=g,vertices=12)
 g=group('TOOL_PICK')
 cylinder('Precision pick grip',(0,.0,0),.008,.075,'rubber',parent=g)
 cable('Nonconductive hook',[(0,.039,0),(0,.14,0),(.009,.16,0),(.017,.151,0)],.002,'ivory',g)
 g=group('TOOL_DRIVE')
 box('Encrypted drive',(0,.04,0),(.045,.09,.014),'black',.005,g)
 box('USB A plug',(0,.103,0),(.013,.035,.006),'steel',.001,g)
 text('Drive engraving',(0,.036,.008),'AES',.019,'steel',parent=g)
 g=group('TOOL_BRIDGE')
 cylinder('Jumper grip',(0,0,0),.009,.06,'rubber',parent=g)
 cable('Bridge lead',[(0,.031,0),(0,.18,0),(.056,.19,0),(.056,.12,0)],.003,'blue',g)
 for x,y in [(0,.032),(.056,.11)]:cylinder('Bridge probe',(x,y,0),.002,.026,'steel',parent=g,vertices=16)
 g=group('TOOL_FUSE')
 cylinder('Glass fuse',(0,.07,0),.007,.027,'glass',parent=g,vertices=32)
 for yy in [.05,.09]:cylinder('Fuse endcap',(0,yy,0),.0075,.01,'steel',parent=g)
 cylinder('Fuse element',(0,.07,0),.0004,.026,'copper',parent=g,vertices=8)
 export('hands')
def drone():
 reset();palette();root=group('Drone')
 box('Flight chassis',(0,0,0),(.24,.087,.20),'black',.025,root)
 ellipsoid('Camera gimbal',(0,-.075,.055),(.036,.035,.044),'steel',root,32)
 cylinder('Camera lens',(0,-.075,.095),.019,.008,'glass','z',root,vertices=32)
 for i in range(4):
  a=i*math.tau/4+math.pi/4;x=math.cos(a)*.22;z=math.sin(a)*.22
  cable('Carbon spar',[(0,0,0),(x,0,z)],.010,'black',root)
  cylinder('Brushless motor',(x,.0,z),.021,.04,'steel',parent=root)
  g=group('Rotor_'+str(i),(x,.03,z),root)
  for sign in [-1,1]:ellipsoid('Propeller',(x+sign*.047,.03,z),(.067,.002,.010),'dark',g,24)
  cylinder('Rotor nut',(x,.035,z),.006,.009,'steel',parent=g,vertices=6)
 export('drone')

if __name__=='__main__':
 tasks={'shop':shop,'facility':facility,'ellis':lambda:person('ellis',True),'oleg':lambda:person('oleg',False),'bios':cat,'hands':tools,'drone':drone}
 requested=os.environ.get('STEVE_MODEL')
 for name,action in tasks.items():
  if not requested or requested==name:action()
 print('Original first-person Blender asset build finished.',flush=True)
