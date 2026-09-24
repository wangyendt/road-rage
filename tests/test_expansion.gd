extends SceneTree
const Data = preload("res://scripts/game_data.gd")
const Director = preload("res://scripts/race_director.gd")
const Controls = preload("res://scripts/controls.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS V2 ",label)
	else:
		failed+=1
		push_error("FAIL V2 "+label)
func step(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
func fresh(count: int=15, level: int=5) -> void:
	Input.action_release("boost")
	game.race_options={"course":0,"ai_count":count,"difficulty":level}
	game.start_race()
	game.state="race"
	game.countdown=0
	game.set_process(false)
func quiet_track() -> void:
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
	game.traffic_timer=INF
	game.pickup_timer=INF
	game.damage_cooldown=10000
	for r in game.rivals: r.cooldown=10000
func max_gap() -> float:
	var gap=-INF
	for r in game.rivals: gap=maxf(gap,r.distance-game.distance)
	return gap
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	check(game.profiles.size()==15,"fifteen complete rider profiles")
	var names={}
	for p in game.profiles: names[p.name]=true
	check(names.size()==15,"rider names and identities are unique")
	check(game.profiles[14].pace>game.profiles[3].pace and game.profiles[3].handling>game.profiles[4].handling,"riders have materially different strengths")
	var shapes=[]
	var lights=[]
	for i in 4:
		game.world.build(i)
		shapes.append(game.world.center_at(1500))
		lights.append(game.world.environment.sky.sky_material.sky_top_color)
		check(game.world.course.id==Data.COURSES[i].id and game.world.chunks.size()==27,"course %d builds complete road and scenery"%i)
	check(shapes[0]!=shapes[1] and shapes[1]!=shapes[2] and shapes[2]!=shapes[3],"course selection changes actual road geometry")
	check(lights[0]!=lights[1] and lights[1]!=lights[2] and lights[2]!=lights[3],"course selection changes actual lighting")
	check(Data.difficulty(5).reaction<Data.difficulty(4).reaction*0.75,"level five has nonlinear reaction challenge")
	for level in range(1,6):
		var p=game.profiles[0]
		var back=Director.target_speed(level,p,-300,3000)
		var even=Director.target_speed(level,p,0,3000)
		var front=Director.target_speed(level,p,300,3000)
		check(back>even and even>front,"level %d adapts pace in both directions"%level)
		check(Director.target_speed(level,p,-100000,3000)<=106 and Director.target_speed(level,p,100000,3000)>=49,"level %d compensation remains bounded"%level)
	check(Director.target_speed(5,game.profiles[0],0,3000)>Director.target_speed(1,game.profiles[0],0,3000)+12,"top difficulty is meaningfully faster without compensation")
	var input=Controls.new()
	input.apply()
	input.rebind("steer_left",KEY_D)
	check(input.keys.steer_left==KEY_D and input.keys.steer_right==KEY_A,"conflicting assignments swap rather than duplicate")
	input.rebind("boost",KEY_F)
	check(InputMap.action_get_events("boost")[0].physical_keycode==KEY_F,"rebinding updates real InputMap")
	input.rebind("boost",KEY_ESCAPE)
	check(input.keys.boost==KEY_F,"reserved keys cannot destroy escape navigation")
	var config=ConfigFile.new()
	input.save_config(config)
	var restored=Controls.new()
	restored.load_config(config)
	check(restored.keys==input.keys,"key bindings survive save/load")
	config.set_value("keys","boost",KEY_D)
	restored.load_config(config)
	check(restored.keys==Controls.DEFAULTS,"invalid duplicate saved bindings recover to defaults")
	game.controls.keys=Controls.DEFAULTS.duplicate()
	game.controls.apply()
	fresh(15,5)
	check(game.rivals.size()==15 and game.standings().size()==16,"full grid has 15 AI and 16 ranked participants")
	fresh(1,1)
	check(game.rivals.size()==1 and game.standings().size()==2,"minimum grid has one AI")
	fresh(15,3)
	game.speed=74
	game.trigger_crash()
	check(game.player.rider.get_parent()==game.player,"impact detaches rider from motorcycle")
	step(0.45)
	check(game.player.recovery_stage=="撞飞" and game.player.rider.position.y>2,"airborne animation has a real elevated trajectory")
	step(0.70)
	check(game.player.recovery_stage=="翻滚落地" and game.player.rider.position.y<1,"rider lands and tumbles near ground")
	step(0.72)
	check(game.player.recovery_stage=="起身","rider gets up after landing")
	step(0.65)
	check(game.player.recovery_stage=="跑回摩托" and absf(game.player.legs[0].rotation.x)>0.01,"automatic return animates walking legs")
	var frozen_time=game.player.recovery_time
	game.open_page("roster")
	step(0.5)
	check(game.player.recovery_time==frozen_time,"opening rider information freezes crash recovery")
	game.back()
	game.back()
	step(1.5)
	check(game.player.recovery_time==0 and game.player.rider.get_parent()==game.player.chassis,"recovery remounts the original motorcycle")
	check(game.damage_cooldown>0 and game.crashes==1,"remount grants temporary protection and records crash")
	var r=game.rivals[0]
	game._crash_rival(r,-1)
	check(r.hp==0 and r.node.recovery_time>0,"AI uses the same crash animation pipeline")
	step(4.2)
	check(r.hp==2 and r.node.recovery_time==0,"AI gets back on bike and continues competing")
	# Measure trailing riders' ability to rejoin, with combat/traffic isolated.
	fresh(15,5)
	quiet_track()
	game.distance=1000
	game.speed=74
	for i in game.rivals.size():
		game.rivals[i].distance=500+i*2
		game.rivals[i].speed=70
	var before=game.distance-game.rivals[0].distance
	step(22)
	var after=game.distance-game.rivals[0].distance
	print("BALANCE trailing_ai_gap_before=%.1f after_22s=%.1f"%[before,after])
	check(after<before-250,"trailing AI can recover a large deficit without teleporting")
	# Three complete player crashes, then skilled boost use. Actual game simulation.
	fresh(15,5)
	quiet_track()
	game.distance=200
	game.speed=74
	for i in game.rivals.size():
		game.rivals[i].distance=230+i*2
		game.rivals[i].speed=76
	for i in 3:
		game.trigger_crash()
		step(4.05)
		game.damage_cooldown=10000
	var crash_gap=max_gap()
	var best_gap=crash_gap
	var continuous=true
	for i in 3600:
		if i%660==0: Input.action_press("boost")
		if i%660==240: Input.action_release("boost")
		var snapshots=[]
		for ai in game.rivals: snapshots.append(ai.distance)
		game._process(1.0/60)
		for j in game.rivals.size():
			var delta=game.rivals[j].distance-snapshots[j]
			if delta<0 or delta>112.1/60: continuous=false
		best_gap=minf(best_gap,max_gap())
	Input.action_release("boost")
	print("BALANCE triple_crash_gap=%.1f best_after_60s=%.1f rank=%d"%[crash_gap,best_gap,game.rank_now()])
	check(game.crashes==3 and best_gap<100.0,"three player crashes do not make the lead permanently unreachable")
	check(continuous,"catch-up changes speed, never teleports race distance")
	game.to_menu()
	check(game.rivals.is_empty() and game.player.rider.get_parent()==game.player.chassis,"menu/reset releases rivals and restores rider hierarchy")
	print("EXPANSION_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)
