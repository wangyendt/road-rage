extends Node3D
## Main game coordinator. Simulation uses track-distance coordinates (metres).
const World = preload("res://scripts/world.gd")
const Bike = preload("res://scripts/bike.gd")
const Geo = preload("res://scripts/geo.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/audio.gd")
const FX = preload("res://scripts/fx.gd")
const TRACK_LENGTH = 5400.0
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
var settings = {"volume":0.8,"music":true,"shake":true,"quality":true,"hard":false}
var test_mode = false
var auto_drive = false
var test_elapsed = 0.0
var screenshot_at = -1.0
var screenshot_path = ""
var quit_after = -1.0
var quitting = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	rng.seed = 92107
	_setup_input()
	_load_save()
	world = World.new()
	add_child(world)
	world.build()
	player = Bike.new()
	add_child(player)
	player.build(Color("f26942"),true)
	camera = Camera3D.new()
	camera.fov = 72
	camera.far = 1400
	camera.near = 0.08
	add_child(camera)
	camera.current = true
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
	var bindings = {"steer_left":[KEY_A,KEY_LEFT],"steer_right":[KEY_D,KEY_RIGHT],"brake":[KEY_S,KEY_DOWN],"throttle":[KEY_W,KEY_UP],"boost":[KEY_SPACE]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action,0.15)
		for key in bindings[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action,ev)
	for pair in [["steer_left",JOY_AXIS_LEFT_X,-1.0],["steer_right",JOY_AXIS_LEFT_X,1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0],["boost",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var ev = InputEventJoypadMotion.new()
		ev.axis = pair[1]
		ev.axis_value = pair[2]
		InputMap.action_add_event(pair[0],ev)
	var joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event("boost",joy)

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
		var key = event.physical_keycode
		if key == KEY_F11:
			var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif key == KEY_M:
			sound.muted = not sound.muted
		elif key == KEY_ESCAPE or key == KEY_P:
			back()
		elif state == "race":
			if key == KEY_J: attack(-1)
			elif key == KEY_K: attack(1)
			elif key == KEY_SHIFT: attack(_nearest_side())
		elif key == KEY_ENTER or key == KEY_SPACE:
			hud.activate_selected()
		elif key == KEY_UP or key == KEY_W:
			hud.move_selection(-1)
		elif key == KEY_DOWN or key == KEY_S:
			hud.move_selection(1)
		elif key == KEY_R and state == "finished":
			start_race()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START: back()
		elif state == "race":
			if event.button_index == JOY_BUTTON_LEFT_SHOULDER: attack(-1)
			if event.button_index == JOY_BUTTON_RIGHT_SHOULDER: attack(1)
		elif event.button_index == JOY_BUTTON_A: hud.activate_selected()
		elif event.button_index == JOY_BUTTON_DPAD_UP: hud.move_selection(-1)
		elif event.button_index == JOY_BUTTON_DPAD_DOWN: hud.move_selection(1)

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
	if state in ["menu","help","settings"] and return_state != "paused":
		demo_distance += dt*12
		world.update_track(demo_distance,TRACK_LENGTH)
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
			announce("全速出击", "自动油门已开启 · J / K 左右攻击",Color("acf2ed"),2.5)
	elif racing:
		var sim_dt = dt
		if hitstop > 0:
			hitstop -= dt
			sim_dt *= 0.12
		_simulate(sim_dt)
	if state in ["race","countdown","finished"]:
		world.update_track(distance,TRACK_LENGTH)
		_update_entities()
	if state not in ["paused","settings","help"]:
		_update_camera(dt)
		shake = move_toward(shake,0,dt*2.5)
		flash = move_toward(flash,0,dt*8)
		damage_flash = move_toward(damage_flash,0,dt*2.5)
		message_time = maxf(0,message_time-dt)
	post.set_shader_parameter("boost",1.0 if boost_active and racing else 0.0)
	post.set_shader_parameter("hit",flash)
	post.set_shader_parameter("damage",damage_flash)
	hud.queue_redraw()

func start_race() -> void:
	_clear_race()
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
	player.chassis.rotation = Vector3.ZERO
	player.down_time = 0
	rng.seed = 92107
	var colors = [Color("eecf62"),Color("70c9d2"),Color("b989ed"),Color("ece7d7"),Color("ed6584")]
	var names_list = ["NOVA","GHOST","VIPER","ECHO","ROOK"]
	for i in 5:
		var bike = Bike.new()
		add_child(bike)
		bike.build(colors[i])
		var start_lane = [-3.0,3.1,-6.0,0.0,6.0][i]
		rivals.append({"node":bike,"name":names_list[i],"color":colors[i],"distance":8.0+i*8,"lane":start_lane,"speed":0.0,"cruise":65.0+i*1.2,"hp":2,"stun":0.0,"cooldown":2.5+i,"windup":0.0,"phase":float(i)*1.5,"finished":false,"finish_time":0.0})
	_spawn_traffic(155,-6.75)
	_spawn_traffic(230,2.25)
	_spawn_pickup(105,2.25,"nitro")
	world.update_track(distance,TRACK_LENGTH)
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
	if combo_time <= 0: combo = 0
	var input_steer = Input.get_axis("steer_left","steer_right")
	var brake = Input.is_action_pressed("brake")
	var wants_boost = Input.is_action_pressed("boost")
	if auto_drive:
		input_steer = _autopilot_steer()
		wants_boost = fmod(elapsed,11.0)>7.0 and nitro>1.0
	if not wants_boost: boost_lock = false
	var was_boost = boost_active
	boost_active = wants_boost and nitro > 0.5 and not brake and not boost_lock
	if boost_active:
		nitro = maxf(0,nitro-dt*28)
		if nitro <= 0.5: boost_lock = true
		if not was_boost: sound.sfx("nitro",-5)
	else:
		nitro = minf(100,nitro+dt*8)
	var target = BOOST_SPEED if boost_active else MAX_SPEED
	if brake: target = 24
	if absf(lane) > 8.8: target = 40
	speed = move_toward(speed,target,dt*(42 if brake else 17))
	steer = lerpf(steer,input_steer,1-exp(-dt*9))
	lane += steer*dt*(10.5 if not boost_active else 11.8)
	# Gentle outward drift through the bends, deliberately forgiving.
	lane += sin(distance*0.0039)*speed*dt*0.0025
	if absf(lane) > 9.0:
		lane = clampf(lane,-9.1,9.1)
		if speed > 35: take_damage(8,"擦碰护栏")
	distance += speed*dt
	player.position = Vector3(lane,0,0)
	player.rotation.y = -steer*0.09
	player.animate(dt,speed,steer,boost_active,total_time)
	for rival in rivals: _simulate_rival(rival,dt)
	_simulate_traffic(dt)
	_simulate_pickups(dt)
	traffic_timer -= dt
	pickup_timer -= dt
	if traffic_timer <= 0 and traffic.size() < 13:
		traffic_timer = rng.randf_range(1.8,2.8) if not settings.hard else rng.randf_range(1.4,2.0)
		_spawn_traffic(distance+rng.randf_range(210,290),[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)])
	if pickup_timer <= 0:
		pickup_timer = 3.1
		_spawn_pickup(distance+190,[-6.75,-2.25,2.25,6.75][rng.randi_range(0,3)],"repair" if health<65 else "nitro")
	if health <= 0:
		finish_race("wrecked")
	elif distance >= TRACK_LENGTH:
		finish_race("finished")

func _simulate_rival(r: Dictionary, dt: float) -> void:
	r.cooldown = maxf(0,r.cooldown-dt)
	r.stun = maxf(0,r.stun-dt)
	var gap = r.distance-distance
	var target = r.cruise + clampf(-gap*0.07,-10,19) + (3 if settings.hard else 0)
	if absf(gap)<14 and r.stun <= 0:
		target = lerpf(target,speed+sin(total_time+r.phase)*4.0,0.68)
	if r.stun > 0: target = 16 if r.hp <= 0 else 38
	if r.hp <= 0 and r.stun <= 0:
		r.hp = 2
		r.node.down_time = 0
	r.speed = move_toward(r.speed,target,dt*19)
	r.distance += r.speed*dt
	var target_lane = sin(total_time*0.34+r.phase)*6.8
	if absf(gap)<17 and r.stun <= 0:
		var side = -1 if sin(r.phase+total_time*0.2)<0 else 1
		target_lane = clampf(lane+side*2.25,-7.8,7.8)
	# AI avoids traffic rather than driving through it.
	for car in traffic:
		var ahead = car.distance-r.distance
		if ahead>0 and ahead<20 and absf(car.lane-r.lane)<1.9:
			target_lane = clampf(car.lane+(-3 if car.lane>r.lane else 3),-7.8,7.8)
	var old_lane = r.lane
	if r.stun <= 0: r.lane = move_toward(r.lane,target_lane,dt*2.6)
	var lean = clampf((r.lane-old_lane)/maxf(dt*3,0.001),-1,1)
	r.node.animate(dt,r.speed,lean,false,total_time+r.phase)
	if r.windup > 0:
		r.windup -= dt
		if r.windup <= 0:
			r.cooldown = rng.randf_range(3.5,5.5)
			if absf(r.distance-distance)<5.3 and absf(r.lane-lane)<3.4 and r.stun<=0:
				r.node.swing(-1 if r.lane>lane else 1)
				take_damage(12,"对手攻击")
				lane += -0.45 if r.lane>lane else 0.45
	elif absf(gap)<5.5 and absf(r.lane-lane)<3.1 and r.cooldown<=0 and r.stun<=0:
		r.windup = 0.85
	if absf(r.distance-distance)<2.0 and absf(r.lane-lane)<0.85 and r.stun<=0:
		var bump_side = -1.0 if r.lane>lane else 1.0
		take_damage(6,"车手擦碰")
		lane = clampf(lane+bump_side*dt*3.0,-8.9,8.9)
		r.lane = clampf(r.lane-bump_side*dt*3.0,-8.9,8.9)
	if r.distance >= TRACK_LENGTH and not r.finished:
		r.finished = true
		r.finish_time = elapsed

func _simulate_traffic(dt: float) -> void:
	for i in range(traffic.size()-1,-1,-1):
		var car = traffic[i]
		var old_z = car.distance-distance+speed*dt
		car.distance += car.speed*dt
		var z = car.distance-distance
		var crossing = minf(old_z,z)<3.2 and maxf(old_z,z)>-3.2
		var dx = absf(car.lane-lane)
		if crossing and dx<1.43 and not car.collided:
			car.collided = true
			take_damage(23,"撞上车辆")
			speed *= 0.59
			lane += -0.75 if lane<car.lane else 0.75
		if z < -4.0 and not car.passed:
			car.passed = true
			if dx>=1.43 and dx<2.6 and not car.collided and speed>50:
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
		if z<2.5 and z>-speed*dt-2.5 and absf(p.lane-lane)<1.35:
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
	if state != "race" or attack_cooldown > 0: return
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
	r.stun = 0.55
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
		r.stun = 3.0
		r.node.down_time = 3.0
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
	if damage_cooldown > 0 or state != "race": return
	health = maxf(0,health-amount*(1.25 if settings.hard else 1.0))
	damage_cooldown = 1.1
	damage_flash = 0.9
	shake = 0.55
	hitstop = 0.045
	combo = 0
	fx.burst(player.position+Vector3(0,0.8,0),Color("ff9a56"),true)
	sound.sfx("crash",-5,1.15)
	announce(cause,"保持车距，青绿色圆环补充氮气，绿色十字修复装甲",Color("ff997d"),1.5)

func _update_entities() -> void:
	player.position = Vector3(lane,0,0)
	for r in rivals:
		r.node.position = world.relative_position(r.lane,r.distance,distance)
		r.node.rotation.y = World.yaw_at(r.distance)*0.5
		r.node.visible = absf(r.distance-distance)<600
	for car in traffic:
		car.node.position = world.relative_position(car.lane,car.distance,distance)
		car.node.rotation.y = World.yaw_at(car.distance)
	for p in pickups:
		p.node.position = world.relative_position(p.lane,p.distance,distance)+Vector3(0,1.15+sin(total_time*3)*0.13,0)

func _update_camera(dt: float) -> void:
	var menu_view = state in ["menu","help","settings"] and return_state != "paused"
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
	camera.position = camera.position.lerp(target_pos,1-exp(-dt*7))
	if settings.shake and shake>0:
		camera.position += Vector3(sin(total_time*95),cos(total_time*83),0)*shake*0.19
	camera.look_at(look)
	if not menu_view: camera.rotation.z += -steer*0.018

func rank_now() -> int:
	var rank = 1
	for r in rivals:
		if r.finished or r.distance>distance: rank += 1
	return mini(6,rank)

func finish_race(reason: String) -> void:
	if state != "race": return
	final_rank = rank_now()
	finish_reason = reason
	state = "finished"
	boost_active = false
	if reason == "finished":
		score += (7-final_rank)*600+int(health)*10
		if best_time<=0 or elapsed<best_time: best_time = elapsed
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
	if state == "race" or state == "countdown":
		resume_state = state
		return_state = state
		state = "paused"
	elif state == "paused":
		state = resume_state
	elif state in ["settings","help"]:
		state = "paused" if return_state == "paused" else "menu"
	elif state == "finished":
		to_menu()
	hud.selected = 0

func to_menu() -> void:
	_clear_race()
	state = "menu"
	return_state = "menu"
	boost_active = false
	player.down_time = 0
	player.chassis.rotation = Vector3.ZERO
	player.attack_time = 0
	hud.selected = 0

func ui_action(action: String) -> void:
	sound.sfx("click",-7)
	match action:
		"start", "retry": start_race()
		"resume": state = resume_state
		"menu": to_menu()
		"help", "settings":
			return_state = "paused" if state == "paused" else "menu"
			state = action
		"back": back()
		"music": settings.music = not settings.music
		"shake": settings.shake = not settings.shake
		"quality": settings.quality = not settings.quality
		"difficulty": settings.hard = not settings.hard
		"volume": settings.volume = 0.0 if settings.volume>=0.99 else minf(1.0,settings.volume+0.2)
		"quit": request_quit()
	_apply_settings()
	_save()
	if action not in ["music","shake","quality","difficulty","volume"]: hud.selected = 0

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

func _save() -> void:
	if test_mode: return
	var file = ConfigFile.new()
	file.set_value("records","score",best_score)
	file.set_value("records","time",best_time)
	for key in settings: file.set_value("settings",key,settings[key])
	file.save(SAVE_PATH)

# Opt-in development harness. Never enabled during ordinary play.
func _parse_test_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			test_mode = true
			auto_drive = true
			start_race()
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
			screenshot_at = 6.0
		if arg.begins_with("--capture-at="): screenshot_at = float(arg.trim_prefix("--capture-at="))
		if arg.begins_with("--quit-after="): quit_after = float(arg.trim_prefix("--quit-after="))
		if arg == "--test-mode": test_mode = true

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
