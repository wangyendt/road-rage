extends SceneTree
## Deterministic full races. test_mode isolates the user's saved career.
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for course in range(4,8):
		game.race_options={"course":course,"ai_count":15,"difficulty":3}
		game.start_race()
		game.auto_drive=true
		game.state="race"
		for frame in 12000:
			game._process(1.0/60)
			if game.state=="finished": break
		print("TERRAIN_RACE ",JSON.stringify({"course":game.world.course.id,"reason":game.finish_reason,"distance":game.distance,"rank":game.final_rank,"health":game.health,"jumps":game.jumps,"best_jump":game.best_jump,"escapes":game.police.escapes,"elapsed":game.elapsed}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
