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
var message = ""
var message_sub = ""
var message_time = 0.0
var message_color = Color("acf2ed")
var finish_reason = ""
var final_rank = 6
var best_score = 0
var best_time = 0.0
var settings = {"volume":0.8,"music":true,"shake":true,"quality":true,"hard":false,"map":true,"mirror":true}
var test_mode = false
var auto_drive = false
var test_elapsed = 0.0
var screenshot_at = -1.0
var screenshot_path = ""
var quit_after = -1.0
var quitting = false
var controls = Controls.new()
var race_options = {"course":0,"ai_count":7,"difficulty":3}
var active_level = 3
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
var records: Dictionary = {}


func _ready() -> void:
	get_tree().auto_accept_quit = false
	rng.seed = 92107
	_setup_input()
	_load_save()
	world = World.new()
	add_child(world)
	world.build(race_options.course)
	player = Bike.new()
	add_child(player)
	player.build(Color("f26942"),true)
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
		if state not in ["race","countdown"]:
			if event.is_action_pressed("pause_game") and state=="paused": back()
			elif key in [KEY_ENTER,KEY_SPACE]: hud.activate_selected()
			elif key in [KEY_UP,KEY_W]: hud.move_selection(-1)
			elif key in [KEY_DOWN,KEY_S]: hud.move_selection(1)
			elif key==KEY_R and state=="finished": start_race()
			return
	if (event is InputEventKey and event.echo): return
	if event.is_action_pressed("pause_game"):
		back()
	elif state in ["race","countdown"]:
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
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_A: hud.activate_selected()
		elif event.button_index==JOY_BUTTON_B: back()
		elif event.button_index==JOY_BUTTON_DPAD_UP: hud.move_selection(-1)
		elif event.button_index==JOY_BUTTON_DPAD_DOWN: hud.move_selection(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state in ["race","countdown"] and not test_mode:
		resume_state = state
		state = "paused"
		if hud: hud.selected = 0

func _process(raw_dt: float) -> void:
	var dt = minf(raw_dt,0.05)
	total_time += dt
	if test_mode: _test_step(raw_dt)
	var racing = state == "race"
	sound.update_audio(dt,speed,boost_active,racing)
	if menu_backdrop():
		demo_distance += dt*12
		world.update_track(demo_distance,track_length)
		player.animate(dt,12,0.0,false,total_time)
		player.position = Vector3.ZERO
		player.rotation.y = 0
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
	elif racing:
		var sim_dt = dt
		if hitstop > 0:
			hitstop -= dt
			sim_dt *= 0.12
		_simulate(sim_dt)
	if state in ["race","countdown","finished"]:
		world.update_track(distance,track_length)
		_update_entities()
	if state in ["race","countdown","finished"] or menu_backdrop():
		_update_camera(dt)
		shake = move_toward(shake,0,dt*2.5)
		flash = move_toward(flash,0,dt*8)
		damage_flash = move_toward(damage_flash,0,dt*2.5)
		message_time = maxf(0,message_time-dt)
	post.set_shader_parameter("boost",1.0 if boost_active and racing else 0.0)
	post.set_shader_parameter("hit",flash)
	post.set_shader_parameter("damage",damage_flash)
	_update_mirror()
	hud.queue_redraw()

func start_race() -> void:
	_clear_race()
	menu_history.clear()
	active_level = clampi(race_options.difficulty,1,5)
	track_length = Data.COURSES[race_options.course].length
	if world.course_index!=race_options.course: world.build(race_options.course)
	_apply_settings()
	state = "countdown"
	return_state = "menu"
	distance = 0
	lane = 0
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
	message_time = 0
	finish_reason = ""
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
		bike.build(profile.color)
		var start_lane = [-6.75,-2.25,2.25,6.75][i%4]
		rivals.append({"id":i,"profile":profile,"node":bike,"name":profile.name,"color":profile.color,"distance":9.0+int(i/4)*8.0,"lane":start_lane,"speed":0.0,"cruise":Data.difficulty(active_level).pace,"hp":2,"stun":0.0,"cooldown":2.5+i*0.17,"windup":0.0,"phase":float(i)*1.5,"finished":false,"finish_time":0.0,"nitro":100.0,"burst":0.0,"burst_cd":4.0+i*0.6,"think":0.0,"target_lane":start_lane,"target_id":-2,"hit_cd":0.0,"crashes":0,"attacks":0})
	_spawn_traffic(155,-6.75)
	_spawn_traffic(230,2.25)
	_spawn_pickup(105,2.25,"nitro")
	world.update_track(distance,track_length)
	_update_entities()
	_update_camera(1)

func _clear_race() -> void:
	for list in [rivals,traffic,pickups]:
		for item in list:
			if is_instance_valid(item.node): item.node.queue_free()
		list.clear()
	fx.clear_effects()

func _simulate(dt: float) -> void:
	elapsed += dt
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
		var target = (BOOST_SPEED if boost_active else MAX_SPEED)+catchup_help
		if brake: target = 24
		if absf(lane)>8.8: target = 40
		speed = move_toward(speed,target,dt*(42 if brake else 17+catchup_help))
		steer = lerpf(steer,input_steer,1-exp(-dt*9))
		lane += steer*dt*(10.5 if not boost_active else 11.8)
		lane += sin(distance*0.0039)*speed*dt*0.0025
		if absf(lane)>9.0:
			lane = clampf(lane,-9.1,9.1)
			if speed>35: take_damage(8,"擦碰护栏")
		distance += speed*dt
		player.position = Vector3(lane,0,0)
		player.rotation.y = -steer*0.09
		player.animate(dt,speed,steer,boost_active,total_time)
	for rival in rivals: _simulate_rival(rival,dt)
	_simulate_traffic(dt)
	_simulate_pickups(dt)
	traffic_timer -= dt
	pickup_timer -= dt
	if traffic_timer<=0 and traffic.size()<16:
		traffic_timer = rng.randf_range(2.0,3.1)/(world.course.traffic*(0.84+active_level*0.055))
		_spawn_traffic(distance+rng.randf_range(210,290),[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)])
	if pickup_timer<=0:
		pickup_timer = 3.1
		_spawn_pickup(distance+190,[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)],"repair" if health<65 else "nitro")
	if health<=0: finish_race("wrecked")
	elif distance>=track_length and player.recovery_time<=0: finish_race("finished")

