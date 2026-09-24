extends Node3D
const Geo = preload("res://scripts/geo.gd")
const CHUNK_LENGTH = 40.0
const CHUNK_COUNT = 27
var chunks: Array[Node3D] = []
var environment: Environment
var sun: DirectionalLight3D
var road_mat: Material
var rng = RandomNumberGenerator.new()
var scenery: Node3D
var finish_gate: Node3D
var current_distance = 0.0

static func center_at(d: float) -> float:
	return sin(d*0.0017)*31.0 + sin(d*0.0039)*12.0

static func yaw_at(d: float) -> float:
	return -atan(cos(d*0.0017)*0.0527+cos(d*0.0039)*0.0468)

func relative_position(lane: float, track_distance: float, player_distance: float) -> Vector3:
	return Vector3(lane+center_at(track_distance)-center_at(player_distance),0,player_distance-track_distance)

func build() -> void:
	rng.seed = 20260924
	_environment()
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/asphalt.gdshader")
	road_mat.set_shader_parameter("grain_texture",load("res://assets/asphalt_noise.tres"))
	for i in CHUNK_COUNT:
		var chunk = _chunk(i)
		add_child(chunk)
		chunks.append(chunk)
	var ocean = Geo.box(self,Vector3(2600,1,2200),Vector3(0,-10,-700),Geo.mat(Color("172b42"),0.5,0.35))
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Distant silhouette creates a deep skyline beyond the highway.
	for i in 12:
		var mountain = Geo.wedge(self,Vector3(rng.randf_range(170,330),rng.randf_range(50,160),170),Vector3(-950+i*175,-9,-950-rng.randf()*100),Geo.mat(Color("263746"),0,1))
		mountain.rotation.y = rng.randf_range(-0.3,0.3)
	finish_gate = _gate("FINISH",Color("b9f3ec"))
	add_child(finish_gate)
	update_track(0,5400)

func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("0b233f")
	sm.sky_horizon_color = Color("bc7d73")
	sm.sky_curve = 0.17
	sm.ground_bottom_color = Color("111d30")
	sm.ground_horizon_color = Color("c58b78")
	sm.sun_angle_max = 4.0
	sky.sky_material = sm
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa9ce")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.07
	environment.fog_enabled = true
	environment.fog_light_color = Color("687984")
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.16
	var we = WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-23,-38,0)
	sun.light_color = Color("ffe2c4")
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	sun.shadow_bias = 0.07
	add_child(sun)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-35,150,0)
	rim.light_color = Color("6fa8ec")
	rim.light_energy = 0.7
	add_child(rim)
	Geo.sphere(self,37,Vector3(-205,99,-820),Geo.mat(Color("ffe0a8"),0,1,1.8))

func _chunk(index: int) -> Node3D:
	var n = Node3D.new()
	n.name = "Highway%02d" % index
	var concrete = Geo.mat(Color("344653"),0.1,0.9)
	var steel = Geo.mat(Color("637985"),0.65,0.4)
	var white = Geo.mat(Color("aac0c7"),0.0,0.9)
	var amber = Geo.mat(Color("ff8852"),0.0,0.5,2.0)
	var cyan = Geo.mat(Color("73cbd7"),0.0,0.5,1.3)
	Geo.box(n,Vector3(19.0,0.5,40.2),Vector3(0,-0.26,0),road_mat)
	for side in [-1,1]:
		Geo.box(n,Vector3(1.0,0.3,40.2),Vector3(side*10,-0.10,0),concrete)
		Geo.box(n,Vector3(0.12,0.015,40.2),Vector3(side*9.1,0.006,0),white)
		Geo.box(n,Vector3(0.22,0.32,40.2),Vector3(side*10.2,0.83,0),steel)
		Geo.box(n,Vector3(0.035,0.07,40.2),Vector3(side*10.05,0.92,0),cyan if side < 0 else amber)
		for zz in [-16,-4,8]:
			Geo.box(n,Vector3(0.22,0.92,0.22),Vector3(side*10.2,0.41,zz),steel)
		# Highway light masts, emissive fixtures avoid dozens of shadow lights.
		Geo.box(n,Vector3(0.16,8.5,0.16),Vector3(side*11,4.15,0),steel)
		Geo.box(n,Vector3(2.8,0.12,0.2),Vector3(side*9.65,8.35,0),steel)
		Geo.box(n,Vector3(1.25,0.08,0.32),Vector3(side*8.6,8.25,0),Geo.mat(Color("ffdda4"),0,0.5,4.0))
	for lane in [-4.5,0.0,4.5]:
		for z in [-15,-5,5,15]:
			Geo.box(n,Vector3(0.13,0.016,4.5),Vector3(lane,0.009,z),white)
	if index % 6 == 0:
		var labels = ["PORT DISTRICT", "EAST EXPRESSWAY", "NIGHT RUN", "KEEP MOVING", "OUTRUN / 07"]
		var gate = _gate(labels[index%labels.size()],Color("75d9dd"))
		gate.name = "SignGate"
		n.add_child(gate)
	# The final sector becomes a cable-stayed bridge, not just another HUD label.
	if index % 3 == 0:
		var bridge = Node3D.new()
		bridge.name = "Bridge"
		n.add_child(bridge)
		var bridge_mat = Geo.mat(Color("455b68"),0.5,0.55)
		for side in [-1,1]:
			Geo.box(bridge,Vector3(1.1,32,1.5),Vector3(side*13.5,15.8,0),bridge_mat)
			Geo.box(bridge,Vector3(0.08,29,0.12),Vector3(side*12.92,16,0.85),amber)
			for z in [-45,-27,27,45]:
				Geo.link(bridge,Vector3(side*13.5,30,0),Vector3(side*11,0.5,z),0.12,steel)
		Geo.box(bridge,Vector3(28,0.7,1.0),Vector3(0,29.7,0),bridge_mat)
		bridge.visible = false
	# A mix of sparse waterfront and dense city blocks.
	for side in [-1,1]:
		for j in 2:
			var height = rng.randf_range(12,65)
			var material = ShaderMaterial.new()
			material.shader = load("res://shaders/building.gdshader")
			material.set_shader_parameter("seed",float(index*4+j+side))
			material.set_shader_parameter("light_color",Color("edb882") if index%3 == 0 else Color("72b4d4"))
			var x = side*(rng.randf_range(38,68)+j*36)
			var b = Geo.box(n,Vector3(rng.randf_range(12,22),height,rng.randf_range(15,28)),Vector3(x,height/2-10,rng.randf_range(-17,17)),material)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if index%3 == 0:
				Geo.box(n,Vector3(13,0.13,0.16),Vector3(x,height-9.5,0),amber if side>0 else cyan)
		# Supporting pillars descend into the waterfront.
		Geo.box(n,Vector3(1.4,11,1.4),Vector3(side*7,-5.8,0),concrete)
	return n

