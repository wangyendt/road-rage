extends "res://tests/test_road_rules.gd"
const Economy=preload("res://scripts/economy.gd")
func run() -> void:
	check(Economy.BIKES.size()==20,"twenty bikes, preserving the original twelve IDs")
	var owned=Economy.new()
	owned.cash=1000000
	for item in Economy.BIKES: owned.select(item.id)
	var cfg=ConfigFile.new()
	owned.save_config(cfg)
	var restored=Economy.new()
	restored.load_config(cfg)
	check(restored.owned==owned.owned and restored.cash==owned.cash and restored.equipped=="sovereign","all purchases and remaining cash roundtrip")
	for i in range(12,20):
		var item=Economy.BIKES[i]
		var ledger=Economy.new()
		ledger.cash=item.price-1
		ledger.select(item.id)
		check(ledger.cash==item.price-1 and item.id not in ledger.owned,"premium %d requires its full price"%i)
		ledger.cash=item.price
		ledger.select(item.id)
		check(ledger.cash==0 and ledger.equipped==item.id and item.id in ledger.owned,"premium %d deducts exact price and equips"%i)
		ledger.select("rr09")
		ledger.select(item.id)
		check(ledger.cash==0 and Economy.price_label(item)=="标价 $%d"%item.price,"premium %d free reselection retains visible original price"%i)
		var axes=Economy.radar_values(item)
		check(axes.size()==6 and Array(axes).min()>=0 and Array(axes).max()<=1,"premium %d radar axes share bounded scale"%i)
		var wins=ceili(item.price/float(Economy.prize(1,16,5)))
		check(wins>=6 and wins<=28,"premium %d costs 6–28 full-grid legendary wins before pickup income"%i)
		var model=load("res://scripts/bike.gd").new()
		model.build(item.color,true,item.shape)
		check(model.chassis.has_node("PremiumKit%d"%item.shape),"premium %d has its own 3D equipment kit"%i)
		model.free()
	check(Economy.radar_values(Economy.BIKES[13])[3]>Economy.radar_values(Economy.BIKES[19])[3],"armor specialist beats flagship defence on real stat scale")
	check(Economy.radar_values(Economy.BIKES[15])[5]>Economy.radar_values(Economy.BIKES[19])[5],"air-control specialist beats flagship instead of all axes being maxed")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for i in 12:
		if not Route.PROFILES[i].closed: continue
		game.world.build(i)
		game.world.set_race_length(Data.COURSES[i].length*4)
		var route=game.world.route
		var lap=route.lap_length
		var same=true
		for d in [0.0,345.0,900.0,lap-1]:
			same=same and absf(game.world.height_at(d)-game.world.height_at(d+lap))<0.001 and absf(game.world.road_half_width(d)-game.world.road_half_width(d+lap))<0.001 and game.world.surface_at(d)==game.world.surface_at(d+lap)
		check(same,"circuit %d repeats road height, width and grip across laps"%i)
		check(game.world.relative_position(0,lap+0.1,lap-0.1).length()<0.21 and absf(game.world.relative_yaw(lap+0.1,lap-0.1))<0.01,"circuit %d closes without a road or camera direction jump"%i)
		check(route.lap(lap+1)==2 and route.lap(lap*4)==4 and absf(route.gap(lap+30,30))<0.001,"circuit %d separates lap progress from physical neighbour distance"%i)
	prepare(0,true,false)
	game.race_options.distance=1
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	var lap=game.world.route.lap_length
	game.distance=lap-1
	game.speed=80
	game.rivals[0].distance=lap+500
	game.ride.reset(game.world,game.distance,80)
	steps(0.1)
	check(game.distance>lap and game.state=="race" and game.world.route.lap(game.distance)==2,"crossing start line after first lap does not finish a two-lap race")
	game.distance=lap+200
	game.lane=0
	game.ride.reset(game.world,game.distance,0)
	game.rivals[0].distance=200
	game.rivals[0].lane=2.0
	game.rivals[0].ride.reset(game.world,200,0)
	game.rivals[0].hit_cd=0
	game.rivals[0].hp=2
	game.attack_cooldown=0
	game._update_entities()
	game.attack(1)
	check(game.rivals[0].node.visible and game.rivals[0].hp<2,"lapped rider is visible and hittable at same physical location")
	game.distance=game.track_length-1
	game.speed=80
	game.ride.reset(game.world,game.distance,80)
	steps(0.1)
	check(game.state=="finished" and game.finish_reason=="finished","only full lap count awards race finish")
	print("CIRCUITS_GARAGE_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
