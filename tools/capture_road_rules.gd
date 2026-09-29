extends SceneTree
## Staged gameplay capture. Spawn coordinates are arranged; mechanics remain active.
var game: Node
var building_hit=false
func _init() -> void: call_deferred("run")
func frames(seconds: float) -> void:
	for i in ceili(seconds*30):
		game._process(1.0/30)
		await process_frame
func prepare(course: int, walls: bool, opposite: bool, at: float, x: float, speed: float) -> void:
	Input.action_release("boost")
	game.settings.air_walls=walls
	game.settings.oncoming=opposite
	game.race_options={"course":course,"ai_count":15,"difficulty":3,"distance":0}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
	game.elapsed=20
	game.distance=at
	game.lane=x
	game.speed=speed
	game.ride.reset(game.world,at,speed)
	for r in game.rivals: r.distance=5000+r.id*20
	game.world.update_track(at,game.track_length)
	game._update_entities()
	game._update_camera(1)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.state="settings"
	await frames(1.2)
	game.state="setup"
	for page in 3:
		game.course_page=page
		await frames(1)
	prepare(0,true,true,1200,-2.25,90)
	game._spawn_traffic(1380,-6.75,"sedan")
	game._spawn_traffic(1500,-6.75,"boxtruck")
	Input.action_press("boost")
	await frames(3)
	Input.action_release("boost")
	await frames(0.5)
	prepare(1,false,false,500,-13,42)
	await frames(2)
	prepare(3,false,false,400,0,35)
	for entry in game.world.solids:
		var at=float(entry.chunk.get_meta("segment"))*40-entry.base.z
		if at>360 and at<430 and entry.base.x<0:
			game.distance=at
			game.lane=entry.base.x+entry.size.x*0.5+0.5
			game.ride.reset(game.world,at,35)
			game._update_entities()
			game._update_camera(1)
			break
	await frames(1.8)
	building_hit=game.crashes>0
	prepare(4,false,false,100,8,35)
	Input.action_press("steer_right")
	await frames(1)
	Input.action_release("steer_right")
	await frames(3)
	var ok=building_hit and game.finish_reason=="sea" and game.race_fine.gross==0 and game.race_income.gross==0
	print("ROAD_RULES_CAPTURE ",JSON.stringify({"passed":ok,"building_hit":building_hit,"result":game.finish_reason,"fine":game.race_fine.gross,"prize":game.race_income.gross}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
