extends SceneTree
## Public gameplay seams: catalogs/economy, road/contact solver, race integration.
const Ride=preload("res://scripts/ride_physics.gd")
const Data=preload("res://scripts/game_data.gd")
const Traffic=preload("res://scripts/traffic_data.gd")
const Economy=preload("res://scripts/economy.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS TERRAIN ",label)
	else:
		failed+=1
		push_error("FAIL TERRAIN "+label)
func flight(course: int, velocity: float, rate: float) -> Dictionary:
	game.world.course_index=course
	game.world.course=Data.COURSES[course]
	var body=Ride.new()
	body.reset(game.world,350,velocity)
	var d=350.0
	var peak=0.0
	var landed=0
	var impact=0.0
	var airtime=0.0
	while d<950:
		var next=d+velocity/rate
		var event=body.step(game.world,d,next,velocity,1.0/rate)
		peak=maxf(peak,body.height)
		if event.landed:
			landed+=1
			impact=maxf(impact,event.impact)
			airtime=maxf(airtime,event.time)
		d=next
	return {"peak":peak,"landed":landed,"impact":impact,"airtime":airtime}
func fresh(course: int = 5) -> void:
	game.race_options={"course":course,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.set_process(false)
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
func run() -> void:
	check(Data.COURSES.size()==12,"twelve selectable race locations")
	check(Economy.BIKES.size()==12,"twelve purchasable motorcycles")
	check(Traffic.MODELS.size()==9,"nine dimensioned traffic archetypes")
	var ledger=Economy.new()
	ledger.cash=100000
	for bike in Economy.BIKES: ledger.select(bike.id)
	check(ledger.owned.size()==12 and ledger.equipped=="rover","all new motorcycles can be bought and equipped")
	var cfg=ConfigFile.new()
	ledger.save_config(cfg)
	var restored=Economy.new()
	restored.load_config(cfg)
	check(restored.owned.size()==12 and restored.equipped=="rover","expanded garage persists without losing old purchases")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for course in 8:
		game.world.build(course)
		check(is_zero_approx(game.world.height_at(0)) and is_zero_approx(game.world.height_at(Data.COURSES[course].length)),"course %d has level start and finish"%course)
	var flat=flight(0,100,60)
	check(flat.peak<0.01 and flat.landed==0,"flat road never invents a jump")
	var slow=flight(5,24,60)
	var fast=flight(5,100,60)
	print("FLIGHT slow=",slow," fast=",fast)
	check(slow.peak<0.1,"slow crest crossing maintains ground contact")
	check(fast.peak>1.0 and fast.airtime>0.5,"speed and convex terrain create real ballistic flight")
	check(fast.landed>=1 and fast.impact>10,"gravity brings bike back to terrain with measurable impact")
	var coarse=flight(5,100,30)
	var fine=flight(5,100,120)
	check(absf(coarse.peak-fine.peak)<0.15 and absf(coarse.airtime-fine.airtime)<0.04,"fixed substeps preserve flight across 30 to 120 Hz")
	game.world.build(6)
	check(game.world.road_half_width(1000)<6.5 and game.world.road_half_width(700)>9,"construction physically narrows road")
	check(game.world.surface_at(1200)=="gravel" and game.world.grip_at(1200)<0.8,"gravel changes actual grip")
	game.world.build(7)
	check(game.world.surface_at(400)=="wet" and game.world.grip_at(400)<0.75,"wet course has distinct traction")
	fresh()
	game.distance=460
	game.speed=100
	game.ride.reset(game.world,460,100)
	game.damage_cooldown=1000
	for r in game.rivals: r.distance=1200
	for i in 190:
		game._process(1.0/60)
	check(game.jumps>0 and game.best_jump>30,"real race awards successful landing and tracks flight length")
	fresh()
	game.distance=535
	game.speed=100
	game.ride.reset(game.world,535,100)
	game.ride.airborne=true
	game.ride.y+=7
	game.ride.height=7
	game.ride.velocity=5
	game._spawn_traffic(535,0,"semi")
	game._simulate_traffic(1.0/60)
	check(game.health==100,"rider can clear a truck instead of colliding through empty air")
	game.ride.y=game.world.height_at(game.distance)
	game.ride.height=0
	game._simulate_traffic(1.0/60)
	check(game.health<100,"same truck blocks the rider at ground level")
	fresh(0)
	game.distance=100
	game._spawn_traffic(105.5,0,"semi")
	game._simulate_traffic(1.0/60)
	check(game.health<100,"long trailer collides before a sedan-size envelope would")
	fresh(0)
	game.distance=100
	game._spawn_traffic(105.5,0,"sedan")
	game._simulate_traffic(1.0/60)
	check(game.health==100,"short sedan remains clear at the same longitudinal gap")
	fresh()
	game.ride.airborne=true
	game.ride.height=4
	game.ride.y=game.world.height_at(0)+4
	game.back()
	var height=game.ride.height
	for i in 120: game._process(1.0/60)
	check(game.ride.height==height,"pause freezes flight physics")
	game.start_race()
	check(not game.ride.airborne and game.ride.height==0 and game.jumps==0,"restart clears flight, suspension and jump records")
	game.world.update_track(540,game.track_length)
	game.distance=540
	game._update_entities()
	var car=game.traffic[0]
	check(absf(car.node.position.y-(game.world.height_at(car.distance)-game.world.height_at(540)))<0.01,"traffic uses the same elevation field as road geometry")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("TERRAIN_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
