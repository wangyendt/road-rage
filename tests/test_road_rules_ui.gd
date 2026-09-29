extends "res://tests/test_road_rules.gd"
func capture(name: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await super.capture(name)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	await click("settings")
	await capture("v47-settings")
	check(game.hud.buttons.size()==10,"all nine settings and back button fit")
	await click("air_walls")
	await click("oncoming")
	check(not game.settings.air_walls and game.settings.oncoming,"main-menu rule toggles respond to actual clicks")
	var file=ConfigFile.new()
	for key in game.settings: file.set_value("settings",key,game.settings[key])
	game.settings.air_walls=true
	game.settings.oncoming=false
	game._load_settings(file)
	check(not game.settings.air_walls and game.settings.oncoming,"rule preferences roundtrip through saved settings")
	await click("back")
	await click("start")
	await capture("v47-course-shapes")
	await click("race_begin")
	check(not game.race_rules.air_walls and game.race_rules.oncoming,"UI-started race uses selected rules")
	var grid={}
	for r in game.rivals: grid[str(r.lane)+str(r.distance)]=true
	check(grid.size()==game.rivals.size(),"two-way rider grid contains no duplicate positions")
	steps(4)
	prepare(0,true,true)
	game.distance=1200
	game.speed=95
	game.lane=-2.25
	game.ride.reset(game.world,1200,95)
	game._spawn_traffic(1260,-2.25,"sedan")
	game._spawn_traffic(1280,-6.75,"boxtruck")
	game.world.update_track(1200,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game._update_mirror()
	game.elapsed=20
	game.message_time=0
	game.boost_active=true
	game.boost_visual=1
	game.post.set_shader_parameter("boost",1.0)
	await capture("v47-oncoming-boost")
	check(game.wrong_way(),"native wrong-way HUD has active speed compensation state")
	var aligned=true
	for chunk in game.world.chunks:
		var d=float(chunk.get_meta("segment"))*40
		var vertex=chunk.get_node("RoadSurface").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
		var rendered=chunk.transform*vertex
		var expected=game.world.relative_position(-game.world.road_half_width(d-20),d-20,game.distance)+Vector3(0,-0.01,0)
		aligned=aligned and rendered.distance_to(expected)<0.01
	check(aligned,"rendered curve vertices exactly match shared metre route")
	var player_dot=game.hud._map_position(game.distance,game.lane,game.hud.MAP_RECT)
	check(game.hud.MAP_RECT.has_point(player_dot),"player marker is inside uniformly scaled map")
	prepare(1,false,false)
	game.distance=500
	game.lane=-16
	game.speed=40
	game.ride.reset(game.world,500,40)
	game.elapsed=20
	steps(0.6)
	await capture("v47-desert-shoulder")
	var rider_screen=game.camera.unproject_position(game.player.global_position+Vector3(0,1,0))
	check(absf(rider_screen.x-game.hud.get_viewport_rect().size.x*0.5)<game.hud.get_viewport_rect().size.x*0.18,"offroad camera keeps rider near center, not behind side HUD")
	check(game.health==100 and game.lane< -15,"native desert shoulder is rideable without phantom rail damage")
	prepare(3,false,false)
	game.distance=400
	game.world.update_track(400,game.track_length)
	var target={}
	for entry in game.world.solids:
		var at=float(entry.chunk.get_meta("segment"))*40-entry.base.z
		if at>350 and at<500 and entry.base.x<0:
			target={"entry":entry,"at":at}
			break
	game.distance=target.at
	game.lane=target.entry.base.x+target.entry.size.x*0.5+0.5
	game.ride.reset(game.world,game.distance,45)
	game.speed=45
	steps(0.15)
	await capture("v47-building-hit")
	check(game.crashes==1 and game.last_damage_cause=="撞上楼体","native wall-off ride collides with visible building")
	prepare(4,false,false)
	game.distance=100
	game.lane=12
	game.speed=30
	game.ride.reset(game.world,100,30)
	steps(0.6)
	await capture("v47-sea-fall")
	check(game.state=="falling" and game.ride.height<0,"sea fall is animated before result screen")
	steps(2)
	await capture("v47-sea-result")
	check(game.finish_reason=="sea" and game.race_income.gross==0 and game.race_fine.gross==0,"sea result has no prize or invented fine")
	var cash=game.economy.cash
	await click("retry")
	check(game.state=="countdown" and game.health==100 and game.economy.cash==cash,"sea retry restores race without repair fee")
	print("ROAD_RULES_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)
