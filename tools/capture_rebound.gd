extends SceneTree
## Staged preview of actual menus and contact physics; no personal save access.
var game: Node
var highest=0.0
func _init() -> void: call_deferred("run")
func frames(seconds: float) -> void:
	for i in ceili(seconds*30):
		game._process(1.0/30)
		highest=maxf(highest,game.ride.height)
		await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	await frames(1.2)
	game.economy.owned.append("spring")
	game.economy.equipped="spring"
	game._apply_bike()
	game.bike_page=2
	game.state="garage"
	await frames(1.8)
	game.race_options={"course":8,"ai_count":7,"difficulty":3,"distance":0}
	game.course_page=2
	game.state="setup"
	await frames(1.8)
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=400
	game.elapsed=8
	game.speed=105
	game.ride.reset(game.world,400,105)
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals: r.distance=3500+r.id*20
	game.world.update_track(400,game.track_length)
	game._update_entities()
	game._update_camera(1)
	Input.action_press("boost")
	await frames(1.9)
	Input.action_release("boost")
	await frames(13.0)
	print("REBOUND_CAPTURE ",JSON.stringify({"peak":highest,"bounces":game.bounces,"jumps":game.jumps,"health":game.health}))
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.15).timeout
	quit()
