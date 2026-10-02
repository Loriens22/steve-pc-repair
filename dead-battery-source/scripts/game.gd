extends Node3D

const WorldBuilder=preload("res://scripts/world.gd")
const HUD=preload("res://scripts/hud.gd")
const Tasks=preload("res://scripts/tasks.gd")

var world=WorldBuilder.new()
var tasks=Tasks.new()
var ui
var body: CharacterBody3D
var shape: CapsuleShape3D
var collision: CollisionShape3D
var head: Node3D
var cam: Camera3D
var torch: SpotLight3D
var hands: Node3D
var hand_root: Node3D
var tool_nodes={}
var tool=0
var tool_names=["HANDS","SCREWDRIVER","MULTIMETER","PRECISION PICK","ENCRYPTED DRIVE","LOOP BRIDGE","FUSE"]
var mobile=false
var look_sensitivity=.0024
var yaw=0.0
var pitch=-.24
var touch_move=Vector2.ZERO
var mobile_run=false
var crouched=false
var zoomed=false
var panel_open=false
var flashlight_on=false
var state="title"
var location="shop"
var repair_step=0
var removed_screws: Array=[]
var tightened_screws: Array=[]
var mission_step=0
var case_taken=false
var feed_identified=false
var camera_isolated=false
var camera_loop=false
var fuse_rating=-1
var pump_power=false
var fuse_installed=false
var valves=[0.0,0.0,1.0]
var temperature=38.0
var pressure=0.0
var flow=0.0
var copy_progress=0.0
var copy_started=false
var evidence=false
var ups_off=[false,false]
var key_screws: Array=[]
var key_open=false
var key_verified=false
var key_down=false
var climbing=false
var finished=false
var secrets: Array=[]
var notes: Array=[]
var alerts=0
var stamina=1.0
var suspicion=0.0
var auction_time=1200.0
var play_time=0.0
var elapsed=0.0
var focus={}
var held=false
var hold_id=""
var hold_progress=0.0
var hold_latched=false
var step_clock=0.0
var draw_clock=0.0
var music_on=true
var voices_on=true
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var fx: AudioStreamPlayer
var feet: AudioStreamPlayer3D
var roomtone: AudioStreamPlayer
var drone: Node3D
var drone_sound: AudioStreamPlayer3D
var drone_path=[Vector3(-3.8,2.05,-3.8),Vector3(3.75,2.05,-3.8),Vector3(3.75,2.05,-15.2),Vector3(-3.8,2.05,-15.2)]
var drone_index=0
var cameras: Array=[]
var last_alarm=-20.0
var dialogue={}
var cine_name=""
var cine_index=-1
var cine_clock=0.0
var cine_pos=Vector3.ZERO
var cine_aim=Vector3.ZERO
var actor_motion={}
var voice_line={}
var speech_clock=0.0
var capture_seen=false
var graphics_quality=1

