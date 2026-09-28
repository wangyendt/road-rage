extends "res://tests/test_ui.gd"
const Stunt = preload("res://scripts/aerial_stunt.gd")
const Controls = preload("res://scripts/controls.gd")
class FlatRoad:
	extends RefCounted
	func height_at(_d: float) -> float: return 0.0
class Hill:
	extends RefCounted
	func height_at(d: float) -> float: return d*0.8
func prepare(course: int = 8, bike: int = 0) -> void:
	game.economy.equipped=game.Economy.BIKES[bike].id
	game.race_options={"course":course,"ai_count":1,"difficulty":5,"distance":0}
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for p in game.pickups: p.node.queue_free()
	game.pickups.clear()
	game.rivals[0].distance=6000
func launch() -> void:
	prepare(8,8)
	game.distance=400
	game.speed=105
	game.ride.reset(game.world,400,105)
	Input.action_press("boost")
	for frame in 180:
		game._process(1.0/60)
		if game.ride.height>20: break
	Input.action_release("boost")
func run() -> void:
	var stunt=Stunt.new()
	check(not stunt.start(1,0.5),"too little remaining airtime rejects separation")
	check(stunt.start(1,1.5),"long flight accepts trick")
	check(not stunt.start(1,1.5),"repeated presses cannot restart the active trick")
	stunt.step(0.4,1.5)
	check(stunt.extension>0.99 and stunt.stage=="展体","rider reaches full extension")
	stunt.step(0.05,0.3)
	check(stunt.stage=="回座","approaching terrain initiates early remount")
	stunt.step(0.3,0.1)
	check(not stunt.active and stunt.extension==0 and stunt.pending_bonus,"rider is seated before contact")
	check(stunt.land() and not stunt.land(),"trick rewards only one actual landing")
	check(not stunt.start(1,1.5) and stunt.start(2,1.5),"one trick per launch including its rebound chain")
	stunt.cancel()
	check(not stunt.active and not stunt.pending_bonus,"interruption clears unfinished rewards")
	var flat_eta=Stunt.contact_eta(FlatRoad.new(),0,70,25,-15)
	var uphill_eta=Stunt.contact_eta(Hill.new(),0,70,25,-15)
	check(uphill_eta<flat_eta and uphill_eta<0.55,"return prediction sees uphill terrain, not just vertical descent")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	# Every map AND every bike: very hard contact, no damage-cooldown protection.
	for course in 12:
		prepare(course,course)
		game.distance=800
		game.speed=65
		game.health=77
		game.ride.reset(game.world,800,65)
		game.ride.y+=180
		game.ride.height=180
		game.ride.velocity=-90
		game.ride.airborne=true
		game.ride.air_time=0.4
		game.ride.peak=180
		var voices=game.sound.rider_hit_count
		for frame in 1800:
			game._simulate(1.0/120)
			if game.jumps>0: break
		check(game.jumps>0,"map/bike %d performs an actual hard terrain contact"%course)
		check(game.health==77 and game.crashes==0 and game.player.recovery_time==0,"map/bike %d hard landing causes no damage or recovery"%course)
		check(game.sound.rider_hit_count==voices and game.damage_cooldown==0,"map/bike %d landing neither plays pain nor grants invulnerability"%course)
		for frame in 120: game._simulate(1.0/120)
		check(game.health==77 and game.crashes==0,"map/bike %d subsequent bounces stay harmless"%course)
		await process_frame
	# Natural cloud-road crest without using a stunt: immunity is unconditional.
	prepare(8,0)
	var peak=0.0
	for frame in 2400:
		if game.distance>300 and game.distance<650: Input.action_press("boost")
		else: Input.action_release("boost")
		game._simulate(1.0/60)
		peak=maxf(peak,game.ride.height)
		if game.distance>1600: break
	check(peak>30 and game.jumps>0,"starter bike takes a natural large cloud-road jump")
	check(game.health==100 and game.crashes==0,"ordinary big jump needs no special trick to land safely")
	launch()
	check(game.attempt_stunt(),"player can initiate a trick through race action")
	for frame in 26: game._process(1.0/60)
	check(game.player.rider.position.y>2.5 and game.player.stunt_pose_active,"actual rider model separates from the seat")
	var cooldown=game.attack_cooldown
	game.attack(1)
	check(game.attack_cooldown==cooldown,"separated rider cannot attack with invisible weapons")
	game.back()
	var extension=game.stunt.extension
	for frame in 60: game._process(1.0/60)
	check(game.state=="paused" and game.stunt.extension==extension,"pause freezes stunt animation")
	game.back()
	for frame in 90: game._process(1.0/60)
	check(game.stunt.pending_bonus and game.stunts==0,"remount queues bonus, does not award in the air")
	check(game.player.rider.position.is_equal_approx(Vector3(0,1.4,0.2)),"rider is visibly back on the motorcycle before landing")
	for frame in 900:
		game._process(1.0/60)
		if game.stunts>0: break
	check(game.stunts==1 and game.score==450,"landing adds 300 trick points plus the existing 150 flight points")
	check(game.health==100 and game.player.recovery_time==0,"stunt landing preserves health and riding state")
	for frame in 40: game._process(1.0/60)
	check(game.stunts==1 and game.score==450,"continued bounce chain does not farm stunt rewards")
	launch()
	game.attempt_stunt()
	for frame in 30: game._process(1.0/60)
	game.take_damage(23,"撞上车辆")
	check(game.health<100 and game.player.recovery_time>0,"real collision still damages and knocks down a stunt rider")
	check(not game.stunt.active and not game.stunt.pending_bonus,"collision cancels trick, not real crash recovery")
	launch()
	game.attempt_stunt()
	game.to_menu()
	check(not game.stunt.active and not game.player.stunt_pose_active,"leaving race restores seat and cleans up trick")
	game.start_race()
	check(game.stunts==0 and game.stunt.last_launch==-1,"restart clears stunt totals and per-flight latch")
	var cfg=ConfigFile.new()
	for action in Controls.ORDER:
		if action!="aerial_stunt": cfg.set_value("keys",action,KEY_E if action=="attack_left" else Controls.DEFAULTS[action])
	var controls=Controls.new()
	controls.load_config(cfg)
	check(controls.keys.attack_left==KEY_E and controls.keys.aerial_stunt!=KEY_E,"old custom E binding survives new action migration")
	controls.rebind("aerial_stunt",KEY_X)
	controls.save_config(cfg)
	var restored=Controls.new()
	restored.load_config(cfg)
	check(restored.keys.aerial_stunt==KEY_X,"stunt rebind survives save/reload")
	Input.action_release("boost")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("STUNT_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