func _simulate_rival(r: Dictionary, dt: float) -> void:
	var d = Data.difficulty(active_level)
	r.cooldown = maxf(0,r.cooldown-dt)
	r.stun = maxf(0,r.stun-dt)
	r.hit_cd = maxf(0,r.hit_cd-dt)
	r.burst_cd = maxf(0,r.burst_cd-dt)
	if r.finished:
		r.distance = minf(track_length+70,r.distance+r.speed*dt)
		return
	if r.node.recovery_time>0:
		r.speed = move_toward(r.speed,0,dt*55)
		r.distance += r.speed*dt
		r.node.animate(dt,r.speed,0,false,total_time)
		if r.node.recovery_time<=0:
			r.hp = 2
			r.stun = 0
			r.hit_cd = 1.5
			r.nitro = minf(100,r.nitro+30)
		return
	r.think -= dt
	var gap = r.distance-distance
	if r.think<=0:
		r.think = d.reaction*0.34
		r.target_lane = _choose_ai_lane(r,d)
		var road_clear = true
		for car in traffic:
			if car.distance-r.distance>0 and car.distance-r.distance<25 and absf(car.lane-r.lane)<2.3: road_clear=false
		if r.burst_cd<=0 and r.nitro>40 and r.stun<=0 and road_clear and (gap< -9 or track_length-r.distance<650) and rng.randf()<d.nitro:
			r.burst = 1.0+d.nitro*1.7
			r.burst_cd = 7.5+(1-r.profile.aggression)*4.0
	var boosting = r.burst>0 and r.nitro>0 and r.stun<=0
	if boosting:
		r.burst -= dt
		r.nitro = maxf(0,r.nitro-dt*26)
	else: r.nitro = minf(100,r.nitro+dt*7.5)
	var target = Director.target_speed(active_level,r.profile,r.distance-race_anchor,track_length-r.distance,boosting)
	if r.stun>0: target = minf(target,45)
	r.speed = move_toward(r.speed,target,dt*(17+r.profile.pace*6))
	r.distance += r.speed*dt
	var old_lane = r.lane
	if r.stun<=0: r.lane = move_toward(r.lane,r.target_lane,dt*d.handling*(0.65+r.profile.handling*0.45))
	var lean = clampf((r.lane-old_lane)/maxf(dt*4,0.001),-1,1)
	r.node.animate(dt,r.speed,lean,boosting,total_time+r.phase)
	for car in traffic:
		if absf(car.distance-r.distance)<3.1 and absf(car.lane-r.lane)<1.42 and r.hit_cd<=0:
			_crash_rival(r,1 if r.lane>car.lane else -1)
			return
	if r.windup>0:
		r.windup -= dt
		if r.windup<=0:
			r.cooldown = d.attack_cd*(1.3-r.profile.aggression*0.5)+rng.randf()
			_resolve_ai_attack(r)
	elif r.cooldown<=0 and r.stun<=0:
		r.target_id = -2
		if absf(gap)<5.4 and absf(r.lane-lane)<3.0 and player.recovery_time<=0:
			r.target_id = -1
		elif r.profile.aggression>0.65:
			for other in rivals:
				if other.id!=r.id and other.hp>0 and other.node.recovery_time<=0 and absf(other.distance-r.distance)<4.2 and absf(other.lane-r.lane)<2.6:
					r.target_id = other.id
					break
		if r.target_id != -2: r.windup = d.reaction
	if absf(r.distance-distance)<1.8 and absf(r.lane-lane)<0.80 and r.stun<=0 and player.recovery_time<=0:
		var bump_side = -1.0 if r.lane>lane else 1.0
		take_damage(6,"车手擦碰")
		lane = clampf(lane+bump_side*dt*3,-8.9,8.9)
		r.lane = clampf(r.lane-bump_side*dt*3,-8.9,8.9)
	if r.distance>=track_length:
		r.finished = true
		r.finish_time = elapsed-maxf(0,r.distance-track_length)/maxf(r.speed,1)

