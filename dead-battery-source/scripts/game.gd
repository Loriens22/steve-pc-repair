extends Node3D

const HUD = preload("res://scripts/hud.gd")
const Puzzles = preload("res://scripts/puzzles.gd")
var ui
var puzzle
var camera: Camera3D
var environment: WorldEnvironment
var world: Node3D
var body: CharacterBody3D
var hero: Node3D
var actors: Dictionary = {}
var cat: Node3D
var legs: Array = []
var arms: Array = []
var state = "title"
var location = "shop"
var finished = false
var panel_open = false
var mobile = false
var touch_move = Vector2.ZERO
var touch_sprint = false
var nearest_id = ""
var interactions: Dictionary = {}
var obstacles: Array = []
var nav: AStarGrid2D
var path: Array = []
var destination_id = ""
var mission_step = 0
var case_taken = false
var secrets: Array = []
var alerts = 0
var play_time = 0.0
var elapsed = 0.0
var music_on = true
var voices_on = true
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var fx: AudioStreamPlayer
var steps: AudioStreamPlayer
var foot_clock = 0.0
var cinematic_name = ""
var cinematic_lines: Array = []
var cinematic_index = -1
var dialogue_clock = 0.0
var dialogue_data: Dictionary
var cine_goal = Vector3.ZERO
var cine_aim = Vector3.ZERO
var cine_active = false
var yaw = .62
var zoom = 25.0
var camera_target = Vector3.ZERO
var rotating = false
var move_phase = 0.0
var drone: Node3D
var cone: MeshInstance3D
var drone_path = [Vector3(-6,0,6),Vector3(-6,0,.1),Vector3(6,0,.1),Vector3(6,0,6)]
var drone_index = 0
var drone_dir = Vector3.FORWARD
var suspicion = 0.0
var last_alert = -20.0
var lasers: Node3D
var suspicion_ui: Label
var pop_anim: Array = []
var export_tick = 0.0
var actor_tweens: Array = []
var actor_previous: Dictionary = {}
var actor_limbs: Dictionary = {}
var hero_previous = Vector3.ZERO

func _ready():
	Engine.max_physics_steps_per_frame=32
	mobile=DisplayServer.window_get_size().x<760
	get_tree().root.content_scale_size=Vector2i(440,780) if mobile else Vector2i(1440,900)
	Input.emulate_mouse_from_touch=true
	var file=FileAccess.open("res://assets/dialogue.json",FileAccess.READ)
	dialogue_data=JSON.parse_string(file.get_as_text())
	setup_environment()
	setup_player()
	setup_audio()
	restore_web_save()
	load_location("shop")
	camera=Camera3D.new()
	camera.fov=42
	camera.near=.1
	camera.far=170
	camera.position=Vector3(19,23,29)
	add_child(camera)
	camera.current=true
	ui=HUD.new()
	add_child(ui)
	ui.setup(self)
	ui.rebuild_markers()
	ui.update_objective()
	suspicion_ui=ui.label_to(ui.root,"",14,Color("f0a571"))
	suspicion_ui.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	load_preferences()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.steveReady = true;")

func setup_environment():
	environment=WorldEnvironment.new()
	var e=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("15272c")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("c4d3c1")
	e.ambient_light_energy=.28
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure=1.05
	e.fog_enabled=true
	e.fog_light_color=Color("15303a")
	e.fog_density=.004
	environment.environment=e
	add_child(environment)
	var sun=DirectionalLight3D.new()
	sun.name="Sun"
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("ffe0b4")
	sun.light_energy=.65
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65
	sun.shadow_bias=.04
	add_child(sun)
	var fill=DirectionalLight3D.new()
	fill.name="Fill"
	fill.rotation_degrees=Vector3(-24,142,0)
	fill.light_color=Color("76b9c5")
	fill.light_energy=.18
	add_child(fill)

func setup_player():
	body=CharacterBody3D.new()
	body.name="Steve"
	add_child(body)
	var collision=CollisionShape3D.new()
	var capsule=CapsuleShape3D.new()
	capsule.height=1.65
	capsule.radius=.23
	collision.shape=capsule
	collision.position.y=.86
	body.add_child(collision)
	hero=load("res://assets/models/steve.glb").instantiate()
	body.add_child(hero)
	for n in ["Leg_L","Leg_R"]:legs.append(hero.find_child(n,true,false))
	for n in ["Arm_L","Arm_R"]:arms.append(hero.find_child(n,true,false))

func setup_audio():
	music=AudioStreamPlayer.new()
	music.volume_db=-12
	add_child(music)
	music.finished.connect(func():
		if music_on:music.play())
	voice=AudioStreamPlayer.new()
	voice.volume_db=0
	add_child(voice)
	fx=AudioStreamPlayer.new()
	fx.volume_db=-6
	add_child(fx)
	steps=AudioStreamPlayer.new()
	steps.stream=load("res://assets/audio/footstep.ogg")
	steps.volume_db=-14
	add_child(steps)

