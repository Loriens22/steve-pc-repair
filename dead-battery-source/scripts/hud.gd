extends CanvasLayer

const INK=Color("0c151b")
const PAPER=Color("d2d9d7")
const MUTED=Color("84999d")
const ACCENT=Color("dbb380")
const GREEN=Color("87baa6")
var game
var root: Control
var font: Font
var top: Control
var task_label: Label
var clock: Label
var tool_label: Label
var focus_label: Label
var prompt: Label
var toast_label: Label
var toast_clock=0.0
var crosshair: Reticle
var stamina_bar: ColorRect
var danger: ColorRect
var warning: Label
var caption: Panel
var speaker: Label
var words: Label
var next_button: Button
var skip_button: Button
var title_panel: Panel
var modal: Panel
var mobile_root: Control
var stick: Thumbstick
var mobile_buttons={}
var stick_finger=-1
var look_finger=-1
var last_look=Vector2.ZERO
var touch_buttons={}
var mouse_stick=false
var mouse_look=false
var last_size=Vector2.ZERO
var gui_finger=-1
var gui_scroll: ScrollContainer
var gui_start=Vector2.ZERO
var gui_moved=false
var fade: ColorRect
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect

class Reticle extends Control:
	var fraction=0.0
	var focused=false
	func _draw():
		var c=size*.5
		var color=Color(.78,.84,.82,.82)
		for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(c+d*5,c+d*10,color,1,true)
		if focused:draw_circle(c,2,color)
		if fraction>0:draw_arc(c,17,-PI/2,-PI/2+TAU*clampf(fraction,0,1),32,Color("dbb380"),2,true)

class Thumbstick extends Control:
	var value=Vector2.ZERO
	var active=false
	func _draw():
		var c=size*.5
		draw_circle(c,67,Color(.03,.09,.12,.40))
		draw_arc(c,63,0,TAU,48,Color(.68,.78,.79,.32),2,true)
		draw_circle(c+value*44,25,Color(.50,.64,.66,.48 if active else .20))
		draw_arc(c+value*44,25,0,TAU,24,Color(.70,.79,.77,.45),1,true)

