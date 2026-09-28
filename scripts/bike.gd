extends Node3D
const Weapons = preload("res://scripts/weapons.gd")
const WeaponVisual = preload("res://scripts/weapon_visual.gd")
const Geo = preload("res://scripts/geo.gd")
var chassis: Node3D
var rider: Node3D
var arm_l: Node3D
var arm_r: Node3D
var weapon_visual: Node3D
var equipped_weapon = "fists"
var attack_duration = 0.32
var recoil_time = 0.0
var recoil_side = 1.0
var wheels: Array[Node3D] = []
var flames: Array[Node3D] = []
var paint = Color("ee6544")
var attack_side = 0
var attack_time = 0.0
var down_time = 0.0
var is_player = false
var glow: OmniLight3D
var legs: Array[Node3D] = []
var recovery_time = 0.0
var recovery_elapsed = 0.0
var recovery_duration = 3.85
var crash_side = 1.0
var recovery_stage = ""
var model_shape = 0

func build(color: Color, player: bool = false, shape: int = 0) -> void:
	model_shape=shape
	paint = color
	is_player = player
	chassis = Node3D.new()
	add_child(chassis)
	var shell = Geo.mat(color, 0.65, 0.25)
	var dark = Geo.mat(Color("101826"), 0.25, 0.6)
	var rubber = Geo.mat(Color("080d13"), 0.0, 0.96)
	var steel = Geo.mat(Color("718599"), 0.85, 0.25)
	var trim = Geo.mat(Color("c8e6e9"), 0.45, 0.3)
	var light = Geo.mat(Color("8de8ff"), 0.1, 0.2, 4.0)
	for z in [-0.91, 0.9]:
		var wheel = Node3D.new()
		chassis.add_child(wheel)
		wheel.position = Vector3(0, 0.49, z)
		var tire = Geo.cylinder(wheel, 0.47, 0.28, Vector3.ZERO, rubber)
		tire.rotation.z = PI/2
		for x in [-0.151, 0.151]:
			var rim = Geo.cylinder(wheel, 0.29, 0.03, Vector3(x,0,0), steel)
			rim.rotation.z = PI/2
			var hub = Geo.cylinder(wheel, 0.13, 0.045, Vector3(x*1.1,0,0), shell)
			hub.rotation.z = PI/2
			for angle in [0.0, PI/3, PI*2/3]:
				var spoke = Geo.box(wheel, Vector3(0.04,0.54,0.045),Vector3(x,0,0),dark)
				spoke.rotation.x = angle
		wheels.append(wheel)
	Geo.box(chassis,Vector3(0.54,0.43,1.13),Vector3(0,0.79,0.0),dark)
	Geo.wedge(chassis,Vector3(0.85,0.72,1.6),Vector3(0,1.06,-0.25),shell)
	Geo.sphere(chassis,0.46,Vector3(0,1.34,-0.23),shell,Vector3(0.84,0.55,1.3))
	Geo.box(chassis,Vector3(0.43,0.14,0.79),Vector3(0,1.25,0.47),dark)
	var tail = Geo.wedge(chassis,Vector3(0.54,0.25,0.67),Vector3(0,1.34,0.92),shell)
	tail.rotation.x = -0.14
	Geo.box(chassis,Vector3(0.36,0.09,0.08),Vector3(0,1.36,1.25),Geo.mat(Color("ff2545"),0,0.4,5))
	for x in [-0.28,0.28]:
		Geo.link(chassis,Vector3(x,0.5,-0.9),Vector3(x,1.38,-0.61),0.08,steel)
		Geo.link(chassis,Vector3(x,0.51,0.91),Vector3(x,0.89,0.1),0.10,steel)
		Geo.box(chassis,Vector3(0.04,0.12,0.52),Vector3(x*1.48,1.13,-0.23),light)
		var exhaust = Geo.cylinder(chassis,0.11,0.79,Vector3(x*1.65,0.64,0.58),steel)
		exhaust.rotation.x = PI/2
		var flame = Geo.sphere(chassis,0.10,Vector3(x*1.65,0.64,1.22),light,Vector3(1,1,3.8))
		flame.visible = false
		flames.append(flame)
	Geo.box(chassis,Vector3(1.12,0.07,0.10),Vector3(0,1.48,-0.60),dark)
	Geo.wedge(chassis,Vector3(0.55,0.40,0.3),Vector3(0,1.56,-0.76),Geo.mat(Color("254455"),0.7,0.15))
	Geo.box(chassis,Vector3(0.47,0.12,0.05),Vector3(0,1.32,-1.06),light)
	if shape==1:
		Geo.box(chassis,Vector3(0.07,0.08,1.65),Vector3(0,1.5,0.1),light)
		for side in [-1,1]: Geo.link(chassis,Vector3(side*0.5,0.65,0.7),Vector3(side*0.43,1.2,-0.6),0.06,shell)
	elif shape==2:
		for side in [-1,1]:
			Geo.box(chassis,Vector3(0.25,0.6,1.0),Vector3(side*0.52,0.99,0.1),shell)
			Geo.link(chassis,Vector3(side*0.7,0.62,-0.6),Vector3(side*0.7,1.08,-0.6),0.12,steel)
	elif shape==3:
		Geo.wedge(chassis,Vector3(0.95,0.9,1.7),Vector3(0,1.14,-0.38),shell)
		for side in [-1,1]: Geo.box(chassis,Vector3(0.055,0.35,0.08),Vector3(side*0.35,1.52,0.98),dark)
		Geo.box(chassis,Vector3(1.45,0.09,0.36),Vector3(0,1.71,0.98),shell)
	elif shape==4:
		Geo.wedge(chassis,Vector3(0.6,0.12,0.95),Vector3(0,1.17,-0.85),shell)
		Geo.box(chassis,Vector3(0.56,0.68,0.08),Vector3(0,1.8,-0.73),Geo.mat(Color("537d84"),0.5,0.3))
		for side in [-1,1]: Geo.link(chassis,Vector3(side*0.3,0.48,-0.9),Vector3(side*0.3,1.57,-0.6),0.12,steel)
	elif shape==5:
		Geo.box(chassis,Vector3(0.7,0.67,1.2),Vector3(0,0.95,0.05),shell)
		for side in [-1,1]:
			for z in [-0.3,0.0,0.3]: Geo.box(chassis,Vector3(0.02,0.4,0.08),Vector3(side*0.36,0.99,z),light)
	elif shape==6:
		for side in [-1,1]:
			Geo.box(chassis,Vector3(0.46,0.6,0.8),Vector3(side*0.55,1.05,0.65),shell)
			Geo.box(chassis,Vector3(0.48,0.06,0.82),Vector3(side*0.55,1.36,0.65),steel)
		Geo.box(chassis,Vector3(0.75,0.78,0.08),Vector3(0,1.83,-0.8),Geo.mat(Color("456573"),0.6,0.25))
	elif shape==7:
		Geo.wedge(chassis,Vector3(0.96,0.8,2.1),Vector3(0,1.12,-0.48),shell)
		for side in [-1,1]:
			Geo.wedge(chassis,Vector3(0.62,0.08,0.53),Vector3(side*0.6,1.2,-0.65),dark)
			Geo.box(chassis,Vector3(0.035,0.06,1.7),Vector3(side*0.44,1.15,-0.25),light)
		Geo.box(chassis,Vector3(1.35,0.08,0.32),Vector3(0,1.7,0.95),shell)
	elif shape>=8:
		var detail=Node3D.new()
		detail.name="SuspensionKit%d"%shape
		chassis.add_child(detail)
		for side in [-1,1]:
			var x=side*0.40
			Geo.link(detail,Vector3(x,0.5,0.75),Vector3(x,1.3,0.35),0.09,steel)
			for coil in 7:
				var t=coil/7.0
				var ring=Geo.cylinder(detail,0.14,0.045,Vector3(x,0.55+t*0.65,0.73-t*0.32),shell)
				ring.rotation.x=-0.43
		if shape==8:
			Geo.wedge(detail,Vector3(0.58,0.2,1.7),Vector3(0,1.45,-0.05),shell)
			Geo.box(detail,Vector3(0.14,0.55,0.08),Vector3(0,1.75,-0.70),light)
		elif shape==9:
			for side in [-1,1]:
				Geo.box(detail,Vector3(0.30,0.75,1.4),Vector3(side*0.53,0.95,0.10),shell)
				Geo.link(detail,Vector3(side*0.75,0.6,-0.75),Vector3(side*0.75,1.4,-0.3),0.13,steel)
		elif shape==10:
			for side in [-1,1]:
				Geo.wedge(detail,Vector3(0.95,0.10,0.7),Vector3(side*0.77,1.22,-0.55),shell)
				Geo.box(detail,Vector3(0.08,0.36,0.62),Vector3(side*0.43,1.60,0.92),light)
		else:
			Geo.box(detail,Vector3(0.64,0.70,0.07),Vector3(0,1.83,-0.80),Geo.mat(Color("72949d"),0.45,0.25))
			for side in [-1,1]:
				Geo.link(detail,Vector3(side*0.58,0.68,-0.8),Vector3(side*0.58,1.3,0.7),0.08,steel)
				Geo.box(detail,Vector3(0.32,0.35,0.6),Vector3(side*0.5,1.1,0.78),dark)
	# Rider: articulated jacket, boots, helmet, and swinging baton.
	rider = Node3D.new()
	chassis.add_child(rider)
	var jacket = Geo.mat(Color("253349"),0.05,0.65)
	var armor = Geo.mat(Color("455768"),0.3,0.55)
	var torso = Geo.box(rider,Vector3(0.66,0.62,0.42),Vector3(0,1.78,0.24),jacket)
	torso.rotation.x = -0.30
	Geo.box(rider,Vector3(0.46,0.35,0.075),Vector3(0,1.82,0.49),shell)
	Geo.box(rider,Vector3(0.09,0.30,0.09),Vector3(0,1.82,0.53),trim)
	for s in [-1.0,1.0]:
		var leg = Node3D.new()
		rider.add_child(leg)
		leg.position = Vector3(s*0.25,1.4,0.43)
		Geo.link(leg,Vector3.ZERO,Vector3(s*0.26,-0.40,-0.45),0.24,jacket)
		Geo.link(leg,Vector3(s*0.26,-0.40,-0.45),Vector3(s*0.21,-0.75,0),0.19,dark)
		Geo.box(leg,Vector3(0.23,0.18,0.4),Vector3(s*0.20,-0.76,-0.14),dark)
		legs.append(leg)
		Geo.sphere(rider,0.20,Vector3(s*0.34,1.98,0.15),armor)
	Geo.sphere(rider,0.29,Vector3(0,2.21,-0.01),shell,Vector3(0.95,1.08,1.10))
	Geo.sphere(rider,0.26,Vector3(0,2.23,-0.15),Geo.mat(Color("132638"),0.75,0.12),Vector3(0.97,0.57,0.76))
	Geo.box(rider,Vector3(0.06,0.24,0.07),Vector3(0,2.26,0.28),trim)
	arm_l = _arm(rider,-1,jacket,dark)
	arm_r = _arm(rider,1,jacket,dark)
	set_weapon("fists")
	glow = OmniLight3D.new()
	glow.light_color = Color("56cfff")
	glow.light_energy = 0
	glow.omni_range = 4.5
	glow.position = Vector3(0,0.6,0.9)
	chassis.add_child(glow)
	for part in rider.get_children(): part.position -= Vector3(0,1.4,0.2)
	rider.position = Vector3(0,1.4,0.2)

