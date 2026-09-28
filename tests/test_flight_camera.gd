extends SceneTree
## Real camera call sites and real flight physics; no personal save access.
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS FLIGHT_CAMERA ",label)
	else:
		failed+=1
		push_error("FAIL FLIGHT_CAMERA "+label)
func prepare(game: Node, course: int) -> void:
	game.race_options={"course":course,"ai_count":1,"difficulty":3,"distance":0}
	game.start_race()
	game.state="race"
	game.settings.shake=false
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	game.rivals[0].distance=5000
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.economy.owned.append("spring")
	game.economy.equipped="spring"
	# Minimal symptom: 2 mm of vertical travel must not cut the viewing angle.
	# Check original threshold plus both blend endpoints, in both directions.
	for course in range(8,12):
		prepare(game,course)
		game.distance=1058.25
		for edge in [5.0,15.0,35.0]:
			for direction in [-1,1]:
				game.ride.height=edge-direction*0.001
				for i in 90: game._update_camera(1.0/60)
				var before=game.camera.quaternion
				game.ride.height=edge+direction*0.001
				game._update_camera(1.0/60)
				var degrees=rad_to_deg(before.angle_to(game.camera.quaternion))
				check(degrees<0.1,"course %d / %.0fm / direction %d continuous (%.4f deg)"%[course,edge,direction,degrees])
	# Same deterministic natural-flight loop that failed with six 4–6 degree cuts.
	for hz in [30,60,120]:
		prepare(game,8)
		game.distance=400
		game.speed=105
		game.ride.reset(game.world,400,105)
		game.world.update_track(400,game.track_length)
		game._update_entities()
		game._update_camera(1)
		Input.action_press("boost")
		var worst=0.0
		var peak=0.0
		for frame in 13*hz:
			if frame==roundi(1.9*hz): Input.action_release("boost")
			var before=game.camera.quaternion
			var height=game.ride.height
			game._process(1.0/hz)
			peak=maxf(peak,game.ride.height)
			var degrees=rad_to_deg(before.angle_to(game.camera.quaternion))
			if height>2 and game.ride.height>2 and game.player.recovery_time<=0: worst=maxf(worst,degrees)
		print("FLIGHT_CAMERA_METRICS ",JSON.stringify({"hz":hz,"peak_m":peak,"worst_air_step_deg":worst,"bounces":game.bounces}))
		check(peak>60,"%d Hz preserves tall flight"%hz)
		check(worst<120.0/hz,"%d Hz has no airborne camera cuts"%hz)
		check(game.bounces>=2,"%d Hz preserves repeated landings/rebounds"%hz)
	Input.action_release("boost")
	print("FLIGHT_CAMERA_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