func _ready():
	Engine.max_physics_steps_per_frame=32
	mobile=DisplayServer.window_get_size().x<760
	if OS.has_feature("web"):
		mobile=mobile or bool(JavaScriptBridge.eval("navigator.maxTouchPoints>0"))
	get_tree().root.content_scale_size=Vector2i(480,852) if mobile else Vector2i(1280,720)
	Input.emulate_mouse_from_touch=not mobile
	get_viewport().scaling_3d_scale=.82 if mobile else 1.0
	dialogue=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue.json"))
	setup_player()
	setup_audio()
	restore_web_save()
	load_preferences()
	world.setup(self)
	tasks.setup(self)
	load_location("shop")
	body.position=Vector3(-2.2,.02,-1.81)
	yaw=0
	pitch=-.34
	update_look()
	ui=HUD.new()
	add_child(ui)
	ui.setup(self)
	set_tool(0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.steveReady=true; document.addEventListener('pointerlockchange',()=>{window.steveLookCaptured=!!document.pointerLockElement;});")
	get_viewport().size_changed.connect(resize_mobile)
	resize_mobile()
	apply_quality()

func resize_mobile():
	if not mobile:return
	var sz=DisplayServer.window_get_size()
	get_tree().root.content_scale_size=Vector2i(960,540) if sz.x>sz.y else Vector2i(480,852)
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED
	apply_quality()

func apply_quality():
	var viewport=get_viewport()
	viewport.scaling_3d_scale=[.62,.82 if mobile else .90,1.0][clampi(graphics_quality,0,2)]
	viewport.msaa_3d=Viewport.MSAA_2X if graphics_quality==2 else Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size=2048 if graphics_quality==2 else 1024
	if world and world.root:
		for light in world.root.find_children("*","SpotLight3D",true,false):
			if light.has_meta("original_shadow"):
				light.shadow_enabled=bool(light.get_meta("original_shadow")) and (graphics_quality==2 or graphics_quality==1 and bool(light.get_meta("balanced_shadow",true)))

func setup_player():
	body=CharacterBody3D.new()
	body.name="Steve"
	body.floor_snap_length=.16
	shape=CapsuleShape3D.new()
	shape.radius=.22
	shape.height=1.70
	collision=CollisionShape3D.new()
	collision.shape=shape
	collision.position.y=.85
	body.add_child(collision)
	add_child(body)
	head=Node3D.new()
	head.position.y=1.62
	body.add_child(head)
	cam=Camera3D.new()
	cam.fov=74
	cam.near=.025
	cam.far=110
	head.add_child(cam)
	cam.current=true
	torch=SpotLight3D.new()
	torch.position=Vector3(.12,-.12,-.10)
	torch.spot_range=16
	torch.spot_angle=26
	torch.spot_attenuation=1.1
	torch.light_color=Color("d4dce1")
	torch.light_energy=2.1
	torch.shadow_enabled=true
	torch.shadow_bias=.035
	torch.visible=false
	cam.add_child(torch)
	hand_root=Node3D.new()
	hand_root.position=Vector3(.22,-.27,-.44)
	hand_root.rotation.x=-.43
	cam.add_child(hand_root)
	hands=load("res://assets/models/hands.glb").instantiate()
	hand_root.add_child(hands)
	for id in ["DRIVER","METER","PICK","DRIVE","BRIDGE","FUSE"]:
		tool_nodes[id]=hands.find_child("TOOL_"+id,true,false)
	for n in hands.find_children("*","MeshInstance3D",true,false):
		n.layers=2
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func setup_audio():
	music=AudioStreamPlayer.new()
	music.volume_db=-22
	add_child(music)
	music.finished.connect(func():
		if music_on:music.play())
	voice=AudioStreamPlayer.new()
	add_child(voice)
	fx=AudioStreamPlayer.new()
	fx.volume_db=-9
	add_child(fx)
	feet=AudioStreamPlayer3D.new()
	feet.position.y=.12
	feet.volume_db=-9
	feet.max_distance=5
	body.add_child(feet)
	roomtone=AudioStreamPlayer.new()
	roomtone.volume_db=-20
	add_child(roomtone)
	roomtone.stream=load("res://assets/audio/ventilation.ogg")
	roomtone.finished.connect(func():roomtone.play())
	roomtone.play()

func load_location(level):
	location=level
	actor_motion.clear()
	world.load_level(level)
	music.stop()
	music.stream=load("res://assets/audio/"+("shop_ambience" if level=="shop" else "vault_ambience")+".ogg")
	if music_on:music.play()
	cameras.clear()
	drone=null
	if level=="vault":setup_security()
	tasks.rebuild()
	tasks.restore_parts()
	apply_quality()

func setup_security():
	drone=load("res://assets/models/drone.glb").instantiate()
	world.root.add_child(drone)
	drone.position=drone_path[0]
	drone_index=1
	drone_sound=AudioStreamPlayer3D.new()
	drone_sound.stream=load("res://assets/audio/drone.ogg")
	drone_sound.volume_db=-9
	drone_sound.unit_size=1
	drone_sound.max_distance=15
	drone.add_child(drone_sound)
	drone_sound.finished.connect(func():drone_sound.play())
	drone_sound.play()
	var beam=SpotLight3D.new()
	beam.light_color=Color("d5deea")
	beam.light_energy=1.5
	beam.spot_range=10
	beam.spot_angle=35
	beam.shadow_enabled=false
	beam.rotation=Vector3(-.26,PI,0)
	drone.add_child(beam)
	for at in [Vector3(-5.34,2.67,-2.2),Vector3(4.09,2.62,-13.8)]:
		var n=Node3D.new()
		n.position=at
		world.root.add_child(n)
		var mesh=MeshInstance3D.new()
		var box=BoxMesh.new()
		box.size=Vector3(.11,.07,.18)
		mesh.mesh=box
		var m=StandardMaterial3D.new()
		m.albedo_color=Color("30383a")
		m.metallic=.4
		m.roughness=.4
		mesh.material_override=m
		n.add_child(mesh)
		var l=SpotLight3D.new()
		l.light_energy=.6
		l.light_color=Color("91a5b9")
		l.spot_range=11
		l.spot_angle=29
		n.add_child(l)
		cameras.append(n)

func playable()->bool:return state in ["shop_repair","shop","vault"] and not panel_open and not climbing

func capture_mouse():
	capture_seen=false
	if not mobile and playable():Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func release_mouse():
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	held=false
	hold_progress=0

func update_look():
	body.rotation.y=yaw
	head.rotation.x=pitch

func look(delta: Vector2):
	if not playable():return
	yaw=wrapf(yaw-delta.x*look_sensitivity,-PI,PI)
	pitch=clampf(pitch-delta.y*look_sensitivity,-1.24,1.24)
	update_look()

func set_tool(index):
	tool=index
	if tool==6 and fuse_rating<0:tool=0
	var names=["DRIVER","METER","PICK","DRIVE","BRIDGE","FUSE"]
	for i in range(names.size()):
		if tool_nodes[names[i]]:tool_nodes[names[i]].visible=tool==i+1
	hold_progress=0
	hold_latched=false
	if ui:ui.refresh()

func toggle_light():
	flashlight_on=not flashlight_on
	torch.visible=flashlight_on
	play_fx("click")

func toggle_crouch():
	if crouched:
		var q=PhysicsRayQueryParameters3D.create(body.global_position+Vector3(0,1.03,0),body.global_position+Vector3(0,1.77,0))
		q.exclude=[body.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q):return
	crouched=not crouched
	shape.height=1.08 if crouched else 1.70
	collision.position.y=.54 if crouched else .85

func action_hold(value: bool):
	if not playable():return
	held=value
	if not value:
		hold_progress=0
		hold_latched=false
		hold_id=""

func jump():
	if playable() and body.is_on_floor() and not crouched:body.velocity.y=3.8

func _physics_process(dt):
	if not playable():
		body.velocity.x=0
		body.velocity.z=0
		return
	var input=touch_move
	if not mobile:
		input=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if input.length()>1:input=input.normalized()
	var running=(mobile_run or Input.is_physical_key_pressed(KEY_SHIFT)) and not crouched and stamina>.08
	var speed=3.15 if running else (1.02 if crouched else 1.78)
	var v=body.basis*Vector3(input.x,0,input.y)*speed
	body.velocity.x=move_toward(body.velocity.x,v.x,dt*10)
	body.velocity.z=move_toward(body.velocity.z,v.z,dt*10)
	if not body.is_on_floor():body.velocity.y-=9.81*dt
	elif body.velocity.y<=0:body.velocity.y=-.05
	body.move_and_slide()
	stamina=clampf(stamina+dt*(-.095 if running and input.length()>.2 else .08),0,1)
	var moving=Vector2(body.velocity.x,body.velocity.z).length()
	step_clock+=dt*moving
	if moving>.25 and body.is_on_floor() and step_clock>.75:
		step_clock=0
		feet.stream=load("res://assets/audio/"+("step_vinyl" if location=="shop" else "step_concrete")+".ogg")
		feet.pitch_scale=randf_range(.94,1.06)
		feet.volume_db=-17 if crouched else (-5 if running else -10)
		feet.play()
	head.position.y=lerpf(head.position.y,(1.01 if crouched else 1.62)+sin(elapsed*(12 if running else 8))*.009*min(1,moving),dt*12)
	if body.position.y<-.8:
		body.position=Vector3(-2.2,.02,-1.81) if location=="shop" else Vector3(-7.85,.03,5.2)

func _process(dt):
	elapsed+=dt
	if world.roof_rain:world.roof_rain.visible=body.position.y>3.8
	if ui:
		if playable():
			play_time+=dt
			refresh_focus()
			process_hold(dt)
			if location=="vault":
				auction_time=max(0,auction_time-dt)
				process_security(dt)
				tasks.process_machines(dt)
				if auction_time<=0 and not key_down:ui.show_timeout()
		elif cine_name!="":process_cinematic(dt)
		process_hands(dt)
		process_actors(dt)
		if speech_clock>0:
			speech_clock-=dt
			if speech_clock<=0 and cine_name=="":ui.clear_line()
		cam.fov=lerpf(cam.fov,48.0 if zoomed and playable() else (67.0 if cine_name!="" else 74.0),1-exp(-dt*8))
		ui.tick(dt)
		draw_clock+=dt
		if draw_clock>.10:
			draw_clock=0
			export_state()
			if OS.has_feature("web") and not mobile and playable():
				var locked=bool(JavaScriptBridge.eval("window.steveLookCaptured"))
				if locked:capture_seen=true
				elif capture_seen:ui.show_pause()

func refresh_focus():
	focus={}
	var origin=cam.global_position
	var direction=-cam.global_basis.z
	var best=1.0e6
	for a in tasks.targets:
		if not tasks.active(a.id):continue
		var point=tasks.target_position(a.id,a.p)
		var offset=point-origin
		var dist=offset.length()
		if dist>2.25 or dist<.05:continue
		var along=direction.dot(offset)
		if along<0:continue
		var radial=(offset-direction*along).length()
		var radius=max(float(a.radius),.035+dist*.018)
		if radial>radius:continue
		var q=PhysicsRayQueryParameters3D.create(origin,point)
		q.exclude=[body.get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.position.distance_to(origin)<dist-.04:continue
		var score=radial/radius+dist*.08
		if score<best:
			best=score
			focus=a.duplicate()
			focus["p"]=point
			focus["distance"]=dist
			focus["label"]=tasks.label(a.id)

func process_hold(dt):
	if not held or focus.is_empty() or hold_latched:
		if not held:hold_progress=0
		return
	if hold_id!=focus.id:
		hold_id=focus.id
		hold_progress=0
	if float(focus.distance)>1.65:
		ui.toast("Move a little closer.")
		hold_latched=true
		return
	var required=tasks.required_tool(focus.id)
	if required>=0 and tool!=required:
		ui.toast("Use "+tool_names[required].to_lower()+" for this step.")
		hold_latched=true
		return
	hold_progress+=dt
	if hold_progress>=float(focus.duration):
		hold_latched=true
		tasks.perform(focus.id)
		save_game()

func process_hands(dt):
	hand_root.visible=playable() and (tool>0 or held and hold_progress>0)
	if not hand_root.visible:return
	var working=held and hold_progress>0 and not focus.is_empty()
	var rest=Vector3(.22,-.27,-.44)+Vector3(sin(elapsed*1.7)*.002,sin(elapsed*2)*.003,0)
	if working:
		var point=cam.global_transform.affine_inverse()*focus.p
		var reach=point.normalized()*min(point.length(),.77)
		var turn=sin(elapsed*17)*.16 if tool==1 else .0
		var rot=Vector3(-PI/2,0,turn)
		hand_root.position=hand_root.position.lerp(reach-Basis.from_euler(rot)*Vector3(0,.20 if tool==1 else .1,0),1-exp(-dt*9))
		hand_root.rotation=rot
	else:
		hand_root.position=hand_root.position.lerp(rest,1-exp(-dt*7))
		hand_root.rotation=hand_root.rotation.lerp(Vector3(-.43,.09,-.05),1-exp(-dt*7))

func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode==KEY_ESCAPE:
			if panel_open and state!="deadline":ui.close_panel()
			elif cine_name=="":ui.show_pause()
		elif e.physical_keycode in [KEY_ENTER,KEY_SPACE] and cine_name!="":next_line()
		elif e.physical_keycode==KEY_SPACE:jump()
		elif e.physical_keycode==KEY_J:ui.show_journal()
		elif e.physical_keycode==KEY_TAB:ui.show_tools()
		elif e.physical_keycode==KEY_C:toggle_crouch()
		elif e.physical_keycode==KEY_F:toggle_light()
		elif e.physical_keycode>=KEY_0 and e.physical_keycode<=KEY_6:set_tool(e.physical_keycode-KEY_0)
	if e is InputEventKey and e.physical_keycode==KEY_E and not e.echo:action_hold(e.pressed)
	if e is InputEventMouseMotion and playable() and not mobile:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):look(e.relative)
	if e is InputEventMouseButton and not mobile and playable():
		if e.button_index==MOUSE_BUTTON_LEFT:
			if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and e.pressed:capture_mouse()
			else:action_hold(e.pressed)
		if e.button_index==MOUSE_BUTTON_RIGHT:zoomed=e.pressed
		if e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			set_tool((tool+(1 if e.button_index==MOUSE_BUTTON_WHEEL_DOWN else 5))%6)

func process_security(dt):
	if not drone:return
	var path=drone_path
	if body.position.y>3.8:
		path=[Vector3(-8.5,5.62,-10.8),Vector3(3.5,5.62,-10.8),Vector3(3.5,5.62,-23.5),Vector3(-8.5,5.62,-23.5)]
		if drone.position.y<4:
			drone.position=path[1]
			drone_index=2
	var goal=path[drone_index]
	drone.position=drone.position.move_toward(goal,dt*(1.0 if key_down else .82))
	world.face(drone,goal)
	if drone.position.distance_to(goal)<.06:drone_index=(drone_index+1)%path.size()
	for n in drone.find_children("Rotor_*","Node3D",true,false):n.rotation.y+=dt*75
	var visible=false
	if mission_step>=2 and elapsed-last_alarm>6:
		visible=sees_player(drone.global_position,drone.global_basis.z,10.5 if flashlight_on else (5.0 if crouched else 7.7),.77)
		if not visible and Vector2(body.velocity.x,body.velocity.z).length()>2.7 and drone.position.distance_to(body.position)<3.8:visible=true
	for i in range(cameras.size()):
		var c=cameras[i]
		c.rotation=Vector3(-.22,(-.80 if i==0 else 2.12)+sin(elapsed*.23+i)*.70,0)
		if (not camera_loop or key_down) and mission_step>=1:
			if sees_player(c.global_position,-c.global_basis.z,10.2,.88):visible=true
	suspicion=clampf(suspicion+dt*(.39 if visible else -.43),0,1)
	if suspicion>=1:
		alerts+=1
		last_alarm=elapsed
		suspicion=0
		auction_time=max(0,auction_time-15)
		body.position=Vector3(-7.8,4.02,-17.0) if body.position.y>3.8 else Vector3(-7.9,.025,-10.50)
		yaw=0
		pitch=-.06
		update_look()
		ui.alarm("COVER COMPROMISED / 15 seconds lost")
		play_fx("alarm")
		save_game()

func sees_player(origin,forward,range_,cosine):
	var target=cam.global_position
	var v=target-origin
	if v.length()>range_ or v.normalized().dot(forward)<cosine:return false
	var q=PhysicsRayQueryParameters3D.create(origin,target)
	q.exclude=[body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func start_game():
	release_mouse()
	crouched=false
	climbing=false
	shape.height=1.70
	collision.position.y=.85
	head.position.y=1.62
	flashlight_on=false
	torch.visible=false
	zoomed=false
	mobile_run=false
	suspicion=0
	stamina=1
	set_tool(0)
	state="shop_repair"
	repair_step=0
	removed_screws.clear()
	tightened_screws.clear()
	mission_step=0
	case_taken=false
	feed_identified=false
	camera_isolated=false
	camera_loop=false
	fuse_rating=-1
	fuse_installed=false
	pump_power=false
	valves=[0.0,0.0,1.0]
	temperature=38.0
	copy_progress=0
	copy_started=false
	evidence=false
	ups_off=[false,false]
	key_screws.clear()
	key_open=false
	key_verified=false
	key_down=false
	finished=false
	secrets.clear()
	notes.clear()
	alerts=0
	auction_time=1200
	play_time=0
	voice.stop()
	cine_name=""
	load_location("shop")
	body.position=Vector3(-2.2,.02,-1.81)
	yaw=0
	pitch=-.34
	cam.reparent(head,false)
	cam.transform=Transform3D.IDENTITY
	update_look()
	ui.close_panel(false)
	ui.set_state()
	capture_mouse()
	save_game()
	ui.toast("Ms. Ellis is waiting. Make her old PC dependable again.")

func depart():
	release_mouse()
	load_location("vault")
	body.position=Vector3(-7.85,.03,5.7)
	yaw=0
	pitch=0
	flashlight_on=false
	torch.visible=false
	begin_cinematic("arrival")

func begin_cinematic(name):
	cine_name=name
	state=name
	cine_index=-1
	release_mouse()
	cam.reparent(self,true)
	hand_root.visible=false
	ui.close_panel(false)
	ui.set_state()
	next_line()

func next_line():
	if cine_name=="":return
	voice.stop()
	cine_index+=1
	var lines=dialogue[cine_name]
	if cine_index>=lines.size():finish_cinematic();return
	var line=lines[cine_index]
	cine_clock=float(line.duration)+.75
	voice_line=line
	ui.show_line(line,true)
	if voices_on:
		voice.stream=load("res://assets/audio/"+line.audio+".ogg")
		voice.play()
	set_shot(line.shot)

func set_shot(shot):
	if location=="shop":
		var other=Vector3(.58,1.47,1.0) if cine_name=="opening" and cine_index<8 else Vector3(.88,1.70,1.05)
		cine_pos=Vector3(.10,1.64,-.58)
		cine_aim=other
		if shot in ["counter","ellis"]:cine_pos=Vector3(.13,1.64,-.55)
		if shot in ["chime","oleg_enter"]:
			if shot=="chime":play_fx("chime")
			cine_aim=Vector3(2.80,1.63,3.65)
			move_actor("oleg",Vector3(2.8,0,3.40),3.0)
		if shot=="escort":
			move_actor("ellis",Vector3(2.60,0,3.55),4.5)
			cine_pos=Vector3(1.8,1.64,2.30)
			cine_aim=Vector3(2.6,1.46,3.55)
		if shot=="car":
			move_actor("ellis",Vector3(3.12,0,7.4),4.1)
			cine_pos=Vector3(2.80,1.64,5.65)
			cine_aim=Vector3(3.12,1.47,7.4)
		if shot=="return":
			world.actors.ellis.visible=false
			world.actors.oleg.position=Vector3(.88,0,1.05)
			world.face(world.actors.oleg,cine_pos)
		if shot=="case":
			cine_pos=Vector3(-.35,1.65,-.51)
			cine_aim=Vector3(-.37,1.12,-.02)
		if shot in ["cat","wide"] and cine_name=="ending":
			cine_pos=Vector3(-2.9,1.63,.82)
			cine_aim=Vector3(-3.46,.4,1.78)
		if shot=="phone":
			cine_pos=Vector3(-.33,1.63,-.5)
			cine_aim=Vector3(-.40,1.13,-.02)
	else:
		cine_pos=Vector3(-7.85,1.65,5.7)
		cine_aim=Vector3(-7.85,1.7,2.2)
		if cine_name=="core":
			cine_pos=Vector3(.12,1.65,-22.53)
			cine_aim=Vector3(.15,1.28,-23.12)
	if cam.global_position.distance_to(cine_pos)>2.3:
		cam.global_position=cine_pos
		ui.cinematic_cut()

func process_cinematic(dt):
	cine_clock-=dt
	if cine_clock<=0:next_line()
	cam.global_position=cam.global_position.lerp(cine_pos,1-exp(-dt*2.2))
	if cine_aim.distance_to(cam.global_position)>.1:cam.look_at(cine_aim+Vector3(0,sin(elapsed*1.8)*.0015,0))

func finish_cinematic():
	voice.stop()
	var scene=cine_name
	cine_name=""
	ui.clear_line()
	cam.reparent(head,false)
	cam.transform=Transform3D.IDENTITY
	if scene=="opening":
		world.actors.ellis.visible=false
		world.actors.oleg.position=Vector3(.88,0,1.05)
		world.face(world.actors.oleg,Vector3(.1,0,-.5))
		body.position=Vector3(.15,.02,-.66)
		yaw=PI
		pitch=-.12
		state="shop"
	elif scene=="arrival":
		state="vault"
		body.position=Vector3(-7.85,.03,5.5)
		yaw=0
		pitch=0
	elif scene=="core":
		state="vault"
		body.position=Vector3(.15,.03,-22.46)
		yaw=0
		pitch=-.36
	elif scene=="ending":
		state="results"
		finished=true
	update_look()
	ui.set_state()
	if state=="results":ui.show_results()
	else:capture_mouse()
	save_game()

func ending():
	finished=true
	load_location("shop")
	world.actors.ellis.visible=false
	world.actors.oleg.position=Vector3(.88,0,1.05)
	world.face(world.actors.oleg,Vector3(.1,0,-.5))
	begin_cinematic("ending")

func move_actor(id,target,duration):
	if not world.actors.has(id):return
	var n=world.actors[id]
	actor_motion[id]={"n":n,"from":n.position,"to":target,"time":0.0,"duration":duration}

func process_actors(dt):
	for id in actor_motion.keys():
		var m=actor_motion[id]
		if not is_instance_valid(m.n):actor_motion.erase(id);continue
		m.time+=dt
		m.n.position=m.from.lerp(m.to,clampf(m.time/m.duration,0,1))
		world.face(m.n,m.to)
		for side in ["L","R"]:
			var leg=m.n.find_child("Leg_"+side,true,false)
			var arm=m.n.find_child("Arm_"+side,true,false)
			var phase=0 if side=="L" else PI
			if leg:leg.rotation.x=sin(m.time*6.0+phase)*.27
			if arm:arm.rotation.x=-sin(m.time*6.0+phase)*.12
		if m.time>=m.duration:
			for bone in ["Leg_L","Leg_R","Arm_L","Arm_R"]:
				var b=m.n.find_child(bone,true,false)
				if b:b.rotation.x=0
			actor_motion.erase(id)
	if location=="shop":
		for id in ["ellis","oleg"]:
			var n=world.actors.get(id)
			if not n or not n.visible:continue
			var jaw=n.find_child("Jaw",true,false)
			if jaw:
				if not jaw.has_meta("rest_y"):jaw.set_meta("rest_y",jaw.position.y)
				var speaking=voice.playing and voice_line.get("speaker","")==("MS. ELLIS" if id=="ellis" else "OLEG")
				jaw.position.y=float(jaw.get_meta("rest_y"))-(abs(sin(elapsed*13))* .004 if speaking else 0)
		var cat=world.actors.get("bios")
		if cat:cat.scale.y=1+sin(elapsed*1.9)*.006

func play_fx(id):
	var path="res://assets/audio/"+id+".ogg"
	if ResourceLoader.exists(path):
		fx.stream=load(path)
		fx.play()

func play_hint(id):
	if not dialogue.get("hints",{}).has(id):return
	var line=dialogue.hints[id]
	voice_line=line
	speech_clock=float(line.duration)+1
	ui.show_line(line,false)
	if voices_on:
		voice.stream=load("res://assets/audio/"+line.audio+".ogg")
		voice.play()

func add_secret(id,words):
	if not secrets.has(id):
		secrets.append(id)
		play_fx("success")
		ui.toast("DISCOVERY / "+words)
		save_game()
	else:ui.toast(words)

func toggle_music():
	music_on=not music_on
	if music_on:music.play()
	else:music.stop()
	save_game()

func toggle_voices():
	voices_on=not voices_on
	if not voices_on:voice.stop()
	save_game()

func has_save()->bool:return FileAccess.file_exists("user://shift-fps.json")

func read_save():
	if not has_save():return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string("user://shift-fps.json"))
	return data if data is Dictionary else {}

func save_game():
	var data={}
	if state=="title" and has_save():data=read_save()
	else:
		for key in ["location","repair_step","removed_screws","tightened_screws","mission_step","case_taken","feed_identified","camera_isolated","camera_loop","fuse_rating","pump_power","fuse_installed","valves","temperature","copy_progress","copy_started","evidence","ups_off","key_screws","key_open","key_verified","key_down","finished","secrets","notes","alerts","auction_time","play_time"]:data[key]=get(key)
		data["position"]=[body.position.x,body.position.y,body.position.z]
		data["yaw"]=yaw
		data["pitch"]=pitch
	data["music_on"]=music_on
	data["voices_on"]=voices_on
	data["look_sensitivity"]=look_sensitivity
	data["graphics_quality"]=graphics_quality
	var saved=JSON.stringify(data)
	var f=FileAccess.open("user://shift-fps.json",FileAccess.WRITE)
	if f:
		f.store_string(saved)
		f.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{try{localStorage.setItem('steve.dead_battery.first_person.v2',"+JSON.stringify(saved)+");}catch(e){}})();")

