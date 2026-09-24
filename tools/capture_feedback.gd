extends SceneTree
## Opt-in visual fixture; never reads or writes the user's career.
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.race_options={"course":3,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=game.track_length
	game.elapsed=82.46
	game.score=17850
	game.hits=23
	game.takedowns=9
	game.near_misses=4
	game.police.escapes=2
	game.finish_race("finished")
	await create_timer(3.5).timeout
	game.start_race()
	game.state="race"
	game.distance=2420
	game.elapsed=35.8
	game.score=2350
	game.trigger_crash()
	game.player.animate(1.0,0,0,false,0)
	game.arrest_player()
	await create_timer(3.5).timeout
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.2).timeout
	quit()
