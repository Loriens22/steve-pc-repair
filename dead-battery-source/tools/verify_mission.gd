extends SceneTree

var game

func _initialize():
	call_deferred("run")

func expect_until(test: Callable, message: String, timeout: float=20) -> bool:
	var t=0.0
	while not test.call() and t<timeout:
		await create_timer(.1).timeout
		t+=.1
	if not test.call():
		push_error("FAIL "+message+" state="+game.state+" pos="+str(game.body.position))
		quit(1)
		return false
	print("PASS "+message)
	return true

func press(text: String):
	for b in game.ui.root.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text.begins_with(text):
			b.pressed.emit()
			return
	push_error("Missing button "+text)
	quit(1)

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	game.skip_cinematic()
	game.go_to_interaction("case")
	if not await expect_until(func():return game.panel_open,"walk to the briefcase"):return
	press("TAKE THE JOB")
	if not await expect_until(func():return game.case_taken,"collect the loadout"):return
	game.go_to_interaction("door")
	if not await expect_until(func():return game.state=="arrival","walk to the shop door"):return
	game.skip_cinematic()
	game.go_to_interaction("badge")
	if not await expect_until(func():return game.mission_step==1,"collect the cover identity"):return
	game.go_to_interaction("security")
	if not await expect_until(func():return game.panel_open,"navigate to the security console",30):return
	for instruction in [[3,1],[4,2],[1,2],[2,3],[5,2]]:
		for j in range(instruction[1]):game.puzzle.tiles[instruction[0]].pressed.emit()
	press("RUN DIAGNOSTIC")
	if not await expect_until(func():return game.mission_step==2,"solve the closed circuit"):return
	game.go_to_interaction("coolant")
	if not await expect_until(func():return game.panel_open,"navigate to the coolant valves"):return
	var plus=[]
	for b in game.ui.root.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text=="+" and b.get_parent()!=game.ui.marker_root:plus.append(b)
	for i in range(3):
		for j in range([3,6,3][i]):plus[i].pressed.emit()
	press("STABILIZE COOLANT")
	if not await expect_until(func():return game.mission_step==3,"restore thermal balance"):return
	game.go_to_interaction("core")
	if not await expect_until(func():return game.state=="core","navigate to the core",30):return
	game.skip_cinematic()
	press("01  /  COPY")
	press("02  /  ISOLATE")
	press("03  /  PULL")
	if not await expect_until(func():return game.mission_step==4,"secure evidence and destroy the key"):return
	game.go_to_interaction("lift")
	if not await expect_until(func():return game.state=="ending","reach extraction",30):return
	game.skip_cinematic()
	if not await expect_until(func():return game.state=="results","complete the ending"):return
	press("RETURN TO THE SHOP")
	game.save_game()
	game.resume_game()
	if not await expect_until(func():return game.finished and game.mission_step==5,"save and resume completed progress"):return
	print("COMPLETE MISSION VERIFIED / alerts=",game.alerts)
	quit(0)
