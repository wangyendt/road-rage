extends Node3D
## Main game coordinator. Simulation uses track-distance coordinates (metres).
const World = preload("res://scripts/world.gd")
const Bike = preload("res://scripts/bike.gd")
const Geo = preload("res://scripts/geo.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/audio.gd")
const FX = preload("res://scripts/fx.gd")
const Data = preload("res://scripts/game_data.gd")
const Director = preload("res://scripts/race_director.gd")
const Economy = preload("res://scripts/economy.gd")
const Police = preload("res://scripts/police.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Loadout = preload("res://scripts/loadout.gd")
var loadout = Loadout.new()
var weapons_claimed = 0
var weapon_notice = 0.0
const RidePhysics = preload("res://scripts/ride_physics.gd")
const PickupVisual = preload("res://scripts/pickup_visual.gd")
const TrafficData = preload("res://scripts/traffic_data.gd")
var ride = RidePhysics.new()
const AerialStunt = preload("res://scripts/aerial_stunt.gd")
var stunt = AerialStunt.new()
var stunts = 0
var stunt_notice = 0.0
var jumps = 0
var bounces = 0
var rebound_timer = 0.0
var rebound_chain = 0
var rebound_power = 0.0
var best_jump = 0.0
var course_page = 0
var bike_page = 0
const Controls = preload("res://scripts/controls.gd")
var track_length = 5400.0
const MAX_SPEED = 74.0
const BOOST_SPEED = 99.0
const SAVE_PATH = "user://road_rage.cfg"
var state = "menu"
var return_state = "menu"
var resume_state = "race"
var world: Node3D
var player: Node3D
var camera: Camera3D
var hud: Control
var sound: Node
var fx: Node3D
var post: ShaderMaterial
var rng = RandomNumberGenerator.new()
var rivals: Array[Dictionary] = []
var traffic: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var distance = 0.0
var lane = 0.0
var speed = 0.0
var health = 100.0
var nitro = 100.0
var score = 0
var takedowns = 0
var hits = 0
var near_misses = 0
var combo = 0
var combo_time = 0.0
var elapsed = 0.0
var total_time = 0.0
var demo_distance = 0.0
var steer = 0.0
var boost_active = false
var boost_lock = false
var countdown = 3.5
var countdown_last = 4
var attack_cooldown = 0.0
var damage_cooldown = 0.0
var shake = 0.0
var hitstop = 0.0
var flash = 0.0
var damage_flash = 0.0
var traffic_timer = 0.0
var pickup_timer = 0.0
var pickup_sequence = 0
var race_cash = 0
var boost_visual = 0.0
var message = ""
var message_sub = ""
var message_time = 0.0
var message_color = Color("acf2ed")
var finish_reason = ""
var last_damage_cause = ""
var final_rank = 6
var best_score = 0
var best_time = 0.0
var settings = {"volume":0.8,"music":true,"shake":true,"quality":true,"hard":false,"map":true,"mirror":true,"air_walls":true,"oncoming":false}
var race_rules={"air_walls":true,"oncoming":false}
var fall_velocity=0.0
var fall_time=0.0
var test_mode = false
var auto_drive = false
var test_elapsed = 0.0
var screenshot_at = -1.0
var screenshot_path = ""
var quit_after = -1.0
var quitting = false
var controls = Controls.new()
var race_options = {"course":0,"ai_count":7,"difficulty":3,"distance":0}
var active_level = 3
var active_distance = 0
var profiles: Array[Dictionary] = Data.riders()
var menu_history: Array[String] = []
var selected_profile = 0
var rebinding = ""
var binding_message = "点击动作后按新键；冲突按键自动交换。"
var mirror_view: SubViewport
var mirror_camera: Camera3D
var race_anchor = 0.0
var catchup_help = 0.0
var crashes = 0
var impact_meter = 0.0
var recovery_was_active = false
var camera_height_anchor = 0.0
var records: Dictionary = {}
var economy = Economy.new()
var police: Node3D
var active_bike: Dictionary = Economy.BIKES[0]
var garage_message = "购买后自动换车；已有车辆免费切换。"
var race_income = {"gross":0,"debt_paid":0,"net":0}
var race_fine = {"gross":0,"paid":0,"unpaid":0}
var finish_celebrated = false
var result_time = 0.0
var result_stamp_played = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg in ["--test-mode","--autoplay"]: test_mode=true
	rng.seed = 92107
	_setup_input()
	_load_save()
	world = World.new()
	add_child(world)
	world.build(race_options.course)
	player = Bike.new()
	add_child(player)
	active_bike=economy.bike().duplicate()
	player.build(active_bike.color,true,active_bike.shape)
	camera = Camera3D.new()
	camera.fov = 72
	camera.far = 1400
	camera.near = 0.08
	add_child(camera)
	camera.current = true
	_create_mirror()
	fx = FX.new()
	add_child(fx)
	sound = Sound.new()
	add_child(sound)
	police=Police.new()
	police.game=self
	add_child(police)
	_create_post()
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_settings()
	_parse_test_args()
	_update_camera(1)

func _setup_input() -> void:
	controls.apply()

func _create_post() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/screen.gdshader")
	rect.material = post
	layer.add_child(rect)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if not rebinding.is_empty():
			if key==KEY_ESCAPE:
				rebinding = ""
				binding_message = "已取消修改"
			else:
				binding_message = controls.rebind(rebinding,key)
				if key not in Controls.RESERVED and key!=0: rebinding = ""
				_save()
			get_viewport().set_input_as_handled()
			return
		if key==KEY_F11:
			var fullscreen = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if key==KEY_M:
			sound.muted = not sound.muted
			return
		if key==KEY_ESCAPE:
			back()
			return
		if state not in ["race","countdown","falling"]:
			if event.is_action_pressed("pause_game") and state=="paused": back()
			elif key in [KEY_ENTER,KEY_SPACE]: hud.activate_selected()
			elif key in [KEY_UP,KEY_W]: hud.move_selection(-1)
			elif key in [KEY_DOWN,KEY_S]: hud.move_selection(1)
			elif key==KEY_R and state=="finished": start_race()
			return
	if (event is InputEventKey and event.echo): return
	if event.is_action_pressed("pause_game"):
		back()
	elif state in ["race","countdown","falling"]:
		if event.is_action_pressed("show_roster"): open_page("roster")
		elif event.is_action_pressed("toggle_map"):
			settings.map = not settings.map
			_save()
		elif event.is_action_pressed("toggle_mirror"):
			settings.mirror = not settings.mirror
			_save()
		elif state=="race":
			if event.is_action_pressed("attack_left"): attack(-1)
			if event.is_action_pressed("attack_right"): attack(1)
			if event.is_action_pressed("attack_auto"): attack(_nearest_side())
			if event.is_action_pressed("cycle_weapon"): cycle_weapon()
			if event.is_action_pressed("aerial_stunt"): attempt_stunt()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_A: hud.activate_selected()
		elif event.button_index==JOY_BUTTON_B: back()
		elif event.button_index==JOY_BUTTON_DPAD_UP: hud.move_selection(-1)
		elif event.button_index==JOY_BUTTON_DPAD_DOWN: hud.move_selection(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state in ["race","countdown","falling"] and not test_mode:
		resume_state = state
		state = "paused"
		if hud: hud.selected = 0

func _process(raw_dt: float) -> void:
	var dt = minf(raw_dt,0.05)
	total_time += dt
	if test_mode: _test_step(raw_dt)
	if state=="finished":
		result_time+=dt
		if result_time>=0.55 and not result_stamp_played:
			result_stamp_played=true
			sound.sfx("click",-12,1.2 if finish_reason=="finished" else 0.7)
	var racing = state == "race"
	sound.update_audio(dt,speed,boost_active,racing)
	sound.update_air_audio(dt,speed,racing and ride.airborne)
	sound.update_world_audio(track_length-distance,police.intensity,racing,dt,police.pitch,police.urgency,police.pan)
	if menu_backdrop():
		demo_distance += dt*12
		world.update_track(demo_distance,track_length)
		player.animate(dt,12,0.0,false,total_time)
		player.position = Vector3.ZERO
		player.rotation = Vector3(atan(world.slope_at(demo_distance)),0,0)
	elif state == "countdown":
		countdown -= dt
		var count = int(ceil(countdown))
		if count != countdown_last and count > 0 and count <= 3:
			countdown_last = count
			sound.sfx("count")
		if countdown <= 0:
			state = "race"
			sound.sfx("go")
			announce("全速出击", "自动油门 · %s / %s 左右攻击"%[controls.label("attack_left"),controls.label("attack_right")],Color("acf2ed"),2.5)
	elif state=="falling":
		_simulate_fall(dt)
	elif racing:
		var sim_dt = dt
		if hitstop > 0:
			hitstop -= dt
			sim_dt *= 0.12
		_simulate(sim_dt)
	if state in ["race","countdown","falling","finished"]:
		world.update_track(distance,track_length,total_time,ride.height)
		_update_entities()
	if state in ["race","countdown","falling","finished"] or menu_backdrop():
		_update_camera(dt)
		shake = move_toward(shake,0,dt*2.5)
		flash = move_toward(flash,0,dt*8)
		damage_flash = move_toward(damage_flash,0,dt*2.5)
		message_time = maxf(0,message_time-dt)
	boost_visual=move_toward(boost_visual,1.0 if boost_active and state=="race" and settings.shake else 0.0,dt*5)
	if state!="race" or not settings.shake: boost_visual=0.0
	post.set_shader_parameter("boost",boost_visual)
	post.set_shader_parameter("hit",flash)
	post.set_shader_parameter("damage",damage_flash)
	_update_mirror()
	hud.queue_redraw()

func start_race() -> void:
	_clear_race()
	race_rules={"air_walls":bool(settings.air_walls),"oncoming":bool(settings.oncoming)}
	fall_time=0
	fall_velocity=0
	loadout=Loadout.new()
	weapons_claimed=0
	weapon_notice=0
	_apply_bike()
	race_income={"gross":0,"debt_paid":0,"net":0}
	race_fine={"gross":0,"paid":0,"unpaid":0}
	finish_celebrated=false
	menu_history.clear()
	active_level = clampi(race_options.difficulty,1,5)
	active_distance = Data.distance_index(race_options.get("distance",0))
	race_options.distance = active_distance
	track_length = Data.race_length(race_options.course,active_distance)
	if world.course_index!=race_options.course: world.build(race_options.course)
	world.set_race_length(track_length)
	world.configure_rules(race_rules.air_walls,race_rules.oncoming)
	_apply_settings()
	state = "countdown"
	return_state = "menu"
	distance = 0
	ride = RidePhysics.new()
	ride.configure(active_bike)
	ride.reset(world,0)
	stunt=AerialStunt.new()
	stunts=0
	stunt_notice=0
	jumps=0
	bounces=0
	rebound_timer=0
	rebound_chain=0
	best_jump=0
	lane = 2.25 if race_rules.oncoming else 0
	speed = 0
	health = 100
	nitro = 100
	score = 0
	takedowns = 0
	hits = 0
	near_misses = 0
	combo = 0
	combo_time = 0
	elapsed = 0
	steer = 0
	boost_active = false
	boost_lock = false
	countdown = 3.5
	countdown_last = 4
	attack_cooldown = 0
	damage_cooldown = 0
	shake = 0
	hitstop = 0
	flash = 0
	damage_flash = 0
	player.attack_time = 0
	traffic_timer = 1.2
	pickup_timer = 1
	pickup_sequence=0
	race_cash=0
	boost_visual=0
	message_time = 0
	finish_reason = ""
	last_damage_cause = ""
	sound.countdown_cues.clear()
	hud.selected = 0
	player.reset_pose()
	crashes = 0
	impact_meter = 0
	catchup_help = 0
	recovery_was_active = false
	rng.seed = 92107
	for i in clampi(race_options.ai_count,1,15):
		var profile = profiles[i]
		var bike = Bike.new()
		add_child(bike)
		bike.build(profile.color,false,i%Economy.BIKES.size())
		bike.set_weapon(profile.weapon)
		var start_lane = [2.25,6.75][i%2] if race_rules.oncoming else [-6.75,-2.25,2.25,6.75][i%4]
		var rival_ride=RidePhysics.new()
		rival_ride.configure(Economy.BIKES[i%Economy.BIKES.size()])
		rival_ride.reset(world,9.0+int(i/(2 if race_rules.oncoming else 4))*8.0)
		rivals.append({"loadout":Loadout.new(profile.weapon),"ride":rival_ride,"id":i,"profile":profile,"node":bike,"name":profile.name,"color":profile.color,"distance":9.0+int(i/(2 if race_rules.oncoming else 4))*8.0,"lane":start_lane,"speed":0.0,"cruise":Data.difficulty(active_level).pace,"hp":2,"stun":0.0,"cooldown":2.5+i*0.17,"windup":0.0,"phase":float(i)*1.5,"finished":false,"finish_time":0.0,"nitro":100.0,"burst":0.0,"boosts_used":0,"boost_reason":"","burst_cd":4.0+i*0.6,"think":0.0,"target_lane":start_lane,"target_id":-2,"hit_cd":0.0,"crashes":0,"attacks":0})
	_spawn_traffic(155,-6.75)
	_spawn_traffic(230,2.25)
	_spawn_pickup(105,2.25,"nitro")
	world.update_track(distance,track_length,total_time,ride.height)
	_update_entities()
	_update_camera(1)

func _clear_race() -> void:
	_cancel_stunt()
	for list in [rivals,traffic,pickups]:
		for item in list:
			if is_instance_valid(item.node): item.node.queue_free()
		list.clear()
	fx.clear_effects()
	if police: police.reset()

func _simulate(dt: float) -> void:
	if not Input.is_action_pressed("boost") and not auto_drive: boost_lock=false
	var previous_distance=distance
	var previous_lane=lane
	weapon_notice=maxf(0,weapon_notice-dt)
	stunt_notice=maxf(0,stunt_notice-dt)
	elapsed += dt
	rebound_timer=maxf(0,rebound_timer-dt)
	attack_cooldown = maxf(0,attack_cooldown-dt)
	damage_cooldown = maxf(0,damage_cooldown-dt)
	combo_time = maxf(0,combo_time-dt)
	impact_meter = maxf(0,impact_meter-dt*4)
	if combo_time<=0: combo = 0
	var positions: Array[float] = [distance]
	var leader = distance
	for r in rivals:
		positions.append(r.distance)
		leader = maxf(leader,r.distance)
	positions.sort()
	race_anchor = distance*0.75+positions[int(positions.size()/2)]*0.25
	catchup_help = Director.player_assist(leader-distance,track_length-distance)
	if player.recovery_time>0:
		nitro=minf(100,nitro+dt*8)
		boost_active = false
		steer = 0
		speed = move_toward(speed,0,dt*52)
		distance += speed*dt
		player.animate(dt,speed,0,false,total_time)
		if player.recovery_time<=0:
			damage_cooldown = 1.8
			nitro = minf(100,nitro+28)
			announce("重新上车","追回去！恢复 28 氮气，短暂无敌保护",Color("a4eadf"),2)
	else:
		var input_steer = Input.get_axis("steer_left","steer_right")
		var brake = Input.is_action_pressed("brake")
		var wants_boost = Input.is_action_pressed("boost")
		if auto_drive:
			input_steer = _autopilot_steer()
			wants_boost = fmod(elapsed,11.0)>7.0 and nitro>1.0
		if not wants_boost: boost_lock = false
		var was_boost = boost_active
		boost_active = wants_boost and nitro>0.5 and not brake and not boost_lock
		if boost_active:
			nitro = maxf(0,nitro-dt*28)
			if nitro<=0.5: boost_lock = true
			if not was_boost: sound.sfx("nitro",-5)
		else: nitro = minf(100,nitro+dt*(8+catchup_help*0.8))
		var target = (active_bike.boost if boost_active else active_bike.speed)+catchup_help
		if wrong_way(): target*=1.08
		if brake: target = 24
		var limit=world.road_half_width(distance)-0.5
		var grip=minf(1.0,world.grip_at(distance)*active_bike.get("grip",1.0))
		if race_rules.air_walls and absf(lane)>limit-0.2: target = 40
		elif not race_rules.air_walls and absf(lane)>world.road_half_width(distance) and ride.height<1.0:
			target=minf(target,38.0 if world.theme==1 else 45.0)
			grip*=0.62
		speed = move_toward(speed,target,dt*(42*grip if brake or (not race_rules.air_walls and absf(lane)>world.road_half_width(distance) and speed>target) else active_bike.accel+catchup_help))
		steer = lerpf(steer,input_steer,1-exp(-dt*9*grip))
		lane += steer*dt*(active_bike.handling*grip*(active_bike.get("air_control",0.35) if ride.airborne else 1.0)*(1.12 if boost_active else 1.0))
		lane += sin(distance*0.0039)*speed*dt*0.0025
		if race_rules.air_walls and absf(lane)>limit:
			lane = clampf(lane,-limit-0.1,limit+0.1)
			if speed>35 and ride.height<1.0: take_damage(8,"擦碰护栏")
		distance += speed*dt
		player.position = Vector3(lane,0,0)
		player.rotation.y = -steer*0.09
		player.animate(dt,speed,steer,boost_active,total_time)
	if not race_rules.air_walls:
		if world.over_sea(lane,distance) and ride.y+ride.velocity*dt-0.5*RidePhysics.GRAVITY*dt*dt<=world.height_at(distance)+0.4:
			_begin_fall()
			return
		var wall=world.roadside_hit(previous_lane,previous_distance,lane,distance,ride.height)
		if not wall.is_empty():
			lane=wall.lane
			if damage_cooldown<=0 and player.recovery_time<=0:
				take_damage(28,wall.cause)
				speed*=0.4
	var contact_event=ride.step(world,previous_distance,distance,speed,dt,player.recovery_time>0)
	if contact_event.landed: speed=contact_event.forward_speed
	for landing in contact_event.contacts:
		if player.recovery_time>0: continue
		if landing.time<=0.12 or landing.peak<=0.08: continue
		if landing.chain==0 and landing.time>0.3 and landing.peak>0.45:
			jumps+=1
			best_jump=maxf(best_jump,landing.distance)
		var comfort=active_bike.get("suspension",22.0)
		# Terrain landings are stunts, never damage/crash events. Suspension tunes feedback only.
		var absorbed=landing.impact*sqrt(1.0-ride.restitution*ride.restitution)
		shake=maxf(shake,minf(0.28,absorbed/maxf(30.0,comfort*3.0)))
		sound.sfx("landing",-12+minf(landing.impact/6,7),1.0+minf(landing.chain,4)*0.1)
		if landing.bounced and player.recovery_time<=0:
			bounces+=1
			rebound_timer=1.15
			rebound_chain=landing.chain+1
			rebound_power=clampf(landing.outgoing/30.0,0.2,1)
			fx.rebound(Vector3(lane,0.12,0),Color("ffbc66"),rebound_power)
		if landing.chain==0 and landing.time>0.3 and landing.peak>0.45:
			score+=150
			nitro=minf(100,nitro+8)
			if not landing.bounced: announce("稳稳落地","飞跃 %.0fm · +150 分 · 无车损"%landing.distance,Color("c6f2cb"),1.6)
	if contact_event.landed:
		if stunt.land():
			stunts+=1
			score+=AerialStunt.BONUS
			nitro=minf(100,nitro+12)
			stunt_notice=2.0
			sound.sfx("pickup",-10,1.15)
	elif stunt.active:
		stunt.step(dt,AerialStunt.contact_eta(world,distance,speed,ride.y,ride.velocity))
	player.pose_stunt(stunt.extension,stunt.active)
	for rival in rivals: _simulate_rival(rival,dt)
	_simulate_traffic(dt,previous_distance)
	_simulate_pickups(dt)
	police.update(dt)
	if state!="race": return
	if track_length-distance<350 and not finish_celebrated:
		finish_celebrated=true
		announce("终点就在前方", "穿过黑白终点线，观众正在为你喝彩！",Color("b9f3ec"),3)
	traffic_timer -= dt
	pickup_timer -= dt
	if traffic_timer<=0 and traffic.size()<16:
		traffic_timer = rng.randf_range(2.0,3.1)/(world.course.traffic*(0.84+active_level*0.055))
		_spawn_traffic(distance+rng.randf_range(210,290),[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)])
	if pickup_timer<=0:
		pickup_timer = 3.1
		pickup_sequence+=1
		var kind="coin" if pickup_sequence%3==0 else ("repair" if health<65 else "nitro")
		_spawn_pickup(distance+190,[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)],kind)
	if health<=0: finish_race("wrecked")
	elif distance>=track_length and player.recovery_time<=0: finish_race("finished")

