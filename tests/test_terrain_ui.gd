extends "res://tests/test_ui.gd"
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	await create_timer(0.3).timeout
	await click("start")
	await click("courses_next")
	check(game.course_page==1,"mouse opens second page of maps")
	for index in range(4,8):
		await click("course:%d"%index)
		check(game.world.course_index==index,"new course %d loads real terrain"%index)
	await capture("v4-maps")
	await click("courses_next")
	check(game.course_page==0,"map pagination wraps to classic maps")
	await click("back")
	await click("garage")
	game.economy.cash=100000
	await click("bikes_next")
	check(game.bike_page==1,"mouse opens expanded motorcycle shop")
	for id in ["nomad","comet","mammoth","falcon"]:
		await click("bike:"+id)
		check(game.active_bike.id==id and game.player.model_shape>=4,"purchase equips distinct 3D model "+id)
	await capture("v4-garage")
	await click("bikes_prev")
	check(game.bike_page==0,"garage retains access to old bikes")
	await click("bike:rr09")
	await click("back")
	await click("start")
	await click("courses_next")
	await click("course:5")
	await click("race_begin")
	check(game.track_length==7200 and game.world.course.id=="windfarm","selected expansion course starts correct race")
	game.set_process(false)
	game.state="race"
	game.police.enabled=false
	game.distance=440
	game.speed=100
	game.ride.reset(game.world,440,100)
	game.damage_cooldown=1000
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals: r.distance+=500
	game._spawn_traffic(620,-4.5,"tanker")
	game._spawn_traffic(660,3.0,"semi")
	Input.action_press("boost")
	for i in 180:
		game._process(1.0/60)
		if game.ride.height>7.5: break
	Input.action_release("boost")
	game._process(1.0/60)
	check(game.ride.airborne and game.player.position.y>7,"rendered motorcycle leaves road under physics")
	await capture("v4-airborne")
	var airborne_height=game.ride.height
	await key(KEY_ESCAPE)
	for i in 90: game._process(1.0/60)
	check(game.state=="paused" and game.ride.height==airborne_height,"pause keyboard freezes an actual jump")
	await key(KEY_ESCAPE)
	for i in 200: game._process(1.0/60)
	check(game.jumps>=1 and not game.ride.airborne,"resuming continues flight to its landing")
	for index in [4,6,7]:
		game.race_options.course=index
		game.start_race()
		game.state="race"
		game.police.enabled=false
		game.distance=1000 if index==6 else 460
		game.speed=60
		game.ride.reset(game.world,game.distance,60)
		game.damage_cooldown=1000
		for car in game.traffic: car.node.queue_free()
		game.traffic.clear()
		game._spawn_traffic(game.distance+28,-3,"boxtruck")
		game._spawn_traffic(game.distance+66,3,"pickup")
		game._spawn_traffic(game.distance+100,-3,"tanker")
		for r in game.rivals: r.distance=game.distance+150+r.id*10
		game.world.update_track(game.distance,game.track_length,game.total_time)
		game._update_entities()
		game._update_camera(1)
		game._update_mirror()
		game.hud.queue_redraw()
		await process_frame
		await capture("v4-course-%d"%index)
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("TERRAIN_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
