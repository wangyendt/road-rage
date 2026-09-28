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
	await create_timer(0.35).timeout
	await capture("v43-menu")
	check(game.hud.buttons.size()>=6,"new main menu retains accessible actions")
	await click("settings")
	await capture("v43-settings")
	await click("bindings")
	await capture("v43-bindings")
	check(game.hud.buttons.size()>=12,"reskinned bindings retain all keyboard actions")
	await click("back")
	await click("back")
	await click("help")
	await capture("v43-help")
	await click("back")
	await click("roster")
	await capture("v43-roster")
	await click("profile:0")
	await capture("v43-profile")
	await click("back")
	await click("back")
	await click("garage")
	game.economy.cash=100000
	await click("bikes_next")
	await click("bikes_next")
	check(game.bike_page==2,"third motorcycle page is accessible")
	for id in ["spring","anvil","kestrel","rover"]:
		await click("bike:"+id)
		check(game.active_bike.id==id and game.player.chassis.get_node_or_null("SuspensionKit%d"%game.active_bike.shape)!=null,"purchase equips unique suspension model "+id)
	await click("bike:spring")
	await capture("v43-garage")
	await click("back")
	await click("start")
	await click("courses_next")
	await click("courses_next")
	check(game.course_page==2,"third map page is accessible")
	for course in range(8,12):
		await click("course:%d"%course)
		check(game.world.course_index==course,"new map selection loads distinct scene %d"%course)
	await click("distance:2")
	check(game.Data.race_length(11,2)==37600,"glacier long selection is 37.6 km")
	await capture("v43-maps")
	await click("course:8")
	await click("distance:0")
	await click("race_begin")
	game.set_process(false)
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals: r.distance=5000+r.id*30
	game.distance=400
	game.speed=105
	game.ride.reset(game.world,400,105)
	Input.action_press("boost")
	for frame in 800:
		game._process(1.0/60)
		if game.ride.height>65: break
	Input.action_release("boost")
	check(game.ride.height>65 and game.player.position.y>65,"real motorcycle launches far above old crest heights")
	var screen=game.camera.unproject_position(game.player.position+Vector3(0,1.3,0))
	check(screen.y>root.size.y*0.28 and screen.y<root.size.y*0.84,"camera keeps the motorcycle visible during tall flight")
	await capture("v43-high-flight")
	for frame in 1800:
		game._process(1.0/60)
		if game.rebound_timer>0: break
	check(game.bounces>0 and game.rebound_timer>0 and game.ride.airborne,"landing physically re-launches bike and activates effect")
	for frame in 9: game._process(1.0/60)
	await capture("v43-rebound")
	var early=hash(root.get_texture().get_image().get_data())
	for frame in 24: game._process(1.0/60)
	await capture("v43-rebound-fade")
	check(early!=hash(root.get_texture().get_image().get_data()),"impact text expands and fades over time")
	var timer=game.rebound_timer
	await key(KEY_ESCAPE)
	game._process(0.05)
	check(game.state=="paused" and game.rebound_timer==timer,"pause stops rebound timeline")
	await capture("v43-pause")
	await click("settings")
	await click("shake")
	var clock=game.hud.ui_clock
	await create_timer(0.12).timeout
	check(not game.settings.shake and game.hud.ui_clock==clock,"reduced interface motion stops background animation")
	await click("back")
	await click("resume")
	game.rebound_timer=0.8
	await capture("v43-reduced-motion")
	game.start_race()
	check(game.rebound_timer==0 and game.bounces==0,"restart removes old impact display")
	# Small window uses the same resolution-independent button hit testing.
	game.to_menu()
	root.size=Vector2i(960,600)
	await process_frame
	await capture("v43-small-menu")
	await click("start")
	check(game.state=="setup","scaled menu click works at 960x600")
	await capture("v43-small-setup")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("REBOUND_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
