extends SceneTree
const Acoustics=preload("res://scripts/siren_acoustics.gd")
const Motion=preload("res://scripts/result_motion.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS PURSUIT ",label)
	else:
		failed+=1
		push_error("FAIL PURSUIT "+label)
func step(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
func fresh() -> void:
	Input.action_release("boost")
	game.start_race()
	game.state="race"
	game.set_process(false)
	for list in [game.rivals,game.traffic,game.pickups]:
		for item in list: item.node.queue_free()
		list.clear()
	game.traffic_timer=INF
	game.pickup_timer=INF
	game.police.next_distance=INF
	game.distance=1000
	game.speed=74
	game.damage_cooldown=1000
func run() -> void:
	var near=Acoustics.sample(Vector2(0,-10),Vector2(0,80),Vector2(0,80))
	var far=Acoustics.sample(Vector2(0,-150),Vector2(0,80),Vector2(0,80))
	check(near.gain>far.gain*4,"siren amplitude decays with distance")
	check(is_equal_approx(near.pitch,1) and is_equal_approx(far.pitch,1),"distance alone never creates Doppler frequency shift")
	var approaching=Acoustics.sample(Vector2(0,-50),Vector2(0,95),Vector2(0,70))
	var leaving=Acoustics.sample(Vector2(0,-50),Vector2(0,65),Vector2(0,99))
	check(approaching.pitch>1 and leaving.pitch<1,"approaching police sounds higher and pulling away sounds lower")
	check(Acoustics.sample(Vector2(0,50),Vector2(0,65),Vector2(0,99)).pitch>1,"closing on a police car ahead also raises pitch")
	check(is_equal_approx(Acoustics.sample(Vector2(0,-40),Vector2(40,70),Vector2(0,70)).pitch,1),"only radial velocity contributes to Doppler shift")
	check(Acoustics.sample(Vector2.ZERO,Vector2(0,80),Vector2(0,80)).pitch==1,"coincident positions have a finite neutral pitch")
	check(Acoustics.sample(Vector2(0,-400),Vector2.ZERO,Vector2.ZERO).gain==0,"distant siren fades fully out")
	check(Acoustics.sample(Vector2(0,-20),Vector2(0,500),Vector2.ZERO).pitch<=1.28,"extreme speeds are safely pitch-limited")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.sound.update_world_audio(2000,1,true,0.016667,1.2)
	check(game.sound.siren_gain>0 and game.sound.siren_gain<1 and game.sound.siren_pitch>1 and game.sound.siren_pitch<1.2,"audio gain and pitch transition smoothly")
	for i in 120: game.sound.update_world_audio(2000,0,false,1.0/60,1)
	check(game.sound.siren_gain<0.001 and absf(game.sound.siren_pitch-1)<0.001,"pause or results fades siren back to silent neutral state")
	for level in range(1,6):
		game.race_options.difficulty=level
		fresh()
		var unit=game.police.spawn(990,0)
		unit.engaged=true
		unit.age=6
		unit.speed=74
		Input.action_press("boost")
		step(3.5)
		Input.action_release("boost")
		step(5)
		check(game.police.escapes==1,"starter bike escape is reachable at difficulty %d"%level)
	game.race_options.difficulty=3
	fresh()
	var cop=game.police.spawn(990,0)
	cop.engaged=true
	cop.age=6
	cop.speed=74
	Input.action_press("boost")
	step(3.5)
	Input.action_release("boost")
	step(5)
	print("ESCAPE_BALANCE escapes=%d gap=%.1f speed=%.1f nitro=%.1f"%[game.police.escapes,game.distance-cop.distance,game.speed,game.nitro])
	check(game.police.escapes==1 and cop.retreat,"starter motorcycle can escape using one nitro charge during cooling")
	check(game.score==300 and game.police.capture==0,"escape grants one feedback reward and clears arrest progress")
	check(game.police.grace_until>game.elapsed and game.police.next_distance>=game.distance+300,"successful escape grants time and distance respawn protection")
	var cop_at=cop.distance
	step(0.1)
	check(cop.distance>cop_at and cop.distance-cop_at<10,"retreating police drives away continuously instead of teleporting")
	var earned=game.score
	step(4)
	check(game.police.escapes==1 and game.score==earned,"retreat cannot award duplicate escape credit")
	fresh()
	cop=game.police.spawn(890,0)
	cop.engaged=true
	game.police.update(0.1)
	check(cop.escape_time>0 and game.police.escapes==0,"briefly crossing escape radius does not instantly finish pursuit")
	game.distance=cop.distance+50
	game.police.update(0.1)
	check(cop.escape_time==0,"losing separation resets escape countdown")
	fresh()
	cop=game.police.spawn(855,0)
	game.police.update(0.1)
	check(cop.escape_time==0,"normal initial police spawn does not count as automatic escape")
	cop.age=6.1
	cop.speed=85
	game._spawn_traffic(cop.distance+10,cop.lane)
	var before=cop.speed
	game.police.update(0.1)
	check(cop.speed<before and absf(cop.target_lane)>1,"traffic obstructs and redirects pursuing police")
	check(Motion.count(4200,0)==0 and Motion.count(4200,2)==4200,"result counter reveals zero to exact final amount")
	check(Motion.count(4200,0.6)>0 and Motion.count(4200,0.6)<4200,"result counter has intermediate animation frames")
	check(Motion.offset(0,false).y>0 and Motion.offset(2,false)==Vector2.ZERO,"results panel slides into exact stable position")
	fresh()
	game.distance=game.track_length
	game.finish_race("finished")
	var cash=game.economy.cash
	step(2)
	check(game.result_time>1.9 and game.result_stamp_played,"result animation clock and accent sound advance after race stops")
	check(game.economy.cash==cash,"count-up animation never awards money again")
	game.start_race()
	game.state="race"
	game.finish_race("wrecked")
	check(game.result_time==0 and not game.result_stamp_played,"new result resets its animation timeline")
	game.queue_free()
	await create_timer(0.6).timeout
	print("PURSUIT_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