func wrong_way() -> bool:
	return state=="race" and race_rules.oncoming and lane< -0.9 and absf(lane)<world.road_half_width(distance)-0.4 and ride.height<1.0 and player.recovery_time<=0

func _clamp_player_lane(value: float) -> float:
	var limit=world.road_half_width(distance)-0.4
	return clampf(value,-limit,limit) if race_rules.air_walls else value

func _begin_fall() -> void:
	_cancel_stunt()
	state="falling"
	fall_velocity=minf(ride.velocity,0)
	fall_time=0
	boost_active=false
	message_time=0
	rebound_timer=0
	# Preserve world altitude; sea level is fixed at -18 m.
	ride.height=ride.y-world.height_at(distance)

func _simulate_fall(dt: float) -> void:
	elapsed+=dt
	fall_time+=dt
	distance+=speed*dt
	speed=move_toward(speed,0,dt*18)
	fall_velocity-=RidePhysics.GRAVITY*dt
	ride.y+=fall_velocity*dt
	ride.height=ride.y-world.height_at(distance)
	player.rotation.z=sin(fall_time*3)*0.25
	if ride.y<= -18:
		ride.y=-18
		ride.height=-18-world.height_at(distance)
		fx.burst(Vector3(lane,ride.height+0.2,0),Color("93edff"),true)
		finish_race("sea")

