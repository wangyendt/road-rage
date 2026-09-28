extends SceneTree
## Same no-cheat autopilot for comparisons. Test mode never touches career saves.
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for setup in [[4,0,0,"rr09"],[5,0,0,"rr09"],[5,0,0,"falcon"],[5,2,0,"falcon"],[5,1,5,"nomad"]]:
		game.economy.owned.append(setup[3])
		game.economy.equipped=setup[3]
		game.race_options={"course":setup[2],"ai_count":15,"difficulty":setup[0],"distance":setup[1]}
		game.start_race()
		game.auto_drive=true
		game.state="race"
		for frame in 18000:
			game._process(1.0/30)
			if game.state=="finished": break
		var boosts=0
		var racers=0
		for r in game.rivals:
			boosts+=r.boosts_used
			if r.boosts_used>0: racers+=1
		print("CHALLENGE_RACE ",JSON.stringify({"level":setup[0],"distance_class":setup[1],"course":setup[2],"bike":setup[3],"length":game.track_length,"reason":game.finish_reason,"distance":game.distance,"rank":game.final_rank,"health":game.health,"boosts":boosts,"boosting_riders":racers,"elapsed":game.elapsed,"ai_crashes":game.rivals.reduce(func(n,r):return n+r.crashes,0)}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