func _choose_ai_lane(r: Dictionary, d: Dictionary) -> float:
	var preferred = sin(elapsed*0.18+r.phase)*6.5
	if absf(r.distance-distance)<15 and player.recovery_time<=0:
		preferred = clampf(lane+(-2.3 if r.id%2==0 else 2.3),-7.9,7.9)
		if active_level>=4 and player.attack_time>0 and r.stun<=0:
			preferred = clampf(r.lane+(-2 if r.lane<lane else 2),-8,8)
	var best = r.lane
	var best_cost = INF
	for candidate in [-7.1,-4.5,-2.3,0.0,2.3,4.5,7.1,preferred]:
		var cost = absf(candidate-preferred)*0.35+absf(candidate-r.lane)*0.18
		for car in traffic:
			var ahead = car.distance-r.distance
			if ahead> -4 and ahead<d.lookahead+maxf(0,r.speed-car.speed)*0.35:
				cost += maxf(0,2.6-absf(candidate-car.lane))*(6.0 if ahead<25 else 3.0)
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
	if r.target_id == -1:
		if absf(r.distance-distance)<5.3 and absf(r.lane-lane)<3.4 and player.recovery_time<=0:
			r.node.swing(-1 if r.lane>lane else 1)
			take_damage(12,"%s 的攻击"%r.name)
			r.attacks += 1
	elif r.target_id>=0 and r.target_id<rivals.size():
		var other = rivals[r.target_id]
		if absf(r.distance-other.distance)<5 and absf(r.lane-other.lane)<3.2 and other.hit_cd<=0 and other.node.recovery_time<=0:
			r.node.swing(-1 if r.lane>other.lane else 1)
			other.hp -= 1
			other.stun = 0.3
			other.hit_cd = 0.7
			other.windup = 0
			r.attacks += 1
			if absf(other.distance-distance)<80: fx.burst(other.node.position+Vector3(0,1.5,0),Color("ffc989"))
			if other.hp<=0: _crash_rival(other,1 if other.lane>r.lane else -1)

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

