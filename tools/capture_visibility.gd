extends SceneTree
## Staged 3D preview of actual renderer, pickups and simulation. No save access.
var game: Node
var preview_models=0
func _init() -> void: call_deferred("run")
func frames(seconds: float, simulate: bool = true) -> void:
	for i in ceili(seconds*30):
		if simulate: game._process(1.0/30)
		if game.world.course_index==8:
			game.police.pursuit_active=true
			game.police.lead_distance=75
			game.police.escape_required=100
		game.hud.queue_redraw()
		await process_frame
func prepare(course: int) -> void:
	Input.action_release("boost")
	game.race_options={"course":course,"ai_count":15,"difficulty":5,"distance":0}
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
	for r in game.rivals: r.distance=5000+r.id*20
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	prepare(0)
	game.distance=800
	game.speed=70
	game.ride.reset(game.world,800,70)
	for i in 3: game._spawn_pickup(818,[-4.5,0,4.5][i],["repair","nitro","coin"][i])
	game.world.update_track(800,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game._update_mirror()
	preview_models=game.pickups.size()
	await frames(2,false)
	await frames(1)
	Input.action_press("boost")
	await frames(4)
	Input.action_release("boost")
	await frames(0.5)
	prepare(8)
	game.distance=400
	game.speed=105
	game.ride.reset(game.world,400,105)
	game.police.pursuit_active=true # Display real pursuit UI without disrupting this trajectory.
	game.police.lead_distance=75
	game.police.escape_required=100
	game.world.update_track(400,game.track_length)
	game._update_entities()
	game._update_camera(1)
	Input.action_press("boost")
	await frames(1.9)
	Input.action_release("boost")
	await frames(7)
	var ok=preview_models==3 and game.health==100 and game.crashes==0 and game.boost_visual==0
	print("VISIBILITY_CAPTURE ",JSON.stringify({"passed":ok,"health":game.health,"crashes":game.crashes,"models":preview_models,"boost":game.boost_visual}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
