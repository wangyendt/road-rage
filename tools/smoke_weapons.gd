extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.race_options={"course":0,"ai_count":15,"difficulty":3}
	game.start_race()
	game.auto_drive=true
	game.state="race"
	for frame in 12000:
		game._process(1.0/60)
		if game.state=="finished": break
	print("WEAPON_RACE ",JSON.stringify({"reason":game.finish_reason,"distance":game.distance,"rank":game.final_rank,"health":game.health,"hits":game.hits,"takedowns":game.takedowns,"weapon":game.loadout.current,"inventory":game.loadout.items,"claims":game.weapons_claimed,"elapsed":game.elapsed}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
