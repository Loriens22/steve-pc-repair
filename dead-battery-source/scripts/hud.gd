extends CanvasLayer

const INK = Color("122329")
const PAPER = Color("ede6d1")
const MUTED = Color("9cafaa")
const ACCENT = Color("eba66f")
const GREEN = Color("9bccb6")
var game
var root: Control
var mobile = false
var modal: Control
var title: Control
var top: Control
var objective: Panel
var objective_title: Label
var objective_text: Label
var intel: Label
var prompt: Button
var captions: Panel
var speaker: Label
var dialogue: Label
var next_line: Button
var skip: Button
var upper_bar: ColorRect
var lower_bar: ColorRect
var toast_label: Label
var toast_timer = 0.0
var marker_root: Control
var markers: Dictionary = {}
var touch_root: Control
var stick
var footer: Label
var last_size = Vector2.ZERO
var chapter: Label
var shade: ColorRect

class Thumbstick extends Control:
	var value = Vector2.ZERO
	var active = false
	signal moved(v)
	func _ready():
		mouse_filter=Control.MOUSE_FILTER_STOP
	func _gui_input(e):
		if e is InputEventScreenTouch:
			active=e.pressed
			if not active:
				value=Vector2.ZERO
				moved.emit(value)
		if active and (e is InputEventScreenTouch or e is InputEventScreenDrag):
			value=((e.position-size/2.0)/45.0).limit_length()
			moved.emit(value)
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
			active=e.pressed
			if not active:
				value=Vector2.ZERO
				moved.emit(value)
		if active and (e is InputEventMouseMotion or e is InputEventMouseButton):
			value=((e.position-size/2.0)/45.0).limit_length()
			moved.emit(value)
		queue_redraw()
		accept_event()
	func _draw():
		draw_circle(size/2.0,57,Color(.07,.13,.15,.75))
		draw_arc(size/2.0,56,0,TAU,64,Color(.6,.75,.7,.35),1.5,true)
		draw_circle(size/2.0+value*37,23,Color(.75,.85,.78,.7))
		draw_arc(size/2.0+value*37,22,0,TAU,32,Color(.94,.72,.5),1.5,true)

func setup(g):
	game=g
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	mobile=game.mobile
	shade=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var sh=Shader.new()
	sh.code="shader_type canvas_item; void fragment(){ float a=(1.0-smoothstep(0.0,0.76,UV.x))*0.87; COLOR=vec4(0.025,0.055,0.062,a); }"
	var sm=ShaderMaterial.new()
	sm.shader=sh
	shade.material=sm
	root.add_child(shade)
	create_top()
	create_title()
	create_objective()
	create_dialogue()
	marker_root=Control.new()
	marker_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(marker_root)
	toast_label=Label.new()
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size",15)
	toast_label.add_theme_color_override("font_color",GREEN)
	root.add_child(toast_label)
	footer=Label.new()
	footer.text="WASD  MOVE      CLICK  WALK / INSPECT      E  INTERACT      SHIFT  HURRY      ESC  PAUSE"
	footer.add_theme_font_size_override("font_size",12)
	footer.add_theme_color_override("font_color",MUTED)
	root.add_child(footer)
	create_touch()
	set_state("title")
	layout()

func style(bg: Color=INK, border: Color=Color("354a4c"), radius: int=4) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left=18
	s.content_margin_right=18
	s.content_margin_top=13
	s.content_margin_bottom=13
	return s

func label_to(p, text: String, fs: int=20, color: Color=PAPER) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",fs)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l

func button_to(p,text: String,action: Callable,primary: bool=true) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,50 if mobile else 46)
	b.add_theme_font_size_override("font_size",15 if mobile else 14)
	b.add_theme_color_override("font_color",INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("5f7874"))
	b.add_theme_stylebox_override("normal",style(ACCENT if primary else INK,ACCENT if primary else Color("45605d")))
	b.add_theme_stylebox_override("hover",style(PAPER, PAPER))
	b.add_theme_stylebox_override("pressed",style(GREEN,GREEN))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),PAPER))
	b.add_theme_stylebox_override("disabled",style(Color("1b302e"),Color("33534a")))
	b.pressed.connect(action)
	p.add_child(b)
	return b

func create_top():
	top=Control.new()
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var brand=label_to(top,"S / STEVE",17)
	brand.position=Vector2(0,0)
	brand.size=Vector2(160,28)
	chapter=label_to(top,"DEAD BATTERY   /   CHAPTER 01",11,MUTED)
	chapter.position=Vector2(0,30)
	chapter.size=Vector2(300,22)
	var row=HBoxContainer.new()
	row.name="Controls"
	row.add_theme_constant_override("separation",7)
	top.add_child(row)
	button_to(row,"CASE FILE",show_journal,false)
	button_to(row,"II",show_pause,false).custom_minimum_size=Vector2(48,46)

