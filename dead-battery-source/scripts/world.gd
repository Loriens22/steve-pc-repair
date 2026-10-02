extends RefCounted

var game
var root: Node3D
var nodes={}
var origins={}
var actors={}
var probe: ReflectionProbe
var env: WorldEnvironment
var rain: CPUParticles3D
var roof_rain: CPUParticles3D

func setup(g):
	game=g
	env=WorldEnvironment.new()
	game.add_child(env)

func load_level(level: String):
	if root:
		game.remove_child(root)
		root.queue_free()
	nodes.clear()
	origins.clear()
	actors.clear()
	rain=null
	roof_rain=null
	root=Node3D.new()
	root.name="OriginalBlenderWorld"
	game.add_child(root)
	var model=load("res://assets/models/"+("shop" if level=="shop" else "facility")+".glb").instantiate()
	root.add_child(model)
	cache(model)
	var path="res://assets/models/"+("shop" if level=="shop" else "facility")+"_collision.json"
	var boxes=JSON.parse_string(FileAccess.get_file_as_string(path))
	for entry in boxes:
		var body=StaticBody3D.new()
		body.position=vec(entry.p)
		var collision=CollisionShape3D.new()
		var shape=BoxShape3D.new()
		shape.size=vec(entry.s)
		collision.shape=shape
		body.add_child(collision)
		root.add_child(body)
	var e=Environment.new()
	e.background_mode=Environment.BG_SKY
	var sky=Sky.new()
	var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color("111b29") if level=="vault" else Color("577184")
	sm.sky_horizon_color=Color("364352") if level=="vault" else Color("a6b1b5")
	sm.ground_bottom_color=Color("0c1015")
	sm.ground_horizon_color=Color("30353b")
	sm.sky_energy_multiplier=.35 if level=="vault" else .55
	sm.sun_angle_max=6
	sky.sky_material=sm
	e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("8596a1")
	e.ambient_light_energy=.17 if level=="shop" else .16
	e.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure=1.0
	e.fog_enabled=true
	e.fog_light_color=Color("61727b") if level=="shop" else Color("1c2c3a")
	e.fog_density=.0015 if level=="shop" else .009
	env.environment=e
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-28,-132,0)
	sun.light_color=Color("ffd4a0") if level=="shop" else Color("b8cfeb")
	sun.light_energy=.42 if level=="shop" else .12
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=45
	root.add_child(sun)
	if level=="shop":
		for p in [Vector3(-2.8,2.99,-2.5),Vector3(2.9,2.99,-2.5),Vector3(-2.8,2.99,1.1),Vector3(2.9,2.99,1.1)]:
			spot(p,Color("ffddac"),2.0,7,68,true)
		omni(Vector3(-2.0,1.35,-2.8),Color("a1c4cd"),.20,2.1)
		omni(Vector3(.12,2.10,-.70),Color("e1d0ba"),.65,3.7)
		actor("ellis",Vector3(.58,0,1.0),PI)
		actor("oleg",Vector3(2.80,0,5.2),PI)
		actor("bios",Vector3(-3.46,0,1.58),.5)
		node("DYN_SHOP_DOOR").rotation.y=-1.05
		probe_room(Vector3(0,1.45,0),Vector3(10,3,8))
	else:
		for p in [Vector3(-7.7,3.43,-1),Vector3(-7.7,3.43,-8),Vector3(-7.7,3.43,-15.5),Vector3(-1.5,3.43,-2),Vector3(-1.5,3.43,-9),Vector3(2.8,3.43,-15),Vector3(7.0,3.43,-2.8),Vector3(7.0,3.43,-15.5),Vector3(0,3.43,-21.3)]:
			spot(p,Color("bfd8dc"),2.0,7.4,70,p.z>-12 and p.x<4)
		for p in [Vector3(-7.7,2.5,-16),Vector3(6.8,2.4,-5.1),Vector3(7.8,2.2,-15.8),Vector3(.4,2.5,-22.1)]:
			omni(p,Color("a7c8d4"),.8,4.0)
		omni(Vector3(-7.8,2.3,4.1),Color("ffba73"),1.0,5.5)
		omni(Vector3(-8.0,4.8,-17.0),Color("aac8e0"),.48,14)
		probe_room(Vector3(0,1.65,-9),Vector3(9,3.2,19))
		door_collider("entry",Vector3(-7.85,1.1,2.2),Vector3(1.19,2.2,.09))
		door_collider("hall",Vector3(-4.76,1.1,-5.05),Vector3(.09,2.2,1.25))
		door_collider("core",Vector3(-.24,1.21,-19.05),Vector3(1.36,2.42,.09))
		rain=rainfall(Vector3(-7,7.0,5.8),Vector3(4.7,.04,3.2),.75)
		roof_rain=rainfall(Vector3(-1,10.0,-17),Vector3(9.4,.04,8.5),.65)
	return root

