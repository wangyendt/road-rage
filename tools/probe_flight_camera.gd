extends SceneTree
## Minimal reproduction + live-render timing. All state is isolated from saves.
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.economy.owned.append("spring")
	game.economy.equipped="spring"
	game.race_options={"course":8,"ai_count":1,"difficulty":3,"distance":0}
	game.start_race()
	game.state="race"
	game.settings.shake=false
	if "--no-hud" in OS.get_cmdline_user_args(): game.hud.visible=false
	if "--no-mirror" in OS.get_cmdline_user_args(): game.settings.mirror=false
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	game.rivals[0].distance=5000
	# No physics, terrain streaming or shader changes: move height by only 2 mm.
	game.distance=1058.25
	game.ride.height=14.999
	for i in 90: game._update_camera(1.0/60)
	var before=game.camera.quaternion
	game.ride.height=15.001
	game._update_camera(1.0/60)
	print("CAMERA_MINIMAL ",JSON.stringify({"height_delta_m":0.002,"angle_deg":rad_to_deg(before.angle_to(game.camera.quaternion))}))
	game.distance=400
	game.speed=105
	game.ride.reset(game.world,400,105)
	game.world.update_track(400,game.track_length)
	game._update_entities()
	game._update_camera(1)
	Input.action_press("boost")
	var previous_wall=Time.get_ticks_usec()
	var previous_angle=game.camera.quaternion
	var timings=[]
	var cpu_timings=[]
	var pipelines=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
	for frame in 780:
		if frame==114: Input.action_release("boost")
		var h=game.ride.height
		var began=Time.get_ticks_usec()
		game._process(0.0 if "--stationary" in OS.get_cmdline_user_args() else 1.0/60)
		var cpu=(Time.get_ticks_usec()-began)/1000.0
		await process_frame
		var wall=(Time.get_ticks_usec()-previous_wall)/1000.0
		previous_wall=Time.get_ticks_usec()
		var angle=rad_to_deg(previous_angle.angle_to(game.camera.quaternion))
		previous_angle=game.camera.quaternion
		if frame>30:
			timings.append(wall)
			cpu_timings.append(cpu)
			if wall>35: print("CAMERA_SLOW_FRAME ",JSON.stringify({"frame":frame,"height":game.ride.height,"cpu_ms":cpu,"wall_ms":wall,"pipeline_draw_delta":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)-pipelines}))
		pipelines=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
		if (h<15)!=(game.ride.height<15):
			print("CAMERA_CROSSING ",JSON.stringify({"frame":frame,"angle_deg":angle,"height":game.ride.height,"cpu_ms":cpu,"frame_ms":wall}))
	timings.sort()
	cpu_timings.sort()
	print("CAMERA_FRAME_TIMING ",JSON.stringify({"median_ms":timings[int(timings.size()*0.5)],"p99_ms":timings[int(timings.size()*0.99)],"max_ms":timings[-1],"cpu_max_ms":cpu_timings[-1]}))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit()
