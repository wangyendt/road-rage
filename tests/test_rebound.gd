extends SceneTree
const Ride=preload("res://scripts/ride_physics.gd")
const Data=preload("res://scripts/game_data.gd")
const Economy=preload("res://scripts/economy.gd")
class FlatRoad:
	extends RefCounted
	func height_at(_d: float) -> float: return 0.0
	func slope_at(_d: float) -> float: return 0.0
class InclineRoad:
	extends RefCounted
	func height_at(d: float) -> float: return d*0.5
	func slope_at(_d: float) -> float: return 0.5
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS REBOUND ",label)
	else:
		failed+=1
		push_error("FAIL REBOUND "+label)
func drop(e: float, hz: float, recovering: bool = false) -> Dictionary:
	var road=FlatRoad.new()
	var body=Ride.new()
	body.configure({"restitution":e})
	body.reset(road,0)
	body.y=20
	body.height=20
	body.airborne=true
	var peaks=[]
	var contacts=[]
	var peak=0.0
	for frame in int(hz*30):
		var event=body.step(road,0,0,0,1.0/hz,recovering)
		if body.bounce_chain>0: peak=maxf(peak,body.height)
		for landing in event.contacts:
			contacts.append(landing)
			if landing.chain>0:
				peaks.append(peak)
				peak=0
		if not body.airborne: break
	return {"peaks":peaks,"contacts":contacts,"count":body.total_bounces,"body":body}
func crest(course: int, hz: float = 120.0) -> Dictionary:
	game.world.course_index=course
	game.world.course=Data.COURSES[course].duplicate()
	var body=Ride.new()
	body.configure(Economy.BIKES[8])
	body.reset(game.world,350,100)
	var d=350.0
	var maxheight=0.0
	var maxslope=0.0
	var contacts=0
	for frame in int(hz*12):
		var at=d+100.0/hz
		var event=body.step(game.world,d,at,100,1.0/hz)
		maxheight=maxf(maxheight,body.height)
		maxslope=maxf(maxslope,absf(game.world.slope_at(at)))
		contacts+=event.contacts.size()
		d=at
	return {"height":maxheight,"slope":maxslope,"contacts":contacts,"bounces":body.total_bounces}
func run() -> void:
	var spring=drop(0.68,120)
	check(spring.count>=3 and spring.count<=9,"spring suspension rebounds several times then settles")
	check(not spring.body.airborne and spring.body.height==0 and spring.body.velocity==0,"settled motorcycle remains in contact without jitter")
	check(absf(spring.peaks[0]-9.248)<0.35,"first rebound height matches e squared times 20m drop")
	var decay=true
	for i in range(1,spring.peaks.size()):
		if spring.peaks[i]>=spring.peaks[i-1]*0.60: decay=false
	check(decay,"successive rebound heights lose energy rather than grow")
	var thirty=drop(0.68,30)
	check(thirty.count==spring.count and absf(thirty.peaks[0]-spring.peaks[0])<0.08,"30Hz and 120Hz produce consistent rebound count and height")
	var damped=drop(0.16,120)
	check(damped.count<spring.count and damped.peaks[0]<1,"damped suspension visibly rebounds lower and less often")
	check(drop(0.0,120).count==0,"zero restitution is an inelastic landing")
	check(drop(0.68,120,true).count==0,"crash recovery never springs the rider back into a new jump")
	var incline=InclineRoad.new()
	var angled=Ride.new()
	angled.configure({"restitution":0.68})
	angled.reset(incline,0,80)
	angled.airborne=true
	angled.y=0.05
	angled.peak=10
	angled.velocity=-20
	var impact=angled.step(incline,0,80.0/120,80,1.0/120)
	check(impact.landed and impact.bounced and impact.forward_speed<80,"uphill rebound trades forward speed for vertical lift")
	check(impact.outgoing_energy<impact.incoming_energy,"inclined impact dissipates kinetic energy instead of inventing lift")
	check(absf(Vector2(impact.forward_speed,angled.velocity).dot(Vector2(-0.5,1).normalized())-impact.outgoing)<0.01,"restitution applies to the road normal on a slope")
	var high=Ride.new()
	high.configure({"restitution":9.0})
	check(high.restitution==0.8,"invalid restitution cannot add infinite energy")
	high.configure({"restitution":-2.0})
	check(high.restitution==0,"negative restitution is clamped")
	check(Data.COURSES.size()==12 and Economy.BIKES.size()==20,"twelve maps and twenty distinct motorcycles")
	var bike_ids=[]
	for bike in Economy.BIKES:
		check(bike.restitution>=0 and bike.restitution<1 and bike.air_control>0 and bike.air_control<=1,"valid physical tuning for "+bike.id)
		bike_ids.append(bike.id)
	check(bike_ids.size()==20 and Economy.BIKES[8].restitution>Economy.BIKES[9].restitution,"new spring and damper motorcycles have meaningful differences")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	for course in range(8,12):
		game.world.build(course)
		var flight=crest(course)
		print("CREST ",Data.COURSES[course].id," ",flight)
		check(flight.height>30 and flight.slope>0.4 and flight.contacts>0,"new map %d produces tall steep crest flight and landing"%course)
		var original=Data.COURSES[course].length
		game.world.set_race_length(original*4)
		check(game.world.height_at(original*4)==0 and absf(game.world.height_at(original+550))>1 and game.world.chunks[0].get_node_or_null("Landmark_"+game.world.course.id+"-1")!=null,"new map %d has its own landmark and extends to long distance"%course)
	var flight30=crest(8,30)
	var flight120=crest(8,120)
	check(absf(flight30.height-flight120.height)<0.25,"tall crest height is stable across frame rates")
	game.race_options={"course":0,"ai_count":15,"difficulty":3,"distance":0}
	game.economy.owned.append("spring")
	game.economy.equipped="spring"
	game.start_race()
	game.state="race"
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for r in game.rivals: r.distance=2000+r.id*30
	check(game.ride.restitution==0.68 and game.player.model_shape==8,"equipped motorcycle changes actual physics and model")
	check(game.rivals[8].ride.restitution==0.68,"AI also receives real suspension response")
	game.distance=600
	game.speed=74
	game.ride.reset(game.world,600,74)
	game.ride.y=20
	game.ride.height=20
	game.ride.airborne=true
	for frame in 1100:
		game._simulate(1.0/120)
		if game.bounces>0: break
	check(game.bounces==1 and game.rebound_timer>0 and game.rebound_chain==1,"actual contact triggers rebound HUD feedback")
	check(game.jumps==1 and game.score==150,"first flight awards points exactly once")
	var countdown=game.rebound_timer
	game.state="paused"
	game._process(0.05)
	check(game.rebound_timer==countdown,"pause freezes the impact badge and bounce state")
	game.state="race"
	for frame in 1200: game._simulate(1.0/120)
	check(game.bounces>=3 and game.jumps==1 and game.score==150,"secondary bounces do not farm jump rewards or inflate flight count")
	game.start_race()
	check(game.bounces==0 and game.rebound_timer==0 and not game.ride.airborne,"restart clears rebound chain and all feedback")
	game.to_menu()
	var cfg=ConfigFile.new()
	game.economy.save_config(cfg)
	var restored=Economy.new()
	restored.load_config(cfg)
	check(restored.equipped=="spring" and restored.bike().restitution==0.68,"new motorcycle ownership restores its physical tuning")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("REBOUND_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
