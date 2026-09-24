extends SceneTree
## Staged encounters using actual input, combat, loot, animation and sound code.
## No personal career is read or changed.
var game: Node
var focus: Dictionary={}
func _init() -> void: call_deferred("run")
func frames(seconds: float) -> void:
	for i in ceili(seconds*30):
		if not focus.is_empty() and focus.hp>0:
			focus.distance=game.distance+0.2
			focus.speed=game.speed
			focus.think=999
			focus.cooldown=999
			focus.burst_cd=999
			focus.target_lane=focus.lane
		game._process(1.0/30)
		await process_frame
func key(code: int) -> void:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
func opponent(index: int, side_offset: float) -> void:
	focus=game.rivals[index]
	focus.distance=game.distance+0.2
	focus.lane=game.lane+side_offset
	focus.speed=game.speed
	focus.ride.reset(game.world,focus.distance,focus.speed)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.controls.keys=game.Controls.DEFAULTS.duplicate()
	game.controls.apply()
	game.race_options={"course":0,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=600
	game.elapsed=10
	game.speed=65
	game.ride.reset(game.world,600,65)
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals:
		r.distance=1500+r.id*12
		r.cooldown=999
	game.world.update_track(game.distance,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game.state="roster"
	await frames(1.4)
	game.state="race"
	opponent(1,-1.65)
	await frames(0.7)
	key(KEY_J)
	await frames(0.6)
	key(KEY_J)
	await frames(1.5)
	key(KEY_Q) # Spear -> fists.
	await frames(0.5)
	key(KEY_Q) # Fists -> kick.
	opponent(9,1.4)
	await frames(0.5)
	key(KEY_K)
	await frames(0.85)
	key(KEY_K)
	await frames(1.3)
	opponent(12,-3.3)
	await frames(0.3)
	key(KEY_J)
	await frames(0.85)
	key(KEY_J)
	await frames(1.4)
	opponent(4,2.0)
	await frames(0.3)
	key(KEY_K)
	await frames(1.6)
	print("WEAPON_CAPTURE ",JSON.stringify({"weapon":game.loadout.current,"inventory":game.loadout.items,"claims":game.weapons_claimed,"hits":game.hits,"takedowns":game.takedowns,"grunts":game.sound.rider_hit_count}))
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.15).timeout
	quit()
