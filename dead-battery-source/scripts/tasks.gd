extends RefCounted

var game
var targets: Array=[]
var thermal_clock=0.0
var screen_clock=0.0
var screen_view: SubViewport
var screen_label: Label
var extra_screens=[]
var archive_label: Label
var key_label: Label

func setup(g):game=g

func target(id,p,label_,tool=0,duration=.65,radius=.08):
	targets.append({"id":id,"p":p,"label":label_,"tool":tool,"duration":duration,"radius":radius})

func rebuild():
	targets.clear()
	if screen_view:
		screen_view.queue_free()
		screen_view=null
	for screen in extra_screens:
		if is_instance_valid(screen):screen.queue_free()
	extra_screens.clear()
	archive_label=null
	key_label=null
	if game.location=="shop":
		target("pc_power",Vector3(-2.84,1.03,-3.00),"Unplug the mains lead",0,.6)
		target("pc_meter",Vector3(-3.06,1.07,-3.137),"Verify discharged power",2,1.0,.15)
		for entry in enumerate_screws():
			var i=entry[0]
			var xy=entry[1]
			target("pc_screw_"+str(i),Vector3(-2.2+xy.x,1.185+xy.y,-2.822),"Remove panel screw",1,.9,.048)
		target("pc_panel",Vector3(-2.20,1.185,-2.822),"Slide off the service panel",0,.65,.17)
		target("pc_clip",Vector3(-2.287,1.30,-2.864),"Release the battery retaining clip",3,.75,.047)
		target("pc_cell",Vector3(-2.30,1.30,-2.862),"Fit the fresh CR2032, positive side out",0,1.0,.050)
		target("pc_bios",Vector3(-1.29,1.165,-2.974),"Validate boot and synchronise the clock",0,1.2,.15)
		target("case",Vector3(-.37,1.13,-.02),"Open Oleg's paid contract",0,.7,.21)
		target("depart",Vector3(2.80,1.13,4.23),"Leave for Tallinn",0,.65,.27)
		target("secret_cat",Vector3(-3.46,.47,1.79),"Give BIOS a scratch",0,.6,.15)
		target("secret_coffee",Vector3(2.76,1.04,-3.23),"Inspect Steve's coffee",0,.5,.075)
		target("secret_receipt",Vector3(.17,1.037,.09),"Read the two-pound receipt",0,.5,.13)
		target("secret_magazine",Vector3(-2.70,.983,2.83),"Read the old BYTE magazine",0,.5,.13)
		target("secret_calendar",Vector3(4.65,1.78,-4.125),"Check Thursday's appointment",0,.5,.16)
	else:
		target("entry",Vector3(-6.99,1.31,2.365),"Present the service identity",0,.75,.10)
		target("workorder",Vector3(-6.67,1.53,-18.089),"Read the service work order",0,.45,.23)
		for i in range(4):target("feed_"+str(i),Vector3(-8.35+i*.20,.91,-17.831),"Probe feed "+str(i+6).pad_zeros(2),2,.85,.049)
		target("isolate",Vector3(-7.72,1.763,-17.807),"Put C3 in isolated service mode",0,.65,.065)
		target("bridge",Vector3(-7.80,1.26,-17.763),"Seat the loop bridge on a green pulse",5,.72,.060)
		target("hall",Vector3(-4.86,1.07,-4.64),"Open the authorised maintenance door",0,.55,.22)
		for i in range(3):target("fuse_"+str(i),Vector3(-6.14+i*.31,.822,-15.66),"Take "+["T2A","T6.3A","T10A"][i]+" fuse",0,.40,.064)
		target("coolant_note",Vector3(8.75,2.45,-6.901),"Read the chilled-water protocol",0,.5,.30)
		target("pump_fuse",Vector3(6.34,1.13,-6.710),"Fit the rated slow-blow fuse",6,.85,.070)
		target("pump_start",Vector3(6.16,1.35,-6.707),"Start the circulation pump",0,.60,.063)
		for i in range(3):target("valve_"+str(i),Vector3([7.74,8.44,9.14][i],1.02,-3.59),"Turn "+["supply","return","bypass"][i]+" valve",0,.50,.115)
		target("archive",Vector3(7.995,1.025,-16.874),"Connect the encrypted evidence drive",4,.70,.09)
		target("core_door",Vector3(-.24,1.15,-18.989),"Enter the root-key vault",0,.75,.25)
		for i in range(2):target("ups_"+str(i),Vector3(-2.1+i*.48,1.40,-23.909),"Disconnect UPS supply "+["A","B"][i],0,.60,.070)
		target("key_probe",Vector3(.49,1.15,-23.132),"Verify the HSM main feed is at zero volts",2,1.0,.075)
		for i in range(2):target("key_screw_"+str(i),Vector3([-.13,.43][i],1.28,-23.129),"Remove tamper-panel screw",1,.9,.047)
		target("key_panel",Vector3(.15,1.28,-23.13),"Remove the tamper panel",0,.65,.18)
		target("key_cell",Vector3(.299,1.315,-23.175),"Pull the battery-backed memory cell",3,1.8,.060)
		target("ladder",Vector3(-8.97,1.15,-19.895),"Climb to the roof",0,.7,.19)
		target("extract",Vector3(-9.82,4.99,-10.023),"Call the extraction vehicle",0,1.0,.12)
		target("secret_ellis",Vector3(8.39,.989,-16.81),"Read pension record M07",0,.5,.12)
		target("secret_serial",Vector3(-3.99,1.2,-9.0),"Inspect the familiar server serial",0,.5,.14)
		target("secret_note",Vector3(-7.55,1.75,-11.98),"Read the engineer's handwritten note",0,.5,.25)
		create_coolant_screen()
		archive_label=create_status_display("ARCHIVE_SCREEN",Color("8dbab6"))
		key_label=create_status_display("KEY_SCREEN",Color("ce9b86"))
		game.world.show_part("DYN_EVIDENCE_DRIVE",game.copy_started and not game.evidence)

