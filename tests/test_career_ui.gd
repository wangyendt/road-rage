extends "res://tests/test_ui.gd"
func advance(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
	await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.economy=game.Economy.new()
	await create_timer(0.4).timeout
	await click("garage")
	check(game.state=="garage","main menu opens motorcycle shop")
	await capture("v3-garage")
	await click("bike:lynx")
	check(game.economy.cash==1000 and game.economy.equipped=="rr09","shop rejects purchase when wallet is short")
	game.economy.award(12000)
	await click("bike:titan")
	check(game.economy.equipped=="titan" and game.player.model_shape==2,"purchase button equips real armored model")
	await capture("v3-garage-owned")
	await click("bike:rr09")
	check(game.economy.equipped=="rr09","owned starter can be selected again")
	await key(KEY_ESCAPE)
	check(game.state=="menu","Escape exits garage")
	game.race_options={"course":0,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.set_process(false)
	game.police.enabled=false
	game.distance=game.track_length-28
	game.speed=40
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for i in game.rivals.size(): game.rivals[i].distance=game.distance-30-i*6
	game._process(1.0/60)
	await capture("v3-finish-festival")
	check(game.world.finish_gate.visible and game.world.spectators.size()==48,"rendered approach shows finish festival")
	var cash_before=game.economy.cash
	await advance(1)
	check(game.finish_reason=="finished" and game.economy.cash>cash_before,"crossing checkerboard pays race prize")
	await capture("v3-prize")
	await click("garage")
	check(game.state=="garage" and game.rivals.is_empty(),"result screen leads to safe between-race bike purchase")
	await key(KEY_ESCAPE)
	game.start_race()
	game.state="race"
	game.distance=1200
	game.speed=45
	game.police.enabled=true
	game.police.next_distance=INF
	game.damage_cooldown=0
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.traffic_timer=INF
	for i in game.rivals.size(): game.rivals[i].distance=game.distance+40+i*7
	var cop=game.police.spawn(game.distance+4,game.lane+2)
	cop.speed=0
	game.trigger_crash()
	await advance(1.0)
	# Set up a visible officer approaching a grounded rider, then use normal simulation.
	cop.distance=game.distance+3
	cop.lane=game.lane+2
	cop.speed=0
	await advance(0.3)
	await capture("v3-police")
	check(cop.on_foot and cop.officer.visible,"rendered officer leaves police car for grounded rider")
	await advance(1.5)
	check(game.finish_reason=="busted","real pursuit reaches arrest results")
	await capture("v3-busted")
	check(game.race_fine.gross>0 and game.race_income.gross==0,"arrest result shows a fine, not a prize")
	await click("garage")
	check(game.state=="garage","arrest screen still permits access to owned motorcycles")
	print("CAREER_UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.7).timeout
	quit(1 if failed else 0)
