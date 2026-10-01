extends RefCounted

class CircuitTile extends Button:
	var mask: int = 0
	func _draw():
		var c = size / 2.0
		var r = min(size.x, size.y) * .37
		for k in range(4):
			if mask & (1 << k):
				var d = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][k]
				draw_line(c, c + d*r, Color("91c7b5"), 6, true)
		draw_circle(c, 6, Color("efac75"))
		draw_circle(c, 2.5, Color("18272b"))

var ui
var game
var panel: Control
var box: VBoxContainer
var hint: Label
var tiles: Array = []
var masks: Array = []
var kind = ""
var valves = [0, 0, 0]
var phase = 0
var core_nodes: Array = []

func open(h, g, puzzle: String):
	ui = h
	game = g
	kind = puzzle
	panel = ui.modal_base()
	box = ui.modal_box(panel, 610)
	var heads = {"circuit":"01 / CLOSED CIRCUIT", "coolant":"02 / THERMAL BALANCE", "core":"03 / A CLEAN BREAK", "case":"PAID IN FULL", "diagnostic":"THE OLDEST FIX IN THE BOOK"}
	ui.label_to(box, heads.get(kind,"DIAGNOSTIC"), 13, ui.ACCENT)
	if kind == "circuit": circuit()
	elif kind == "coolant": coolant()
	elif kind == "core": core()
	elif kind == "case": briefcase()
	elif kind == "diagnostic": diagnostic()
	ui.button_to(box, "BACK TO THE JOB", close, false)

func close():
	game.panel_open = false
	panel.queue_free()
	ui.modal = null

func solved(message: String):
	game.sfx("success")
	ui.toast(message)
	game.puzzle_complete(kind)
	close()

func circuit():
	ui.label_to(box,"Give security a new route.",30)
	ui.label_to(box,"Rotate the copper traces. Connect IN on the left of the middle row to OUT on its right. Then run the diagnostic.",17,ui.MUTED)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",10)
	box.add_child(row)
	ui.label_to(row,"IN >",17,ui.ACCENT)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",7)
	grid.add_theme_constant_override("v_separation",7)
	row.add_child(grid)
	ui.label_to(row,"> OUT",17,ui.ACCENT)
	masks = [3, 6, 12, 10, 9, 3, 3, 5, 9]
	var rotations = [1, 2, 1, 1, 2, 2, 2, 1, 1]
	for i in range(9):
		for j in range(rotations[i]): masks[i] = rotate_mask(masks[i])
		var t = CircuitTile.new()
		t.custom_minimum_size = Vector2(72,72) if ui.mobile else Vector2(90,90)
		t.mask = masks[i]
		t.add_theme_stylebox_override("normal", ui.style(Color("203439"),Color("42605c")))
		t.add_theme_stylebox_override("hover", ui.style(Color("2b4949"),ui.ACCENT))
		t.pressed.connect(func():
			masks[i] = rotate_mask(masks[i])
			t.mask = masks[i]
			t.queue_redraw()
			game.sfx("click"))
		grid.add_child(t)
		tiles.append(t)
	hint = ui.label_to(box,"A small detour. An enormous blind spot.",16,ui.MUTED)
	ui.button_to(box,"RUN DIAGNOSTIC",check_circuit)
	ui.button_to(box,"TECHNICIAN'S HINT",func():hint.text="From IN: right, up, right, down, right. Five tiles make the route.",false)

func rotate_mask(m: int) -> int:
	return ((m << 1) & 15) | ((m >> 3) & 1)

func check_circuit():
	var x = 0
	var y = 1
	var incoming = 3
	var seen: Array = []
	for j in range(16):
		var idx = y*3+x
		if seen.has(idx) or not (masks[idx] & (1 << incoming)): break
		seen.append(idx)
		var next = -1
		for d in range(4):
			if d != incoming and masks[idx] & (1 << d): next=d
		if next < 0: break
		var dir = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][next]
		x += dir.x
		y += dir.y
		if x == 3 and y == 1:
			solved("CAMERA LOOP ACTIVE • Keep an eye on the patrol drone.")
			return
		if x<0 or x>2 or y<0 or y>2: break
		incoming = (next+2)%4
	game.sfx("error")
	hint.text="Open circuit. Check where each trace enters the next tile."