func _simulate_rival(r: Dictionary, dt: float) -> void:
	var previous_distance: float=r.distance
	var d = Data.difficulty(active_level)
	r.cooldown = maxf(0,r.cooldown-dt)
	r.stun = maxf(0,r.stun-dt)
	r.hit_cd = maxf(0,r.hit_cd-dt)
	r.burst_cd = maxf(0,r.burst_cd-dt)
	if r.finished:
		r.distance = minf(track_length+70,r.distance+r.speed*dt)
		r.ride.step(world,previous_distance,r.distance,r.speed,dt)
		return
	if r.node.recovery_time>0:
		r.speed = move_toward(r.speed,0,dt*55)
		r.distance += r.speed*dt
		r.node.animate(dt,r.speed,0,false,total_time)
		r.ride.step(world,previous_distance,r.distance,r.speed,dt,true)
		if r.node.recovery_time<=0:
			r.ride.reset(world,r.distance,r.speed)
			r.hp = 2
			r.stun = 0
			r.hit_cd = 1.5
			r.nitro = minf(100,r.nitro+30)
		return
	r.think -= dt
	var gap = r.distance-distance
	var road_clear = _ai_boost_clear(r)
	if r.think<=0:
		r.think = d.reaction*0.34
		r.target_lane = _choose_ai_lane(r,d)
		var next_gap = INF
		for other in rivals:
			if other.id!=r.id and not other.finished and other.hp>0 and other.distance>r.distance:
				next_gap=minf(next_gap,other.distance-r.distance)
		if distance>r.distance: next_gap=minf(next_gap,distance-r.distance)
		var reason=Director.boost_reason(active_level,gap,next_gap,track_length-r.distance,r.nitro,elapsed)
		if r.burst<=0 and r.burst_cd<=0 and r.stun<=0 and road_clear and not reason.is_empty() and rng.randf()<d.nitro:
			r.burst = 3.0 if active_level==5 else 1.0+d.nitro*1.7
			r.burst_cd = (5.2 if active_level==5 else 7.5)+(1-r.profile.aggression)*4.0
			r.boosts_used += 1
			r.boost_reason = reason
	# A blocked lane, hit or empty tank cancels the burst; it never resumes for free.
	if not road_clear or r.stun>0 or r.nitro<=0: r.burst=0
	var boosting = r.burst>0
	r.burst=maxf(0,r.burst-dt)
	if boosting: r.nitro = maxf(0,r.nitro-dt*26)
	else: r.nitro = minf(100,r.nitro+dt*(10.5 if active_level==5 else 7.5))
	var target = Director.target_speed(active_level,r.profile,r.distance-race_anchor,track_length-r.distance,boosting)
	if active_level==5:
		for car in traffic:
			var ahead=car.distance-r.distance
			if ahead>0 and ahead<car.get("length",4.1)*0.5+10+maxf(0,r.speed-car.speed)*0.45 and absf(car.lane-r.lane)<car.get("width",1.95)*0.5+0.7:
				target=minf(target,maxf(20,car.speed-3))
	if r.stun>0: target = minf(target,45)
	r.speed = move_toward(r.speed,target,dt*((25.0 if active_level==5 else 17.0)+r.profile.pace*6))
	r.distance += r.speed*dt
	var landing=r.ride.step(world,previous_distance,r.distance,r.speed,dt)
	if landing.landed: r.speed=landing.forward_speed
	var old_lane = r.lane
	if r.stun<=0: r.lane = move_toward(r.lane,r.target_lane,dt*d.handling*world.grip_at(r.distance)*(0.35 if r.ride.airborne else 1.0)*(0.65+r.profile.handling*0.45))
	r.lane=clampf(r.lane,-world.road_half_width(r.distance)+0.65,world.road_half_width(r.distance)-0.65)
	var lean = clampf((r.lane-old_lane)/maxf(dt*4,0.001),-1,1)
	r.node.animate(dt,r.speed,lean,boosting,total_time+r.phase)
	for car in traffic:
		if minf(car.distance-previous_distance,car.distance+car.speed*dt-r.distance)<car.get("length",4.1)*0.5+1.05 and maxf(car.distance-previous_distance,car.distance+car.speed*dt-r.distance)>-car.get("length",4.1)*0.5-1.05 and absf(car.lane-r.lane)<car.get("width",1.95)*0.5+0.45 and r.ride.y<world.height_at(car.distance)+car.get("height",1.75) and r.hit_cd<=0:
			_crash_rival(r,1 if r.lane>car.lane else -1)
			return
	if r.windup>0:
		r.windup -= dt
		if r.windup<=0:
			r.cooldown = d.attack_cd*(1.3-r.profile.aggression*0.5)*clampf(Weapons.data(r.loadout.current).cooldown/0.6,0.8,1.6)+rng.randf()
			_resolve_ai_attack(r)
	elif r.cooldown<=0 and r.stun<=0:
		r.target_id = -2
		if Weapons.reaches(r.loadout.current,r.lane-lane,gap,r.ride.y-ride.y) and player.recovery_time<=0:
			r.target_id = -1
		elif r.profile.aggression>0.65:
			for other in rivals:
				if other.id!=r.id and other.hp>0 and other.node.recovery_time<=0 and Weapons.reaches(r.loadout.current,other.lane-r.lane,other.distance-r.distance,other.ride.y-r.ride.y):
					r.target_id = other.id
					break
		if r.target_id != -2: r.windup = d.reaction
	if absf(r.ride.y-ride.y)<1.25 and absf(r.distance-distance)<1.8 and absf(r.lane-lane)<0.80 and r.stun<=0 and player.recovery_time<=0:
		var bump_side = -1.0 if r.lane>lane else 1.0
		take_damage(6,"车手擦碰")
		lane = _clamp_player_lane(lane+bump_side*dt*3)
		r.lane = clampf(r.lane-bump_side*dt*3,-8.9,8.9)
	if r.distance>=track_length:
		r.finished = true
		r.finish_time = elapsed-maxf(0,r.distance-track_length)/maxf(r.speed,1)