func play_music():
	music.stream=load("res://assets/audio/"+location+"_ambience.ogg")
	if music_on:music.play()

func toggle_music():
	music_on=not music_on
	if music_on:music.play()
	else:music.stop()
	save_game()

func sfx(name: String):
	fx.stream=load("res://assets/audio/"+name+".ogg")
	fx.play()

func add_obstacle(p: Vector3,s: Vector3):
	var b=StaticBody3D.new()
	var c=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=s
	c.shape=shape
	b.position=p
	b.add_child(c)
	world.add_child(b)
	if s.y>.2 and p.y+s.y/2>.3:
		obstacles.append(Rect2(Vector2(p.x-s.x/2-.31,p.z-s.z/2-.31),Vector2(s.x+.62,s.z+.62)))

func light_at(p: Vector3,color: Color,energy: float,range_value: float=8):
	var l=OmniLight3D.new()
	l.position=p
	l.light_color=color
	l.light_energy=energy*.25
	l.omni_range=range_value
	world.add_child(l)

func actor(id: String,p: Vector3,angle: float=0):
	var a=load("res://assets/models/"+id+".glb").instantiate()
	a.position=p
	a.rotation.y=angle
	world.add_child(a)
	actors[id]=a
	actor_previous[id]=p
	actor_limbs[id]=[a.find_child("Leg_L",true,false),a.find_child("Leg_R",true,false),a.find_child("Arm_L",true,false),a.find_child("Arm_R",true,false)]
	return a

func interactable(id: String,label: String,p: Vector3,stand: Vector3,radius: float=1.65):
	interactions[id]={"name":label,"pos":p,"stand":stand,"radius":radius}

func load_location(loc: String):
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world=Node3D.new()
	add_child(world)
	location=loc
	actors.clear()
	actor_previous.clear()
	actor_limbs.clear()
	interactions.clear()
	obstacles.clear()
	path.clear()
	destination_id=""
	nearest_id=""
	drone=null
	lasers=null
	cat=null
	var geometry=load("res://assets/models/"+loc+".glb").instantiate()
	world.add_child(geometry)
	if loc=="shop":
		add_obstacle(Vector3(2,-.35,0),Vector3(24,.65,14))
		add_obstacle(Vector3(0,1.8,-7),Vector3(18,3.6,.18))
		add_obstacle(Vector3(-9,1.8,0),Vector3(.18,3.6,14))
		add_obstacle(Vector3(-.8,.6,-.75),Vector3(7.3,1.2,1.1))
		add_obstacle(Vector3(-3,.5,-4.9),Vector3(8,1,1.65))
		add_obstacle(Vector3(-8.25,1.35,-1.65),Vector3(1.14,2.7,5.4))
		add_obstacle(Vector3(5.5,.5,-5.15),Vector3(3,1,1.25))
		for x in [4.8,6.4]:add_obstacle(Vector3(x,.6,2.6),Vector3(1.2,1.2,.95))
		add_obstacle(Vector3(5.6,.25,4.15),Vector3(2.4,.5,.8))
		add_obstacle(Vector3(12.2,.9,3.9),Vector3(2.2,1.8,4.2))
		body.position=Vector3(.2,.04,1.4)
		hero.rotation.y=PI
		actor("ellis",Vector3(2.9,.04,1.05),PI+.25)
		actor("oleg",Vector3(7.5,.04,-.6),-PI/2)
		cat=actor("bios",Vector3(-4.9,.25,3.1),.6)
		light_at(Vector3(-3,3.3,-3.8),Color("ffd7a0"),1.9,10)
		light_at(Vector3(5,3.2,-3),Color("ead7b4"),1.2,8)
		light_at(Vector3(-2,3,-6),Color("99e4b5"),.65,6)
		interactable("case","Oleg's briefcase",Vector3(-1.25,1.58,-.75),Vector3(-1.25,0,.47),2)
		interactable("pc","Ms. Ellis's computer",Vector3(1,1.9,-.3),Vector3(1.2,0,.6),2)
		interactable("cat","Pet BIOS",Vector3(-4.9,.8,3.1),Vector3(-4,0,3),1.7)
		interactable("coffee","Coffee of unknown age",Vector3(5.9,1.4,-4.9),Vector3(5.7,0,-3.7),2)
		interactable("floppy","A suspicious floppy",Vector3(-8.1,2.4,.4),Vector3(-6.95,0,.6),2)
		interactable("tools","The honest toolkit",Vector3(-3.4,1.5,-4.6),Vector3(-3.7,0,-3.5),2)
		interactable("calendar","Thursday's appointments",Vector3(3.8,2.2,-6.2),Vector3(3.75,0,-5.5),2)
		interactable("magazine","BYTE magazine",Vector3(5.4,.8,4.15),Vector3(4.2,0,4.4),1.8)
		interactable("register","The repair ledger",Vector3(-3.7,1.5,-.5),Vector3(-3.4,0,.6),2)
		interactable("door","Leave for Tallinn",Vector3(8.8,1.3,-.7),Vector3(7.8,0,-.6),1.6)
		environment.environment.background_color=Color("1c3034")
		environment.environment.ambient_light_energy=.28
		get_node("Sun").light_color=Color("ffdcad")
		get_node("Sun").light_energy=.65
	else:
		add_obstacle(Vector3(0,-.35,0),Vector3(24,.65,20))
		add_obstacle(Vector3(0,2,-10),Vector3(24,4,.25))
		add_obstacle(Vector3(-12,2,0),Vector3(.25,4,20))
		for x in [-7,-3,2,6.5]:
			for z in [-6,-3.5]:add_obstacle(Vector3(x,1.35,z),Vector3(1.62,2.7,1.1))
		add_obstacle(Vector3(-9,.5,2.25),Vector3(3,1,1.3))
		add_obstacle(Vector3(2.3,1.35,-8.1),Vector3(1.4,2.7,1.4))
		add_obstacle(Vector3(2.3,.42,-6.75),Vector3(1.9,.84,.65))
		add_obstacle(Vector3(8.8,.5,4.5),Vector3(2.1,1,1.05))
		body.position=Vector3(8,.04,7.4)
		hero.rotation.y=PI
		interactable("badge","The service cart",Vector3(8.6,1.45,4.5),Vector3(8.6,0,5.6),1.8)
		interactable("security","Security console",Vector3(-9,1.7,2.3),Vector3(-9,0,3.5),1.8)
		interactable("coolant","Coolant valves",Vector3(-11.2,1.7,-3.8),Vector3(-10.2,0,-3.8),1.8)
		interactable("core","The Widowmaker",Vector3(2.3,2.3,-8.1),Vector3(4.2,0,-7.3),2.1)
		interactable("lift","Roof extraction",Vector3(9.1,2,-9.4),Vector3(9.1,0,-8.7),1.9)
		interactable("server","The pension records",Vector3(-3,1.6,-3.1),Vector3(-3,0,-2.2),1.8)
		interactable("note","A maintenance note",Vector3(-8.3,1.7,2.1),Vector3(-7.2,0,2.9),2)
		interactable("rack","A familiar serial number",Vector3(6.5,1.6,-5.5),Vector3(6.5,0,-4.9),1.7)
		light_at(Vector3(2.3,2.6,-8.1),Color("49d6d9"),3,7)
		for p in [Vector3(-6,3,-4),Vector3(7,3,-4),Vector3(-8,3,3)]:light_at(p,Color("72b4c9"),1.5,9)
		light_at(Vector3(8,2.4,7),Color("eaa867"),1.4,8)
		environment.environment.background_color=Color("0d1f29")
		environment.environment.ambient_light_energy=.23
		get_node("Sun").light_color=Color("8eafc8")
		get_node("Sun").light_energy=.55
		create_drone()
		create_lasers()
		create_rain()
	build_nav()
	if is_instance_valid(ui):
		ui.rebuild_markers()
		ui.update_objective()
	play_music()