func coolant():
	ui.label_to(box,"Cool heads. Warm pipes.",30)
	ui.label_to(box,"The core unlocks at 18°C. Balance three valves to a total flow of 12 L/min. The maintenance note says: amber = 3, blue = twice amber, return = amber.",17,ui.MUTED)
	var colors = [ui.ACCENT,Color("79bccc"),ui.GREEN]
	for i in range(3):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",15)
		box.add_child(row)
		var l = ui.label_to(row,["AMBER / SUPPLY","BLUE / CORE","GREEN / RETURN"][i],15,colors[i])
		l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var value = ui.label_to(row,"00 L/min",22)
		ui.button_to(row,"-",func():
			valves[i] = (valves[i]+8)%9
			value.text = "%02d L/min" % valves[i]
			update_temperature(),false).custom_minimum_size=Vector2(48,46)
		ui.button_to(row,"+",func():
			valves[i] = (valves[i]+1)%9
			value.text = "%02d L/min" % valves[i]
			update_temperature(),false).custom_minimum_size=Vector2(48,46)
	hint = ui.label_to(box,"CORE TEMPERATURE   38°C / TARGET 18°C",17,ui.ACCENT)
	ui.button_to(box,"STABILIZE COOLANT",func():
		if valves == [3,6,3]: solved("THERMAL BALANCE RESTORED • The magnetic lock is open.")
		else:
			game.sfx("error")
			hint.text="Uneven pressure. Try 3 / 6 / 3 L/min.")

func update_temperature():
	game.sfx("click")
	var e = abs(valves[0]-3)+abs(valves[1]-6)+abs(valves[2]-3)
	hint.text="CORE TEMPERATURE   %d°C / TARGET 18°C" % (18+e*2)

func core():
	ui.label_to(box,"Backup first. Always.",30)
	ui.label_to(box,"A clean shutdown needs a clean sequence. Copy the stolen records, isolate the signing key, then remove its power. Choose the next step.",17,ui.MUTED)
	hint=ui.label_to(box,"EVIDENCE: NOT SECURED\nSIGNING KEY: ACTIVE\nPOWER: ONLINE",16,ui.ACCENT)
	for i in range(3):
		var b=ui.button_to(box,["01  /  COPY THE RECORDS","02  /  ISOLATE THE SIGNING KEY","03  /  PULL THE CMOS BATTERY"][i],func():
			if i == phase:
				phase+=1
				game.sfx("success")
				core_nodes[i].disabled=true
				hint.text=["EVIDENCE: ENCRYPTED COPY SECURED\nSIGNING KEY: ACTIVE\nPOWER: ONLINE","EVIDENCE: SECURED\nSIGNING KEY: ISOLATED\nPOWER: ONLINE","EVIDENCE: SECURED\nSIGNING KEY: DESTROYED\nPOWER: OFFLINE"][i]
				if phase==3:solved("ASSET DOWN • Evidence secured. Reach the roof lift.")
			else:
				game.sfx("error")
				hint.text="Order matters. A good technician always backs up first.")
		core_nodes.append(b)

func briefcase():
	ui.label_to(box,"Some jobs travel first class.",30)
	ui.label_to(box,"CLIENT     Oleg / verified\nPAYMENT    100% received\nDESTINATION    Tallinn · Meridian\nTARGET     The Widowmaker signing key",17,ui.MUTED)
	for s in ["01  BURN PHONE  /  encrypted line to Oleg","02  SERVICE BADGE  /  night maintenance","03  MULTITOOL  /  warranty not included","04  FLIGHT  /  first class, one carry-on"]:
		ui.label_to(box,s,16)
	ui.label_to(box,"“Anything else?”\n“One CR2032. I hate repeat visits.”",18,ui.ACCENT)
	ui.button_to(box,"TAKE THE JOB",func():solved("LOADOUT READY • Leave through the shop door."))

func diagnostic():
	ui.label_to(box,"Still good for another decade.",30)
	ui.label_to(box,"MS. ELLIS / WINDOWS 98\nBattery: CR2032 · 3.02 V\nBIOS clock: correct\nArthur's letters: backed up twice\nInvoice: £2.00",18,ui.MUTED)
	ui.label_to(box,"You don't replace a life because its battery ran out.",20,ui.ACCENT)
	ui.button_to(box,"PRINT A SECOND BACKUP",func():
		game.find_secret("backup")
		ui.toast("SECOND BACKUP PRINTED • Arthur would approve.")
		game.sfx("success")
		close())