func enumerate_screws():return [[0,Vector2(-.187,-.184)],[1,Vector2(.187,-.184)],[2,Vector2(-.187,.184)],[3,Vector2(.187,.184)]]

func active(id)->bool:
	if id.begins_with("secret_"):return true
	if game.location=="shop":
		if id=="case":return game.repair_step>=10 and not game.case_taken and not game.finished
		if id=="depart":return game.case_taken and not game.finished
		if id=="pc_power":return game.repair_step in [0,8]
		if id=="pc_meter":return game.repair_step==1
		if id.begins_with("pc_screw_"):
			var i=int(id.trim_prefix("pc_screw_"))
			return game.repair_step==2 and not game.removed_screws.has(i) or game.repair_step==7 and not game.tightened_screws.has(i)
		if id=="pc_panel":return game.repair_step in [3,6]
		if id=="pc_clip":return game.repair_step==4
		if id=="pc_cell":return game.repair_step==5
		if id=="pc_bios":return game.repair_step==9
		return false
	if id=="workorder" or id=="coolant_note":return true
	if id=="entry":return game.mission_step==0
	if id.begins_with("feed_"):return game.mission_step==1 and not game.feed_identified
	if id=="isolate":return game.mission_step==1 and game.feed_identified and not game.camera_isolated
	if id=="bridge":return game.mission_step==1 and game.camera_isolated and not game.camera_loop
	if id=="hall":return game.mission_step==2
	if id.begins_with("fuse_"):return game.mission_step>=1 and not game.fuse_installed
	if id=="pump_fuse":return game.mission_step>=3 and not game.fuse_installed
	if id=="pump_start":return game.mission_step>=3 and game.fuse_installed and not game.pump_power and not game.key_down
	if id.begins_with("valve_"):return game.mission_step==3
	if id=="archive":return game.mission_step==4
	if id=="core_door":return game.mission_step==5
	if id.begins_with("ups_"):return game.mission_step==6 and not game.ups_off[int(id.trim_prefix("ups_"))]
	if id=="key_probe":return game.mission_step==6 and not game.key_verified
	if id.begins_with("key_screw_"):return game.mission_step==6 and game.key_verified and not game.key_screws.has(int(id.trim_prefix("key_screw_")))
	if id=="key_panel":return game.mission_step==6 and game.key_screws.size()==2
	if id=="key_cell":return game.mission_step==7
	if id=="ladder":return game.key_down and game.body.position.y<2
	if id=="extract":return game.key_down and game.body.position.y>3.8
	return false