func build_nav():
	nav=AStarGrid2D.new()
	nav.region=Rect2i(0,0,76,64)
	nav.cell_size=Vector2(.4,.4)
	nav.offset=Vector2(-13,-11)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for x in range(76):
		for y in range(64):
			var p=nav.get_point_position(Vector2i(x,y))
			var valid=(p.x> -8.65 and p.x<13 and p.y> -6.65 and p.y<6.65) if location=="shop" else (p.x> -11.5 and p.x<11.5 and p.y> -9.4 and p.y<9.4)
			for r in obstacles:
				if r.has_point(p):valid=false
			nav.set_point_solid(Vector2i(x,y),not valid)

func grid_point(p: Vector3) -> Vector2i:
	var point=Vector2i(round((p.x+13)/.4),round((p.z+11)/.4))
	point.x=clampi(point.x,0,75)
	point.y=clampi(point.y,0,63)
	if nav.is_point_solid(point):
		for radius in range(1,6):
			for x in range(-radius,radius+1):
				for y in range(-radius,radius+1):
					var q=point+Vector2i(x,y)
					if nav.is_in_boundsv(q) and not nav.is_point_solid(q):return q
	return point

func navigate(p: Vector3):
	var points=nav.get_point_path(grid_point(body.position),grid_point(p))
	path.clear()
	for q in points:path.append(Vector3(q.x,.04,q.y))
	if path.size()>0:path.pop_front()

func go_to_interaction(id: String):
	if panel_open or state not in ["shop","vault"]:return
	destination_id=id
	navigate(interactions[id].stand)
	if body.position.distance_to(interactions[id].stand)<.65:
		interact(id)
		destination_id=""

func start_game():
	finished=false
	case_taken=false
	mission_step=0
	secrets.clear()
	alerts=0
	play_time=0
	load_location("shop")
	body.position=Vector3(.5,.04,-2.5)
	hero.rotation.y=0
	actors.oleg.visible=false
	begin_cinematic("opening")