func _simulate_traffic(dt: float) -> void:
	for i in range(traffic.size()-1,-1,-1):
		var car = traffic[i]
		var old_z = car.distance-distance+speed*dt
		car.distance += car.speed*dt
		var z = car.distance-distance
		var crossing = minf(old_z,z)<3.2 and maxf(old_z,z)>-3.2
		var dx = absf(car.lane-lane)
		if crossing and dx<1.43 and not car.collided and player.recovery_time<=0:
			car.collided = true
			take_damage(23,"撞上车辆")
			speed *= 0.59
			lane += -0.75 if lane<car.lane else 0.75
		if z < -4.0 and not car.passed:
			car.passed = true
			if dx>=1.43 and dx<2.6 and not car.collided and speed>50 and player.recovery_time<=0:
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
		p.node.rotation.y += dt*2
		if z<2.5 and z>-speed*dt-2.5 and absf(p.lane-lane)<1.35 and player.recovery_time<=0:
			if p.kind == "repair":
				health = minf(100,health+25)
				announce("装甲修复", "+25 车体耐久",Color("bff58f"),1.2)
			else:
				nitro = minf(100,nitro+35)
				score += 50
				announce("氮气补给", "+35 氮气  /  +50 分",Color("9cecf4"),1.2)
			sound.sfx("pickup",-6)
			fx.burst(p.node.position,Color("8fe5e9"))
			p.node.queue_free()
			pickups.remove_at(i)
		elif z < -20:
			p.node.queue_free()
			pickups.remove_at(i)

func _spawn_traffic(at: float, x: float) -> void:
	# Keep a safe gap in a lane; never generate an unavoidable four-car wall.
	for car in traffic:
		if absf(car.distance-at)<18: return
	for p in pickups:
		if absf(p.distance-at)<10 and absf(p.lane-x)<2: return
	var colors = [Color("a7b9c2"),Color("255262"),Color("d78b54"),Color("343d55"),Color("a85659")]
	var n = world.car(colors[rng.randi_range(0,colors.size()-1)],rng.randf()<0.25)
	add_child(n)
	traffic.append({"node":n,"distance":at,"lane":x,"speed":rng.randf_range(30,43),"passed":false,"collided":false})

func _spawn_pickup(at: float, x: float, kind: String) -> void:
	for car in traffic:
		if absf(car.distance-at)<15 and absf(car.lane-x)<2: return
	var n = Node3D.new()
	var color = Color("9fe579") if kind == "repair" else Color("62def2")
	var material = Geo.mat(color,0.3,0.25,2.5)
	var torus = TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.56
	torus.rings = 16
	torus.ring_segments = 8
	var mi = MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = material
	mi.rotation.x = PI/2
	n.add_child(mi)
	if kind == "repair":
		Geo.box(n,Vector3(0.52,0.13,0.13),Vector3.ZERO,material)
		Geo.box(n,Vector3(0.13,0.52,0.13),Vector3.ZERO,material)
	else:
		var bolt = Geo.box(n,Vector3(0.15,0.57,0.15),Vector3.ZERO,material)
		bolt.rotation.z = -0.4
	add_child(n)
	pickups.append({"node":n,"distance":at,"lane":x,"kind":kind})