func required_tool(id):
	if id=="archive" and game.copy_started:return 0
	for a in targets:
		if a.id==id:return int(a.tool)
	return 0

func target_position(id,base):
	if id=="pc_panel":
		var panel=game.world.node("DYN_PC_PANEL")
		if panel:return panel.global_position+Vector3(0,0,.012)
	if id=="pc_power":
		var plug=game.world.node("DYN_PC_PLUG")
		if plug:return plug.global_position+Vector3(0,.01,.04)
	return base

func label(id):
	if id=="pc_power" and game.repair_step==8:return "Reconnect the mains lead"
	if id=="pc_panel" and game.repair_step==6:return "Refit the service panel"
	if id.begins_with("pc_screw_") and game.repair_step==7:return "Retighten panel screw"
	if id=="bridge":return "Seat bridge / GREEN" if fmod(game.elapsed,5)<2.1 else "Wait for the GREEN diagnostic pulse"
	if id=="archive" and game.copy_started:return "Retrieve verified evidence" if game.copy_progress>=1 else "Copying pension archive / %d%%"%int(game.copy_progress*100)
	if id.begins_with("valve_"):
		var i=int(id.trim_prefix("valve_"))
		return ["Supply","Return","Bypass"][i]+" valve / %d%%"%int(game.valves[i]*100)
	for a in targets:
		if a.id==id:return a.label
	return "Inspect"