func create_title():
	title=VBoxContainer.new()
	title.add_theme_constant_override("separation",14)
	root.add_child(title)
	label_to(title,"AN HONEST SHOP. A VERY DIFFERENT NIGHT SHIFT.",11,ACCENT)
	var heading=label_to(title,"STEVE",102 if not mobile else 76)
	heading.add_theme_constant_override("outline_size",0)
	label_to(title,"THE PC REPAIR MAN",25 if not mobile else 20)
	var line=ColorRect.new()
	line.color=ACCENT
	line.custom_minimum_size=Vector2(56,2)
	line.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	title.add_child(line)
	label_to(title,"He fixes old computers.\nAnd problems nobody talks about.",20,MUTED)
	var spacer=Control.new()
	spacer.custom_minimum_size=Vector2(0,12)
	title.add_child(spacer)
	button_to(title,"START THE NIGHT SHIFT     >",game.start_game)
	var resume=button_to(title,"CONTINUE YOUR SHIFT",game.resume_game,false)
	resume.visible=game.has_save()
	label_to(title,"01 / DEAD BATTERY",12,ACCENT)
	label_to(title,"Move with WASD or click to walk. Tap to play on mobile.\nHeadphones recommended · Progress saves on this device.",12,MUTED)

func create_objective():
	objective=Panel.new()
	objective.add_theme_stylebox_override("panel",style(Color(.055,.1,.12,.92),Color("47605a")))
	objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(objective)
	objective_title=label_to(objective,"THE SHOP / 18:42",11,ACCENT)
	objective_title.position=Vector2(18,14)
	objective_text=label_to(objective,"Open Oleg's briefcase.",18 if mobile else 21)
	objective_text.position=Vector2(18,40)
	intel=label_to(objective,"PAYMENT 100%   •   SECRETS 0 / 8",11,MUTED)
	intel.position=Vector2(18,108)
	prompt=button_to(root,"E  /  INSPECT",game.interact_nearest,false)
	prompt.visible=false

func create_dialogue():
	upper_bar=ColorRect.new()
	upper_bar.color=Color(.015,.025,.027,.95)
	upper_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(upper_bar)
	lower_bar=ColorRect.new()
	lower_bar.color=Color(.015,.025,.027,.95)
	lower_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(lower_bar)
	captions=Panel.new()
	captions.add_theme_stylebox_override("panel",style(Color(.04,.075,.083,.95),Color("344b49")))
	captions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(captions)
	speaker=label_to(captions,"STEVE",13,ACCENT)
	speaker.position=Vector2(18,14)
	dialogue=label_to(captions,"",23 if not mobile else 20)
	dialogue.position=Vector2(18,40)
	next_line=button_to(captions,"NEXT LINE   >" if mobile else "SPACE / NEXT LINE   >",game.next_dialogue,false)
	skip=button_to(root,"SKIP SCENE",game.skip_cinematic,false)

func create_touch():
	touch_root=Control.new()
	touch_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_root)
	stick=Thumbstick.new()
	stick.size=Vector2(120,120)
	stick.moved.connect(func(v):game.touch_move=v)
	touch_root.add_child(stick)
	var b=button_to(touch_root,"ACT",game.interact_nearest)
	b.name="Act"
	b.size=Vector2(70,64)
	var sprint=button_to(touch_root,"HURRY",func():game.touch_sprint=not game.touch_sprint,false)
	sprint.name="Hurry"
	sprint.size=Vector2(75,42)