class ServicePlan extends Control:
	var game
	var font
	func _process(_dt):queue_redraw()
	func _draw():
		var scale_=min(size.x/23,size.y/37)
		var o=Vector2((size.x-22*scale_)*.5,12)
		var rooms=[[-10.5,-12.3,5.7,14.5,"WEST CORRIDOR"],[-10.5,-18.2,5.7,5.9,"POWER"],[-4.7,-19.0,9.4,21.2,"SERVER HALL"],[4.7,-7,5.8,9.2,"CHILLER"],[4.7,-18.2,5.8,7.2,"ARCHIVE"],[-4.7,-26.2,9.4,7.2,"ROOT VAULT"]]
		for a in rooms:
			var r=Rect2(o+Vector2(a[0]+11,a[1]+27)*scale_,Vector2(a[2],a[3])*scale_)
			draw_rect(r,Color("162b35"))
			draw_rect(r,Color("759794"),false,1)
			draw_string(font,r.position+Vector2(4,18),a[4],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a4b6b2"))
		var p=o+Vector2(game.body.position.x+11,game.body.position.z+27)*scale_
		draw_circle(p,5,Color("dbb380"))
		draw_line(p,p+Vector2(-sin(game.yaw),-cos(game.yaw))*12,Color("dbb380"),2,true)
		draw_string(font,Vector2(12,size.y-12),"SERVICE PLAN / Roof hatch behind west power room",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("84999d"))

func setup(g):
	game=g
	font=load("res://assets/fonts/workshop_ui.ttf")
	root=Control.new()
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=18
	root.theme=theme
	for i in range(3):
		var rect=ColorRect.new()
		rect.color=Color(0,0,0,0) if i==0 else Color("060a0d")
		rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
		root.add_child(rect)
		if i==0:
			fade=rect
			fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		elif i==1:letterbox_top=rect
		else:letterbox_bottom=rect
	top=Control.new()
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var brand=label(top,"S / STEVE",12,ACCENT)
	brand.position=Vector2(0,0)
	task_label=label(top,"",17,PAPER)
	task_label.position=Vector2(0,24)
	task_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	task_label.size=Vector2(540,70)
	var case_button=button(top,"CASE",show_journal)
	case_button.name="CaseButton"
	var pause_button=button(top,"II",show_pause)
	pause_button.name="PauseButton"
	clock=label(root,"",17,ACCENT)
	tool_label=label(root,"",17 if game.mobile else 14,MUTED)
	focus_label=label(root,"",19,PAPER)
	focus_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	focus_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	prompt=label(root,"",16 if game.mobile else 13,ACCENT)
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label=label(root,"",17,PAPER)
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	crosshair=Reticle.new()
	crosshair.mouse_filter=Control.MOUSE_FILTER_IGNORE
	crosshair.size=Vector2(48,48)
	root.add_child(crosshair)
	warning=label(root,"",14,Color("e09a7b"))
	warning.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stamina_bar=ColorRect.new()
	stamina_bar.color=Color(.65,.76,.73,.6)
	stamina_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(stamina_bar)
	danger=ColorRect.new()
	danger.color=Color(.52,.025,.01,0)
	danger.mouse_filter=Control.MOUSE_FILTER_IGNORE
	danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(danger)
	caption=Panel.new()
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel",style(Color(.022,.045,.057,.93),Color(.24,.34,.35,.7)))
	root.add_child(caption)
	speaker=label(caption,"",12,ACCENT)
	speaker.position=Vector2(20,14)
	words=label(caption,"",20,PAPER)
	words.position=Vector2(20,39)
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	next_button=button(caption,"NEXT LINE",game.next_line)
	next_button.name="NextLine"
	skip_button=button(root,"SKIP SCENE",game.finish_cinematic)
	skip_button.name="SkipScene"
	caption.visible=false
	skip_button.visible=false
	mobile_root=Control.new()
	mobile_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(mobile_root)
	stick=Thumbstick.new()
	stick.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stick.size=Vector2(144,144)
	mobile_root.add_child(stick)
	for id in ["act","run","crouch","light","tools","jump"]:
		var b=button(mobile_root,{"act":"ACT","run":"RUN","crouch":"DUCK","light":"LIGHT","tools":"TOOLS","jump":"UP"}[id],func():mobile_action(id))
		b.set_meta("action",id)
		if id=="act":
			b.button_down.connect(func():game.action_hold(true))
			b.button_up.connect(func():game.action_hold(false))
			b.set_meta("hold",true)
		mobile_buttons[id]=b
	build_title()
	layout()
	set_state()

func style(background=INK,border=Color("34484d")):
	var s=StyleBoxFlat.new()
	s.bg_color=background
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(12)
	return s

func label(parent,text,size=18,color=PAPER):
	var n=Label.new()
	n.text=text
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func button(parent,text,callback):
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(56,56 if game.mobile else 44)
	b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_stylebox_override("normal",style(Color(.025,.06,.077,.90)))
	b.add_theme_stylebox_override("hover",style(Color("243e49"),ACCENT))
	b.add_theme_stylebox_override("pressed",style(Color("3b555b"),ACCENT))
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_title():
	title_panel=Panel.new()
	title_panel.add_theme_stylebox_override("panel",style(Color(.025,.045,.058,.92),Color(.35,.44,.45,.3)))
	root.add_child(title_panel)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	title_panel.add_child(scroll)
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x=320
	v.add_theme_constant_override("separation",14)
	scroll.add_child(v)
	label(v,"CASE 01 / DEAD BATTERY",12,ACCENT)
	label(v,"STEVE",55)
	label(v,"THE PC REPAIR MAN",20)
	var copy=label(v,"An honest shop. A very different night shift.\n\nA first-person repair and stealth adventure.",17,MUTED)
	copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.x=310
	button(v,"START YOUR SHIFT",game.start_game)
	if game.has_save():button(v,"CONTINUE YOUR SHIFT",game.resume_game)
	button(v,"CONTROLS",show_controls)
	var l=label(v,"Original Blender environments, surfaces,\ncharacters, tools, sound and typeface.",11,MUTED)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(v,"Everything has a fix.",14,ACCENT)

func layout():
	var sz=root.get_viewport_rect().size
	last_size=sz
	letterbox_top.position=Vector2.ZERO
	letterbox_top.size=Vector2(sz.x,24)
	letterbox_bottom.position=Vector2(0,sz.y-24)
	letterbox_bottom.size=Vector2(sz.x,24)
	var pad=18 if game.mobile else 26
	top.position=Vector2(pad,pad)
	top.size=Vector2(sz.x-pad*2,95)
	var case_button=top.get_node("CaseButton")
	var pause_button=top.get_node("PauseButton")
	pause_button.position=Vector2(top.size.x-56,0)
	pause_button.size=Vector2(56,56 if game.mobile else 44)
	case_button.position=Vector2(top.size.x-138,0)
	case_button.size=Vector2(74,56 if game.mobile else 44)
	task_label.size.x=sz.x-pad*2 if game.mobile else min(650,sz.x-220)
	if game.mobile:task_label.position.y=65
	clock.position=Vector2(pad,120 if game.mobile else 95)
	tool_label.position=Vector2(pad,sz.y-(236 if game.mobile else 58))
	focus_label.position=Vector2(18,sz.y-(316 if game.mobile else 128))
	focus_label.size=Vector2(sz.x-36,60)
	prompt.position=Vector2(20,focus_label.position.y+61)
	prompt.size=Vector2(sz.x-40,24)
	crosshair.position=(sz-crosshair.size)/2
	warning.position=Vector2(20,sz.y*.17)
	warning.size=Vector2(sz.x-40,24)
	toast_label.position=Vector2(22,sz.y*.23)
	toast_label.size=Vector2(sz.x-44,85)
	stamina_bar.position=Vector2(pad,sz.y-(245 if game.mobile else 32))
	stamina_bar.size=Vector2(110,2)
	title_panel.position=Vector2(22,min(160,max(16,sz.y-536))) if game.mobile else Vector2(42,sz.y*.13)
	title_panel.size=Vector2(min(404,sz.x-44),min(500,sz.y-32))
	var title_scroll=title_panel.get_child(0)
	title_scroll.position=Vector2(26,26)
	title_scroll.size=title_panel.size-Vector2(52,52)
	var mult=1.10 if game.mobile and sz.x>sz.y else 1.0
	mobile_root.scale=Vector2.ONE*mult
	mobile_root.position=Vector2(0,sz.y-185*mult-46)
	mobile_root.size=Vector2(sz.x/mult,185)
	stick.position=Vector2(12,14)
	var width=mobile_root.size.x
	var bx=width-222
	mobile_buttons.act.position=Vector2(width-92,51)
	mobile_buttons.act.size=Vector2(74,74)
	var positions={"tools":Vector2(bx,28),"light":Vector2(bx+65,0),"crouch":Vector2(bx+65,126),"run":Vector2(bx,96),"jump":Vector2(width-92,130)}
	for id in positions:
		mobile_buttons[id].position=positions[id]
		mobile_buttons[id].size=Vector2(58,56)
	skip_button.position=Vector2(sz.x-156,18)
	skip_button.size=Vector2(138,56)
	caption.size.x=min(800,sz.x-36)
	speaker.size=Vector2(caption.size.x-40,20)
	words.size.x=caption.size.x-40
	next_button.size=Vector2(caption.size.x-40,56 if game.mobile else 44)
	if modal:
		modal.position=Vector2((sz.x-modal.size.x)/2,(sz.y-modal.size.y)/2)

func set_state():
	title_panel.visible=game.state=="title"
	top.visible=game.cine_name=="" and game.state not in ["title","results"]
	tool_label.visible=game.playable()
	crosshair.visible=game.playable()
	mobile_root.visible=game.mobile and game.playable()
	skip_button.visible=game.cine_name!=""
	letterbox_top.visible=game.cine_name!=""
	letterbox_bottom.visible=game.cine_name!=""
	refresh()

func refresh():
	task_label.text=game.tasks.objective()
	tool_label.text=game.tool_names[game.tool]+(" / F to toggle light" if not game.mobile else " / swipe right to look")
	if game.tool==6:tool_label.text="FUSE / "+["T2A","T6.3A","T10A"][max(0,game.fuse_rating)]
	if mobile_buttons.has("crouch"):
		mobile_buttons.crouch.text="STAND" if game.crouched else "DUCK"
		mobile_buttons.light.text="OFF" if game.flashlight_on else "LIGHT"
		mobile_buttons.run.text="WALK" if game.mobile_run else "RUN"

func tick(dt):
	if root.get_viewport_rect().size!=last_size:layout()
	set_state()
	clock.text="AUCTION / %02d:%02d"%[int(game.auction_time)/60,int(game.auction_time)%60] if game.location=="vault" and not game.finished else ""
	var focus=game.focus
	focus_label.visible=game.playable() and not focus.is_empty()
	prompt.visible=focus_label.visible
	if focus_label.visible:
		focus_label.text=focus.label
		var required=game.tasks.required_tool(focus.id)
		prompt.text=("HOLD ACT" if game.mobile else "HOLD E / MOUSE")+" / "+game.tool_names[required] if required>=0 else "INSPECT"
		if float(focus.distance)>1.65:prompt.text="MOVE CLOSER"
	crosshair.focused=not focus.is_empty()
	crosshair.fraction=game.hold_progress/float(focus.get("duration",1))
	crosshair.queue_redraw()
	stamina_bar.visible=game.playable() and game.stamina<.99
	stamina_bar.size.x=110*game.stamina
	danger.color.a=game.suspicion*.13
	warning.visible=game.playable() and game.suspicion>.08
	warning.text="SURVEILLANCE / %d%% / FIND COVER"%int(game.suspicion*100)
	toast_clock-=dt
	toast_label.visible=toast_clock>0 and game.cine_name==""
	if caption.visible:
		var height=max(30,words.get_line_count()*27)
		words.size.y=height
		next_button.position=Vector2(20,48+height)
		caption.size.y=height+(112 if game.cine_name!="" else 70)
		var bottom=273 if game.mobile and game.cine_name=="" else 24
		caption.position=Vector2((last_size.x-caption.size.x)/2,last_size.y-caption.size.y-bottom)

func toast(text):
	toast_label.text=text
	toast_clock=4.5

func alarm(text):
	toast(text)
	danger.color.a=.45

func show_line(line,cinematic):
	speaker.text=line.speaker
	words.text=line.text
	caption.visible=true
	next_button.visible=cinematic

func clear_line():caption.visible=false

func cinematic_cut():
	fade.color.a=.95
	game.create_tween().tween_property(fade,"color:a",0.0,.38)

func mobile_action(id):
	match id:
		"run":game.mobile_run=not game.mobile_run
		"crouch":game.toggle_crouch()
		"light":game.toggle_light()
		"tools":show_tools()
		"jump":game.jump()
	refresh()

func panel(title,height=550):
	if modal:return null
	game.panel_open=true
	game.release_mouse()
	var sz=root.get_viewport_rect().size
	modal=Panel.new()
	modal.size=Vector2(min(650,sz.x-34),min(height,sz.y-42))
	modal.position=(sz-modal.size)/2
	modal.add_theme_stylebox_override("panel",style(Color(.025,.048,.064,.985),Color("456368")))
	root.add_child(modal)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(22,20)
	scroll.size=modal.size-Vector2(44,40)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var v=VBoxContainer.new()
	v.custom_minimum_size.x=scroll.size.x-12
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",12)
	scroll.add_child(v)
	label(v,title,23,ACCENT)
	return v

func close_panel(capture=true):
	if modal:
		modal.queue_free()
		modal=null
	game.panel_open=false
	if capture:game.capture_mouse()

func paragraph(parent,text,size=17):
	var l=label(parent,text,size,PAPER)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x=max(parent.size.x,parent.custom_minimum_size.x)
	return l

func show_pause():
	if game.cine_name!="" or modal:return
	game.save_game()
	var v=panel("TAKE A BREATHER",610)
	button(v,"BACK TO WORK",close_panel)
	var m=button(v,"MUSIC / "+("ON" if game.music_on else "OFF"),func():game.toggle_music())
	m.pressed.connect(func():m.text="MUSIC / "+("ON" if game.music_on else "OFF"))
	var b=button(v,"VOICES / "+("ON" if game.voices_on else "OFF"),func():game.toggle_voices())
	b.pressed.connect(func():b.text="VOICES / "+("ON" if game.voices_on else "OFF"))
	paragraph(v,"Look sensitivity",15)
	var row=HBoxContainer.new()
	v.add_child(row)
	for i in range(3):button(row,["LOW","NORMAL","FAST"][i],func():game.look_sensitivity=[.0015,.0024,.0032][i];game.save_game())
	paragraph(v,"Graphics",15)
	var quality=HBoxContainer.new()
	v.add_child(quality)
	for i in range(3):
		var q=button(quality,["BATTERY","BALANCED","HIGH"][i],func():game.graphics_quality=i;game.apply_quality();game.save_game())
		q.add_theme_font_size_override("font_size",13)
	button(v,"CONTROLS",func():close_panel(false);show_controls())
	button(v,"RESTART THIS SHIFT",func():close_panel(false);game.start_game())
	paragraph(v,"Progress saves on this device.",13)

func show_controls():
	if modal:return
	var v=panel("IN YOUR HANDS",560)
	paragraph(v,"DESKTOP\nWASD: walk. Mouse: look. E or left mouse: hold to use.\n0: hands. 1: screwdriver. 2: meter. 3: pick. 4: drive. 5: bridge.\nShift: run. C: crouch. F: torch. Space: jump.\nRight mouse: inspect closer. Tab: tools. J: case file. Esc: pause.\n\nPHONE\nLeft stick: walk. Swipe the right side: look.\nHold ACT to use your tool. TOOLS changes equipment.\nRUN and DUCK toggle. LIGHT toggles the torch.\nMovement and looking work together with separate fingers.",16)
	button(v,"BACK",close_panel)

func show_tools():
	if modal or game.cine_name!="":return
	var v=panel("WORKSHOP KIT",620)
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	v.add_child(grid)
	for i in range(7):
		if i==6 and game.fuse_rating<0:continue
		var text=str(i)+" / "+game.tool_names[i]
		if i==6:text+=" / "+["T2A","T6.3A","T10A"][game.fuse_rating]
		var b=button(grid,text,func():game.set_tool(i);close_panel())
		b.add_theme_font_size_override("font_size",13 if game.mobile else 16)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(v,"BACK",close_panel)

func show_journal():
	if modal or game.cine_name!="":return
	var v=panel("CASE 01 / DEAD BATTERY",660)
	paragraph(v,game.tasks.objective(),19)
	paragraph(v,game.tasks.hint(),17)
	paragraph(v,"The contract is paid in full. Preserve the evidence before destroying Widowmaker. Keep your service identity intact. Server racks stop surveillance sightlines. Crouching and switching off the torch help you stay unnoticed.",16)
	paragraph(v,"Discoveries: %d / 8\nAlerts: %d\nCurrent tool: %s"%[game.secrets.size(),game.alerts,game.tool_names[game.tool]],15)
	button(v,"SERVICE FLOOR PLAN",func():close_panel(false);show_plan())
	button(v,"BACK TO THE JOB",close_panel)

func show_plan():
	var v=panel("MERIDIAN / SERVICE PLAN",650)
	var plan=ServicePlan.new()
	plan.game=game
	plan.font=font
	plan.custom_minimum_size=Vector2(v.custom_minimum_size.x,min(460,modal.size.y-160))
	v.add_child(plan)
	button(v,"BACK TO THE JOB",close_panel)

func show_note(title,text):
	if modal:return
	var v=panel(title,590)
	paragraph(v,text,18)
	button(v,"BACK TO THE JOB",close_panel)

func show_contract():
	var v=panel("PAID IN FULL",620)
	paragraph(v,"EUR 45,000 / Cleared before Oleg walked in.\n\nFirst-class ticket to Tallinn. Night-maintenance identity. Encrypted phone. Screwdriver, meter, pick, secure drive and loop bridge.\n\nAsset: Widowmaker, Meridian's battery-backed signing key. Eight million stolen pension records. An auction at midnight.\n\nGet inside. Preserve the archive. Destroy the key. Return to BIOS.",17)
	button(v,"PACK THE KIT",close_panel)

func show_results():
	game.release_mouse()
	var v=panel("EVERYTHING HAS A FIX",600)
	label(v,"GHOST TECHNICIAN" if game.alerts==0 else "CONTRACT COMPLETE",24,PAPER)
	paragraph(v,"Widowmaker is gone. The pension archive is secured. Ms. Ellis still has Arthur's letters.\n\nDiscoveries: %d / 8\nAlerts: %d\nShift: %d minutes\n\nA two-pound repair. Eight million second chances."%[game.secrets.size(),game.alerts,int(game.play_time)/60],18)
	button(v,"RETURN TO THE SHOP",func():close_panel(false);game.state="shop";game.body.position=Vector3(-2.5,.02,1.1);game.yaw=0;game.pitch=0;game.update_look();game.capture_mouse();game.save_game())
	button(v,"PLAY ANOTHER SHIFT",func():close_panel(false);game.start_game())

func show_timeout():
	game.state="deadline"
	var v=panel("THE AUCTION WENT LIVE",400)
	paragraph(v,"Meridian has advanced the sale. Your last service checkpoint is preserved. Return to it with a five-minute window.",18)
	button(v,"RETRY FROM CHECKPOINT",func():close_panel(false);game.state="vault";game.auction_time=300;game.suspicion=0;game.capture_mouse();game.save_game())
	button(v,"RESTART THE SHIFT",func():close_panel(false);game.start_game())

func buttons_below(n):
	var arr=[]
	if n is Button and n.is_visible_in_tree():arr.append(n)
	for c in n.get_children():arr.append_array(buttons_below(c))
	return arr

func button_snapshot():
	var arr=[]
	for b in buttons_below(root):
		var r=b.get_global_rect()
		arr.append({"text":b.text,"x":r.get_center().x,"y":r.get_center().y,"width":r.size.x,"height":r.size.y,"disabled":b.disabled})
	return arr

func _input(e):
	if not game or not game.mobile:return
	if e is InputEventScreenTouch:
		touch(e.index,e.position,e.pressed)
	elif e is InputEventScreenDrag:
		if e.index==gui_finger and is_instance_valid(gui_scroll):
			if e.position.distance_to(gui_start)>8:gui_moved=true
			if gui_moved:gui_scroll.scroll_vertical-=int(e.relative.y)
			get_viewport().set_input_as_handled()
		elif e.index==stick_finger:
			move_stick(e.position)
			get_viewport().set_input_as_handled()
		elif e.index==look_finger:
			game.look(e.relative*2.3)
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		if e.pressed and game.playable() and stick.get_global_rect().has_point(e.position):
			mouse_stick=true
			move_stick(e.position)
			get_viewport().set_input_as_handled()
		elif e.pressed and game.playable() and e.position.x>last_size.x*.42:
			var over=false
			for b in buttons_below(root):
				if b.get_global_rect().has_point(e.position):over=true
			if not over:mouse_look=true
		elif not e.pressed:
			mouse_stick=false
			mouse_look=false
			if stick_finger<0:reset_stick()
	elif e is InputEventMouseMotion:
		if mouse_stick:move_stick(e.position);get_viewport().set_input_as_handled()
		if mouse_look:game.look(e.relative*2.3);get_viewport().set_input_as_handled()

func touch(id,pos,pressed):
	if pressed:
		var scroll=modal.get_child(0) if modal else (title_panel.get_child(0) if game.state=="title" else null)
		if scroll and scroll.get_global_rect().has_point(pos):
			gui_finger=id
			gui_scroll=scroll
			gui_start=pos
			gui_moved=false
		var list=buttons_below(modal if modal else root)
		list.reverse()
		for b in list:
			if button_contains(b,pos):
				touch_buttons[id]=b
				b.button_down.emit()
				get_viewport().set_input_as_handled()
				return
		if game.playable():
			if stick.get_global_rect().has_point(pos) and stick_finger<0:
				stick_finger=id
				move_stick(pos)
				get_viewport().set_input_as_handled()
			elif pos.x>last_size.x*.42 and look_finger<0:
				look_finger=id
				last_look=pos
				get_viewport().set_input_as_handled()
	else:
		if touch_buttons.has(id):
			var b=touch_buttons[id]
			if is_instance_valid(b):
				b.button_up.emit()
				if not b.get_meta("hold",false) and b.get_global_rect().has_point(pos) and not (id==gui_finger and gui_moved):b.pressed.emit()
			touch_buttons.erase(id)
			get_viewport().set_input_as_handled()
		if id==gui_finger:
			gui_finger=-1
			gui_scroll=null
		if id==stick_finger:
			stick_finger=-1
			reset_stick()
			get_viewport().set_input_as_handled()
		if id==look_finger:
			look_finger=-1
			get_viewport().set_input_as_handled()

func move_stick(pos):
	var v=(pos-stick.get_global_rect().get_center())/52
	if v.length()>1:v=v.normalized()
	if v.length()<.12:v=Vector2.ZERO
	stick.value=v
	stick.active=true
	stick.queue_redraw()
	game.touch_move=v

func reset_stick():
	stick.value=Vector2.ZERO
	stick.active=false
	stick.queue_redraw()
	game.touch_move=Vector2.ZERO

func button_contains(b,pos):
	if not b.get_global_rect().has_point(pos):return false
	var parent=b.get_parent()
	while parent and parent!=root:
		if parent is ScrollContainer and not parent.get_global_rect().has_point(pos):return false
		parent=parent.get_parent()
	return true
