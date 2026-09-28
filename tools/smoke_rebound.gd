extends SceneTree
## Natural full-race smoke; no invulnerability, position jumps or personal saves.
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for course in range(8,12):
		var id=game.Economy.BIKES[course].id
		game.economy.owned.append(id)
		game.economy.equipped=id
		game.race_options={"course":course,"ai_count":15,"difficulty":3,"distance":0}
		game.start_race()
		game.auto_drive=true
		game.state="race"
		var peak=0.0
		for frame in 18000:
			game._process(1.0/30)
			peak=maxf(peak,game.ride.height)
			if game.state=="finished": break
		print("REBOUND_RACE ",JSON.stringify({"course":game.world.course.id,"bike":id,"reason":game.finish_reason,"distance":game.distance,"rank":game.final_rank,"health":game.health,"jumps":game.jumps,"bounces":game.bounces,"peak":peak,"best_jump":game.best_jump,"elapsed":game.elapsed}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