func restart():
	voice.stop()
	start_game()

func begin_cinematic(name: String):
	state=name
	cinematic_name=name
	cinematic_lines=dialogue_data[name]
	cinematic_index=-1
	cine_active=true
	path.clear()
	body.velocity=Vector3.ZERO
	ui.set_state(state)
	next_dialogue()

func next_dialogue():
	if not cine_active:return
	voice.stop()
	cinematic_index+=1
	if cinematic_index>=cinematic_lines.size():
		finish_cinematic()
		return
	var line=cinematic_lines[cinematic_index]
	ui.show_line(line)
	dialogue_clock=line.duration+.7
	if voices_on:
		voice.stream=load("res://assets/audio/"+line.audio+".ogg")
		voice.play()
	set_shot(line.shot,line.speaker)

func skip_cinematic():
	if not cine_active:return
	voice.stop()
	finish_cinematic()

func finish_cinematic():
	cine_active=false
	for t in actor_tweens:
		if t.is_valid():t.kill()
	actor_tweens.clear()
	if cinematic_name=="opening":
		actors.ellis.visible=false
		actors.oleg.visible=true
		actors.oleg.position=Vector3(-1.2,.04,-2)
		body.position=Vector3(.2,.04,1.4)
		state="shop"
	elif cinematic_name=="arrival":state="vault"
	elif cinematic_name=="core":
		state="vault"
		ui.set_state(state)
		ui.update_objective()
		open_puzzle("core")
		return
	elif cinematic_name=="ending":
		state="results"
		finished=true
		ui.set_state(state)
		ui.results()
		save_game()
		return
	ui.set_state(state)
	ui.update_objective()
	save_game()

func actor_move(node: Node3D,p: Vector3,duration: float):
	var t=create_tween()
	t.tween_property(node,"position",p,duration)
	actor_tweens.append(t)

func set_shot(shot: String,speaker_name: String):
	var focus=body.position+Vector3(0,1,0)
	var dist=Vector3(4,3,6)
	if location=="shop":
		if shot in ["counter","wide"]:
			focus=Vector3(.5,.9,-.4)
			dist=Vector3(13,12,19)
		elif shot=="ellis":
			focus=actors.ellis.position+Vector3(0,1.3,0)
			dist=Vector3(-3,2.8,-5)
		elif shot in ["oleg","return"]:
			focus=actors.oleg.position+Vector3(0,1.3,0)
			if shot=="return":
				body.position=Vector3(-.1,.04,-2.9)
				actors.oleg.position=Vector3(-1.2,.04,-2.7)
				actors.oleg.rotation.y=.8
				focus=Vector3(-.9,1,-2.5)
		elif shot=="chime":
			sfx("chime")
			actors.oleg.visible=true
			actor_move(actors.oleg,Vector3(4,.04,-2.6),4)
		elif shot=="oleg_enter":
			focus=Vector3(5,.9,-1.5)
			dist=Vector3(6,4,8)
		elif shot in ["escort","car"]:
			if shot=="escort":
				actor_move(body,Vector3(10,.04,-.5),5)
				actor_move(actors.ellis,Vector3(11,.04,1),6)
				actors.ellis.rotation.y=PI/2
			focus=Vector3(10.7,1,1.5)
			dist=Vector3(5,3.3,8)
		elif shot=="case":
			focus=Vector3(-1.25,1.4,-.75)
			dist=Vector3(2.5,2.4,3)
		elif shot=="cat":
			focus=cat.position+Vector3(0,.25,0)
			dist=Vector3(3,2.3,4)
		elif shot=="phone":
			focus=Vector3(-1.2,1.5,-.7)
			dist=Vector3(2,1.8,3)
		elif shot=="end":
			focus=Vector3(-1,1,0)
			dist=Vector3(10,8,13)
	else:
		if shot in ["vault","wide"]:
			focus=Vector3(0,1,-1)
			dist=Vector3(17,20,25)
		elif shot=="cart":
			focus=Vector3(8.8,1,4.5)
			dist=Vector3(4,3.5,6)
		elif shot=="core":
			focus=Vector3(2.3,1.5,-8.1)
			dist=Vector3(5,4,7)
		elif shot=="steve":dist=Vector3(3.5,2.4,4.5)
	cine_aim=focus
	cine_goal=focus+dist

func objective_text() -> String:
	if finished:return "Job done. Pet the cat."
	if location=="shop":return "Leave through the shop door." if case_taken else "Inspect Oleg's briefcase."
	return ["Collect your cover identity from the service cart.","Loop surveillance at the security console.","Balance the coolant valves.","Reach the Widowmaker core.","Reach the roof lift. Get home.","Case closed."][clampi(mission_step,0,5)]

func marker_available(id: String) -> bool:
	if id=="case":return not case_taken
	if id=="badge":return mission_step==0
	if id=="security":return mission_step<=1
	if id=="coolant":return mission_step<=2
	if id=="core":return mission_step<=3
	return true

