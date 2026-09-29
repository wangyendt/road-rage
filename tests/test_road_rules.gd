extends "res://tests/test_ui.gd"
const Route=preload("res://scripts/track_route.gd")
const Data=preload("res://scripts/game_data.gd")
func prepare(course: int, walls: bool, opposite: bool) -> void:
	game.settings.air_walls=walls
	game.settings.oncoming=opposite
	game.race_options={"course":course,"ai_count":1,"difficulty":3,"distance":0}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
	game.rivals[0].distance=4000
func steps(seconds: float) -> void:
	for i in ceili(seconds*60): game._process(1.0/60)
func run() -> void:
	var fingerprints={}
	for course in 12:
		var route=Route.new()
		route.build(course,Data.COURSES[course].length)
		var good=true
		for i in range(1,100):
			var d=route.length*i/100
			good=good and absf(route.point(d+1).distance_to(route.point(d))-1)<0.005 and absf(route.heading(d))<0.72 and absf(route.heading(d+1)-route.heading(d))<0.003
		check(good,"map %d has metre arc length and gentle forward-only curves"%course)
		fingerprints[str(route.point(route.length*0.3))+str(route.point(route.length*0.8))]=true
		var rect=Rect2(10,10,200,180)
		var d=route.length*0.4
		var sx=route.project(d,1,rect).distance_to(route.project(d,0,rect))
		var sy=route.project(d+1,0,rect).distance_to(route.project(d,0,rect))
		check(absf(sx/sy-1)<0.01,"map %d projects both axes at the same scale"%course)
	check(fingerprints.size()==12,"all twelve course silhouettes are distinct")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	check(game.settings.air_walls and not game.settings.oncoming,"default walls on and opposing traffic off")
	prepare(1,true,false)
	game.lane=-9.4
	game.speed=70
	Input.action_press("steer_left")
	steps(0.6)
	Input.action_release("steer_left")
	check(game.lane>=-9.2,"enabled air wall still bounds the left edge")
	prepare(1,false,false)
	game.lane=-10
	game.speed=70
	Input.action_press("steer_left")
	steps(0.6)
	Input.action_release("steer_left")
	check(game.lane< -11 and game.health==100,"wall-off allows left desert shoulder without guardrail damage")
	steps(2)
	check(game.speed<=39 and game.speed>0,"non-paved shoulder slows but remains driveable")
	game.lane=0
	steps(2)
	check(game.speed>60,"returning to road restores speed")
	prepare(3,false,false)
	game.distance=400
	game.world.update_track(400,game.track_length)
	var hit={}
	for entry in game.world.solids:
		var at=float(entry.chunk.get_meta("segment"))*40-entry.base.z
		if at>300 and at<600:
			hit={"at":at,"entry":entry}
			break
	check(not hit.is_empty(),"rendered city has collision solids")
	game.distance=hit.at
	game.lane=hit.entry.base.x
	game.ride.reset(game.world,game.distance)
	game.speed=45
	game.damage_cooldown=0
	game._simulate(1.0/60)
	check(game.health<100 and game.last_damage_cause=="撞上楼体" and game.crashes==1,"driving into rendered building damages and crashes rider")
	var entry=hit.entry
	var swept=game.world.roadside_hit(entry.base.x,hit.at-entry.size.z,entry.base.x,hit.at+entry.size.z,0)
	check(not swept.is_empty(),"swept building collision catches large frame movement")
	prepare(4,false,false)
	game.world.update_track(500,game.track_length)
	var water_chunk=game.world.chunks[posmod(12,game.world.CHUNK_COUNT)]
	var water_mesh=water_chunk.get_node("RoadSurface").mesh
	var flat_sea=true
	for vertex in water_mesh.surface_get_arrays(water_mesh.get_surface_count()-1)[Mesh.ARRAY_VERTEX]:
		flat_sea=flat_sea and absf((water_chunk.transform*vertex).y+game.world.height_at(500)+18)<0.01
	check(flat_sea,"visible sea stays at fixed world altitude below hilly coastline")
	game.distance=100
	game.lane=12
	game.speed=50
	game.ride.reset(game.world,100)
	game._process(1.0/60)
	check(game.state=="falling","unprotected sea edge starts physical fall")
	var h=game.ride.height
	game.back()
	steps(0.5)
	check(game.state=="paused" and game.ride.height==h,"pause freezes sea fall")
	game.back()
	steps(2)
	check(game.state=="finished" and game.finish_reason=="sea" and game.ride.height<=-18,"water contact ends race with distinct sea reason")
	check(game.race_fine.gross==0 and game.race_income.gross==0,"sea failure grants no prize and no police fine")
	prepare(4,true,false)
	game.lane=12
	game.ride.reset(game.world,0)
	game._process(1.0/60)
	check(game.state=="race" and game.lane<10,"default wall prevents sea fall")
	prepare(4,false,false)
	game.lane=-12
	game._process(1.0/60)
	check(game.state=="race","landward coast shoulder is not sea")
	game.lane=12
	game.ride.airborne=true
	game.ride.y=game.world.height_at(game.distance)+30
	game.ride.height=30
	game.ride.velocity=5
	game._process(1.0/60)
	check(game.state=="race" and game.ride.height>25,"airborne crossing over sea may steer back before falling")
	prepare(0,true,true)
	check(game.lane>0 and game.world.oncoming,"two-way starts player on right with matching road markings")
	game._spawn_traffic(100,-2.25,"sedan")
	game._spawn_traffic(150,2.25,"sedan")
	check(game.traffic[0].speed<0 and game.traffic[1].speed>0,"left traffic approaches and right traffic travels forward")
	game._update_entities()
	check(absf(wrapf(game.traffic[0].node.rotation.y-game.world.relative_yaw(100,0),-PI,PI))>3,"oncoming car model faces opposite direction")
	game.lane=-2.25
	game.speed=74
	game._simulate(1.0/60)
	check(game.wrong_way() and game.speed>74,"grounded opposing lane gives bounded speed compensation")
	game.lane=2.25
	check(not game.wrong_way(),"return to right side clears wrong-way state")
	game.lane=-12
	check(not game.wrong_way(),"offroad cannot farm wrong-way speed bonus")
	game.lane=-2.25
	game.ride.height=20
	check(not game.wrong_way(),"airborne cannot farm wrong-way speed bonus")
	game.ride.reset(game.world,game.distance)
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.distance=20
	game.speed=120
	game.health=100
	game.damage_cooldown=0
	game._spawn_traffic(12,-2.25,"sedan")
	game._simulate_traffic(0.05,0)
	check(game.health<77 and game.last_damage_cause=="迎面撞车","signed relative sweep catches fast head-on collision with stronger impact")
	var car=game.traffic[0]
	car.distance=game.distance-60
	game._simulate_traffic(0.05)
	check(game.traffic.is_empty(),"oncoming cars clean up after passing")
	game.ui_action("air_walls")
	game.ui_action("oncoming")
	check(game.race_rules.air_walls and game.race_rules.oncoming,"mid-race rule edits do not instantly reshape current race")
	game.start_race()
	check(not game.race_rules.air_walls and not game.race_rules.oncoming,"next race applies both settings")
	print("ROAD_RULES_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)