func rainfall(at,extent,life):
	var p=CPUParticles3D.new()
	p.position=at
	p.amount=45 if game.mobile else 95
	p.lifetime=life
	p.preprocess=life
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents=extent
	p.direction=Vector3(.08,-1,.02)
	p.spread=2
	p.initial_velocity_min=6.0
	p.initial_velocity_max=6.2
	p.gravity=Vector3(0,-9.81,0)
	var mesh=QuadMesh.new()
	mesh.size=Vector2(.0015,.072)
	var m=StandardMaterial3D.new()
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color=Color(.63,.74,.80,.38)
	m.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material=m
	p.mesh=mesh
	root.add_child(p)
	return p

func vec(a)->Vector3:return Vector3(a[0],a[1],a[2])

func cache(n):
	if n is Node3D:
		nodes[String(n.name)]=n
		origins[String(n.name)]=n.transform
	for child in n.get_children():cache(child)

func node(name: String):return nodes.get(name)

func actor(name,p,yaw):
	var n=load("res://assets/models/"+name+".glb").instantiate()
	root.add_child(n)
	n.position=p
	n.rotation.y=yaw
	actors[name]=n
	if name in ["ellis","oleg"]:
		var solid=StaticBody3D.new()
		var collision=CollisionShape3D.new()
		var capsule=CapsuleShape3D.new()
		capsule.height=1.50 if name=="ellis" else 1.73
		capsule.radius=.19
		collision.shape=capsule
		collision.position.y=capsule.height*.5
		solid.add_child(collision)
		n.add_child(solid)
	return n

func spot(p,color,energy,range_,angle,shadows=false):
	var light=SpotLight3D.new()
	light.position=p
	light.rotation_degrees.x=-90
	light.light_color=color
	light.light_energy=energy
	light.spot_range=range_
	light.spot_angle=angle
	light.spot_attenuation=1.0
	light.shadow_enabled=shadows
	light.set_meta("original_shadow",shadows)
	light.set_meta("balanced_shadow",p.x*p.z>0 if game.location=="shop" else abs(p.x)<4)
	light.shadow_bias=.035
	root.add_child(light)
	return light

func omni(p,color,energy,range_):
	var light=OmniLight3D.new()
	light.position=p
	light.light_color=color
	light.light_energy=energy
	light.omni_range=range_
	light.omni_attenuation=1.3
	root.add_child(light)
	return light

func probe_room(p,extent):
	probe=ReflectionProbe.new()
	probe.position=p
	probe.size=extent
	probe.intensity=.65
	probe.box_projection=true
	probe.cull_mask=1
	root.add_child(probe)

func door_collider(id,p,s):
	var n=StaticBody3D.new()
	n.name="DoorCollision_"+id
	n.position=p
	var c=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=s
	c.shape=shape
	n.add_child(c)
	root.add_child(n)
	nodes[String(n.name)]=n

func open_door(id):
	var n=node("DYN_"+id.to_upper()+"_DOOR")
	if n:
		var t=game.create_tween()
		t.tween_property(n,"position",n.position+Vector3(0,2.34,0),1.4).set_trans(Tween.TRANS_SINE)
	var collider=node("DoorCollision_"+id)
	if collider:collider.get_child(0).set_deferred("disabled",true)
	game.play_fx("door")

func part_shift(name,offset):
	var n=node(name)
	if n:
		game.create_tween().tween_property(n,"position",origins[name].origin+offset,.45).set_trans(Tween.TRANS_SINE)

func part_restore(name):
	var n=node(name)
	if n:
		game.create_tween().tween_property(n,"transform",origins[name],.45)

func show_part(name,show):
	var n=node(name)
	if n:n.visible=show

func face(n,target):
	if n:
		var flat=Vector3(target.x,n.global_position.y,target.z)
		if flat.distance_to(n.global_position)>.02:n.look_at(flat,Vector3.UP,true)

func replace_screen(name,texture):
	var n=node(name)
	if not n or not n is MeshInstance3D:return
	var m=StandardMaterial3D.new()
	m.albedo_texture=texture
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness=.27
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	n.material_override=m