func perform(id):
	var w=game.world
	if id.begins_with("secret_"):
		secret(id)
		return
	if id.begins_with("pc_screw_"):
		var i=int(id.trim_prefix("pc_screw_"))
		game.play_fx("driver")
		if game.repair_step==2:
			game.removed_screws.append(i)
			w.show_part("DYN_PC_SCREW_"+str(i),false)
			if game.removed_screws.size()==4:game.repair_step=3
		else:
			game.tightened_screws.append(i)
			w.part_restore("DYN_PC_SCREW_"+str(i))
			if game.tightened_screws.size()==4:game.repair_step=8
	elif id=="pc_power":
		if game.repair_step==0:
			w.part_shift("DYN_PC_PLUG",Vector3(.02,.025,.08))
			game.repair_step=1
		else:
			w.part_restore("DYN_PC_PLUG")
			game.repair_step=9
		game.play_fx("relay")
	elif id=="pc_meter":
		game.repair_step=2
		game.ui.toast("0.00 V / Discharged. Safe to open.")
		game.play_fx("success")
	elif id=="pc_panel":
		if game.repair_step==3:
			w.part_shift("DYN_PC_PANEL",Vector3(.52,.035,.09))
			game.repair_step=4
		else:
			w.part_restore("DYN_PC_PANEL")
			for i in range(4):
				w.show_part("DYN_PC_SCREW_"+str(i),true)
				w.part_shift("DYN_PC_SCREW_"+str(i),Vector3(0,0,.02))
			game.repair_step=7
		game.play_fx("door")
	elif id=="pc_clip":
		w.part_shift("DYN_CELL_CLIP",Vector3(.005,0,0))
		w.show_part("DYN_OLD_CELL",false)
		game.repair_step=5
		game.play_fx("clip")
	elif id=="pc_cell":
		w.show_part("DYN_OLD_CELL",true)
		w.part_restore("DYN_CELL_CLIP")
		game.repair_step=6
		game.play_fx("fuse")
		game.ui.toast("CR2032 seated / + face out / 3.02 V")
	elif id=="pc_bios":
		game.repair_step=10
		w.replace_screen("SHOP_CRT",load("res://assets/textures/bios_fixed.png"))
		game.play_fx("success")
		game.begin_cinematic("opening")
	elif id=="case":
		game.case_taken=true
		var lid=w.node("DYN_CASE_LID")
		if lid:game.create_tween().tween_property(lid,"rotation:x",-1.85,.6)
		game.ui.show_contract()
	elif id=="depart":game.depart()
	elif id=="entry":
		game.mission_step=1
		w.open_door("entry")
		game.ui.toast("NIGHT MAINTENANCE / Service identity accepted.")
	elif id=="workorder":
		if not game.notes.has("workorder"):game.notes.append("workorder")
		game.ui.show_note("NIGHT MAINTENANCE", "Feed 07 supplies optical security. Put bus C3 into isolated service mode, then bridge the recorder during the GREEN diagnostic pulse. The watchdog must remain powered.\n\nPump motor: 3.6A running, 6A at startup. Fit a T6.3A slow-blow fuse.")
	elif id.begins_with("feed_"):
		var i=int(id.trim_prefix("feed_"))
		if i==1:
			game.feed_identified=true
			game.ui.toast("FEED 07 / 12.0V / C3 optical security. Trace confirmed.")
		else:game.ui.toast(["FEED 06 / 24.0V / Door interlock","","FEED 08 / 5.0V / Fire controller","FEED 09 / 24.0V / Leak sensor"][i])
		game.play_fx("click")
	elif id=="isolate":
		game.camera_isolated=true
		w.part_shift("DYN_BREAKER_2",Vector3(0,-.028,0))
		game.ui.toast("C3 in service mode / Watchdog still at 5V.")
		game.play_fx("relay")
	elif id=="bridge":
		if fmod(game.elapsed,5)>=2.1:
			game.ui.toast("Pulse missed. Release, watch the green LED, and try again.")
			game.play_fx("error")
			return
		game.camera_loop=true
		w.show_part("DYN_LOOP_BRIDGE",true)
		game.mission_step=2
		game.play_hint("camera_loop")
		game.play_fx("success")
	elif id=="hall":
		game.mission_step=3
		w.open_door("hall")
	elif id.begins_with("fuse_"):
		var i=int(id.trim_prefix("fuse_"))
		game.fuse_rating=i
		for j in range(3):w.show_part("DYN_SPARE_FUSE_"+str(j),j!=i)
		game.ui.toast(["T2A","T6.3A","T10A"][i]+" slow-blow fuse added to tools.")
		game.play_fx("fuse")
	elif id=="coolant_note":
		if not game.notes.has("coolant"):game.notes.append("coolant")
		game.ui.show_note("CHILLED-WATER LOOP", "Chiller supply: 12°C. Core heat load: 4kW.\n\nThe core needs at least 8 L/min. Keep pressure between 180 and 220 kPa. Close the bypass, then balance supply and return. The interlock opens below 20°C.\n\nReturn fully open, supply three-quarters open, bypass closed is a safe starting point.")
	elif id=="pump_fuse":
		if game.fuse_rating!=1:
			game.play_hint("wrong_fuse")
			game.ui.toast("Motor protection calls for T6.3A. Spare fuses are in the power room.")
			return
		game.fuse_installed=true
		game.fuse_rating=-1
		game.set_tool(0)
		game.play_fx("fuse")
		game.ui.toast("T6.3A protection restored. Start the pump.")
	elif id=="pump_start":
		game.pump_power=true
		game.play_hint("pump_online")
		game.play_fx("relay")
	elif id.begins_with("valve_"):
		var i=int(id.trim_prefix("valve_"))
		game.valves[i]=fmod(game.valves[i]+.25,1.25)
		var n=w.node("DYN_VALVE_"+str(i))
		if n:game.create_tween().tween_property(n,"rotation:z",game.valves[i]*TAU,.3)
		game.play_fx("driver")
	elif id=="archive":
		if not game.copy_started:
			game.copy_started=true
			w.show_part("DYN_EVIDENCE_DRIVE",true)
			game.ui.toast("Encrypted mirror started / 16 seconds. Keep your cover.")
			game.play_fx("relay")
		elif game.copy_progress<1:
			game.ui.toast("Copy still running. Leave the drive connected.")
		else:
			game.evidence=true
			w.show_part("DYN_EVIDENCE_DRIVE",false)
			game.mission_step=5
			game.play_hint("copy_ready")
			game.play_fx("success")
	elif id=="core_door":
		game.mission_step=6
		w.open_door("core")
		game.begin_cinematic("core")
	elif id.begins_with("ups_"):
		var i=int(id.trim_prefix("ups_"))
		game.ups_off[i]=true
		w.part_shift("DYN_UPS_"+str(i),Vector3(0,-.048,0))
		game.play_fx("relay")
	elif id=="key_probe":
		if not game.ups_off[0] or not game.ups_off[1]:
			game.ui.toast("Main feed is live. Isolate BOTH UPS supplies first.")
			return
		game.key_verified=true
		game.ui.toast("Main feed: 0.00V. Secure-memory battery: 3.0V. Safe to open.")
		game.play_fx("success")
	elif id.begins_with("key_screw_"):
		var i=int(id.trim_prefix("key_screw_"))
		game.key_screws.append(i)
		w.show_part("DYN_KEY_SCREW_"+str(i),false)
		game.play_fx("driver")
	elif id=="key_panel":
		game.key_open=true
		game.mission_step=7
		w.part_shift("DYN_KEY_PANEL",Vector3(.70,.04,.08))
		game.play_fx("door")
	elif id=="key_cell":
		game.key_down=true
		game.mission_step=8
		w.show_part("DYN_KEY_CELL",false)
		game.play_fx("shutdown")
		game.play_hint("key_down")
		game.get_tree().create_timer(4.4).timeout.connect(func():
			if game.location=="vault" and not game.finished:game.play_hint("escape"))
		game.ui.toast("ROOT KEY ZEROIZED / Evidence secured. Emergency patrol incoming.")
	elif id=="ladder":climb()
	elif id=="extract":
		game.mission_step=9
		game.ending()
	game.ui.refresh()