func _ai_boost_clear(r: Dictionary) -> bool:
	if r.ride.airborne: return false
	var width=minf(world.road_half_width(r.distance),world.road_half_width(r.distance+70))-0.8
	if absf(r.lane)>width: return false
	for car in traffic:
		var ahead=car.distance-r.distance
		var horizon=25.0 if active_level<5 else 18.0+maxf(0,r.speed-car.speed)*0.9+car.get("length",4.1)*0.5
		if ahead> -car.get("length",4.1)*0.5 and ahead<horizon and absf(car.lane-r.lane)<car.get("width",1.95)*0.5+1.0: return false
	return true

func _choose_ai_lane(r: Dictionary, d: Dictionary) -> float:
	var preferred = sin(elapsed*0.18+r.phase)*6.5
	if absf(r.distance-distance)<15 and player.recovery_time<=0:
		var spacing = clampf(Weapons.data(r.loadout.current).reach*0.8,2.2,4.3) if active_level==5 else 2.3
		preferred = clampf(lane+(-spacing if r.id%2==0 else spacing),-7.9,7.9)
		if active_level>=4 and player.attack_time>0 and r.stun<=0:
			preferred = clampf(r.lane+(-2 if r.lane<lane else 2),-8,8)
	var best = r.lane
	var best_cost = INF
	for candidate in [-7.1,-4.5,-2.3,0.0,2.3,4.5,7.1,preferred]:
		if race_rules.oncoming and candidate<0.9: continue
		if absf(candidate)>minf(world.road_half_width(r.distance),world.road_half_width(r.distance+d.lookahead))-0.85: continue
		var cost = absf(candidate-preferred)*0.35+absf(candidate-r.lane)*0.18
		for car in traffic:
			var ahead = car.distance-r.distance
			if active_level==5: ahead+=(car.speed-r.speed)*0.55
			if ahead> -4 and ahead<d.lookahead+maxf(0,r.speed-car.speed)*0.35:
				cost += maxf(0,car.get("width",1.95)*0.5+1.6-absf(candidate-car.lane))*(6.0 if ahead<25 else 3.0)
		for other in rivals:
			if other.id!=r.id and absf(other.distance-r.distance)<7:
				cost += maxf(0,1.7-absf(candidate-other.lane))*2.5
		if absf(r.distance-distance)<3: cost += maxf(0,1.3-absf(candidate-lane))*4
		if cost<best_cost:
			best_cost=cost
			best=candidate
	return best