func interact_nearest():
	if panel_open or nearest_id=="":return
	interact(nearest_id)

func interact(id: String):
	if panel_open or state not in ["shop","vault"]:return
	sfx("click")
	path.clear()
	destination_id=""
	match id:
		"case":open_puzzle("case")
		"pc":open_puzzle("diagnostic")
		"cat":
			find_secret("bios")
			sfx("pet")
			ui.inspect("BIOS. Basic Input, Orange Sweetheart.","He has no idea what you do at night.\nHe knows you come back.\n\nA tiny tag on his collar reads: IF LOST, TURN OFF AND ON AGAIN.")
			var t=create_tween()
			t.tween_property(cat,"rotation:y",cat.rotation.y+.5,.5)
			t.tween_property(cat,"rotation:y",cat.rotation.y,1)
		"coffee":
			find_secret("coffee")
			touch_sprint=true
			ui.inspect("The coffee has seniority.","This pot predates at least three governments.\n\nSteve takes a sip. He can now hear the fluorescent lights arguing.\n\nHURRY mode enabled. Probably fine.")
		"floppy":
			find_secret("floppy")
			ui.inspect("NOT A BOOT DISK", "The label says FAMILY PHOTOS.\nThe directory says: operation_tea_kettle / 1998.\n\nOne file: README.TXT\n\n‘If anyone asks, we were installing a printer.’\n— Oleg")
		"tools":ui.inspect("A very ordinary toolkit.","A soldering iron. Tweezers. A number-two screwdriver.\n\nThe screwdriver has visited seventeen countries. The passport has visited twelve.\n\nSteve keeps the receipts.")
		"calendar":
			find_secret("thursday")
			ui.inspect("Thursday. Always Thursday.","09:00 / Ms. Ellis — clean and a cup of tea\n10:30 / Mr. Patel — ‘the internet is heavy’\n12:00 / Mrs. Cooper — find the mouse\n\nThe last entry is in a different handwriting:\nFEED YOURSELF TOO, STEVEN.\n— Ellis")
		"magazine":
			find_secret("byte")
			ui.inspect("A future worth 640 kilobytes.","BYTE / October 1998\nCover: ‘The future fits on your desktop.’\n\nSteve's margin note: ‘Except when it wants a first-class ticket.’\n\nThe crossword answer to 7-down is BIOS. The cat appears pleased.")
		"register":ui.inspect("The repair ledger.","ELLIS / CR2032 / £2.00\nPATEL / Loose cable / £0.00\nCOOPER / Mouse recovered / £0.00\n\nTHOMAS / Consulting / PAID IN FULL\n\nThe last entry has a lot more zeroes.")
		"door":
			if finished:ui.toast("The only thing left to fix tonight is dinner.")
			elif not case_taken:ui.toast("The briefcase is on the counter. A job needs its tools.")
			else:
				sfx("door")
				load_location("vault")
				begin_cinematic("arrival")
		"badge":
			mission_step=1
			ui.toast("COVER SECURED / STEVEN THOMAS / NIGHT MAINTENANCE")
			ui.update_objective()
			save_game()
		"security":
			if mission_step<1:ui.toast("A service identity first. Check the cart by the entrance.")
			elif mission_step==1:open_puzzle("circuit")
			else:ui.toast("Surveillance is looped. The drone still uses its own eyes.")
		"coolant":
			if mission_step<2:ui.toast("The valves are monitored. Loop surveillance first.")
			elif mission_step==2:open_puzzle("coolant")
			else:ui.toast("Flow steady. Core temperature 18°C.")
		"core":
			if mission_step<3:ui.toast("The magnetic lock is hot. Restore coolant balance first.")
			elif mission_step==3:begin_cinematic("core")
			else:ui.toast("Signing key destroyed. A very expensive paperweight.")
		"lift":
			if mission_step<4:ui.toast("Not yet. Eight million people are still counting on you.")
			else:
				mission_step=5
				load_location("shop")
				actors.ellis.visible=false
				actors.oleg.position=Vector3(-1.1,.04,-2.2)
				begin_cinematic("ending")
		"note":ui.inspect("Night shift instructions.","SUPPLY / AMBER / 3 L/min\nCORE / BLUE / twice supply\nRETURN / GREEN / same as supply\n\n‘I drew you a diagram, Viktor. Don't improvise.’\n— Maintenance\n\nSteve approves of maintenance.")
		"server":
			find_secret("ellis_file")
			ui.inspect("Page seven.","ELLIS, M. / Age 93 / Widow\nRisk rating: compliant\nBalance available: lifetime savings\n\nSteve is very quiet for a moment.\n\nThe evidence is coming home.")
		"rack":
			find_secret("serial")
			ui.inspect("Warranty sticker.","MRD-281\nUnder the sticker: REPAIRED BY STEVE / 2004\n\nHe remembers the fan noise.\nHe also remembers writing ‘do not use for evil’ on the invoice.\n\nNobody reads the terms.")