func process_machines(dt):
	if game.pump_power:
		game.flow=11.8*min(float(game.valves[0]),float(game.valves[1]))*(1-.5*float(game.valves[2]))
		game.pressure=260*float(game.valves[0])/max(.20,float(game.valves[1]))*(1-.35*float(game.valves[2]))
		var target_temperature=min(60.0,12.0+57.4/max(.1,game.flow))
		game.temperature=lerpf(game.temperature,target_temperature,1-exp(-dt*.62))
	else:
		game.flow=0
		game.pressure=0
	if game.mission_step==3 and game.flow>=8 and game.pressure>=180 and game.pressure<=220 and game.temperature<20:
		thermal_clock+=dt
		if thermal_clock>1.4:
			game.mission_step=4
			game.play_hint("cooling_ready")
			game.ui.toast("THERMAL INTERLOCK READY / Back up the archive in the east office.")
			game.save_game()
	else:thermal_clock=0
	if game.copy_started and not game.evidence:
		game.copy_progress=min(1,game.copy_progress+dt/16)
	for entry in [["kPa",game.pressure,400],["C",game.temperature,60]]:
		var unit=entry[0]
		var value=entry[1]
		var maxvalue=entry[2]
		var n=game.world.node("DYN_GAUGE_"+unit)
		if n:n.rotation.z=deg_to_rad(135-clampf(float(value)/maxvalue,0,1)*270)
	var led=game.world.node("DYN_DIAG_LED")
	if led is MeshInstance3D:
		if not led.material_override:
			var m=StandardMaterial3D.new()
			m.emission_enabled=true
			m.emission_energy_multiplier=.6
			led.material_override=m
		var green=fmod(game.elapsed,5)<2.1
		led.material_override.albedo_color=Color("54ba74") if green else Color("70251b")
		led.material_override.emission=led.material_override.albedo_color
	screen_clock+=dt
	if screen_clock>.5 and screen_label:
		screen_clock=0
		screen_label.text="CORE / CHILLED WATER\n\nFLOW       %.1f L/min\nPRESSURE   %d kPa\nCORE       %.1f C\n\nTARGET: 8 L/min / 180-220 kPa\n"%[game.flow,game.pressure,game.temperature]
		screen_view.render_target_update_mode=SubViewport.UPDATE_ONCE
		if archive_label:
			var progress="READY / INSERT SECURE DRIVE"
			if game.copy_started:progress="COPY / %d%% / VERIFYING"%int(game.copy_progress*100)
			if game.copy_progress>=1:progress="VERIFIED / RETRIEVE DRIVE"
			if game.evidence:progress="EVIDENCE SECURED / AES-256"
			archive_label.text="MERIDIAN / SEALED ARCHIVE\n\n8,014,922 PENSION RECORDS\nELLIS, HELEN / INDEX M07\n\n"+progress+"\nBACKUP BEFORE DESTRUCTION"
		if key_label:
			key_label.text="WIDOWMAKER / ROOT MEMORY\n\nUPS A    "+("0.00 V" if game.ups_off[0] else "230 V")+"\nUPS B    "+("0.00 V" if game.ups_off[1] else "230 V")+"\nCELL     "+("REMOVED" if game.key_down else "3.00 V")+"\n\n"+("ROOT ZEROIZED / IRREVERSIBLE" if game.key_down else "DUAL SUPPLY / TAMPER SEALED")
		for screen in extra_screens:screen.render_target_update_mode=SubViewport.UPDATE_ONCE
		var interlock=game.world.node("DYN_CORE_LED")
		if interlock is MeshInstance3D:
			var m=StandardMaterial3D.new()
			m.albedo_color=Color("cf573e") if game.key_down else (Color("72ba91") if game.mission_step>=5 else Color("c56c4e"))
			m.emission_enabled=true
			m.emission=m.albedo_color
			m.emission_energy_multiplier=.65
			interlock.material_override=m

