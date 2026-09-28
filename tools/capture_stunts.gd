extends SceneTree
## Isolated staged trajectory, actual simulation/rendering; no user save access.
var game: Node
var highest=0.0
var attempted=false
func _init() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.economy.equipped="spring"
	game.race_options={"course":8,"ai_count":1,"difficulty":5,"distance":0}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=400
	game.speed=105
	game.ride.reset(game.world,400,105)
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
	game.rivals[0].distance=6000
	game.world.update_track(400,game.track_length)
	game._update_entities()
	game._update_camera(1)
	Input.action_press("boost")
	for frame in 450:
		if frame==57: Input.action_release("boost")
		game._process(1.0/30)
		highest=maxf(highest,game.ride.height)
		if not attempted and game.ride.height>20: attempted=game.attempt_stunt()
		await process_frame
	var ok=attempted and game.stunts==1 and game.health==100 and game.crashes==0 and game.bounces>0
	print("STUNT_CAPTURE ",JSON.stringify({"passed":ok,"peak":highest,"stunts":game.stunts,"bounces":game.bounces,"jumps":game.jumps,"health":game.health,"crashes":game.crashes}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