func _resolve_ai_attack(r: Dictionary) -> void:
	if r.stun>0 or r.node.recovery_time>0: return
	var w=Weapons.data(r.loadout.current)
	if r.target_id == -1:
		if Weapons.reaches(w.id,r.lane-lane,r.distance-distance,r.ride.y-ride.y) and player.recovery_time<=0:
			r.node.swing(-1 if r.lane>lane else 1)
			var previous_health=health
			take_damage(w.rider_damage,"%s · %s"%[r.name,w.name])
			if health<previous_health:
				var side=1.0 if lane>r.lane else -1.0
				lane=_clamp_player_lane(lane+side*w.shove*0.4)
				player.react_to_hit(side)
				r.attacks += 1
	elif r.target_id>=0 and r.target_id<rivals.size():
		var other = rivals[r.target_id]
		if Weapons.reaches(w.id,r.lane-other.lane,r.distance-other.distance,r.ride.y-other.ride.y) and other.hit_cd<=0 and other.node.recovery_time<=0:
			var side=1 if other.lane>r.lane else -1
			r.node.swing(side)
			other.hp -= w.damage
			other.stun = w.stagger
			other.hit_cd = 0.7
			other.windup = 0
			other.lane=clampf(other.lane+side*w.shove*0.5,-8.5,8.5)
			other.node.react_to_hit(side)
			r.attacks += 1
			sound.rider_hit(other.id,absf(other.distance-distance),other.hp<=0)
			if absf(other.distance-distance)<80: fx.burst(other.node.position+Vector3(0,1.5,0),w.color)
			if other.hp<=0: _crash_rival(other,side)

func _crash_rival(r: Dictionary, side: float) -> void:
	if r.node.recovery_time>0: return
	r.hp = 0
	r.stun = r.node.recovery_duration
	r.hit_cd = r.node.recovery_duration+1
	r.windup = 0
	r.burst = 0
	r.speed *= 0.45
	r.crashes += 1
	r.node.begin_crash(side)
	if absf(r.distance-distance)<90: fx.burst(r.node.position+Vector3(0,0.8,0),Color("ffb865"),true)

func _simulate_traffic(dt: float, previous_player_distance: float = NAN) -> void:
	if is_nan(previous_player_distance): previous_player_distance=distance-speed*dt
	for i in range(traffic.size()-1,-1,-1):
		var car = traffic[i]
		var old_z = car.distance-previous_player_distance
		car.distance += car.speed*dt
		var edge=world.road_half_width(car.distance+20)-car.get("width",1.95)*0.5-0.4
		car.lane=move_toward(car.lane,clampf(car.lane,-edge,edge),dt*3.0)
		var z = car.distance-distance
		var extent=car.get("length",4.1)*0.5+1.1
		var hit_width=car.get("width",1.95)*0.5+0.45
		var crossing = minf(old_z,z)<extent and maxf(old_z,z)>-extent
		var vertical_hit=ride.y<world.height_at(car.distance)+car.get("height",1.75) and ride.y+2.3>world.height_at(car.distance)
		var dx = absf(car.lane-lane)
		if crossing and vertical_hit and dx<hit_width and not car.collided and player.recovery_time<=0:
			car.collided = true
			take_damage(36 if car.get("oncoming",false) else 23,"迎面撞车" if car.get("oncoming",false) else "撞上车辆")
			speed *= 0.59
			lane += -0.75 if lane<car.lane else 0.75
		if z < -extent-1.0 and not car.passed:
			car.passed = true
			if dx>=hit_width and dx<hit_width+1.2 and not ride.airborne and not car.collided and speed>50 and player.recovery_time<=0:
				near_misses += 1
				score += 100
				nitro = minf(100,nitro+10)
				announce("极限擦身", "+100 分  /  氮气 +10",Color("aff0e9"),1.0)
		if z < -55:
			car.node.queue_free()
			traffic.remove_at(i)

func _simulate_pickups(dt: float) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var p = pickups[i]
		var z = p.distance-distance
		if z<2.5 and z>-speed*dt-2.5 and ride.height<1.9 and absf(p.lane-lane)<1.35 and player.recovery_time<=0:
			if p.kind == "repair":
				health = minf(100,health+25)
				announce("装甲修复", "+25 车体耐久",Color("bff58f"),1.2)
			elif p.kind == "coin":
				var receipt=economy.collect_cash(100)
				race_cash+=receipt.gross
				announce("金币奖励", "+$%d 入账 · 抵扣罚款 $%d"%[receipt.net,receipt.debt_paid],PickupVisual.color("coin"),1.2)
				_save()
			else:
				nitro = minf(100,nitro+35)
				score += 50
				announce("氮气补给", "+35 氮气  /  +50 分",Color("9cecf4"),1.2)
			sound.sfx("pickup",-6)
			fx.burst(p.node.position,PickupVisual.color(p.kind))
			p.node.queue_free()
			pickups.remove_at(i)
		elif z < -20:
			p.node.queue_free()
			pickups.remove_at(i)

func _spawn_traffic(at: float, x: float, model: String = "") -> void:
	# Keep a safe gap in a lane; never generate an unavoidable four-car wall.
	for car in traffic:
		if absf(car.distance-at)<18: return
	for p in pickups:
		if absf(p.distance-at)<10 and absf(p.lane-x)<2: return
	var colors = [Color("a7b9c2"),Color("255262"),Color("d78b54"),Color("343d55"),Color("a85659")]
	var spec=TrafficData.choose(rng,world.course.id)
	for option in TrafficData.MODELS:
		if option.id==model: spec=option
	var edge=world.road_half_width(at)-spec.width*0.5-0.5
	x=clampf(x,-edge,edge)
	var n = world.traffic_vehicle(spec,colors[rng.randi_range(0,colors.size()-1)])
	add_child(n)
	traffic.append({"node":n,"distance":at,"lane":x,"speed":(spec.speed+rng.randf_range(-2,2))*(-1 if race_rules.oncoming and x<0 else 1),"oncoming":race_rules.oncoming and x<0,"model":spec.id,"width":spec.width,"length":spec.length,"height":spec.height,"passed":false,"collided":false})

