extends Node3D
const Geo = preload("res://scripts/geo.gd")
var chassis: Node3D
var rider: Node3D
var arm_l: Node3D
var arm_r: Node3D
var bat: Node3D
var wheels: Array[Node3D] = []
var flames: Array[Node3D] = []
var paint = Color("ee6544")
var attack_side = 0
var attack_time = 0.0
var down_time = 0.0
var is_player = false
var glow: OmniLight3D

func build(color: Color, player: bool = false) -> void:
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
		Geo.link(rider,Vector3(s*0.25,1.4,0.43),Vector3(s*0.51,1.00,-0.02),0.24,jacket)
		Geo.link(rider,Vector3(s*0.51,1.00,-0.02),Vector3(s*0.46,0.65,0.43),0.19,dark)
		Geo.box(rider,Vector3(0.23,0.18,0.4),Vector3(s*0.45,0.64,0.29),dark)
		Geo.sphere(rider,0.20,Vector3(s*0.34,1.98,0.15),armor)
	Geo.sphere(rider,0.29,Vector3(0,2.21,-0.01),shell,Vector3(0.95,1.08,1.10))
	Geo.sphere(rider,0.26,Vector3(0,2.23,-0.15),Geo.mat(Color("132638"),0.75,0.12),Vector3(0.97,0.57,0.76))
	Geo.box(rider,Vector3(0.06,0.24,0.07),Vector3(0,2.26,0.28),trim)
	arm_l = _arm(rider,-1,jacket,dark)
	arm_r = _arm(rider,1,jacket,dark)
	bat = Geo.cylinder(arm_r,0.057,1.18,Vector3(0,-0.66,-0.35),steel)
	bat.rotation.x = -0.35
	bat.visible = false
	glow = OmniLight3D.new()
	glow.light_color = Color("56cfff")
	glow.light_energy = 0
	glow.omni_range = 4.5
	glow.position = Vector3(0,0.6,0.9)
	chassis.add_child(glow)

func _arm(parent: Node3D, side: int, jacket: Material, glove: Material) -> Node3D:
	var arm = Node3D.new()
	parent.add_child(arm)
	arm.position = Vector3(side*0.35,1.95,0.1)
	Geo.link(arm,Vector3.ZERO,Vector3(side*0.16,-0.27,-0.23),0.19,jacket)
	Geo.link(arm,Vector3(side*0.16,-0.27,-0.23),Vector3(side*0.16,-0.44,-0.65),0.16,jacket)
	Geo.sphere(arm,0.12,Vector3(side*0.16,-0.44,-0.65),glove)
	return arm

func animate(dt: float, speed: float, steer: float, boost: bool, time: float) -> void:
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
	if attack_time > 0:
		var phase = 1-attack_time/0.36
		var swing = sin(phase*PI)
		var arm = arm_l if attack_side < 0 else arm_r
		arm.rotation.z = attack_side*1.7*swing
		arm.rotation.y = -attack_side*0.9*swing
		bat.visible = attack_side > 0
	else:
		bat.visible = false
	for flame in flames:
		flame.visible = boost
		flame.scale.z = 3.5+sin(time*65)*1.5
	glow.light_energy = 1.2 if boost else 0.0

func swing(side: int) -> void:
	attack_side = side
	attack_time = 0.36