func open_puzzle(kind: String):
	puzzle=Puzzles.new()
	puzzle.open(ui,self,kind)

func puzzle_complete(kind: String):
	match kind:
		"case":case_taken=true
		"circuit":mission_step=2
		"coolant":
			mission_step=3
			if is_instance_valid(lasers):lasers.visible=false
		"core":
			mission_step=4
			sfx("shutdown")
			light_at(Vector3(2.3,2,-8.1),Color("ed9c59"),2,7)
	ui.update_objective()
	save_game()

func find_secret(id: String):
	if not secrets.has(id):
		secrets.append(id)
		ui.toast("A SMALL DISCOVERY / %d OF 8" % secrets.size())
		ui.update_objective()
		save_game()

func create_drone():
	drone=Node3D.new()
	drone.position=drone_path[0]+Vector3(0,1.7,0)
	world.add_child(drone)
	var b=MeshInstance3D.new()
	var mesh=SphereMesh.new()
	mesh.radius=.3
	mesh.height=.6
	b.mesh=mesh
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color("253e47")
	mat.metallic=.65
	mat.roughness=.3
	b.material_override=mat
	drone.add_child(b)
	for x in [-.43,.43]:
		var rotor=MeshInstance3D.new()
		var rm=CylinderMesh.new()
		rm.top_radius=.24
		rm.bottom_radius=.24
		rm.height=.055
		rotor.mesh=rm
		rotor.material_override=mat
		rotor.position=Vector3(x,.05,0)
		drone.add_child(rotor)
	var eye=OmniLight3D.new()
	eye.light_color=Color("fa663c")
	eye.light_energy=1.2
	eye.omni_range=3
	eye.position=Vector3(0,-.12,-.27)
	drone.add_child(eye)
	cone=MeshInstance3D.new()
	var cm=ArrayMesh.new()
	var a=[]
	a.resize(Mesh.ARRAY_MAX)
	var vertices=PackedVector3Array()
	var colors=PackedColorArray()
	var width=.52
	for i in range(16):
		var v1=Vector3(sin(-width+i*width*2/16)*5.8,.055,-cos(-width+i*width*2/16)*5.8)
		var v2=Vector3(sin(-width+(i+1)*width*2/16)*5.8,.055,-cos(-width+(i+1)*width*2/16)*5.8)
		vertices.append_array([Vector3(0,.055,0),v1,v2])
		colors.append_array([Color(1,.28,.12,.25),Color(1,.28,.12,.015),Color(1,.28,.12,.015)])
	a[Mesh.ARRAY_VERTEX]=vertices
	a[Mesh.ARRAY_COLOR]=colors
	cm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	cone.mesh=cm
	var m=StandardMaterial3D.new()
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo=true
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	cone.material_override=m
	world.add_child(cone)

func create_lasers():
	lasers=Node3D.new()
	world.add_child(lasers)
	for yy in [.5,1,1.5,2]:
		var m=MeshInstance3D.new()
		var b=BoxMesh.new()
		b.size=Vector3(4.6,.015,.015)
		m.mesh=b
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color("df6446")
		mat.emission_enabled=true
		mat.emission=Color("fb7544")
		mat.emission_energy_multiplier=1.5
		m.material_override=mat
		m.position=Vector3(2.25,yy,-5.65)
		lasers.add_child(m)
	lasers.visible=mission_step<3

func create_rain():
	var rain=MultiMeshInstance3D.new()
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.instance_count=100
	var mesh=BoxMesh.new()
	mesh.size=Vector3(.014,.28,.014)
	mm.mesh=mesh
	var material=StandardMaterial3D.new()
	material.albedo_color=Color(.45,.72,.8,.25)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.material_override=material
	rain.multimesh=mm
	rain.name="Rain"
	for i in range(100):mm.set_instance_transform(i,Transform3D(Basis(),Vector3(randf_range(-16,16),randf_range(.1,9),randf_range(-14,-11))))
	world.add_child(rain)

func _physics_process(dt):
	if not is_instance_valid(body):return
	if state not in ["shop","vault"] or panel_open:
		body.velocity=Vector3.ZERO
		animate_hero(dt,0)
		return
	var input=Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):input.x-=1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):input.x+=1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):input.y-=1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):input.y+=1
	input+=touch_move
	input=input.limit_length()
	var direction=Vector3.ZERO
	if input.length()>.05:
		path.clear()
		destination_id=""
		direction=(camera.global_basis.x*input.x+camera.global_basis.z*input.y)
		direction.y=0
		direction=direction.normalized()
	elif path.size()>0:
		var target=path[0]-body.position
		target.y=0
		if target.length()<.18:
			path.pop_front()
		else:direction=target.normalized()
	elif destination_id!="":
		var id=destination_id
		destination_id=""
		if body.position.distance_to(interactions[id].stand)<1.1:interact(id)
	var speed=5.1 if Input.is_physical_key_pressed(KEY_SHIFT) or touch_sprint else 3.05
	body.velocity.x=direction.x*speed
	body.velocity.z=direction.z*speed
	if not body.is_on_floor():body.velocity.y-=9.81*dt
	else:body.velocity.y=0
	body.move_and_slide()
	var bounds=Vector4(-8.6,12.9,-6.6,6.6) if location=="shop" else Vector4(-11.4,11.4,-9.3,9.3)
	body.position.x=clampf(body.position.x,bounds.x,bounds.y)
	body.position.z=clampf(body.position.z,bounds.z,bounds.w)
	if body.position.y<-.1:body.position.y=.04
	if direction.length()>.05:hero.rotation.y=lerp_angle(hero.rotation.y,atan2(direction.x,direction.z),dt*12)
	animate_hero(dt,direction.length()*speed)
	nearest_id=""
	var best=1000.0
	for id in interactions:
		if not marker_available(id):continue
		var d=body.position.distance_to(interactions[id].stand)
		if d<interactions[id].radius and d<best:
			best=d
			nearest_id=id
	if location=="vault":update_drone(dt)

