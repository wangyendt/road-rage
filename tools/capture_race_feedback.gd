extends SceneTree
## Staged audiovisual showcase. All feedback, sounds and receipts use game code.
## Never loads/saves the user's career; placement is for demonstration, not a full race.
var game: Node
func _init() -> void: call_deferred("run")
func frames(seconds: float) -> void:
	for i in ceili(seconds*30):
		game._process(1.0/30)
		await process_frame
func place(distance: float, speed: float) -> void:
	game.distance=distance
	game.speed=speed
	game.ride.reset(game.world,distance,speed)
	game.world.update_track(distance,game.track_length)
	game._update_entities()
	game._update_camera(1.0)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.race_options={"course":3,"ai_count":7,"difficulty":3,"distance":0}
	game.settings.music=false
	game.start_race()
	await frames(4.4)
	place(1400,78)
	game.elapsed=20
	game.message_time=0
	game.police.next_distance=INF
	for r in game.rivals: r.distance=game.distance+80+r.id*18
	var cop=game.police.spawn(game.distance-80,-4)
	await frames(3.5)
	# Force a readable escape-window setup; police then run their actual hold logic.
	cop.distance=game.distance-165
	cop.speed=60
	cop.age=7
	cop.engaged=true
	game.speed=100
	await frames(4.6)
	game.police.enabled=false
	game.distance=game.track_length
	game.score=12450
	game.finish_race("finished")
	await frames(3)
	game.start_race()
	game.state="race"
	place(2480,0)
	game.elapsed=37.5
	game.health=1
	game.take_damage(20,"撞上车辆")
	game.finish_race("wrecked")
	await frames(3)
	game.start_race()
	game.state="race"
	place(1920,0)
	game.elapsed=28
	game.trigger_crash()
	game.player.animate(1,0,0,false,0)
	game.arrest_player()
	await frames(3)
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
