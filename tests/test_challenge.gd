extends SceneTree
const Data=preload("res://scripts/game_data.gd")
const Director=preload("res://scripts/race_director.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS CHALLENGE ",label)
	else:
		failed+=1
		push_error("FAIL CHALLENGE "+label)
func fresh(choice: int = 0, level: int = 5, course: int = 0) -> void:
	game.race_options={"course":course,"ai_count":15,"difficulty":level,"distance":choice}
	game.start_race()
	game.state="race"
	game.elapsed=10
	game.distance=600
	game.race_anchor=600
	game.police.enabled=false
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.traffic_timer=INF
	game.pickup_timer=INF
	for r in game.rivals:
		r.distance=1600+r.id*30
		r.cooldown=999
	game.ride.reset(game.world,600,74)
func run() -> void:
	check(Data.race_length(0,0)==5400 and Data.race_length(0,1)==10800 and Data.race_length(0,2)==21600,"harbor short medium long have exact independent distances")
	check(Data.race_length(5,2)==28800,"legacy windfarm long course remains 28.8 km")
	check(Data.distance_index("bad")==0 and Data.distance_index(-1)==0 and Data.distance_index(99)==2,"invalid and legacy distance options are bounded")
	check(Data.record_key("harbor",5,0)=="harbor_5" and Data.record_key("harbor",5,1)=="harbor_5_medium" and Data.record_key("harbor",5,2)=="harbor_5_long","short preserves legacy keys while medium and long separate records")
	check(Director.boost_reason(5,20,30,4000,100,10)=="超车","legend can boost past an AI while ahead of player")
	check(Director.boost_reason(5,20,INF,4000,60,10)=="防守","legend defends a nearby lead with nitro")
	check(Director.boost_reason(5,200,INF,4000,100,10)=="直道提速","leader uses a full tank instead of hoarding it forever")
	check(Director.boost_reason(5,200,INF,800,20,10)=="终点冲刺","final sprint uses a small remaining reserve")
	check(Director.boost_reason(5,-50,30,1400,60,10).is_empty(),"approach to finish conserves reserve")
	check(Director.boost_reason(5,-50,30,4000,10,10).is_empty() and Director.boost_reason(5,-50,30,4000,100,1).is_empty(),"empty reserves and launch countdown do not trigger boost")
	check(Director.boost_reason(4,20,30,4000,100,10).is_empty(),"lower levels retain conservative boost opportunities")
	var profile=Data.riders()[0]
	check(Director.target_speed(5,profile,0,4000)>90 and Director.target_speed(4,profile,0,4000)<76,"legend increases cruising challenge without changing level four")
	check(Director.target_speed(5,profile,500,4000)>84,"legend leaders no longer slow to a novice cruising speed")
	check(Director.target_speed(5,profile,0,4000,true)>110 and Director.target_speed(5,profile,-9999,0,true)<=124,"boost is substantial but strictly capped")
	check(Director.target_speed(5,profile,0,100)>Director.target_speed(5,profile,0,4000),"legend ramps pressure toward finish")
	check(Director.player_assist(500,4000)>5 and Director.target_speed(5,profile,-500,4000)>Director.target_speed(5,profile,500,4000),"setbacks still allow bounded recovery on both sides")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	var cfg=ConfigFile.new()
	cfg.set_value("race","distance",2)
	cfg.set_value("race","difficulty",5)
	var config_path="res://builds/test-distance.cfg"
	cfg.save(config_path)
	var reloaded=ConfigFile.new()
	reloaded.load(config_path)
	game._load_race_config(reloaded)
	check(game.race_options.distance==2 and game.race_options.difficulty==5,"distance and difficulty survive config disk reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	game._load_race_config(ConfigFile.new())
	check(game.race_options.distance==0,"legacy save without distance defaults to short")
	cfg.set_value("race","distance","broken")
	game._load_race_config(cfg)
	check(game.race_options.distance==0,"malformed saved distance is safely reset")
	game.race_options={"course":0,"ai_count":1,"difficulty":3}
	game.start_race()
	check(game.track_length==5400 and game.active_distance==0,"old caller without distance remains short")
	for course in 8:
		fresh(2,5,course)
		var end=game.track_length
		var varied=false
		for n in 20:
			if absf(game.world.height_at(Data.COURSES[course].length+500+n*40))>0.1: varied=true
		game.world.update_track(end-100,end)
		check(game.world.course.length==end and game.world.height_at(end)==0 and game.world.finish_gate.visible and game.world.finish_gate.position.distance_to(game.world.relative_position(0,end,end-100))<0.01 and (varied or course==0),"map %d extends terrain and places level finish on actual curved route"%course)
	check(Data.COURSES[5].length==7200,"changing world length never mutates shared course catalog")
	fresh(2)
	game.distance=5500
	game.speed=0
	game._simulate(0.01)
	check(game.state=="race","passing the original short finish does not end long race")
	game.distance=game.track_length+1
	game.elapsed=240
	game.finish_race("finished")
	check(game.records.get("harbor_5_long",0)==240 and not game.records.has("harbor_5"),"long race result writes only its own record")
	game.ui_action("retry")
	check(game.track_length==21600 and game.active_distance==2,"retry retains chosen long distance")
	fresh(0)
	check(game.track_length==5400 and game.world.course.length==5400,"same-map long-to-short rebuilds terrain length")
	var r=game.rivals[0]
	r.distance=630
	r.lane=5
	r.speed=85
	r.burst_cd=0
	r.nitro=100
	r.think=0
	r.ride.reset(game.world,630,85)
	game._simulate_rival(r,0.1)
	check(r.boosts_used==1 and r.burst>0 and r.nitro<100 and r.speed>85,"real legend leader starts boost consumes fuel and accelerates")
	var used=r.boosts_used
	for i in 20: game._simulate_rival(r,0.1)
	check(r.boosts_used==used and r.nitro<60,"active boost cannot retrigger on each AI thought")
	r.stun=1
	game._simulate_rival(r,0.1)
	check(r.burst==0,"a hit cancels boost instead of suspending it")
	var charge=r.nitro
	game._simulate_rival(r,0.1)
	check(r.nitro>charge and r.nitro<=100,"nitro recharges within a finite tank")
	r.stun=0
	r.burst_cd=0
	r.think=0
	r.nitro=100
	r.lane=4.5
	r.speed=95
	game._spawn_traffic(r.distance+14,r.lane)
	game.traffic[0].speed=30
	game._simulate_rival(r,0.1)
	check(r.burst==0 and r.speed<95,"nearby same-lane traffic prevents boost and triggers braking")
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	r.burst=2
	game._crash_rival(r,1)
	game._simulate_rival(r,0.1)
	check(r.burst==0 and r.node.recovery_time>0,"crashed AI cannot boost off the ground")
	fresh(0)
	r=game.rivals[1] # Long spear specialist chooses a reach-aware line.
	r.distance=game.distance+5
	r.lane=4.3
	var target=game._choose_ai_lane(r,Data.difficulty(5))
	check(target>3.5 and target<5.3,"legend spear rider holds a useful longer combat distance")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("CHALLENGE_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