func animate_hero(dt: float,speed: float):
	move_phase+=dt*speed*3.6
	var amount=min(speed/3.05,1.3)
	for i in range(2):
		if is_instance_valid(legs[i]):legs[i].rotation.x=sin(move_phase+i*PI)*.45*amount
		if is_instance_valid(arms[i]):arms[i].rotation.x=-sin(move_phase+i*PI)*.35*amount
	hero.position.y=sin(move_phase*2)*.024*amount
	if speed>.1:
		foot_clock-=dt
		if foot_clock<=0:
			steps.pitch_scale=randf_range(.85,1.2)
			steps.play()
			foot_clock=.32 if speed<4 else .23

func update_drone(dt):
	if not is_instance_valid(drone):return
	var goal=drone_path[drone_index]+Vector3(0,1.7,0)
	var d=goal-drone.position
	if d.length()<.2:
		drone_index=(drone_index+1)%drone_path.size()
	else:
		drone.position+=d.normalized()*dt*(1.35 if mission_step<4 else 2.1)
		drone_dir=d.normalized()
	drone.position.y=1.7+sin(elapsed*3)*.08
	drone.rotation.y=lerp_angle(drone.rotation.y,atan2(-drone_dir.x,-drone_dir.z),dt*4)
	cone.position=Vector3(drone.position.x,0,drone.position.z)
	cone.rotation.y=drone.rotation.y
	var to=body.position-Vector3(drone.position.x,0,drone.position.z)
	var seen=to.length()<5.8 and to.length()>.2 and to.normalized().dot(drone_dir)>.875
	if seen:
		var query=PhysicsRayQueryParameters3D.create(drone.position,body.position+Vector3(0,.8,0))
		query.exclude=[body.get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		seen=hit.is_empty()
	suspicion=clampf(suspicion+dt*(.85 if seen else -1),0,1)
	if suspicion>=1 and elapsed-last_alert>4:
		alerts+=1
		last_alert=elapsed
		suspicion=0
		sfx("alarm")
		body.position=Vector3(8,.04,7.4)
		path.clear()
		destination_id=""
		ui.toast("SPOTTED / Oleg loops the alarm. Back to your cover. Progress kept.")
		save_game()

func _process(dt):
	elapsed+=dt
	if not is_instance_valid(camera):return
	if cine_active:
		var speed=(body.position-hero_previous).length()/max(dt,.001)
		animate_hero(dt,min(speed,3.0))
		for id in actors:
			var a=actors[id]
			var speed_a=(a.position-actor_previous.get(id,a.position)).length()/max(dt,.001)
			for i in range(4):
				var limb=actor_limbs[id][i]
				if is_instance_valid(limb):limb.rotation.x=sin(elapsed*7+(i%2)*PI)*min(speed_a,.8)*(.45 if i<2 else -.3)
			actor_previous[id]=a.position
	hero_previous=body.position
	if cine_active:
		dialogue_clock-=dt
		if dialogue_clock<=0:next_dialogue()
		camera.position=camera.position.lerp(cine_goal,min(1,dt*1.9))
		camera_target=camera_target.lerp(cine_aim,min(1,dt*2.3))
	else:
		var aim=Vector3(-4.1,.65,0) if state=="title" else Vector3.ZERO.lerp(Vector3(body.position.x,0,body.position.z),.43)
		if location=="vault":aim=Vector3(0,0,-1).lerp(Vector3(body.position.x,0,body.position.z),.35)
		if mobile and state!="title":aim=Vector3(body.position.x,0,body.position.z)
		var angle=yaw+sin(elapsed*.12)*.025 if state=="title" else yaw
		var dist=31.0 if state=="title" else zoom
		if mobile:dist*=.78
		var goal=aim+Vector3(sin(angle)*dist,dist*.74,cos(angle)*dist)
		camera.position=camera.position.lerp(goal,min(1,dt*2.8))
		camera_target=camera_target.lerp(aim,min(1,dt*3.3))
	camera.look_at(camera_target+Vector3(0,.7,0),Vector3.UP)
	if state in ["shop","vault"] and not panel_open:play_time+=dt
	if is_instance_valid(cat):cat.scale.y=1+sin(elapsed*2)*.015
	if location=="vault":
		var rain=world.get_node_or_null("Rain")
		if rain:
			for i in range(100):
				var tr=rain.multimesh.get_instance_transform(i)
				tr.origin.y-=dt*6
				if tr.origin.y<0:tr.origin.y=9
				rain.multimesh.set_instance_transform(i,tr)
	if is_instance_valid(suspicion_ui):
		suspicion_ui.visible=state=="vault" and suspicion>.05
		suspicion_ui.text="PATROL / SUSPICION %d%%" % int(suspicion*100)
		suspicion_ui.position=Vector2(20,ui.root.get_viewport_rect().size.y-(390 if mobile else 250))
		suspicion_ui.size=Vector2(ui.root.get_viewport_rect().size.x-40,25)
	if OS.has_feature("web"):
		export_tick+=dt
		if export_tick>.05:
			export_tick=0
			var marks={}
			for id in interactions:
				var p=camera.unproject_position(interactions[id].pos+Vector3(0,.9,0))
				marks[id]=[p.x,p.y]
			var sz=ui.root.get_viewport_rect().size
			var info={"state":state,"location":location,"step":mission_step,"case":case_taken,"secrets":secrets.size(),"alerts":alerts,"position":[body.position.x,body.position.z],"nearest":nearest_id,"panel":panel_open,"ready":true,"markers":marks,"viewport":[sz.x,sz.y],"line":cinematic_index,"controls":ui.button_snapshot()}
			JavaScriptBridge.eval("window.steveState = "+JSON.stringify(info)+";")

func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode==KEY_ESCAPE:
			if panel_open:ui.dismiss_modal()
			else:ui.show_pause()
		elif e.physical_keycode in [KEY_SPACE,KEY_ENTER] and cine_active:next_dialogue()
		elif e.physical_keycode==KEY_E:interact_nearest()
		elif e.physical_keycode==KEY_J and state in ["shop","vault"]:ui.show_journal()
	if panel_open:return
	if e is InputEventMouseButton:
		if e.button_index==MOUSE_BUTTON_RIGHT:rotating=e.pressed
		if e.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clampf(zoom-1.5,17,42)
		if e.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clampf(zoom+1.5,17,42)
		if e.button_index==MOUSE_BUTTON_LEFT and e.pressed and state in ["shop","vault"]:
			var from=camera.project_ray_origin(e.position)
			var dir=camera.project_ray_normal(e.position)
			if abs(dir.y)>.001:
				var p=from+dir*(-from.y/dir.y)
				destination_id=""
				navigate(p)
	if e is InputEventMouseMotion and rotating:yaw-=e.relative.x*.006

func has_save() -> bool:
	return FileAccess.file_exists("user://shift.json")

func save_game():
	var saved=JSON.stringify({"location":location,"case":case_taken,"step":mission_step,"secrets":secrets,"alerts":alerts,"time":play_time,"music":music_on,"voices":voices_on,"finished":finished})
	var f=FileAccess.open("user://shift.json",FileAccess.WRITE)
	if f:
		f.store_string(saved)
		f.close()
	if OS.has_feature("web"):
		# IndexedDB flushes asynchronously; mirror this small save before a tab can reload.
		JavaScriptBridge.eval("(()=>{try{localStorage.setItem('steve.dead_battery.shift.v1',"+JSON.stringify(saved)+");}catch(e){}})();")

func restore_web_save():
	if not OS.has_feature("web"):return
	var saved=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('steve.dead_battery.shift.v1');}catch(e){return null;}})();")
	if saved is String and JSON.parse_string(saved) is Dictionary:
		var f=FileAccess.open("user://shift.json",FileAccess.WRITE)
		if f:
			f.store_string(saved)
			f.close()

func load_preferences():
	if not has_save():return
	var f=FileAccess.open("user://shift.json",FileAccess.READ)
	var d=JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		music_on=d.get("music",true)
		voices_on=d.get("voices",true)
		if not music_on:music.stop()

func resume_game():
	if not has_save():start_game();return
	var f=FileAccess.open("user://shift.json",FileAccess.READ)
	var d=JSON.parse_string(f.get_as_text())
	case_taken=d.get("case",false)
	mission_step=d.get("step",0)
	secrets=d.get("secrets",[])
	alerts=d.get("alerts",0)
	play_time=d.get("time",0)
	finished=d.get("finished",false)
	load_location(d.get("location","shop"))
	if location=="shop":actors.ellis.visible=false
	state="shop" if location=="shop" else "vault"
	ui.set_state(state)
	ui.update_objective()
	ui.toast("SHIFT RESUMED / Tools accounted for.")

func fullscreen():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(!document.fullscreenElement){document.getElementById('canvas').requestFullscreen?.();}else{document.exitFullscreen?.();}")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)