func _spawn_pickup(at: float, x: float, kind: String) -> void:
	x=clampf(x,-world.road_half_width(at)+1.1,world.road_half_width(at)-1.1)
	for car in traffic:
		if absf(car.distance-at)<15 and absf(car.lane-x)<2: return
	var n = PickupVisual.build(kind)
	add_child(n)
	pickups.append({"node":n,"distance":at,"lane":x,"kind":kind})

func attempt_stunt() -> bool:
	if state!="race" or player.recovery_time>0 or player.attack_time>0 or attack_cooldown>0: return false
	if not ride.airborne or ride.height<6: return false
	var eta=AerialStunt.contact_eta(world,distance,speed,ride.y,ride.velocity)
	if not stunt.start(ride.launches,eta): return false
	sound.sfx("swing",-15,0.8)
	return true

func _cancel_stunt() -> void:
	stunt.cancel()
	if player: player.pose_stunt(0,false)

func attack(side: int) -> void:
	if state != "race" or attack_cooldown > 0 or player.recovery_time>0 or stunt.active: return
	var w=Weapons.data(loadout.current)
	attack_cooldown = w.cooldown
	player.swing(side)
	fx.slash(player.position+Vector3(0,1.55,-0.05),side,w.color,w.reach)
	sound.sfx("whip" if w.kind=="flex" else "swing",-7,1.15 if w.kind=="punch" else (0.75 if w.kind=="heavy" else 1.0))
	var nearest: Dictionary = {}
	var nearest_d = 100.0
	for r in rivals:
		var dx = r.lane-lane
		var dz = absf(r.distance-distance)
		if Weapons.reaches(w.id,dx,dz,r.ride.y-ride.y,side) and r.hp>0 and r.hit_cd<=0 and r.node.recovery_time<=0:
			if dz+absf(dx)<nearest_d:
				nearest = r
				nearest_d = dz+absf(dx)
	if nearest.is_empty(): return
	var r = nearest
	r.hp -= w.damage
	r.windup = 0
	r.cooldown = 2.4
	r.stun = w.stagger*(0.65 if active_level==5 else 1.0)
	r.lane = clampf(r.lane+side*w.shove,-8.4,8.4)
	r.node.react_to_hit(side)
	hits += 1
	combo += 1
	combo_time = 5.0
	score += 90*mini(combo,5)
	nitro = minf(100,nitro+12)
	hitstop = 0.055
	shake = 0.36
	flash = 1
	var heavy = r.hp<=0
	sound.rider_hit(r.id,absf(r.distance-distance),heavy)
	fx.burst(r.node.position+Vector3(0,1.6,0),w.color,heavy)
	if heavy:
		takedowns += 1
		score += 350*mini(combo,5)
		_crash_rival(r,side)
		sound.sfx("crash",-2)
		shake = 0.65
		hitstop = 0.10
		var loot=claim_weapon(r)
		if not loot.is_empty():
			announce("击倒 %s · 夺得%s"%[r.name,Weapons.data(loot).name],"已自动装备 · %s 切换拳脚 / 已夺武器"%controls.label("cycle_weapon"),Weapons.data(loot).color,2.4)
		else: announce("击倒  /  "+r.name,"+%d 分  ·  %d 连击" % [350*mini(combo,5),combo],Color("ffc271"),1.6)
	else:
		sound.sfx("hit",-1,rng.randf_range(0.9,1.08))
		announce(w.name+"命中","再来一击，放倒对手  /  氮气 +12",Color("d7f9f5"),0.9)
	if Input.get_connected_joypads().size()>0:
		Input.start_joy_vibration(Input.get_connected_joypads()[0],0.5,0.8,0.16)

func _nearest_side() -> int:
	var closest = 1000.0
	var side = 1
	for r in rivals:
		var delta = absf(r.distance-distance)+absf(r.lane-lane)
		if delta<closest and r.hp>0:
			closest = delta
			side = -1 if r.lane<lane else 1
	return side

func take_damage(amount: float, cause: String) -> void:
	if damage_cooldown>0 or state!="race" or player.recovery_time>0: return
	_cancel_stunt()
	last_damage_cause = cause
	health = maxf(0,health-amount*Data.difficulty(active_level).damage*active_bike.armor)
	damage_cooldown = 1.1
	damage_flash = 0.9
	shake = 0.55
	hitstop = 0.045
	combo = 0
	impact_meter += amount
	fx.burst(player.position+Vector3(0,0.8,0),Color("ff9a56"),true)
	sound.sfx("crash",-5,1.15)
	sound.rider_hit(-1,0,amount>=20)
	if health>0 and (amount>=20 or impact_meter>=32):
		trigger_crash()
	else:
		announce(cause,"留意预警；拉开距离或先手攻击",Color("ff997d"),1.4)

func trigger_crash() -> void:
	if player.recovery_time>0: return
	_cancel_stunt()
	rebound_timer=0
	crashes += 1
	impact_meter = 0
	boost_active = false
	boost_lock = true
	speed *= 0.48
	player.begin_crash(-1 if lane>0 else 1)
	announce("撞飞！","自动起身、找车并重新上车；比赛继续",Color("ffc088"),3.6)

func _update_entities() -> void:
	player.position = Vector3(lane,ride.height,0)
	player.rotation.x=ride.pitch
	if player.recovery_time<=0: player.chassis.position.y=sin(total_time*35)*0.009*minf(speed/40,1)-ride.compression
	for r in rivals:
		r.node.position = world.relative_position(r.lane,r.distance,distance)
		r.node.position.y+=r.ride.height
		r.node.rotation.x=r.ride.pitch
		r.node.rotation.y = world.relative_yaw(r.distance,distance)
		r.node.visible = absf(r.distance-distance)<600
	for car in traffic:
		car.node.position = world.relative_position(car.lane,car.distance,distance)
		car.node.rotation.y = world.relative_yaw(car.distance,distance)+(PI if car.get("oncoming",false) else 0)
		car.node.rotation.x=atan(world.slope_at(car.distance))*(-1 if car.get("oncoming",false) else 1)
	for p in pickups:
		p.node.position = world.relative_position(p.lane,p.distance,distance)+Vector3(0,1.15+sin(total_time*3)*0.13,0)
		# Always show the readable front instead of spinning into a thin edge.
		var to_camera=camera.position-p.node.position
		p.node.rotation.y=atan2(to_camera.x,to_camera.z)
		p.node.get_node("Legend").visible=absf(p.distance-distance)<135