func restore_web_save():
	if not OS.has_feature("web"):return
	var saved=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('steve.dead_battery.first_person.v2');}catch(e){return null;}})();")
	if saved is String and JSON.parse_string(saved) is Dictionary:
		var f=FileAccess.open("user://shift-fps.json",FileAccess.WRITE)
		if f:
			f.store_string(saved)
			f.close()

func load_preferences():
	var data=read_save()
	music_on=data.get("music_on",true)
	voices_on=data.get("voices_on",true)
	look_sensitivity=data.get("look_sensitivity",.0024)
	graphics_quality=clampi(int(data.get("graphics_quality",1)),0,2)

func resume_game():
	var data=read_save()
	if data.is_empty():start_game();return
	for key in data:
		if key not in ["position","yaw","pitch"]:set(key,data[key])
	load_location(location)
	body.position=world.vec(data.get("position",[-2.2,.02,-1.81]))
	yaw=float(data.get("yaw",0))
	pitch=float(data.get("pitch",-.24))
	state="shop_repair" if location=="shop" and repair_step<10 else ("shop" if location=="shop" else "vault")
	if location=="shop" and repair_step>=10:
		world.actors.ellis.visible=false
		world.actors.oleg.position=Vector3(.88,0,1.05)
	if finished:
		state="shop"
		body.position=Vector3(-2.4,.02,1.7)
	ui.close_panel(false)
	cam.reparent(head,false)
	cam.transform=Transform3D.IDENTITY
	update_look()
	ui.set_state()
	capture_mouse()
	ui.toast("SHIFT RESUMED / Progress and tools restored.")