func create_coolant_screen():
	screen_view=SubViewport.new()
	screen_view.disable_3d=true
	screen_view.size=Vector2i(768,432)
	screen_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	game.add_child(screen_view)
	var bg=ColorRect.new()
	bg.color=Color("061519")
	bg.size=Vector2(768,432)
	screen_view.add_child(bg)
	screen_label=Label.new()
	screen_label.position=Vector2(30,25)
	screen_label.size=Vector2(710,380)
	screen_label.add_theme_font_override("font",load("res://assets/fonts/workshop.ttf"))
	screen_label.add_theme_font_size_override("font_size",35)
	screen_label.add_theme_color_override("font_color",Color("86b6ae"))
	screen_view.add_child(screen_label)
	game.world.replace_screen("COOLANT_SCREEN",screen_view.get_texture())

func create_status_display(name,color):
	var view=SubViewport.new()
	view.disable_3d=true
	view.size=Vector2i(768,432)
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	game.add_child(view)
	extra_screens.append(view)
	var background=ColorRect.new()
	background.color=Color("081114")
	background.size=Vector2(768,432)
	view.add_child(background)
	var text=Label.new()
	text.position=Vector2(28,27)
	text.size=Vector2(710,380)
	text.add_theme_font_override("font",load("res://assets/fonts/workshop_ui.ttf"))
	text.add_theme_font_size_override("font_size",33)
	text.add_theme_color_override("font_color",color)
	view.add_child(text)
	game.world.replace_screen(name,view.get_texture())
	return text

