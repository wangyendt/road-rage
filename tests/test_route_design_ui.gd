extends "res://tests/test_road_rules.gd"
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for course in 12:
		prepare(course,true,true)
		var peak=300.0
		for d in range(300,int(game.track_length)-300,10):
			if absf(game.world.route.curvature(d))>absf(game.world.route.curvature(peak)): peak=d
		game.distance=peak-50
		game.rivals[0].distance=game.distance+1100
		game.speed=90
		game.lane=2.25
		game.elapsed=20
		game.ride.reset(game.world,game.distance,90)
		game.message_time=0
		for frame in 60:
			game._process(1.0/60)
			await process_frame
		var aligned=true
		var shoulders=true
		for chunk in game.world.chunks:
			var at=float(chunk.get_meta("segment"))*40
			var mesh=chunk.get_node("RoadSurface").mesh
			var vertex=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
			aligned=aligned and (chunk.transform*vertex).distance_to(game.world.relative_position(-game.world.road_half_width(at-20),at-20,game.distance)+Vector3(0,-0.01,0))<0.01
			for side in [-1,1]:
				var inner=game.world._terrain_point(at,at,side,0)
				var outer=game.world._terrain_point(at,at,side*128,0)
				var expected=game.world.relative_position(side*(game.world.road_half_width(at)+35),at,at)
				shoulders=shoulders and outer.distance_to(expected)<0.01 and absf(outer.distance_to(inner)-35)<0.01

		check(aligned,"map %d sharp bend asphalt matches minimap route in every live chunk"%course)
		check(shoulders,"map %d terrain does not fold across road inside tighter bends"%course)
		var pos=game.camera.unproject_position(game.player.global_position+Vector3(0,1,0))
		check(game.state=="race" and game.health==100 and absf(pos.x-root.size.x/2.0)<root.size.x*0.18,"map %d bend stays playable with rider centered and no forced crash"%course)
		await capture("v49-turn-%02d"%course)
	game.state="setup"
	for page in 3:
		game.course_page=page
		game.hud.queue_redraw()
		await process_frame
		await capture("v49-course-page-%d"%page)
	print("ROUTE_DESIGN_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
