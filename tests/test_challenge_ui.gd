extends "res://tests/test_ui.gd"
func click(action: String) -> void:
	game.hud.queue_redraw()
	await super.click(action)
	game.hud.queue_redraw()
	await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	await create_timer(0.25).timeout
	await click("start")
	await click("ai_max")
	await click("level_plus")
	await click("level_plus")
	await click("distance:1")
	check(game.race_options.distance==1,"medium can be selected with mouse")
	await click("distance:2")
	check(game.race_options.distance==2 and game.race_options.difficulty==5,"long distance and legend difficulty selected together")
	await capture("v42-long-legend-setup")
	await click("courses_next")
	await click("course:5")
	check(game.race_options.distance==2 and game.race_options.course==5,"changing pages and map retains distance choice")
	await capture("v42-long-hills")
	await click("race_begin")
	game.set_process(false)
	check(game.track_length==28800 and game.world.course.length==28800,"UI starts a real 28.8 km race")
	game.state="race"
	game.distance=12000
	game.elapsed=140
	game.speed=90
	game.ride.reset(game.world,game.distance,90)
	game.world.update_track(game.distance,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game.hud.queue_redraw()
	await capture("v42-long-progress")
	check(game.state=="race" and game.world.height_at(12000)!=0,"beyond old finish hills and race remain active")
	game.police.enabled=false
	game.distance=game.track_length-2
	game.speed=90
	game.ride.reset(game.world,game.distance,90)
	game._process(0.1)
	game.hud.queue_redraw()
	check(game.state=="finished" and game.finish_reason=="finished","crossing actual long finish opens success results")
	check(game.records.has("windfarm_5_long") and game.world.finish_gate.visible,"long finish festival and separate record both exist")
	for frame in 60: game._process(1.0/30)
	game.hud.queue_redraw()
	await capture("v42-long-finish")
	await click("retry")
	check(game.track_length==28800 and game.distance==0,"restart preserves long setup and resets progress")
	await click("back")
	await click("menu")
	await click("start")
	await click("distance:0")
	await click("courses_prev")
	await click("course:0")
	await click("race_begin")
	check(game.track_length==5400 and game.world.course.length==5400,"short selection restores original finish after long run")
	game.state="race"
	game.elapsed=10
	game.distance=600
	game.speed=85
	game.police.enabled=false
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals: r.distance=1200+r.id*20
	var r=game.rivals[1]
	r.distance=612
	r.lane=2.5
	r.speed=90
	r.nitro=100
	r.burst_cd=0
	r.think=0
	r.cooldown=99
	r.ride.reset(game.world,r.distance,90)
	game.ride.reset(game.world,600,85)
	game.race_anchor=600
	game._simulate_rival(r,0.1)
	game.world.update_track(600,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game.hud.queue_redraw()
	await capture("v42-ai-nitro")
	check(r.burst>0 and r.boosts_used==1 and r.nitro<100,"rendered AI actually triggers finite nitro")
	await click("profile:1")
	check(game.state=="profile","boosting rider dossier is accessible from standings")
	await capture("v42-ai-nitro-profile")
	var before=r.nitro
	game._process(0.3)
	check(r.nitro==before,"viewing rider dossier pauses nitro consumption")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("CHALLENGE_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