func _arm(parent: Node3D, side: int, jacket: Material, glove: Material) -> Node3D:
	var arm = Node3D.new()
	parent.add_child(arm)
	arm.position = Vector3(side*0.35,1.95,0.1)
	Geo.link(arm,Vector3.ZERO,Vector3(side*0.16,-0.27,-0.23),0.19,jacket)
	Geo.link(arm,Vector3(side*0.16,-0.27,-0.23),Vector3(side*0.16,-0.44,-0.65),0.16,jacket)
	Geo.sphere(arm,0.12,Vector3(side*0.16,-0.44,-0.65),glove)
	return arm

func animate(dt: float, speed: float, steer: float, boost: bool, time: float) -> void:
	if recovery_time>0:
		_animate_recovery(dt)
		return
	attack_time = maxf(0,attack_time-dt)
	for wheel in wheels:
		wheel.rotation.x -= speed*dt/0.47
	var target_lean = -steer*0.32
	if down_time > 0:
		down_time = maxf(0,down_time-dt)
		target_lean = 1.35
	chassis.rotation.z = lerpf(chassis.rotation.z,target_lean,1-exp(-dt*11))
	chassis.position.y = sin(time*35)*0.009*minf(speed/40,1)
	rider.rotation.x = lerpf(rider.rotation.x,0.07 if boost else 0.0,dt*8)
	arm_l.rotation = Vector3.ZERO
	arm_r.rotation = Vector3.ZERO
	for leg in legs: leg.rotation=Vector3.ZERO
	recoil_time=maxf(0,recoil_time-dt)
	rider.rotation.z=recoil_side*sin(recoil_time/0.28*PI)*0.25
	var swing=0.0
	if attack_time > 0:
		var phase = clampf(1-attack_time/attack_duration,0,1)
		swing = sin(phase*PI)
		var arm = arm_l if attack_side < 0 else arm_r
		if equipped_weapon=="kick":
			var leg=legs[0 if attack_side<0 else 1]
			leg.rotation.z=attack_side*1.25*swing
			leg.rotation.x=-0.38*swing
			rider.rotation.z=-attack_side*0.15*swing
		else:
			arm.rotation.z = attack_side*1.1*swing
			arm.rotation.y = -attack_side*0.75*swing
	if weapon_visual:
		var side=attack_side if attack_time>0 else 1
		var hand=arm_l if side<0 else arm_r
		if weapon_visual.get_parent()!=hand: weapon_visual.reparent(hand,false)
		weapon_visual.position=Vector3(side*0.16,-0.44,-0.65)
		weapon_visual.rotation=Vector3(0.45*(1-swing),0,-side*(0.25+2.0*swing))
		weapon_visual.pose(time,swing)
	for flame in flames:
		flame.visible = boost
		flame.scale.z = 3.5+sin(time*65)*1.5
	glow.light_energy = 1.2 if boost else 0.0

