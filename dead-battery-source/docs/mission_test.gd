extends SceneTree
var g
var checks=0
var walking=true
func _initialize():call_deferred("run")
func fail(message):
 printerr("FAIL / ",message)
 quit(1)
 walking=false
func verify(value,message):
 if not value:fail(message)
 else:checks+=1;print("PASS / ",message)
func settle(t=.25):await create_timer(t).timeout
func move_to(x,z):
 if not walking:return
 var dest=Vector3(x,g.body.position.y,z)
 var start=Time.get_ticks_msec()
 var initial=g.body.position
 while Vector2(g.body.position.x-x,g.body.position.z-z).length()>.16:
  var d=dest-g.body.position
  g.yaw=atan2(-d.x,-d.z);g.pitch=-.08;g.update_look()
  g.touch_move=Vector2(0,-1)
  if Time.get_ticks_msec()-start>12000:
   fail("Walking blocked from %s to (%s,%s), current %s"%[initial,x,z,g.body.position]);return
  await physics_frame
 g.touch_move=Vector2.ZERO
 await settle(.3)
func aim(id):
 var a={}
 for t in g.tasks.targets:
  if t.id==id:a=t;break
 verify(not a.is_empty(),"Target exists / "+id)
 a=a.duplicate();a.p=g.tasks.target_position(id,a.p)
 var d=a.p-g.cam.global_position
 g.yaw=atan2(-d.x,-d.z);g.pitch=asin(d.y/d.length());g.update_look()
 await settle(.15)
 g.refresh_focus()
 if g.focus.get("id","")!=id:
  var q=PhysicsRayQueryParameters3D.create(g.cam.global_position,a.p)
  q.exclude=[g.body.get_rid()]
  print("PHASE ",g.repair_step," ",g.mission_step," focus ",g.focus," forward ",-g.cam.global_basis.z," expected ",d.normalized());print("RAY / ",id," ",g.get_world_3d().direct_space_state.intersect_ray(q)," origin ",g.cam.global_position," target ",a.p)
 verify(g.focus.get("id","")==id,"First-person focus reaches / "+id)
 return a
func use(id,tool_=-1):
 if not walking:return
 var point=Vector3.ZERO
 for t in g.tasks.targets:
  if t.id==id:point=g.tasks.target_position(id,t.p)
 if point.distance_to(g.cam.global_position)>1.57:await move_to(point.x,point.z+1.0)
 var a=await aim(id)
 if tool_<0:tool_=g.tasks.required_tool(id)
 g.set_tool(tool_)
 g.action_hold(true)
 await settle(float(a.duration)+.25)
 verify(g.hold_latched or not g.tasks.active(id),"Held tool action completed / "+id)
 print("ACTION STATE / ",id," tool ",g.tool," phase ",g.repair_step," step ",g.mission_step," toast ",g.ui.toast_label.text)
 g.action_hold(false)
 await settle(.15)
func fixture(name):
 g.save_game()
 var f=FileAccess.open("res://docs/fixture_"+name+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify(g.read_save()))
 f.close()

