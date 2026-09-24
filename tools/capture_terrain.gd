extends SceneTree
## Real simulation/render/audio capture; staged starting positions, no save writes.
var game: Node
func _init() -> void: call_deferred("run")
func stage(course: int, at: float, velocity: float) -> void:
	game.race_options={"course":course,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=at
	game.elapsed=8
	game.speed=velocity
	game.ride.reset(game.world,at,velocity)
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals:
		r.distance=at+80+r.id*8
		r.speed=75
		r.ride.reset(game.world,r.distance,r.speed)
	game._spawn_traffic(at+185,-3,"tanker")
	game._spawn_traffic(at+225,3,"semi")
	game.world.update_track(at,game.track_length,game.total_time)
	game._update_entities()
	game._update_camera(1)
	game._update_mirror()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.economy.owned.append("nomad")
	game.economy.equipped="nomad"
	stage(5,420,98)
	Input.action_press("boost")
	await create_timer(3.4).timeout
	Input.action_release("boost")
	await create_timer(2.8).timeout
	stage(6,880,65)
	await create_timer(5.0).timeout
	stage(7,430,70)
	await create_timer(3.0).timeout
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