func layout():
	var sz=root.get_viewport_rect().size
	last_size=sz
	var pad=22 if mobile else 35
	top.position=Vector2(pad,pad)
	top.size=Vector2(sz.x-pad*2,54)
	var cr=top.get_node("Controls")
	cr.position=Vector2(top.size.x-(202 if mobile else 208),0)
	if mobile:
		chapter.visible=false
		title.position=Vector2(25,sz.y*.23)
		title.size=Vector2(sz.x-50,0)
	else:
		title.position=Vector2(70,sz.y*.25)
		title.size=Vector2(430,0)
	objective.position=Vector2(pad,sz.y-(300 if mobile else 192))
	objective.size=Vector2(min(360,sz.x-pad*2),140)
	objective_title.size=Vector2(objective.size.x-36,20)
	objective_text.size=Vector2(objective.size.x-36,58)
	intel.size=Vector2(objective.size.x-36,20)
	prompt.size=Vector2(min(400,sz.x-40),50)
	prompt.position=Vector2((sz.x-prompt.size.x)/2,sz.y-(85 if not mobile else 355))
	upper_bar.position=Vector2.ZERO
	upper_bar.size=Vector2(sz.x,45 if mobile else 60)
	lower_bar.position=Vector2(0,sz.y-(45 if mobile else 60))
	lower_bar.size=upper_bar.size
	captions.size=Vector2(min(800,sz.x-40),0)
	speaker.size=Vector2(captions.size.x-36,22)
	dialogue.size.x=captions.size.x-36
	captions.position=Vector2((sz.x-captions.size.x)/2,sz.y-220 if not mobile else sz.y-260)
	skip.size=Vector2(125,40)
	skip.position=Vector2(sz.x-145,12)
	toast_label.position=Vector2(20,95)
	toast_label.size=Vector2(sz.x-40,50)
	footer.position=Vector2(pad,sz.y-30)
	footer.size=Vector2(sz.x-pad*2,20)
	touch_root.position=Vector2(0,sz.y-165)
	touch_root.size=Vector2(sz.x,150)
	stick.position=Vector2(20,15)
	touch_root.get_node("Act").position=Vector2(sz.x-100,50)
	touch_root.get_node("Hurry").position=Vector2(sz.x-104,0)

func set_state(state: String):
	title.visible=state=="title"
	shade.visible=state=="title"
	var cine=state in ["opening","arrival","core","ending"]
	captions.visible=cine
	upper_bar.visible=cine
	lower_bar.visible=cine
	skip.visible=cine
	objective.visible=state in ["shop","vault"]
	top.visible=not cine
	footer.visible=not mobile and state in ["shop","vault"]
	touch_root.visible=mobile and state in ["shop","vault"]
	if marker_root:marker_root.visible=state in ["shop","vault"]
	if state not in ["shop","vault"]:prompt.visible=false
	layout()

func update_objective():
	objective_title.text="THE SHOP / 18:42" if game.location=="shop" else "TALLINN / MERIDIAN / 23:48"
	objective_text.text=game.objective_text()
	intel.text="PAID IN FULL   •   SECRETS %d / 8" % game.secrets.size()

func show_line(line: Dictionary):
	speaker.text=line.speaker
	dialogue.text=line.text

func toast(text: String):
	toast_label.text=text
	toast_timer=5
	toast_label.visible=true

func rebuild_markers():
	for c in marker_root.get_children():c.queue_free()
	markers.clear()
	for id in game.interactions:
		var b=Button.new()
		b.text="+"
		b.size=Vector2(50,50) if mobile else Vector2(28,28)
		b.add_theme_font_size_override("font_size",18)
		b.add_theme_color_override("font_color",PAPER)
		var normal=style(Color(.03,.09,.11,.8),Color(.78,.6,.4,.6),25 if mobile else 14)
		normal.set_content_margin_all(0)
		var hover=style(ACCENT,ACCENT,25 if mobile else 14)
		hover.set_content_margin_all(0)
		b.add_theme_stylebox_override("normal",normal)
		b.add_theme_stylebox_override("hover",hover)
		b.tooltip_text=game.interactions[id].name
		b.pressed.connect(func():game.go_to_interaction(id))
		marker_root.add_child(b)
		markers[id]=b

func _process(dt):
	if not game:return
	if root.get_viewport_rect().size!=last_size:layout()
	var sz=root.get_viewport_rect().size
	if captions.visible:
		var text_height=max(30,dialogue.get_line_count()*(28 if mobile else 31))
		dialogue.size.y=text_height
		next_line.position=Vector2(18,56+text_height)
		next_line.size=Vector2(captions.size.x-36,46)
		captions.size.y=118+text_height
		captions.position.y=sz.y-captions.size.y-(55 if mobile else 78)
	if objective.visible:objective.position.y=90 if mobile else sz.y-objective.size.y-58
	if mobile:prompt.position.y=sz.y-225
	if toast_timer>0:
		toast_timer-=dt
		toast_label.modulate.a=min(1,toast_timer)
		if toast_timer<=0:toast_label.visible=false
	if marker_root.visible:
		for id in markers:
			var p=game.interactions[id].pos+Vector3(0,.9,0)
			var b=markers[id]
			b.visible=not game.camera.is_position_behind(p) and game.marker_available(id)
			if b.visible:
				b.position=game.camera.unproject_position(p)-b.size/2.0
				b.modulate.a=.95 if id==game.nearest_id else .65
		prompt.visible=game.nearest_id!="" and not game.panel_open
		if prompt.visible:prompt.text=("TAP / " if mobile else "E / ")+game.interactions[game.nearest_id].name.to_upper()

func modal_base() -> Control:
	game.panel_open=true
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var bg=ColorRect.new()
	bg.color=Color(.01,.025,.03,.87)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(bg)
	return modal