func run():
 Engine.time_scale=3
 g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await settle(.4)
 g.start_game();g.mobile=true;g.mobile_run=true
 await settle(.3)
 g.zoomed=true;g.set_tool(3);g._process(1.0);g._process(1.0)
 verify(g.cam.fov>=48 and g.cam.fov<=74 and g.hand_root.position.length()<1.2,"Camera and carried-tool interpolation stay stable after a one-second frame")
 g.zoomed=false;g.set_tool(0);g._process(1.0)
 verify(g.cam.get_parent()==g.head,"First-person camera attached to player head")
 verify(g.world.node("SHOP_CRT")!=null,"Shop display preserved in Blender export")
 await use("pc_power")
 await use("pc_meter",1)
 verify(g.repair_step==1,"Wrong tool cannot advance repair")
 await use("pc_meter")
 for i in range(4):await use("pc_screw_"+str(i))
 await use("pc_panel")
 fixture("pc_open")
 await use("pc_clip")
 await use("pc_cell")
 await use("pc_panel")
 for i in range(4):await use("pc_screw_"+str(i))
 await use("pc_power")
 await move_to(-1.29,-1.90)
 fixture("repaired")
 await use("pc_bios")
 verify(g.repair_step==10 and g.cine_name=="opening","All physical PC repair steps lead to voiced opening")
 verify(g.voice.playing and g.ui.caption.visible,"Cinematic voice and subtitles active")
 g.finish_cinematic()
 await move_to(-.37,-.85)
 await use("case")
 verify(g.case_taken and g.panel_open,"Briefcase opens paid contract")
 g.ui.close_panel(false)
 await move_to(3.03,-.8)
 await move_to(2.80,3.20)
 await use("depart")
 verify(g.cine_name=="arrival","Travel starts first-person arrival")
 g.finish_cinematic()
 await settle(.3)
 fixture("arrival")
 # Patrol visibility and alarm are asserted separately so every collision route is deterministic.
 g.last_alarm=g.elapsed+1000
 # Keep the patrol active. Its position is controlled only during separate security assertions below.
 await move_to(-6.99,3.30)
 await use("entry")
 await move_to(-7.75,1.1)
 await move_to(-7.85,-10.4)
 await move_to(-7.85,-13.2)
 await move_to(-8.15,-16.75)
 await use("feed_0")
 verify(not g.feed_identified,"Wrong security feed remains identifiable")
 await use("feed_1")
 await use("isolate")
 # Test missed pulse and successful retry.
 while fmod(g.elapsed,5)<2.7 or fmod(g.elapsed,5)>3.7:await process_frame
 await use("bridge")
 verify(not g.camera_loop,"Bridge rejects an unsafe diagnostic pulse")
 while fmod(g.elapsed,5)>.45:await process_frame
 await use("bridge")
 verify(g.camera_loop,"Bridge preserves watchdog and loops camera recorder")
 await move_to(-6.05,-14.80)
 await use("fuse_1")
 await move_to(-7.85,-13.2)
 await move_to(-7.85,-10.4)
 await move_to(-5.92,-5.05)
 await use("hall")
 await move_to(-3.9,-5.05)
 await move_to(-3.9,-1.1)
 await move_to(4.1,-3.2)
 await move_to(5.6,-3.2)
 await move_to(6.24,-5.74)
 await use("pump_fuse")
 await use("pump_start")
 fixture("chiller")
 await move_to(7.7,-2.4)
 for i in range(3):await use("valve_0")
 for i in range(4):await use("valve_1")
 await use("valve_2")
 await settle(10)
 verify(g.mission_step==4 and g.pressure>=180 and g.pressure<=220 and g.flow>=8 and g.temperature<20,"Real flow, pressure and temperature unlock thermal interlock")
 verify(g.world.node("COOLANT_SCREEN")!=null,"In-world live diagnostic screen is preserved")
 await move_to(5.6,-3.2)
 await move_to(3.75,-3.2)
 await move_to(4.1,-14.6)
 await move_to(6.0,-14.6)
 await move_to(8.45,-15.88)
 await use("archive")
 verify(g.copy_started and not g.evidence,"Evidence copy starts asynchronously")
 await use("archive")
 verify(not g.evidence,"Evidence cannot be retrieved before verification")
 await settle(16)
 await use("archive")
 verify(g.evidence,"Verified evidence retrieved from archive computer")
 await move_to(6,-14.6)
 await move_to(4.1,-14.6)
 await move_to(4.1,-17.6)
 await move_to(-.24,-17.6)
 await use("core_door")
 g.finish_cinematic()
 await move_to(-1.65,-22.75)
 await use("key_probe")
 verify(not g.key_verified,"Meter rejects an HSM live on dual UPS")
 await use("ups_0")
 await use("ups_1")
 await move_to(.15,-22.15)
 await use("key_probe")
 fixture("core")
 for i in range(2):await use("key_screw_"+str(i))
 await use("key_panel")
 await use("key_cell")
 verify(g.key_down and g.evidence,"Signing key zeroizes only after evidence has been preserved")
 # Deterministic surveillance assertions, with actual level collision and the player's capsule.
 var saved_pos=g.body.position
 g.body.position=Vector3(3.75,.02,-4.1)
 g.yaw=0;g.pitch=0;g.update_look()
 await settle(.1)
 verify(g.sees_player(Vector3(3.75,2.05,-3.0),Vector3(0,0,-1),10,.7),"Surveillance sees unobstructed player")
 g.body.position=Vector3(-2.84,.02,-7.7)
 await settle(.1)
 verify(not g.sees_player(Vector3(-2.84,2.05,-4.2),Vector3(0,0,-1),10,.7),"Server rack physically blocks surveillance sightline")
 var alerts_before=g.alerts
 var clock_before=g.auction_time
 g.drone.position=Vector3(-3.8,2.05,-3.8);g.drone_index=1
 g.body.position=Vector3(-1.8,.025,-3.8);g.last_alarm=-100;g.suspicion=.99
 g.process_security(.05)
 verify(g.alerts==alerts_before+1,"Patrol detection triggers an actual alarm")
 verify(g.body.position.distance_to(Vector3(-7.9,.025,-10.5))<.1 and abs(g.auction_time-(clock_before-15))<.1,"Alarm returns Steve to cover and applies a fifteen-second penalty")
 g.body.position=saved_pos
 g.suspicion=0;g.last_alarm=g.elapsed+60
 await move_to(.0,-20.2)
 await move_to(.0,-17.5)
 await move_to(-3.9,-17.5)
 await move_to(-3.9,-5.05)
 await move_to(-5.9,-5.05)
 await move_to(-7.7,-10.4)
 await move_to(-7.7,-13.3)
 await move_to(-8.75,-17.2)
 await move_to(-8.97,-18.7)
 await use("ladder")
 await settle(5.7)
 verify(g.body.position.y>3.8,"Ladder climbs through physical roof aperture")
 fixture("roof")
 await move_to(-9.8,-11.1)
 await use("extract")
 verify(g.cine_name=="ending","Rooftop extraction leads to voiced ending")
 g.finish_cinematic()
 verify(g.finished and g.state=="results","Full first-person mission completes")
 g.ui.close_panel(false);g.state="shop";g.save_game()
 var save=g.read_save()
 verify(save.evidence and save.key_down and save.finished,"Persistent save retains mission completion")
 print("MISSION PASS / ",checks," checks")
 g.queue_free()
 await process_frame
 quit()