func attack(side: int) -> void:
	if state != "race" or attack_cooldown > 0 or player.recovery_time>0: return
	attack_cooldown = 0.43
	player.swing(side)
	fx.slash(player.position+Vector3(0,1.55,-0.05),side)
	sound.sfx("swing",-6,rng.randf_range(0.94,1.1))
	var nearest: Dictionary = {}
	var nearest_d = 100.0
	for r in rivals:
		var dx = r.lane-lane
		var dz = absf(r.distance-distance)
		if dx*side >= -0.25 and absf(dx)<3.5 and dz<6.4 and r.hp>0:
			if dz+absf(dx)<nearest_d:
				nearest = r
				nearest_d = dz+absf(dx)
	if nearest.is_empty(): return
	var r = nearest
	r.hp -= 1
	r.windup = 0
	r.cooldown = 2.4
	r.stun = 0.22 if active_level==5 else 0.45
	r.lane = clampf(r.lane+side*0.7,-8.4,8.4)
	hits += 1
	combo += 1
	combo_time = 5.0
	score += 90*mini(combo,5)
	nitro = minf(100,nitro+12)
	hitstop = 0.055
	shake = 0.36
	flash = 1
	var heavy = r.hp<=0
	fx.burst(r.node.position+Vector3(0,1.6,0),Color("ffe29c"),heavy)
	if heavy:
		takedowns += 1
		score += 350*mini(combo,5)
		_crash_rival(r,side)
		sound.sfx("crash",-2)
		shake = 0.65
		hitstop = 0.10
		announce("击倒  /  "+r.name,"+%d 分  ·  %d 连击" % [350*mini(combo,5),combo],Color("ffc271"),1.6)
	else:
		sound.sfx("hit",-1,rng.randf_range(0.9,1.08))
		announce("重击命中","再来一击，放倒对手  /  氮气 +12",Color("d7f9f5"),0.9)
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
	health = maxf(0,health-amount*Data.difficulty(active_level).damage)
	damage_cooldown = 1.1
	damage_flash = 0.9
	shake = 0.55
	hitstop = 0.045
	combo = 0
	impact_meter += amount
	fx.burst(player.position+Vector3(0,0.8,0),Color("ff9a56"),true)
	sound.sfx("crash",-5,1.15)
	if health>0 and (amount>=20 or impact_meter>=32):
		trigger_crash()
	else:
		announce(cause,"留意预警；拉开距离或先手攻击",Color("ff997d"),1.4)

func trigger_crash() -> void:
	if player.recovery_time>0: return
	crashes += 1
	impact_meter = 0
	boost_active = false
	boost_lock = true
	speed *= 0.48
	player.begin_crash(-1 if lane>0 else 1)
	announce("撞飞！","自动起身、找车并重新上车；比赛继续",Color("ffc088"),3.6)

func _update_entities() -> void:
	player.position = Vector3(lane,0,0)
	for r in rivals:
		r.node.position = world.relative_position(r.lane,r.distance,distance)
		r.node.rotation.y = world.yaw_at(r.distance)*0.5
		r.node.visible = absf(r.distance-distance)<600
	for car in traffic:
		car.node.position = world.relative_position(car.lane,car.distance,distance)
		car.node.rotation.y = world.yaw_at(car.distance)
	for p in pickups:
		p.node.position = world.relative_position(p.lane,p.distance,distance)+Vector3(0,1.15+sin(total_time*3)*0.13,0)

