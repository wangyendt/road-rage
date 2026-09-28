extends "res://tests/test_ui.gd"
const Economy = preload("res://scripts/economy.gd")
func clear_pickups() -> void:
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
func collect(kind: String) -> void:
	clear_pickups()
	game._spawn_pickup(game.distance,game.lane,kind)
	game._simulate_pickups(1.0/60)
func picture() -> Image:
	game._update_mirror()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func portion(img: Image, area: Rect2) -> int:
	return hash(img.get_region(Rect2i(area.position*Vector2(img.get_size()),area.size*Vector2(img.get_size()))).get_data())
func run() -> void:
	var account=Economy.new()
	account.cash=0
	account.debt=60
	var receipt=account.collect_cash(100)
	check(receipt.net==40 and receipt.debt_paid==60 and account.cash==40 and account.debt==0,"coin money repays fines before increasing spendable balance")
	check(account.total_prizes==0 and account.total_pickups==100,"coins do not inflate podium prize statistics")
	account.collect_cash(-10)
	check(account.cash==40 and account.total_pickups==100,"negative coin credit ignored")
	var file=ConfigFile.new()
	account.save_config(file)
	var restored=Economy.new()
	restored.load_config(file)
	check(restored.total_pickups==100 and restored.cash==40,"coin ledger survives config roundtrip")
	restored.load_config(ConfigFile.new())
	check(restored.total_pickups==0 and restored.cash==1000,"old saves need no migration or reset")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.race_options={"course":0,"ai_count":15,"difficulty":5,"distance":0}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.health=50
	game.nitro=10
	var cash=game.economy.cash
	collect("repair")
	check(game.health==75 and game.nitro==10 and game.economy.cash==cash,"repair heals 25 without charging money or granting nitro")
	collect("nitro")
	check(game.nitro==45 and game.health==75 and game.score==50 and game.economy.cash==cash,"nitro grants charge and score but not money")
	collect("coin")
	check(game.economy.cash==cash+100 and game.health==75 and game.nitro==45 and game.score==50,"actual coin grants cash only")
	game._simulate_pickups(0.1)
	check(game.economy.cash==cash+100 and game.pickups.is_empty(),"collected coins cannot award twice")
	game.ride.height=6
	game._spawn_pickup(game.distance,game.lane,"coin")
	game._simulate_pickups(0.1)
	check(game.pickups.size()==1,"ground pickups are not collected from high altitude")
	game.ride.height=0
	game.player.begin_crash()
	game._simulate_pickups(0.1)
	check(game.pickups.size()==1,"recovering riders cannot collect pickups")
	game.player.reset_pose()
	clear_pickups()
	for index in 3:
		game.pickup_timer=0
		game._simulate(1.0/60)
	check(game.pickups.any(func(p): return p.kind=="coin"),"normal spawning includes real coins")
	clear_pickups()
	game.distance=800
	game.speed=0
	game.ride.reset(game.world,800)
	for i in 3: game._spawn_pickup(818,[-4.5,0,4.5][i],["repair","nitro","coin"][i])
	game.world.update_track(800,game.track_length)
	game._update_entities()
	game._update_camera(1)
	game.message_time=0
	game.elapsed=20
	await picture()
	await capture("v46-pickups")
	check(game.pickups[0].node.get_child(0).mesh is BoxMesh and is_equal_approx(game.pickups[1].node.get_child(0).mesh.top_radius,0.30) and is_equal_approx(game.pickups[2].node.get_child(0).mesh.top_radius,0.85),"repair case, twin bottles and large coin have distinct silhouettes")
	check(game.pickups.map(func(p): return p.node.get_node("Legend").text)==["修复 +25","氮气 +35","金币 $100"],"readable labels distinguish actual reward types and amounts")
	game.ride.height=65
	game.ride.airborne=true
	game.ride.y=game.world.height_at(game.distance)+65
	game._update_entities()
	game._update_camera(1)
	game.police.pursuit_active=true
	game.police.lead_distance=48
	game.police.escape_required=100
	game.police.escape_progress=0.4
	await picture()
	await capture("v46-clear-road")
	var clear_road=Rect2(390,350,700,400)
	check(not game.hud.FLIGHT_RECT.intersects(clear_road) and not game.hud.PURSUIT_RECT.intersects(clear_road),"airborne and pursuit cards leave central landing road clear")
	check(not game.hud.FLIGHT_RECT.intersects(game.hud.MAP_RECT) and not game.hud.PURSUIT_RECT.intersects(game.hud.MAP_RECT),"new side rail does not overlap minimap")
	game.settings.map=false
	check(game.hud._pursuit_feedback().visible,"police warning remains when map hidden")
	game.settings.map=true
	game.ride.reset(game.world,800)
	game._update_entities()
	game._update_camera(1)
	game.police.pursuit_active=false
	game.hud.set_process(false)
	game.post.set_shader_parameter("boost",0.0)
	var plain=await picture()
	game.post.set_shader_parameter("boost",1.0)
	var blurred=await picture()
	check(portion(plain,Rect2(0.40,0.40,0.20,0.30))==portion(blurred,Rect2(0.40,0.40,0.20,0.30)),"boost shader leaves center road pixels unchanged")
	check(portion(plain,Rect2(0.02,0.50,0.20,0.20))!=portion(blurred,Rect2(0.02,0.50,0.20,0.20)),"boost shader changes peripheral background pixels")
	game.boost_visual=1
	game.boost_active=true
	await picture()
	await capture("v46-boost")
	game.boost_visual=0
	game.nitro=80
	game.speed=70
	Input.action_press("boost")
	game._process(1.0/60)
	check(game.boost_visual>0 and game.boost_visual<1,"real boost input smoothly starts visual intensity")
	for i in 20: game._process(1.0/60)
	check(game.boost_visual==1 and game.boost_active,"sustained boost reaches full visual strength")
	Input.action_release("boost")
	game._process(1.0/60)
	check(game.boost_visual>0 and game.boost_visual<1,"release fades visual intensity instead of snapping")
	for i in 20: game._process(1.0/60)
	check(game.boost_visual==0,"release clears speed effect completely")
	game.settings.shake=false
	game._process(1.0/60)
	check(game.boost_visual==0 and game.post.get_shader_parameter("boost")==0,"reduced motion disables new wind and background blur")
	game.settings.shake=true
	game.state="paused"
	game._process(1.0/60)
	check(game.boost_visual==0,"pause clears acceleration postprocessing")
	game.state="race"
	game.health=35
	game.economy.cash=2000
	game.player.begin_crash()
	game.player.recovery_elapsed=1
	game.arrest_player()
	check(game.race_fine.gross==1100 and game.economy.cash==900 and game.finish_reason=="busted","level 5 arrest still fines 1100 exactly once")
	game.arrest_player()
	check(game.economy.cash==900,"repeated arrest does not charge twice")
	game.result_time=2
	await picture()
	await capture("v46-fine")
	game.start_race()
	check(game.health==100 and game.economy.cash==900,"restart restores full durability with no repair charge")
	print("VISIBILITY_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)