func modal_box(p: Control, width: float=620) -> VBoxContainer:
	var center=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(center)
	var pan=PanelContainer.new()
	pan.custom_minimum_size=Vector2(min(width,root.get_viewport_rect().size.x-30),0)
	pan.add_theme_stylebox_override("panel",style(Color("14292e"),Color("56766b"),6))
	center.add_child(pan)
	var v=VBoxContainer.new()
	v.add_theme_constant_override("separation",16 if not mobile else 12)
	pan.add_child(v)
	return v

func dismiss_modal():
	if modal:
		modal.queue_free()
		modal=null
	game.panel_open=false

func show_pause():
	if modal or game.state in ["opening","arrival","core","ending"]:return
	var p=modal_base()
	var v=modal_box(p,480)
	label_to(v,"TAKE A BREATHER",13,ACCENT)
	label_to(v,"The job can wait a minute.",30)
	button_to(v,"BACK TO WORK",dismiss_modal)
	var mb=button_to(v,"MUSIC / "+("ON" if game.music_on else "OFF"),func():game.toggle_music(),false)
	mb.pressed.connect(func():mb.text="MUSIC / "+("ON" if game.music_on else "OFF"))
	var vb=button_to(v,"VOICES / "+("ON" if game.voices_on else "OFF"),func():game.voices_on=not game.voices_on,false)
	vb.pressed.connect(func():
		vb.text="VOICES / "+("ON" if game.voices_on else "OFF")
		game.save_game())
	button_to(v,"FULLSCREEN",game.fullscreen,false)
	label_to(v,"WASD / Move · Shift / Hurry\nClick / Walk & inspect · E / Interact\nRight-drag / Orbit · Wheel / Zoom\nEsc / Pause · Space / Advance dialogue",15,MUTED)
	button_to(v,"RESTART THIS SHIFT",func():
		dismiss_modal()
		game.restart(),false)

func show_journal():
	if modal:return
	var p=modal_base()
	var v=modal_box(p,610)
	label_to(v,"CASE 01 / DEAD BATTERY",13,ACCENT)
	label_to(v,"The Widowmaker",34)
	label_to(v,"Meridian sells stolen pension records. Oleg wants its signing key destroyed. Steve wants those people to get their money back.",17,MUTED)
	var lines=["COVER / Collect the service identity from the cart.","SECURITY / Loop the surveillance feed at the console.","COOLANT / Balance the valves. Amber 3, blue 6, return 3.","ASSET / Back up the records. Isolate the key. Remove power.","EXTRACTION / Reach the roof lift before the patrol spots you."]
	for i in range(5):
		label_to(v,("[OK]  " if game.mission_step>i else "[  ]  ")+lines[i],16,GREEN if game.mission_step>i else PAPER)
	label_to(v,"PAYMENT: RECEIVED\nSECRETS FOUND: %d / 8\nALERTS: %d" % [game.secrets.size(),game.alerts],14,ACCENT)
	button_to(v,"CLOSE CASE FILE",dismiss_modal)

func inspect(title_text: String,body: String):
	var p=modal_base()
	var v=modal_box(p,570)
	label_to(v,"STEVE'S FIELD NOTES",12,ACCENT)
	label_to(v,title_text,30)
	label_to(v,body,18,MUTED)
	button_to(v,"BACK TO WORK",dismiss_modal)

func results():
	var p=modal_base()
	var v=modal_box(p,640)
	label_to(v,"CASE CLOSED / 01",13,ACCENT)
	label_to(v,"Everything has a fix.",36)
	label_to(v,"The Widowmaker is offline. The evidence is safe.\nEight million people get their lives back.\nAnd one cat gets his breakfast.",19,MUTED)
	var rank="GHOST TECHNICIAN" if game.alerts==0 else "FIELD ENGINEER"
	label_to(v,rank,23,GREEN)
	label_to(v,"TIME  %02d:%02d     ALERTS  %d     SECRETS  %d / 8" % [int(game.play_time)/60,int(game.play_time)%60,game.alerts,game.secrets.size()],14,ACCENT)
	button_to(v,"RETURN TO THE SHOP",func():
		dismiss_modal()
		game.state="shop"
		game.finished=true
		set_state("shop")
		update_objective())
	button_to(v,"PLAY A NEW SHIFT",func():
		dismiss_modal()
		game.restart(),false)

func button_snapshot(node: Node = null) -> Array:
	if node==null:node=root
	var result: Array = []
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and child.get_parent()!=marker_root:
			var r=child.get_global_rect()
			result.append({"text":child.text,"x":r.get_center().x,"y":r.get_center().y,"width":r.size.x,"height":r.size.y,"disabled":child.disabled})
		result.append_array(button_snapshot(child))
	return result
