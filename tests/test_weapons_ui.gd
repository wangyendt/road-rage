extends "res://tests/test_ui.gd"
func click(action: String) -> void:
	game.hud.queue_redraw()
	await super.click(action)
	game.hud.queue_redraw()
	await process_frame
func key(code: int) -> void:
	await super.key(code)
	game.hud.queue_redraw()
	await process_frame
func place_target(index: int, x: float) -> Dictionary:
	var r=game.rivals[index]
	r.distance=game.distance
	r.lane=x
	r.ride.reset(game.world,game.distance,0)
	r.hp=2
	r.hit_cd=0
	r.node.reset_pose()
	game._update_entities()
	return r
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.controls.keys=game.Controls.DEFAULTS.duplicate()
	game.controls.apply()
	await create_timer(0.25).timeout
	await click("start")
	await click("ai_max")
	await click("roster")
	await capture("v41-rider-weapons")
	await click("profile:9")
	check(game.profiles[9].weapon=="whip" and game.state=="profile","rider dossier exposes the whip specialist")
	await capture("v41-weapon-profile")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await click("race_begin")
	game.set_process(false)
	game.state="race"
	game.distance=600
	game.elapsed=10
	game.speed=65
	game.police.enabled=false
	game.ride.reset(game.world,600,65)
	for r in game.rivals: r.distance=800+r.id*10
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.world.update_track(game.distance,game.track_length,game.total_time)
	game._update_entities()
	game._update_camera(1)
	game._update_mirror()
	game.hud.queue_redraw()
	check(game.loadout.current=="fists" and not game.player.weapon_visual.visible,"rendered race starts with no carried weapon")
	await key(KEY_Q)
	check(game.loadout.current=="kick","default Q selects the kick fighting style")
	await key(KEY_J)
	game.player.animate(0.20,65,0,false,game.total_time)
	check(absf(game.player.legs[0].rotation.z)>0.8,"actual attack key extends the left leg")
	await capture("v41-kick")
	await key(KEY_Q)
	check(game.loadout.current=="kick","actual Q press respects attack recovery")
	game.player.animate(1,65,0,false,game.total_time)
	game.attack_cooldown=0
	await key(KEY_Q)
	var enemy=place_target(1,2.0)
	await key(KEY_K)
	check(enemy.hp==1 and game.sound.last_rider_hit.id==1,"keyboard punch triggers the victim's grunt event")
	var has_voice=false
	for voice in game.sound.voices:
		if voice.stream==game.sound.sounds[game.sound.last_rider_hit.sound]: has_voice=true
	check(has_voice,"real Godot voice player receives the rider-grunt WAV")
	game.player.animate(0.5,65,0,false,game.total_time)
	game.attack_cooldown=0
	await key(KEY_K)
	check(game.loadout.current=="spear" and game.player.weapon_visual.visible,"second keyboard strike captures and shows the spear")
	game.player.animate(0.3,65,0,false,game.total_time)
	enemy.node.animate(0.45,65,0,false,game.total_time)
	game.hud.queue_redraw()
	await capture("v41-loot")
	game.attack_cooldown=0
	game.player.attack_time=0
	await click("cycle_weapon")
	check(game.loadout.current=="fists","weapon HUD can also cycle through equipment by mouse")
	await key(KEY_ESCAPE)
	await click("settings")
	await click("bindings")
	await click("bind:cycle_weapon")
	await key(KEY_X)
	check(game.controls.keys.cycle_weapon==KEY_X,"new action is available in real keybinding screen")
	await capture("v41-bindings")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await click("resume")
	await key(KEY_Q)
	check(game.loadout.current=="fists","old shortcut stops switching after rebinding")
	await key(KEY_X)
	check(game.loadout.current=="kick","new shortcut switches immediately in race")
	game.loadout.acquire("whip")
	game.player.set_weapon("whip")
	game.player.swing(1)
	game.player.animate(0.25,65,0,false,game.total_time)
	game.hud.queue_redraw()
	await capture("v41-whip")
	check(game.player.weapon_visual.links.size()>10,"flexible whip renders a segmented animated model")
	game.trigger_crash()
	game.player.animate(4,65,0,false,game.total_time)
	check(game.player.weapon_visual.visible and game.loadout.current=="whip","rendered remount restores the player's acquired weapon")
	game.start_race()
	check(game.loadout.items.size()==2 and not game.player.weapon_visual.visible,"retry visibly returns the player to unarmed start")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("WEAPON_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