func _update_camera(dt: float) -> void:
	var menu_view = menu_backdrop()
	var target_pos: Vector3
	var look: Vector3
	if menu_view:
		target_pos = Vector3(5.8+sin(total_time*0.13)*0.8,2.9,6.5)
		look = Vector3(-2.2,1.25,-0.5)
		camera.fov = lerpf(camera.fov,49,clampf(dt*4,0,1))
	else:
		target_pos = Vector3(lane*0.72,3.5 if not boost_active else 3.1,7.0 if not boost_active else 7.5)
		look = Vector3(lane*0.7+steer*1.2,1.35,-16)
		var fov_target = 69+speed/74*9+(7 if boost_active else 0)
		camera.fov = lerpf(camera.fov,fov_target,clampf(dt*4,0,1))
	if player.recovery_time>0 and not menu_view:
		target_pos = Vector3(lane+1.8,4.0,8.8)
		look = Vector3(lane,1.0,-2.0)
		camera.fov = lerpf(camera.fov,65,clampf(dt*4,0,1))
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
	if state != "race": return
	final_rank = rank_now()
	finish_reason = reason
	state = "finished"
	boost_active = false
	if reason == "finished":
		score += (rivals.size()+2-final_rank)*600+int(health)*10
		if best_time<=0 or elapsed<best_time: best_time = elapsed
		var record_key = "%s_%d"%[world.course.id,active_level]
		var previous = float(records.get(record_key,0))
		if previous<=0 or elapsed<previous: records[record_key]=elapsed
		sound.sfx("finish",-1)
	else:
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
	elif state in ["race","countdown"]:
		resume_state = state
		return_state = state
		state = "paused"
	elif state=="paused": state = resume_state
	elif state=="finished": to_menu()
	elif not menu_history.is_empty(): state = menu_history.pop_back()
	else: state = "menu"
	hud.selected = 0

func open_page(page: String) -> void:
	if state in ["race","countdown"]:
		resume_state = state
		menu_history.append("paused")
		return_state = "paused"
	else: menu_history.append(state)
	state = page
	hud.selected = 0

func menu_backdrop() -> bool:
	return state not in ["race","countdown","paused","finished"] and "paused" not in menu_history and "finished" not in menu_history

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
	if action.begins_with("course:"):
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
			"back": back()
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
	world.environment.glow_enabled = settings.quality
	world.sun.shadow_enabled = settings.quality
	get_viewport().msaa_3d = Viewport.MSAA_2X if settings.quality else Viewport.MSAA_DISABLED

func _load_save() -> void:
	var file = ConfigFile.new()
	if file.load(SAVE_PATH) != OK: return
	best_score = int(file.get_value("records","score",0))
	best_time = float(file.get_value("records","time",0.0))
	for key in settings:
		settings[key] = file.get_value("settings",key,settings[key])
	settings.volume = clampf(float(settings.volume),0,1)
	race_options.course = clampi(int(file.get_value("race","course",0)),0,Data.COURSES.size()-1)
	race_options.ai_count = clampi(int(file.get_value("race","ai_count",7)),1,15)
	race_options.difficulty = clampi(int(file.get_value("race","difficulty",4 if settings.hard else 3)),1,5)
	var saved_records = file.get_value("records","courses",{})
	if saved_records is Dictionary: records=saved_records
	controls.load_config(file)

func _save() -> void:
	if test_mode: return
	var file = ConfigFile.new()
	file.set_value("records","score",best_score)
	file.set_value("records","time",best_time)
	for key in settings: file.set_value("settings",key,settings[key])
	for key in race_options: file.set_value("race",key,race_options[key])
	file.set_value("records","courses",records)
	controls.save_config(file)
	file.save(SAVE_PATH)

# Opt-in development harness. Never enabled during ordinary play.
func _parse_test_args() -> void:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--ai="): race_options.ai_count=clampi(int(arg.trim_prefix("--ai=")),1,15)
		if arg.begins_with("--level="): race_options.difficulty=clampi(int(arg.trim_prefix("--level=")),1,5)
		if arg.begins_with("--course="): race_options.course=clampi(int(arg.trim_prefix("--course=")),0,3)
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
		print("SMOKE_RESULT ",JSON.stringify({"state":state,"distance":distance,"health":health,"hits":hits,"takedowns":takedowns,"traffic":traffic.size(),"fps":Engine.get_frames_per_second(),"score":score}))
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
	mirror_camera.fov = 82
	mirror_camera.far = 220
	mirror_view.add_child(mirror_camera)
	mirror_camera.current = true

func _update_mirror() -> void:
	var active = settings.mirror and state in ["race","countdown"]
	mirror_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		mirror_camera.position = Vector3(lane,2.8,1.8)
		mirror_camera.look_at(Vector3(lane,1.2,55))

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
