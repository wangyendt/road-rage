extends "res://tests/test_ui.gd"
func capture(name: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await super.capture(name)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	await click("garage")
	for page in 5:
		check(game.bike_page==page,"garage page %d is accessible"%page)
		var count=0
		for button in game.hud.buttons:
			if button.action.begins_with("bike:"): count+=1
		check(count==4,"page %d exposes four buy/equip actions"%page)
		await capture("v49-garage-%d"%page)
		await click("bikes_next")
	check(game.bike_page==0,"five-page garage wraps to starter bikes")
	await click("bikes_prev")
	var cash=game.economy.cash
	await click("bike:sovereign")
	check(game.economy.cash==cash and "sovereign" not in game.economy.owned and "余额不足" in game.garage_message,"insufficient-funds click explains gap without charging")
	game.economy.cash=108000
	await click("bike:sovereign")
	check(game.economy.cash==0 and game.economy.equipped=="sovereign" and game.player.model_shape==19,"actual UI purchase applies flagship model")
	await capture("v49-garage-owned")
	await click("bike:sovereign")
	check(game.economy.cash==0,"owned-bike click does not charge again")
	await click("back")
	await click("start")
	for page in 3:
		game.course_page=page
		await capture("v49-course-page-%d"%page)
	await click("course:8")
	await click("distance:1")
	await click("race_begin")
	check(game.track_length==17200 and game.world.route.closed and game.world.route.lap_length==8600,"setup starts actual two-lap cloud circuit")
	game.state="race"
	game.distance=8600+30
	game.ride.reset(game.world,game.distance)
	game.world.update_track(game.distance,game.track_length)
	game._update_entities()
	game._update_camera(1)
	await capture("v49-lap-two")
	check(game.world.route.lap(game.distance)==2,"in-race HUD reports second lap")
	print("PREMIUM_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
