extends "res://tests/test_ui.gd"
func advance(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
	await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.race_options={"course":0,"ai_count":7,"difficulty":3}
	game.controls.keys=game.Controls.DEFAULTS.duplicate()
	game.controls.apply()
	await create_timer(0.4).timeout
	await click("start")
	await click("ai_max")
	await click("level_plus")
	await click("level_plus")
	check(game.race_options.ai_count==15 and game.race_options.difficulty==5,"setup selects 15 rivals at level five")
	await click("level_plus")
	await click("ai_plus")
	check(game.race_options.ai_count==15 and game.race_options.difficulty==5,"maximum selections are clamped")
	for i in 4:
		await click("course:%d"%i)
		check(game.world.course_index==i,"course card %d changes rendered world"%i)
	await capture("v2-setup")
	await click("roster")
	check(game.state=="roster","setup opens fifteen rider profiles")
	await capture("v2-roster")
	await click("profile:14")
	check(game.state=="profile" and game.selected_profile==14,"last rider portrait opens matching profile")
	await capture("v2-profile")
	await key(KEY_ESCAPE)
	check(game.state=="roster","profile returns to roster")
	await key(KEY_ESCAPE)
	check(game.state=="setup","roster returns to race setup")
	await key(KEY_ESCAPE)
	await click("settings")
	await click("bindings")
	await click("bind:boost")
	await key(KEY_F)
	check(game.controls.keys.boost==KEY_F and game.rebinding.is_empty(),"captured key becomes the boost binding")
	await click("bind:boost")
	var muted=game.sound.muted
	await key(KEY_M)
	check(game.rebinding=="boost" and game.sound.muted==muted,"reserved key is rejected without triggering global shortcut")
	await key(KEY_ESCAPE)
	check(game.state=="bindings" and game.rebinding.is_empty(),"Escape cancels capture without leaving bindings")
	await click("bind:steer_left")
	await key(KEY_D)
	check(game.controls.keys.steer_right==KEY_A,"UI rebind swaps conflicting keys")
	await capture("v2-bindings")
	await click("reset_keys")
	check(game.controls.keys==game.Controls.DEFAULTS,"restore defaults resets all keys")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await click("start")
	await click("race_begin")
	check(game.state=="countdown" and game.rivals.size()==15,"full grid starts through real UI")
	game.controls.rebind("pause_game",KEY_W)
	await key(KEY_W)
	check(game.state=="paused","custom pause key opens pause menu")
	await key(KEY_W)
	check(game.state=="countdown","custom pause key overrides menu navigation when resuming")
	game.controls.rebind("pause_game",KEY_P)
	game.settings.map=true
	game.settings.mirror=true
	await key(KEY_V)
	await key(KEY_B)
	check(not game.settings.map and not game.settings.mirror,"race shortcuts hide mini-map and rear mirror")
	await key(KEY_V)
	await key(KEY_B)
	check(game.settings.map and game.settings.mirror,"race shortcuts restore both views")
	await key(KEY_TAB)
	check(game.state=="roster" and game.resume_state=="countdown","race roster safely pauses countdown")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(game.state=="countdown","closing roster and pause restores countdown")
	# Inspect real 3D recovery poses at reproducible moments.
	game.set_process(false)
	game.race_options.course=1
	game.start_race()
	game.state="race"
	game.distance=1100
	game.speed=74
	game.damage_cooldown=10000
	game.traffic_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for i in game.rivals.size():
		game.rivals[i].distance=1130+i*10
		game.rivals[i].cooldown=10000
	game.trigger_crash()
	await advance(0.45)
	check(game.player.recovery_stage=="撞飞","rendered rider enters airborne stage")
	await capture("v2-crash-air")
	await advance(0.70)
	check(game.player.recovery_stage=="翻滚落地","rendered rider lands and tumbles")
	await capture("v2-crash-land")
	await advance(1.45)
	check(game.player.recovery_stage=="跑回摩托","rendered rider runs back to the motorcycle")
	await capture("v2-crash-return")
	await advance(1.5)
	check(game.player.recovery_time==0,"rendered sequence automatically remounts")
	await capture("v2-canyon")
	game.race_options.course=2
	game.start_race()
	await advance(0.1)
	await capture("v2-alpine")
	game.to_menu()
	print("EXPANSION_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.6).timeout
	quit(1 if failed else 0)