func _update_camera(dt: float) -> void:
	var menu_view = menu_backdrop()
	var target_pos: Vector3
	var look: Vector3
	if menu_view:
		target_pos = Vector3(5.8+sin(total_time*0.13)*0.8,2.9,6.5)
		look = Vector3(-2.2,1.25,-0.5)
		camera.fov = lerpf(camera.fov,49,clampf(dt*4,0,1))
	else:
		target_pos = Vector3(lane*(0.72 if race_rules.air_walls else 1.0),3.5 if not boost_active else 3.1,7.0 if not boost_active else 7.5)
		target_pos.y+=ride.height
		target_pos.y=maxf(target_pos.y,world.height_at(distance-8)-world.height_at(distance)+2.8)
		var road_ahead=world.height_at(distance+16)-world.height_at(distance)
		var ground_look=1.35+ride.height*0.75+road_ahead
		var flight_look=1.35+ride.height-minf(ride.height*0.08,5.0)+clampf(road_ahead,-6,6)
		# Blend the reference targets, not the camera's world-space height.
		# A hard switch at 15 m caused 4–6 degree cuts on ascent AND descent.
		var flight_mix=smoothstep(5.0,35.0,ride.height)
		look = Vector3(lane*(0.7 if race_rules.air_walls else 1.0)+steer*1.2+world.relative_position(0,distance+16,distance).x,lerpf(ground_look,flight_look,flight_mix),-16)
		var high_clearance=maxf(0,ride.height-15)
		target_pos.y+=minf(high_clearance*0.04,2.5)
		target_pos.z+=minf(high_clearance*0.045,4.0)
		var fov_target = 69+speed/74*9+(7 if boost_active else 0)
		camera.fov = lerpf(camera.fov,fov_target,clampf(dt*4,0,1))
	if player.recovery_time>0 and not menu_view:
		target_pos = Vector3(lane+1.8,maxf(4.0+ride.height,world.height_at(distance-9)-world.height_at(distance)+2.8),8.8)
		look = Vector3(lane,1.0+ride.height,-2.0)
		camera.fov = lerpf(camera.fov,65,clampf(dt*4,0,1))
	# Track the rider's vertical reference immediately; smooth only camera offset.
	# Otherwise rapid 60m+ climbs leave the camera below the bike for several frames.
	if not menu_view: camera.position.y+=ride.height-camera_height_anchor
	camera_height_anchor=0.0 if menu_view else ride.height
	camera.position = camera.position.lerp(target_pos,1-exp(-dt*7))
	if settings.shake and shake>0:
		camera.position += Vector3(sin(total_time*95),cos(total_time*83),0)*shake*0.19
	camera.look_at(look)
	if not menu_view: camera.rotation.z += -steer*0.018

func rank_now() -> int:
	var rank = 1
	for r in rivals:
		if r.finished or r.distance>distance: rank += 1
	return mini(rivals.size()+1,rank)

func finish_race(reason: String) -> void:
	if state not in ["race","falling"]: return
	_cancel_stunt()
	final_rank = rank_now()
	finish_reason = reason
	state = "finished"
	result_time=0
	result_stamp_played=false
	boost_active = false
	if reason == "finished":
		race_income=economy.award(Economy.prize(final_rank,rivals.size()+1,active_level))
		score += (rivals.size()+2-final_rank)*600+int(health)*10
		if best_time<=0 or elapsed<best_time: best_time = elapsed
		var record_key = Data.record_key(world.course.id,active_level,active_distance)
		var previous = float(records.get(record_key,0))
		if previous<=0 or elapsed<previous: records[record_key]=elapsed
		sound.sfx("finish",-1)
	else:
		sound.sfx("busted" if reason=="busted" else "defeat",-5)
		player.down_time = 4
		player.chassis.rotation.z = 1.25
	best_score = maxi(best_score,score)
	_save()
	hud.selected = 0

func announce(title: String, sub: String, color: Color, duration: float) -> void:
	message = title
	message_sub = sub
	message_color = color
	message_time = duration

func back() -> void:
	if not rebinding.is_empty():
		rebinding = ""
	elif state in ["race","countdown","falling"]:
		resume_state = state
		return_state = state
		state = "paused"
	elif state=="paused": state = resume_state
	elif state=="finished": to_menu()
	elif not menu_history.is_empty(): state = menu_history.pop_back()
	else: state = "menu"
	hud.selected = 0

func open_page(page: String) -> void:
	if state in ["race","countdown","falling"]:
		resume_state = state
		menu_history.append("paused")
		return_state = "paused"
	else: menu_history.append(state)
	state = page
	hud.selected = 0

func menu_backdrop() -> bool:
	return state not in ["race","countdown","falling","paused","finished"] and "paused" not in menu_history and "finished" not in menu_history

func to_menu() -> void:
	_clear_race()
	state = "menu"
	menu_history.clear()
	rebinding = ""
	return_state = "menu"
	boost_active = false
	player.reset_pose()
	hud.selected = 0

func ui_action(action: String) -> void:
	sound.sfx("click",-7)
	if action.begins_with("bike:"):
		if state!="garage" or not rivals.is_empty(): return
		garage_message=economy.select(action.get_slice(":",1))
		_apply_bike()
	elif action.begins_with("distance:"):
		if state!="setup": return
		race_options.distance = Data.distance_index(int(action.get_slice(":",1)))
	elif action.begins_with("course:"):
		race_options.course = int(action.get_slice(":",1))
		world.build(race_options.course)
	elif action.begins_with("profile:"):
		selected_profile = clampi(int(action.get_slice(":",1)),0,14)
		open_page("profile")
	elif action.begins_with("bind:"):
		rebinding = action.get_slice(":",1)
		binding_message = "请按新键；ESC 取消。"
	else:
		match action:
			"start": open_page("setup")
			"race_begin", "retry": start_race()
			"resume": state = resume_state
			"menu": to_menu()
			"help", "settings", "roster", "bindings": open_page(action)
			"garage":
				if state=="finished": to_menu()
				if rivals.is_empty(): open_page("garage")
			"back": back()
			"courses_next": course_page=posmod(course_page+1,ceili(Data.COURSES.size()/4.0))
			"courses_prev": course_page=posmod(course_page-1,ceili(Data.COURSES.size()/4.0))
			"bikes_next": bike_page=posmod(bike_page+1,ceili(Economy.BIKES.size()/4.0))
			"bikes_prev": bike_page=posmod(bike_page-1,ceili(Economy.BIKES.size()/4.0))
			"cycle_weapon": cycle_weapon()
			"ai_minus": race_options.ai_count = maxi(1,race_options.ai_count-1)
			"ai_plus": race_options.ai_count = mini(15,race_options.ai_count+1)
			"ai_max": race_options.ai_count = 15
			"level_minus": race_options.difficulty = maxi(1,race_options.difficulty-1)
			"level_plus": race_options.difficulty = mini(5,race_options.difficulty+1)
			"music": settings.music = not settings.music
			"shake": settings.shake = not settings.shake
			"quality": settings.quality = not settings.quality
			"map": settings.map = not settings.map
			"mirror": settings.mirror = not settings.mirror
			"air_walls": settings.air_walls = not settings.air_walls
			"oncoming": settings.oncoming = not settings.oncoming
			"difficulty": race_options.difficulty = posmod(race_options.difficulty,5)+1
			"reset_keys":
				controls.keys = Controls.DEFAULTS.duplicate()
				controls.apply()
				rebinding = ""
				binding_message = "已恢复默认按键"
			"volume": settings.volume = 0.0 if settings.volume>=0.99 else minf(1.0,settings.volume+0.2)
			"quit": request_quit()
	_apply_settings()
	_save()
	if action in ["start","retry","race_begin","resume","menu","back","help","settings","roster","bindings"]: hud.selected=0

func _apply_settings() -> void:
	Engine.max_fps = 120 if settings.quality else 60
	sound.music_enabled = settings.music
	sound.master_volume = settings.volume
	if menu_backdrop(): world.configure_rules(bool(settings.air_walls),bool(settings.oncoming))
	world.environment.glow_enabled = settings.quality
	world.sun.shadow_enabled = settings.quality
	get_viewport().msaa_3d = Viewport.MSAA_2X if settings.quality else Viewport.MSAA_DISABLED