func swing(side: int) -> void:
	attack_side = side
	attack_duration=Weapons.data(equipped_weapon).duration
	attack_time = attack_duration

func begin_crash(side: float = 1.0) -> void:
	if recovery_time>0: return
	crash_side = side
	recovery_elapsed = 0
	recovery_time = recovery_duration
	attack_time = 0
	rider.reparent(self,true)
	if weapon_visual: weapon_visual.visible = false
	for flame in flames: flame.visible = false
	glow.light_energy = 0

func reset_pose() -> void:
	recovery_time = 0
	recovery_elapsed = 0
	recovery_stage = ""
	down_time = 0
	attack_time = 0
	recoil_time=0
	if rider.get_parent()!=chassis: rider.reparent(chassis,false)
	rider.position = Vector3(0,1.4,0.2)
	rider.rotation = Vector3.ZERO
	chassis.position = Vector3.ZERO
	chassis.rotation = Vector3.ZERO
	for leg in legs: leg.rotation = Vector3.ZERO
	arm_l.rotation = Vector3.ZERO
	arm_r.rotation = Vector3.ZERO
	if weapon_visual: weapon_visual.visible = Weapons.armed(equipped_weapon)
	for flame in flames: flame.visible = false

func _animate_recovery(dt: float) -> void:
	recovery_elapsed += dt
	recovery_time = maxf(0,recovery_duration-recovery_elapsed)
	var t = recovery_elapsed
	chassis.rotation.z = crash_side*1.35*clampf(t/0.4,0,1)
	chassis.position.y = -0.10
	for leg in legs: leg.rotation = Vector3.ZERO
	if t<0.85:
		recovery_stage = "撞飞"
		var p = t/0.85
		rider.position = Vector3(crash_side*1.7*p,lerpf(1.4,0.6,p)+sin(p*PI)*2.5,-3.5*p)
		rider.rotation = Vector3(-1.5*PI*p,0,crash_side*sin(p*PI)*0.65)
		arm_l.rotation.z = -1.2
		arm_r.rotation.z = 1.2
	elif t<1.60:
		recovery_stage = "翻滚落地"
		var p = (t-0.85)/0.75
		rider.position = Vector3(lerpf(1.7,2.3,p)*crash_side,0.55+sin(p*PI)*0.2,lerpf(-3.5,-4.5,p))
		rider.rotation = Vector3(PI/2+sin(p*PI)*PI,0,0)
	elif t<2.15:
		recovery_stage = "起身"
		var p = smoothstep(0,1,(t-1.60)/0.55)
		rider.position = Vector3(crash_side*2.3,lerpf(0.55,0.95,p),-4.5)
		rider.rotation = Vector3(lerpf(PI/2,0,p),0,0)
		arm_l.rotation.z = -0.5*(1-p)
		arm_r.rotation.z = 0.5*(1-p)
	elif t<3.2:
		recovery_stage = "跑回摩托"
		var p = (t-2.15)/1.05
		rider.position = Vector3(crash_side*lerpf(2.3,0.9,p),0.95+absf(sin(p*PI*5))*0.07,lerpf(-4.5,0.25,p))
		rider.rotation = Vector3(0.12,PI+crash_side*0.28,0)
		for i in legs.size(): legs[i].rotation.x = sin(p*PI*10+i*PI)*0.62
		arm_l.rotation.x = sin(p*PI*10)*0.65
		arm_r.rotation.x = -sin(p*PI*10)*0.65
	else:
		recovery_stage = "扶车上车"
		var p = smoothstep(0,1,(t-3.2)/0.65)
		chassis.rotation.z = crash_side*1.35*(1-p)
		chassis.position.y = -0.10*(1-p)
		rider.position = Vector3(crash_side*0.9*(1-p),lerpf(0.95,1.4,p),lerpf(0.25,0.2,p))
		rider.rotation = Vector3(0,PI*(1-p),0)
		arm_l.rotation = Vector3.ZERO
		arm_r.rotation = Vector3.ZERO
	if recovery_time<=0: reset_pose()

func set_weapon(id: String) -> void:
	equipped_weapon=Weapons.data(id).id
	if is_instance_valid(weapon_visual):
		weapon_visual.get_parent().remove_child(weapon_visual)
		weapon_visual.queue_free()
	weapon_visual=WeaponVisual.new()
	arm_r.add_child(weapon_visual)
	weapon_visual.build(equipped_weapon)
	weapon_visual.position=Vector3(0.16,-0.44,-0.65)
	weapon_visual.rotation=Vector3(0.45,0,-0.25)
	if recovery_time>0: weapon_visual.visible=false

func react_to_hit(side: float) -> void:
	recoil_time=0.28
	recoil_side=side