func _gate(text: String, color: Color) -> Node3D:
	var gate = Node3D.new()
	var steel = Geo.mat(Color("344653"),0.6,0.6)
	for side in [-1,1]:
		Geo.box(gate,Vector3(0.4,8.9,0.4),Vector3(side*10.8,4.3,0),steel)
	Geo.box(gate,Vector3(22,0.32,0.35),Vector3(0,8.5,0),steel)
	Geo.box(gate,Vector3(8.7,1.75,0.2),Vector3(0,7.65,0),Geo.mat(Color("153341"),0.3,0.6))
	Geo.box(gate,Vector3(8.7,0.07,0.22),Vector3(0,8.5,0.04),Geo.mat(color,0,0.5,2))
	var label = Label3D.new()
	label.text = text + "  ↓"
	label.font_size = 70
	label.pixel_size = 0.008
	label.position = Vector3(0,7.65,0.13)
	label.modulate = color
	label.outline_size = 0
	gate.add_child(label)
	return gate

func update_track(distance: float, finish: float) -> void:
	current_distance = distance
	var base = int(floor(distance/CHUNK_LENGTH))-2
	for i in CHUNK_COUNT:
		var segment = base+i
		var chunk = chunks[posmod(segment,CHUNK_COUNT)]
		var d = segment*CHUNK_LENGTH
		chunk.position = relative_position(0,d,distance)
		chunk.rotation.y = yaw_at(d)
		var sign_gate = chunk.get_node_or_null("SignGate")
		if sign_gate: sign_gate.visible = absf(d-finish)>85
		var bridge = chunk.get_node_or_null("Bridge")
		if bridge: bridge.visible = d>=3600 and d<=finish+200
	finish_gate.position = relative_position(0,finish,distance)
	finish_gate.rotation.y = yaw_at(finish)
	finish_gate.visible = finish-distance < 900 and finish-distance > -80

func car(color: Color, van: bool = false) -> Node3D:
	var n = Node3D.new()
	var body = Geo.mat(color,0.65,0.26)
	var rubber = Geo.mat(Color("0b1018"),0,0.95)
	var glass = Geo.mat(Color("163548"),0.75,0.18)
	var metal = Geo.mat(Color("778b93"),0.8,0.35)
	Geo.box(n,Vector3(1.95,0.69,4.1),Vector3(0,0.71,0),body)
	Geo.box(n,Vector3(1.69,0.66 if not van else 1.3,2.12 if not van else 3.2),Vector3(0,1.29 if not van else 1.58,0.1),glass if not van else body)
	Geo.box(n,Vector3(1.74,0.13,1.65),Vector3(0,1.68 if not van else 2.25,0.19),body)
	Geo.box(n,Vector3(1.57,0.45,0.05),Vector3(0,1.29 if not van else 1.8,1.18 if not van else 1.72),glass)
	Geo.box(n,Vector3(1.8,0.17,0.12),Vector3(0,0.43,2.06),metal)
	Geo.box(n,Vector3(0.46,0.17,0.02),Vector3(0,0.67,2.06),Geo.mat(Color("dee0d2")))
	for side in [-1,1]:
		for z in [-1.28,1.28]:
			var wheel = Geo.cylinder(n,0.39,0.22,Vector3(side*0.98,0.39,z),rubber)
			wheel.rotation.z = PI/2
			var rim = Geo.cylinder(n,0.23,0.24,Vector3(side*0.99,0.39,z),metal)
			rim.rotation.z = PI/2
		Geo.box(n,Vector3(0.53,0.15,0.04),Vector3(side*0.63,0.91,2.06),Geo.mat(Color("ff384d"),0,0.3,3))
		Geo.box(n,Vector3(0.51,0.15,0.04),Vector3(side*0.65,0.88,-2.06),Geo.mat(Color("e4f7ff"),0,0.3,3))
	return n