func _load_save() -> void:
	if test_mode: return
	var file = ConfigFile.new()
	if file.load(SAVE_PATH) != OK: return
	best_score = int(file.get_value("records","score",0))
	best_time = float(file.get_value("records","time",0.0))
	_load_settings(file)
	_load_race_config(file)
	var saved_records = file.get_value("records","courses",{})
	if saved_records is Dictionary: records=saved_records
	controls.load_config(file)
	economy.load_config(file)

func _load_settings(file: ConfigFile) -> void:
	for key in settings:
		settings[key] = file.get_value("settings",key,settings[key])
	settings.volume = clampf(float(settings.volume),0,1)
	settings.air_walls=bool(settings.air_walls)
	settings.oncoming=bool(settings.oncoming)

func _load_race_config(file: ConfigFile) -> void:
	race_options.course = clampi(int(file.get_value("race","course",0)),0,Data.COURSES.size()-1)
	race_options.ai_count = clampi(int(file.get_value("race","ai_count",7)),1,15)
	race_options.difficulty = clampi(int(file.get_value("race","difficulty",4 if settings.hard else 3)),1,5)
	race_options.distance = Data.distance_index(file.get_value("race","distance",0))

func _save() -> void:
	if test_mode: return
	var file = ConfigFile.new()
	file.set_value("records","score",best_score)
	file.set_value("records","time",best_time)
	for key in settings: file.set_value("settings",key,settings[key])
	for key in race_options: file.set_value("race",key,race_options[key])
	file.set_value("records","courses",records)
	controls.save_config(file)
	economy.save_config(file)
	file.save(SAVE_PATH)

# Opt-in development harness. Never enabled during ordinary play.
func _parse_test_args() -> void:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--distance="): race_options.distance=maxi(0,Data.DISTANCE_IDS.find(arg.trim_prefix("--distance=")))
		if arg.begins_with("--ai="): race_options.ai_count=clampi(int(arg.trim_prefix("--ai=")),1,15)
		if arg.begins_with("--level="): race_options.difficulty=clampi(int(arg.trim_prefix("--level=")),1,5)
		if arg.begins_with("--course="): race_options.course=clampi(int(arg.trim_prefix("--course=")),0,Data.COURSES.size()-1)
		if arg in ["--test-mode","--autoplay"]: test_mode=true
	for arg in args:
		if arg=="--autoplay":
			auto_drive=true
			start_race()
		if arg.begins_with("--screenshot="):
			screenshot_path=arg.trim_prefix("--screenshot=")
			screenshot_at=6
		if arg.begins_with("--capture-at="): screenshot_at=float(arg.trim_prefix("--capture-at="))
		if arg.begins_with("--quit-after="): quit_after=float(arg.trim_prefix("--quit-after="))

func _test_step(dt: float) -> void:
	test_elapsed += dt
	if auto_drive and state == "race":
		attack(_nearest_side())
	if screenshot_at>0 and test_elapsed>screenshot_at:
		screenshot_at = -1
		_capture.call_deferred()
	if quit_after>0 and test_elapsed>quit_after:
		print("SMOKE_RESULT ",JSON.stringify({"state":state,"distance":distance,"track_length":track_length,"distance_class":Data.DISTANCE_IDS[active_distance],"ai_boosts":rivals.reduce(func(total,r): return total+r.boosts_used,0),"health":health,"hits":hits,"takedowns":takedowns,"traffic":traffic.size(),"fps":Engine.get_frames_per_second(),"score":score,"rank":final_rank,"reason":finish_reason,"prize":race_income.gross,"fine":race_fine.gross,"cash":economy.cash,"bike":active_bike.id,"escapes":police.escapes,"jumps":jumps,"bounces":bounces,"best_jump":best_jump,"weapon":loadout.current,"weapons_claimed":weapons_claimed}))
		request_quit()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var result = get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("SCREENSHOT ",screenshot_path," result=",result)

func _autopilot_steer() -> float:
	var target = sin(elapsed*0.17)*5.5
	for r in rivals:
		if absf(r.distance-distance)<8 and r.hp>0:
			target = r.lane+(-2.0 if r.lane>0 else 2.0)
			break
	for car in traffic:
		if car.distance-distance>0 and car.distance-distance<35 and absf(car.lane-target)<2:
			target = car.lane+(-3.2 if car.lane>0 else 3.2)
	return clampf((target-lane)*0.65,-1,1)

func request_quit() -> void:
	if quitting: return
	quitting = true
	set_process(false)
	sound.shutdown()
	# Allow the audio thread to release the last active playback before shutdown.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _create_mirror() -> void:
	mirror_view = SubViewport.new()
	mirror_view.name = "RearView"
	mirror_view.size = Vector2i(480,144)
	mirror_view.world_3d = get_viewport().world_3d
	mirror_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mirror_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(mirror_view)
	mirror_camera = Camera3D.new()
	# The local bike/rider is on layer 2; airborne poses must not cover the mirror.
	mirror_camera.set_cull_mask_value(2,false)
	mirror_camera.fov = 82
	mirror_camera.far = 220
	mirror_view.add_child(mirror_camera)
	mirror_camera.current = true

func _update_mirror() -> void:
	var active = settings.mirror and state in ["race","countdown","falling"]
	mirror_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		mirror_camera.position = Vector3(lane,2.8+ride.height,1.8)
		mirror_camera.look_at(world.relative_position(lane,distance-55,distance)+Vector3(0,1.2,0))

func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"id":-1,"name":"YOU","color":Color("ff8257"),"distance":distance,"finished":state=="finished" and finish_reason=="finished","finish_time":elapsed,"recovering":player.recovery_time>0})
	for r in rivals:
		rows.append({"id":r.id,"name":r.name,"color":r.color,"distance":r.distance,"finished":r.finished,"finish_time":r.finish_time,"recovering":r.node.recovery_time>0})
	rows.sort_custom(func(a,b):
		if a.finished and b.finished: return a.finish_time<b.finish_time
		if a.finished!=b.finished: return a.finished
		return a.distance>b.distance)
	return rows

func _apply_bike() -> void:
	active_bike=economy.bike().duplicate()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player=Bike.new()
	add_child(player)
	player.build(active_bike.color,true,active_bike.shape)
	player.set_weapon(loadout.current)

func arrest_player() -> void:
	if state!="race" or player.recovery_time<=0 or player.recovery_elapsed<0.85: return
	race_fine=economy.fine(350+active_level*150)
	finish_race("busted")

func cycle_weapon() -> void:
	if state!="race" or player.recovery_time>0 or stunt.active: return
	if player.attack_time>0 or attack_cooldown>0:
		return # Switching cannot cancel a heavy weapon's recovery/cooldown.
	loadout.cycle()
	player.set_weapon(loadout.current)
	weapon_notice=0.8
	sound.sfx("click",-12,1.1)

func claim_weapon(r: Dictionary) -> String:
	if r.hp>0 or r.node.recovery_time<=0: return ""
	var id=loadout.take_from(r.loadout)
	if id.is_empty(): return ""
	weapons_claimed+=1
	player.set_weapon(id)
	r.node.set_weapon(r.loadout.current)
	weapon_notice=2.0
	fx.weapon_claim(r.node.position+Vector3(0,1.6,0),player.position+Vector3(0,1.6,0),Weapons.data(id).color)
	sound.sfx("pickup",-8,0.9)
	return id