func climb():
	game.climbing=true
	game.held=false
	game.body.velocity=Vector3.ZERO
	game.yaw=0
	game.pitch=.45
	game.update_look()
	game.ui.toast("CLIMBING / Keep quiet on the roof.")
	var tween=game.create_tween()
	tween.tween_property(game.body,"position",Vector3(-8.97,.025,-19.76),.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(game.body,"position",Vector3(-8.97,4.18,-19.76),4.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(game.body,"position",Vector3(-8.97,4.025,-19.30),.55).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		game.climbing=false
		game.yaw=PI
		game.pitch=-.06
		game.update_look()
		game.save_game())

func secret(id):
	var entries={
		"secret_cat":"BIOS is the only supervisor who approves naps.",
		"secret_coffee":"No cloud. Just coffee. Steve's mug has outlived four start-ups.",
		"secret_receipt":"Two pounds for the part. Arthur's letters backed up for free.",
		"secret_magazine":"BYTE, October 1998. Steve has bookmarked an article about the year 2000.",
		"secret_calendar":"Thursday: Ms. Ellis. Every Thursday. Some appointments matter.",
		"secret_ellis":"Helen Ellis / record 00000007. This contract just became personal.",
		"secret_serial":"ELL-1933-THU. The ledger has Ms. Ellis's identifier hidden in plain sight.",
		"secret_note":"Have you tried unplugging the oligarch? An engineer with a sense of humour."}
	game.add_secret(id,entries[id])
	if id=="secret_cat":
		game.play_fx("pet")
		var cat=game.world.actors.get("bios")
		if cat:
			var head=cat.find_child("Head",true,false)
			if head:
				var t=game.create_tween()
				t.tween_property(head,"rotation:x",-.20,.3)
				t.tween_property(head,"rotation:x",0,.7)

func restore_parts():
	var w=game.world
	if game.location=="shop":
		for i in range(4):w.show_part("DYN_PC_SCREW_"+str(i),game.repair_step>=7 or not game.removed_screws.has(i))
		if game.repair_step>=4 and game.repair_step<7:w.part_shift("DYN_PC_PANEL",Vector3(.52,.035,.09))
		if game.repair_step>=1 and game.repair_step<=8:w.part_shift("DYN_PC_PLUG",Vector3(.02,.025,.08))
		if game.repair_step==5:w.part_shift("DYN_CELL_CLIP",Vector3(.005,0,0))
		w.show_part("DYN_OLD_CELL",game.repair_step!=5)
		if game.repair_step>=10:w.replace_screen("SHOP_CRT",load("res://assets/textures/bios_fixed.png"))
	else:
		w.show_part("DYN_LOOP_BRIDGE",game.camera_loop)
		if game.camera_isolated:w.part_shift("DYN_BREAKER_2",Vector3(0,-.028,0))
		for i in range(3):w.show_part("DYN_SPARE_FUSE_"+str(i),game.fuse_rating!=i)
		for i in range(3):
			var valve=w.node("DYN_VALVE_"+str(i))
			if valve:valve.rotation.z=game.valves[i]*TAU
		if game.mission_step>=1:w.open_door("entry")
		if game.mission_step>=3:w.open_door("hall")
		if game.mission_step>=6:w.open_door("core")
		for i in range(2):
			if game.ups_off[i]:w.part_shift("DYN_UPS_"+str(i),Vector3(0,-.048,0))
			w.show_part("DYN_KEY_SCREW_"+str(i),not game.key_screws.has(i))
		if game.key_open:w.part_shift("DYN_KEY_PANEL",Vector3(.70,.04,.08))
		w.show_part("DYN_KEY_CELL",not game.key_down)

func objective():
	if game.finished:return "SHIFT COMPLETE / A small shop. Eight million second chances."
	if game.location=="shop":
		if game.repair_step<10:
			return ["Disconnect the mains lead","Verify power is discharged with the meter","Remove the four service-panel screws / %d of 4"%game.removed_screws.size(),"Slide off the service panel","Release the retaining clip with the precision pick","Fit the new CR2032 / positive face out","Refit the service panel","Retighten the four screws / %d of 4"%game.tightened_screws.size(),"Reconnect the mains lead","Validate the boot, clock, and backup"][game.repair_step]
		return "Leave through the front door for Tallinn" if game.case_taken else "Inspect Oleg's briefcase on the counter"
	var texts=["Present the service badge at the loading door","Trace feed 07, isolate C3, and bridge its green pulse","Open the maintenance door into the server hall","Repair the chiller / fuse, flow, and pressure","Mirror the pension archive in the east office","Bring the evidence into the root-key vault","Isolate both UPS feeds, verify 0V, and open the HSM","Pull the secure-memory battery","Reach the west-bay roof hatch and call extraction","Contract complete"]
	return texts[clampi(game.mission_step,0,texts.size()-1)]

func hint():
	if game.location=="shop":
		return "The mains connector and meter test jack are left of the PC. Choose your tools with 0-5 or TOOLS."
	if game.mission_step==1:return "Power room: west corridor, back wall. Probe the numbered pads with the meter. Feed 07 is the camera line."
	if game.mission_step==3:return "T6.3A fuse is on the power-room cart. Cooling is east of the hall. Start with supply 75%, return 100%, bypass 0%."
	if game.mission_step==4:return "The archive PC is in the east office. Connect the encrypted drive, let the copy finish, then retrieve it with empty hands."
	if game.mission_step==6:return "Both UPS switches are inside the vault, left of the HSM. Meter the feed before turning either tamper screw."
	if game.mission_step>=8:return "Return to the west power room and pass through its rear doorway. The ladder reaches the roof. Crouch behind HVAC units."
	return "Read the work order. Use cover, keep your light off near patrols, and listen for the drone."
