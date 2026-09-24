extends "res://tests/test_ui.gd"
func advance(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
	await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.race_options={"course":3,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.distance=game.track_length
	game.score=12700
	game.finish_race("finished")
	var balance=game.economy.cash
	await advance(0.12)
	await capture("v32-win-enter")
	var early=hash(root.get_texture().get_image().get_data())
	await advance(0.58)
	await capture("v32-win-count")
	var middle=hash(root.get_texture().get_image().get_data())
	check(early!=middle,"victory entrance and count-up produce different rendered frames")
	await advance(1.0)
	await capture("v32-win-settled")
	check(game.economy.cash==balance,"visible result animation never changes persisted payout")
	await click("garage")
	check(game.state=="garage","animated results retain accurate clickable buttons")
	await key(KEY_ESCAPE)
	game.start_race()
	game.state="race"
	game.distance=1100
	game.trigger_crash()
	game.player.animate(1.0,0,0,false,0)
	game.arrest_player()
	await advance(0.1)
	await capture("v32-busted-enter")
	var first=hash(root.get_texture().get_image().get_data())
	await advance(1.5)
	await capture("v32-busted-settled")
	check(first!=hash(root.get_texture().get_image().get_data()),"arrest result animates entrance, fine and emergency light sweep")
	check(game.finish_reason=="busted" and game.race_fine.gross>0,"failure effect preserves actual arrest receipt")
	await click("retry")
	check(game.state=="countdown","retry remains responsive after result animation")
	game.state="race"
	game.finish_race("wrecked")
	await advance(0.8)
	await capture("v32-wrecked")
	check(game.finish_reason=="wrecked" and game.race_fine.gross==0,"wrecked result is distinct from police arrest")
	await click("retry")
	game.state="race"
	game.police.enabled=true
	game.police.next_distance=INF
	game.distance=1400
	game.speed=99
	var cop=game.police.spawn(1230,-3)
	cop.engaged=true
	cop.age=7
	cop.speed=65
	game.police.update(0.5)
	game.hud.queue_redraw()
	await capture("v32-escape-progress")
	check(game.police.escape_progress>0 and game.police.pursuit_active,"escape HUD displays separation and hold progress")
	game.police.update(2.1)
	check(game.police.escapes==1 and not game.police.pursuit_active,"completed escape clears pursuit state")
	game.hud.queue_redraw()
	await capture("v32-escaped")
	for i in 90: game.sound.update_world_audio(3000,0.8,true,1.0/60,1.15)
	check(game.sound.siren.pitch_scale>1.14 and game.sound.siren.volume_db>-20,"actual Godot siren player receives proximity gain and approaching pitch")
	for i in 90: game.sound.update_world_audio(3000,0.08,true,1.0/60,0.86)
	check(game.sound.siren.pitch_scale<0.87 and game.sound.siren.volume_db<-25,"actual Godot siren becomes quieter and lower while receding")
	print("FEEDBACK_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.8).timeout
	quit(1 if failed else 0)