func export_state():
	if not OS.has_feature("web"):return
	var targets={}
	for a in tasks.targets:
		if tasks.active(a.id):
			var point=tasks.target_position(a.id,a.p)
			targets[a.id]={"p":[point.x,point.y,point.z],"tool":tasks.required_tool(a.id),"duration":a.duration,"screen":[cam.unproject_position(point).x,cam.unproject_position(point).y]}
	var sz=ui.root.get_viewport_rect().size
	var info={"fps":Engine.get_frames_per_second(),"ready":true,"state":state,"location":location,"repair":repair_step,"step":mission_step,"case":case_taken,"tool":tool,"position":[body.position.x,body.position.y,body.position.z],"eye":[cam.global_position.x,cam.global_position.y,cam.global_position.z],"yaw":yaw,"pitch":pitch,"focus":focus.get("id",""),"hold":hold_progress,"panel":panel_open,"secrets":secrets.size(),"alerts":alerts,"crouched":crouched,"valves":valves,"temperature":temperature,"pressure":pressure,"flow":flow,"copy":copy_progress,"evidence":evidence,"key_down":key_down,"removed":removed_screws.size(),"tightened":tightened_screws.size(),"key_screws":key_screws.size(),"feed":feed_identified,"isolated":camera_isolated,"green":fmod(elapsed,5.0)<2.1,"line":cine_index,"viewport":[sz.x,sz.y],"targets":targets,"controls":ui.button_snapshot()}
	JavaScriptBridge.eval("window.steveState="+JSON.stringify(info)+";")
