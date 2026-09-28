extends "res://tests/test_ui.gd"
func advance(seconds: float) -> void:
	for i in roundi(seconds*60): game._process(1.0/60)
	await process_frame
func capture(name: String) -> void:
	# Wait for a freshly redrawn HUD, not a draw queued earlier in the same frame.
	game.hud.queue_redraw()
	await process_frame
	await super.capture(name)
func map_hash() -> int:
	var picture=root.get_texture().get_image()
	# Canvas-item stretch keeps virtual coordinates; image pixels follow window size.
	var pixels=Vector2(picture.get_size())/game.hud.get_viewport_rect().size
	var r=Rect2i((Vector2(1175,330)*game.hud.ui_scale+game.hud.ui_offset)*pixels,Vector2(232,277)*game.hud.ui_scale*pixels)
	return hash(picture.get_region(r).get_data())
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.settings.music=false
	game.race_options={"course":3,"ai_count":15,"difficulty":3}
	game.start_race()
	await advance(0.7)
	await capture("v44-start-3")
	var start=hash(root.get_texture().get_image().get_data())
	await advance(2)
	await capture("v44-start-1")
	check(start!=hash(root.get_texture().get_image().get_data()),"rendered start gantry changes lights and number")
	await advance(0.82)
	await capture("v44-start-go")
	check(game.state=="race" and game.sound.countdown_cues==["count","count","count","go"],"native countdown audio plays three ticks then GO")
	game.distance=1600
	game.elapsed=20
	game.police.next_distance=INF
	game.speed=70
	var cop=game.police.spawn(1565,-3)
	game.police.update(0.05)
	game.world.update_track(game.distance,game.track_length)
	game.message_time=0
	game.elapsed=20.2
	await capture("v44-pursuit-red")
	var red=map_hash()
	game.elapsed=20.6
	await capture("v44-pursuit-normal")
	check(red!=map_hash(),"minimap visibly alternates normal and translucent red")
	game.settings.shake=false
	await capture("v44-reduced-motion")
	var steady=map_hash()
	game.elapsed+=0.4
	await capture("v44-reduced-motion-later")
	check(steady==map_hash(),"reduced-motion minimap is pixel-stable")
	game.settings.shake=true
	game.back()
	var clock=game.elapsed
	await advance(1)
	check(game.elapsed==clock,"pause freezes pursuit pulse clock")
	game.ui_action("resume")
	game.settings.map=false
	await capture("v44-map-hidden")
	check(game.hud._pursuit_feedback().visible,"pursuit icon remains available when minimap is hidden")
	game.settings.map=true
	game.speed=100
	cop.distance=game.distance-170
	cop.engaged=true
	game.police.update(0.6)
	await capture("v44-escaping")
	check(game.hud._pursuit_feedback().mode=="escaping","escape progress gets green identity")
	game.police.update(2)
	await capture("v44-escaped")
	check(game.hud._pursuit_feedback().mode=="escaped","successful escape renders confirmation icon")
	for i in 120: game.sound.update_world_audio(3000,0.8,true,1.0/60,1.15,1,-0.6)
	check(game.sound.siren_yelp.volume_db>game.sound.siren.volume_db,"near siren transitions to urgent yelp layer")
	check(game.sound.police_panner.pan< -0.59 and game.sound.siren_yelp.pitch_scale>1.14,"native bus pan and yelp Doppler applied")
	var near_cutoff=game.sound.police_filter.cutoff_hz
	for i in 120: game.sound.update_world_audio(3000,0.06,true,1.0/60,0.85,0,0.4)
	check(game.sound.police_filter.cutoff_hz<near_cutoff and game.sound.siren.volume_db< -25,"far siren is softer and spectrally muffled")
	check(game.sound.siren_yelp.volume_db<game.sound.siren.volume_db,"far pursuit returns to long wail")
	for i in 120: game.sound.update_world_audio(3000,0.8,false,1.0/60,1.15,1,0)
	check(game.sound.siren.volume_db< -70 and game.sound.siren_yelp.volume_db< -70,"finished or paused race fades all police audio")
	game.start_race()
	game.state="race"
	game.distance=1800
	game.elapsed=24
	game.police.spawn(game.distance-5,game.lane+1)
	game.trigger_crash()
	game.player.animate(1,0,0,false,0)
	game.police.pursuit_active=true
	game.police.capture=0.3
	await capture("v44-arrest-danger")
	check(game.hud._pursuit_feedback().icon=="cuffs","on-foot arrest warning uses handcuffs")
	game.arrest_player()
	await advance(1.6)
	await capture("v44-busted")
	check(game.finish_reason=="busted" and game.race_fine.gross>0,"police result shows actual fine receipt")
	await click("retry")
	game.state="race"
	game.police.enabled=false
	game.distance=2100
	game.health=1
	game.take_damage(20,"重落地")
	game.finish_race("wrecked")
	await advance(1.6)
	await capture("v44-wrecked")
	check(game.last_damage_cause=="重落地" and game.race_fine.gross==0,"wreck displays damage cause without police fine")
	for rank in [1,2,5]:
		game.start_race()
		game.state="race"
		game.distance=game.track_length
		for i in rank-1: game.rivals[i].finished=true
		game.score=12450
		game.finish_race("finished")
		await advance(1.6)
		await capture("v44-finish-%d"%rank)
		check(game.final_rank==rank and game.race_income.gross>0,"rank %d renders distinct finish with actual award"%rank)
	await click("garage")
	check(game.state=="garage","result buttons retain stable clickable bounds")
	print("RACE_FEEDBACK_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
