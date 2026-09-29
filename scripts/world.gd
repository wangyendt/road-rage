extends Node3D
const Geo = preload("res://scripts/geo.gd")
const Route = preload("res://scripts/track_route.gd")
const Data = preload("res://scripts/game_data.gd")
var route=Route.new()
var air_walls=true
var oncoming=false
var solids: Array[Dictionary]=[]
var course_index = 0
var theme = 0
var wind_rotors: Array[Node3D] = []
var course: Dictionary = Data.COURSES[0]
const CHUNK_LENGTH = 40.0
const CHUNK_COUNT = 27
var chunks: Array[Node3D] = []
var environment: Environment
var sun: DirectionalLight3D
var road_mat: Material
var sea_mat: ShaderMaterial
var rng = RandomNumberGenerator.new()
var scenery: Node3D
var finish_gate: Node3D
var current_distance = 0.0
var spectators: Array[Dictionary] = []
var finish_line: Node3D

func center_at(d: float) -> float:
	return route.point(d).x

func yaw_at(d: float) -> float:
	return -route.heading(d)

func relative_yaw(d: float, player_distance: float) -> float:
	return yaw_at(d)-yaw_at(player_distance)

func relative_position(lane: float, track_distance: float, player_distance: float) -> Vector3:
	var p=route.point(track_distance,lane)-route.point(player_distance)
	var angle=route.heading(player_distance)
	return Vector3(p.dot(Vector2(cos(angle),-sin(angle))),height_at(track_distance)-height_at(player_distance),-p.dot(Vector2(sin(angle),cos(angle))))

func configure_rules(walls: bool, opposite: bool) -> void:
	if air_walls==walls and oncoming==opposite: return
	air_walls=walls
	oncoming=opposite
	for chunk in chunks: chunk.set_meta("segment",-999999)

func sea_side(d: float, side: int) -> bool:
	return (course.id=="coast" and side>0) or (course.id=="harbor" and d>course.length*0.66)

func over_sea(lane: float, d: float) -> bool:
	return absf(lane)>road_half_width(d)+0.9 and sea_side(d,1 if lane>0 else -1)

func roadside_hit(from_lane: float, from_d: float, to_lane: float, to_d: float, height: float) -> Dictionary:
	for entry in solids:
		var at=float(entry.chunk.get_meta("segment",-999999))*CHUNK_LENGTH-entry.base.z
		if sea_side(at,1 if entry.base.x>0 else -1): continue
		if absf(at-to_d)>entry.size.z+absf(to_d-from_d)+5: continue
		var margin=Vector3(0.65,0.85,1.15)
		var box=AABB(Vector3(entry.base.x,entry.base.y,0)-entry.size*0.5-margin,entry.size+margin*2)
		var a=relative_position(from_lane,from_d,at)+Vector3(0,height+0.85,0)
		var b=relative_position(to_lane,to_d,at)+Vector3(0,height+0.85,0)
		if box.has_point(b) or box.intersects_segment(a,b)!=null:
			return {"cause":entry.cause,"lane":entry.base.x-signf(entry.base.x)*(entry.size.x*0.5+1.0)}
	return {}

func build(map_index: int = 0) -> void:
	for child in get_children(): child.free()
	chunks.clear()
	solids.clear()
	wind_rotors.clear()
	spectators.clear()
	course_index = clampi(map_index,0,Data.COURSES.size()-1)
	course = Data.COURSES[course_index].duplicate()
	route.build(course_index,course.length)
	theme = course.get("theme",course_index)
	rng.seed = 20260924+course_index*77
	_environment()
	sea_mat=ShaderMaterial.new()
	sea_mat.shader=load("res://shaders/sea.gdshader")
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/asphalt.gdshader")
	road_mat.set_shader_parameter("wetness",0.8 if course.id=="storm" else 0.0)
	road_mat.set_shader_parameter("grain_texture",load("res://assets/asphalt_noise.tres"))
	road_mat.set_shader_parameter("base_tint",[Color("0c1014"),Color("242020"),Color("131e22"),Color("070b15")][theme])
	for i in CHUNK_COUNT:
		var chunk = _chunk(i)
		add_child(chunk)
		chunks.append(chunk)
	var ground_colors = [Color("172b42"),Color("8b5940"),Color("537a74"),Color("121527")]
	var ground = Geo.box(self,Vector3(2600,1,2200),Vector3(0,-32,-700),Geo.mat(ground_colors[theme],0.15,0.75))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 12:
		var height = rng.randf_range(60,180)
		var pos = Vector3(-950+i*175,height/2-10,-950-rng.randf()*100)
		var mountain = Geo.wedge(self,Vector3(rng.randf_range(170,330),height,170),pos,Geo.mat([Color("263746"),Color("a8694e"),Color("6a858a"),Color("172139")][theme],0,1))
		mountain.rotation.y = rng.randf_range(-0.3,0.3)
		if course.id=="alpine":
			Geo.wedge(self,Vector3(75,height*0.30,65),Vector3(pos.x,height*0.85-10,pos.z),Geo.mat(Color("dce9e7"),0,0.85))
	if course.id=="storm":
		environment.fog_density=0.0033
		environment.fog_light_color=Color("73818e")
		sun.light_energy=0.75
	if course.id=="windfarm":
		environment.sky.sky_material.sky_top_color=Color("448fa6")
		environment.sky.sky_material.sky_horizon_color=Color("c7d7aa")
		environment.fog_light_color=Color("a0b59d")
	if course.id=="coast": environment.fog_light_color=Color("78a8b6")
	if course.id=="skyway":
		environment.sky.sky_material.sky_top_color=Color("397bc1")
		environment.fog_light_color=Color("b6dce4")
		environment.fog_density=0.0020
	if course.id=="volcano":
		environment.sky.sky_material.sky_top_color=Color("221b32")
		environment.sky.sky_material.sky_horizon_color=Color("b35235")
		environment.fog_light_color=Color("6f4246")
		sun.light_color=Color("ff9f6b")
	if course.id=="glacier":
		environment.sky.sky_material.sky_top_color=Color("345b8c")
		environment.sky.sky_material.sky_horizon_color=Color("c9e6ff")
		environment.fog_light_color=Color("b8d7ed")
		sun.light_color=Color("b8d9ff")
	finish_gate = _gate("FINISH",Color("b9f3ec"))
	add_child(finish_gate)
	_build_finish_festival()
	update_track(0,course.length)

func set_race_length(length: float) -> void:
	# Terrain must continue beyond the old finish, not become a long flat extension.
	course = course.duplicate()
	course.length = maxf(1000.0,length)
	route.build(course_index,course.length)
	for chunk in chunks: chunk.set_meta("segment",-999999)

func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = [Color("0b233f"),Color("467c9e"),Color("488cab"),Color("04091d")][theme]
	sm.sky_horizon_color = [Color("bc7d73"),Color("e5b28a"),Color("c9e5eb"),Color("253967")][theme]
	sm.sky_curve = 0.17
	sm.ground_bottom_color = Color("111d30")
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.sun_angle_max = 4.0
	sky.sky_material = sm
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa9ce")
	environment.ambient_light_energy = 0.46 if course.id=="neon" else 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.07
	environment.fog_enabled = true
	environment.fog_light_color = [Color("687984"),Color("bb8868"),Color("b3ced3"),Color("17213b")][theme]
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.16
	var we = WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-23,-38,0)
	sun.light_color = Color("9db6ff") if course.id=="neon" else Color("ffe2c4")
	sun.light_energy = 0.6 if course.id=="neon" else 1.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	sun.shadow_bias = 0.07
	add_child(sun)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-35,150,0)
	rim.light_color = Color("6fa8ec")
	rim.light_energy = 0.7
	add_child(rim)
	Geo.sphere(self,22 if course.id=="neon" else 37,Vector3(-205,150 if course.id=="neon" else 99,-820),Geo.mat(Color("b1d1ec") if course.id=="neon" else Color("ffe0a8"),0,1,1.8))

func _chunk(index: int) -> Node3D:
	var n = Node3D.new()
	n.name = "Highway%02d" % index
	var concrete = Geo.mat(Color("344653"),0.1,0.9)
	var steel = Geo.mat(Color("637985"),0.65,0.4)
	var white = Geo.mat(Color("aac0c7"),0.0,0.9)
	var amber = Geo.mat(Color("ff8852"),0.0,0.5,2.0)
	var cyan = Geo.mat(Color("73cbd7"),0.0,0.5,1.3)
	var surface=MeshInstance3D.new()
	surface.name="RoadSurface"
	n.add_child(surface)
	for side in [-1,1]:
		Geo.box(n,Vector3(0.16,8.5,0.16),Vector3(side*11,4.15,0),steel)
		Geo.box(n,Vector3(2.8,0.12,0.2),Vector3(side*9.65,8.35,0),steel)
		Geo.box(n,Vector3(1.25,0.08,0.32),Vector3(side*8.6,8.25,0),Geo.mat(Color("ffdda4"),0,0.5,4.0))
	var cones=Node3D.new()
	cones.name="WorkCones"
	n.add_child(cones)
	for side in [-1,1]:
		for z in [-15,-5,5,15]:
			var cone=Node3D.new()
			cones.add_child(cone)
			cone.set_meta("side",side)
			cone.set_meta("z",z)
			Geo.box(cone,Vector3(0.6,0.08,0.6),Vector3(0,0.04,0),Geo.mat(Color("1c2226")))
			Geo.wedge(cone,Vector3(0.4,0.85,0.4),Vector3(0,0.5,0),Geo.mat(Color("ff9a41")))
			Geo.box(cone,Vector3(0.27,0.12,0.27),Vector3(0,0.6,0),white)
	if index % 6 == 0:
		var labels = [course.en,"KEEP MOVING","PASS / LEFT",course.en,"NEXT SECTOR"]
		var gate = _gate(labels[index%labels.size()],Color("75d9dd"))
		gate.name = "SignGate"
		n.add_child(gate)
	# The final sector becomes a cable-stayed bridge, not just another HUD label.
	if course.id=="harbor" and index % 3 == 0:
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
	_make_scenery(n,index,amber,cyan,concrete)
	for child in n.get_children():
		if child.name not in ["RoadSurface","WorkCones"]:
			child.set_meta("base_position",child.position)
			child.set_meta("base_rotation",child.rotation)
	return n

func _make_scenery(n: Node3D, index: int, amber: Material, cyan: Material, concrete: Material) -> void:
	for side in [-1,1]:
		if course.id=="coast" and side>0: continue
		if course.id in ["skyway","volcano","mesa","glacier"]:
			_expansion_landmark(n,index,side)
		elif course.id in ["harbor","neon","coast"]:
			for j in (1 if course.id=="coast" else 2):
				var height = rng.randf_range(15,80 if course.id=="neon" else 65)
				var material = ShaderMaterial.new()
				material.shader = load("res://shaders/building.gdshader")
				material.set_shader_parameter("seed",float(index*4+j+side))
				material.set_shader_parameter("light_color",Color("cc75dc") if course.id=="neon" and index%2==0 else Color("72b4d4"))
				var x = side*(rng.randf_range(35,65)+j*34)
				var b = Geo.box(n,Vector3(rng.randf_range(12,22),height,rng.randf_range(15,28)),Vector3(x,height/2-10,rng.randf_range(-17,17)),material)
				solids.append({"chunk":n,"base":b.position,"size":b.mesh.size,"cause":"撞上楼体"})
				b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if index%3==0: Geo.box(n,Vector3(13,0.13,0.16),Vector3(x,height-9.5,0),amber if side>0 else cyan)
		elif course.id in ["canyon","quarry"]:
			for j in 3:
				var h = rng.randf_range(10,35)
				var x = side*(24+j*21+rng.randf()*8)
				var stone = Geo.mat(Color("a36143") if j%2==0 else Color("c5845a"),0,1)
				var rock = Geo.wedge(n,Vector3(18,h,25),Vector3(x,h/2-7,rng.randf_range(-15,15)),stone)
				# Axis-aligned rock solid matches the rendered roadside shape.
				solids.append({"chunk":n,"base":rock.position,"size":rock.mesh.size,"cause":"撞上岩壁"})
				Geo.box(n,Vector3(14,h*0.15,20),Vector3(x,h*0.60-7,0),Geo.mat(Color("d89b6b"),0,1))
			var green = Geo.mat(Color("496b46"),0,1)
			var cactus_x = side*17.0
			Geo.cylinder(n,0.22,3.6,Vector3(cactus_x,1.5,9),green)
			Geo.link(n,Vector3(cactus_x,1.7,9),Vector3(cactus_x+side*1.2,2,9),0.3,green)
			Geo.cylinder(n,0.16,1.6,Vector3(cactus_x+side*1.2,2.6,9),green)
		else:
			for j in 4:
				var x = side*(18+j*10+rng.randf()*4)
				var h = rng.randf_range(7,15)
				var z = rng.randf_range(-19,19)
				Geo.cylinder(n,0.32,h*0.65,Vector3(x,h*0.32-2,z),Geo.mat(Color("5b4f42"),0,1))
				for tier in 3:
					var tree = Geo.wedge(n,Vector3(h*0.6-tier,h*0.6,h*0.6-tier),Vector3(x,h*0.40+tier*h*0.17-1,z),Geo.mat(Color("1e594a") if tier%2==0 else Color("36766a"),0,1))
					tree.rotation.y = PI/4
				Geo.sphere(n,1.8,Vector3(x+3,-0.5,z+4),Geo.mat(Color("899882") if course.id=="windfarm" else Color("bfceca"),0,1),Vector3(1.5,0.5,1))
		if course.id=="windfarm" and index%2==0:
			var tower=Node3D.new()
			n.add_child(tower)
			tower.position=Vector3(side*43,0,0)
			Geo.cylinder(tower,0.85,38,Vector3(0,17,0),Geo.mat(Color("dfe7dd")))
			var rotor=Node3D.new()
			tower.add_child(rotor)
			rotor.position=Vector3(0,36,0)
			Geo.sphere(rotor,1.2,Vector3.ZERO,white_material())
			for blade in 3:
				var arm=Node3D.new()
				rotor.add_child(arm)
				arm.rotation.z=blade*TAU/3
				Geo.wedge(arm,Vector3(1.3,17,0.4),Vector3(0,9,0),white_material())
			wind_rotors.append(rotor)
		if course.id=="quarry" and index%3==0:
			Geo.box(n,Vector3(3,25,3),Vector3(side*28,9,0),Geo.mat(Color("daa14c")))
			Geo.box(n,Vector3(30,1.5,1.6),Vector3(side*34,22,0),Geo.mat(Color("e4b65c")))
		if course.id=="coast" and index%4==0:
			var lighthouse=Geo.cylinder(n,2.1,20,Vector3(side*35,7,0),white_material())
			Geo.cylinder(lighthouse,2.5,2,Vector3(0,11,0),Geo.mat(Color("ff805f")))
			Geo.sphere(lighthouse,1.4,Vector3(0,13,0),Geo.mat(Color("ffe9ad"),0,0.5,3))
		Geo.box(n,Vector3(1.4,11,1.4),Vector3(side*7,-5.8,0),concrete)
	if course.id=="neon" and index%3==0:
		var neon = Geo.mat(Color("b562ff"),0,0.5,4)
		for side in [-1,1]: Geo.box(n,Vector3(0.13,10,0.15),Vector3(side*10.8,5,-12),neon)
		Geo.box(n,Vector3(21.6,0.13,0.15),Vector3(0,10,-12),neon)

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

func update_track(distance: float, finish: float, time: float = 0.0, view_height: float = 0.0) -> void:
	current_distance = distance
	var base = int(floor(distance/CHUNK_LENGTH))-6
	for i in CHUNK_COUNT:
		var segment = base+i
		var chunk = chunks[posmod(segment,CHUNK_COUNT)]
		var d = segment*CHUNK_LENGTH
		chunk.position = relative_position(0,d,distance)
		chunk.rotation = Vector3(0,relative_yaw(d,distance),0)
		if chunk.get_meta("segment",-999999)!=segment:
			_shape_chunk(chunk,d)
			chunk.set_meta("segment",segment)
		var sign_gate = chunk.get_node_or_null("SignGate")
		if sign_gate: sign_gate.visible = absf(d-finish)>85 and (view_height<2.5 or absf(d-distance)>70)
		var bridge = chunk.get_node_or_null("Bridge")
		if bridge: bridge.visible = d>=finish*0.66 and d<=finish+200
	finish_gate.position = relative_position(0,finish,distance)
	finish_gate.rotation.y = relative_yaw(finish,distance)
	finish_gate.rotation.x = atan(slope_at(finish))
	for rotor in wind_rotors: rotor.rotation.z=time*0.38
	finish_gate.visible = finish-distance < 700 and finish-distance > -100
	if finish_gate.visible:
		for fan in spectators:
			fan.arm.rotation.z=fan.side*(0.4+sin(time*5+fan.phase)*0.6)
			fan.node.position.y=fan.base_y+absf(sin(time*3.5+fan.phase))*0.14

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

func _build_finish_festival() -> void:
	finish_line=Node3D.new()
	finish_line.name="FinishLine"
	finish_gate.add_child(finish_line)
	var white=Geo.mat(Color("f4f4ed"),0,0.8)
	var black=Geo.mat(Color("10151d"),0,0.8)
	for row in 4:
		for col in 24:
			Geo.box(finish_line,Vector3(0.76,0.025,0.76),Vector3(-8.74+col*0.76,0.04,-1.14+row*0.76),white if (row+col)%2==0 else black)
	var platform=Geo.mat(Color("314251"),0.4,0.8)
	var colors=[Color("ff8257"),Color("69d6d2"),Color("e9c577"),Color("a88ce5"),Color("e9eff3")]
	for side in [-1,1]:
		for row in 2:
			Geo.box(finish_gate,Vector3(3,0.8+row*0.65,37),Vector3(side*(12.3+row*2.3),row*0.325,-10),platform)
			for i in 12:
				var fan=Node3D.new()
				finish_gate.add_child(fan)
				var height=0.4+row*0.65
				fan.position=Vector3(side*(11.9+row*2.4),height,-26+i*2.8)
				fan.rotation.y=side*PI/2
				var shirt=Geo.mat(colors[(i+row*2)%colors.size()],0,0.9)
				Geo.box(fan,Vector3(0.5,0.68,0.32),Vector3(0,1.05,0),shirt)
				Geo.sphere(fan,0.21,Vector3(0,1.62,0),Geo.mat(Color("c59977").darkened(float(i%3)*0.13)))
				for x in [-0.15,0.15]: Geo.box(fan,Vector3(0.17,0.72,0.2),Vector3(x,0.38,0),black)
				var arm=Node3D.new()
				fan.add_child(arm)
				arm.position=Vector3(0.28,1.25,0)
				Geo.box(arm,Vector3(0.14,0.7,0.14),Vector3(0,0.3,0),shirt)
				if i%3==0:
					Geo.box(arm,Vector3(0.035,0.8,0.035),Vector3(0,0.9,0),white)
					Geo.box(arm,Vector3(0.65,0.4,0.025),Vector3(0.3,1.07,0),shirt)
				spectators.append({"node":fan,"arm":arm,"base_y":height,"side":float(side),"phase":float(i+row*9)})
		var banner=Label3D.new()
		banner.text="WELCOME RIDERS"
		banner.position=Vector3(side*13,4.8,-11)
		banner.rotation.y=side*PI/2
		banner.font_size=72
		banner.pixel_size=0.011
		banner.modulate=Color("f8d58d")
		finish_gate.add_child(banner)
		var board=Geo.box(finish_gate,Vector3(8,1.2,0.08),banner.position+Vector3(side*0.05,0,0),platform)
		board.rotation.y=side*PI/2

func white_material() -> Material:
	return Geo.mat(Color("d7e5df"),0.2,0.7)

func height_at(d: float) -> float:
	# Start and finish are level staging areas; all elevation is deterministic.
	var ramp=smoothstep(160.0,340.0,d)*(1.0-smoothstep(course.length-400.0,course.length-180.0,d))
	var amplitude=float(course.get("amplitude",[0.0,7.0,14.0,2.5,19.0,12.0,8.0,24.0][mini(course_index,7)]))
	var base=amplitude*(0.65+0.45*sin(d*0.004)+0.2*sin(d*0.009))
	var hump=0.0
	if course_index>=4:
		var period=float(course.get("period",[0,0,0,0,720,430,620,840][mini(course_index,7)]))
		var width=float(course.get("hump_width",[0.0,0,0,0,200,180,165,240][mini(course_index,7)]))
		var peak=float(course.get("hump_peak",[0.0,0,0,0,12,9,10,14][mini(course_index,7)]))
		var t=fposmod(d-430.0,float(period))
		if t<width: hump=peak*0.5*(1-cos(TAU*t/width))
	return (base+hump)*ramp

func slope_at(d: float) -> float:
	return (height_at(d+0.1)-height_at(d-0.1))/0.2

func road_half_width(d: float) -> float:
	if course_index<4: return 9.5
	var period=1000.0 if course.id=="quarry" else 1550.0
	var t=fposmod(d-850.0,period)
	var pinch=smoothstep(0.0,90.0,t)*(1-smoothstep(280.0,390.0,t))
	var staging=smoothstep(300.0,500.0,d)*(1-smoothstep(course.length-500,course.length-350,d))
	return 9.5-pinch*staging*(3.4 if course.id=="quarry" else 2.3)

func surface_at(d: float) -> String:
	if course.id in ["storm","glacier"]: return "wet"
	if course.id in ["quarry","mesa"] and d>350 and d<course.length-350 and fposmod(d,1050)<350: return "gravel"
	return "asphalt"

func grip_at(d: float) -> float:
	return {"wet":0.70,"gravel":0.77,"asphalt":1.0}[surface_at(d)]

func road_hint(d: float) -> String:
	if road_half_width(d+65)<7.5: return "前方收窄 · 提前并线"
	if slope_at(d+60)>0.12: return "前方上坡 · 高速冲顶会腾空"
	if surface_at(d)=="gravel": return "碎石路段 · 降低速度稳住车身"
	if surface_at(d)=="wet": return "湿滑路面 · 提前刹车"
	return ""

func _point(d: float, at: float, fraction: float, y: float) -> Vector3:
	return relative_position(road_half_width(at)*fraction,at,d)+Vector3(0,y,0)

func _ribbon(st: SurfaceTool, d: float, x1: float, x2: float, y: float, dashed: bool = false, flat_water: bool = false) -> void:
	for step in 16:
		if dashed and step%4>=2: continue
		var a=d-20+step*2.5
		var b=a+2.5
		var points=[_point(d,a,x1,y),_point(d,b,x1,y),_point(d,b,x2,y),_point(d,a,x2,y)]
		if flat_water:
			for i in points.size(): points[i].y=-18.0-height_at(d)
		for index in [0,1,2,0,2,3]:
			st.set_uv(Vector2(points[index].x,points[index].z)*0.2)
			st.add_vertex(points[index])

func _shape_chunk(chunk: Node3D, d: float) -> void:
	var mesh=ArrayMesh.new()
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(st,d,-1,1,-0.01)
	st.generate_normals()
	st.set_material(road_mat if surface_at(d)!="gravel" else Geo.mat(Color("766653"),0,1))
	st.commit(mesh)
	st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-0.96,0.96]: _ribbon(st,d,x-0.007,x+0.007,0.006)
	for x in ([-0.475,0.475] if oncoming else [-0.475,0.0,0.475]): _ribbon(st,d,x-0.007,x+0.007,0.009,true)
	st.generate_normals()
	st.set_material(white_material())
	st.commit(mesh)
	if oncoming:
		st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x in [-0.022,0.022]: _ribbon(st,d,x-0.009,x+0.009,0.015)
		st.generate_normals()
		st.set_material(Geo.mat(Color("ffd34f"),0,0.8,0.3))
		st.commit(mesh)
	if air_walls:
		st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1,1]:
			_ribbon(st,d,side*1.00,side*1.07,-0.06)
			_ribbon(st,d,side*1.075-0.013,side*1.075+0.013,0.85)
		st.generate_normals()
		var rail=Geo.mat(Color("526c78"),0.5,0.65)
		rail.cull_mode=BaseMaterial3D.CULL_DISABLED
		st.set_material(rail)
		st.commit(mesh)
	for side in [-1,1]:
		st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var water=sea_side(d,side)
		_ribbon(st,d,minf(side*1.0,side*128),maxf(side*1.0,side*128),-18.0 if water else -0.04,false,water)
		st.generate_normals()
		var earth=Color("ad7950") if theme==1 else (Color("34434c") if course.id in ["harbor","neon"] else Color("526c47"))
		if course.id in ["alpine","storm","glacier"]: earth=Color("90aaad")
		st.set_material(sea_mat if water else Geo.mat(earth,0,0.95))
		st.commit(mesh)
	chunk.get_node("RoadSurface").mesh=mesh
	for child in chunk.get_children():
		if child.has_meta("base_position"):
			var p: Vector3=child.get_meta("base_position")
			if absf(p.x)>20: child.visible=not sea_side(d,1 if p.x>0 else -1)
			child.position=relative_position(p.x,d-p.z,d)+Vector3(0,p.y,0)
			child.rotation=child.get_meta("base_rotation",Vector3.ZERO)+Vector3(0,relative_yaw(d-p.z,d),0)
	var cones=chunk.get_node("WorkCones")
	cones.visible=road_half_width(d)<9.4
	if cones.visible:
		for cone in cones.get_children():
			var at=d-float(cone.get_meta("z"))
			cone.position=_point(d,at,float(cone.get_meta("side"))*0.98,0)

func traffic_vehicle(spec: Dictionary, color: Color) -> Node3D:
	var id=spec.id
	if id in ["sedan","hatch","suv","taxi","van"]:
		var n=car(Color("efc14a") if id=="taxi" else color,id in ["van","suv"])
		n.scale=Vector3(spec.width/2.22,spec.height/(2.44 if id=="suv" else (2.32 if id=="van" else (2.0 if id=="taxi" else 1.75))),spec.length/4.1)
		if id=="taxi":
			Geo.box(n,Vector3(0.65,0.23,0.38),Vector3(0,1.85,0),Geo.mat(Color("fff2c1"),0,0.7,1))
		elif id=="suv":
			for side in [-1,1]: Geo.box(n,Vector3(0.08,0.08,2.2),Vector3(side*0.7,2.38,0),Geo.mat(Color("18212a")))
		return n
	var n=Node3D.new()
	var paint=Geo.mat(color,0.45,0.4)
	var steel=Geo.mat(Color("84959b"),0.7,0.3)
	var dark=Geo.mat(Color("16212b"),0.2,0.8)
	var glass=Geo.mat(Color("2c5267"),0.7,0.2)
	var length: float=spec.length
	var width: float=spec.width
	var front=-length/2.0
	var pickup=id=="pickup"
	var cab_height=1.1 if pickup else 2.25
	Geo.box(n,Vector3(width,0.45,length),Vector3(0,0.72,0),dark)
	Geo.box(n,Vector3(width*0.95,cab_height,2.1),Vector3(0,1.0+cab_height/2,front+1.15),paint)
	Geo.box(n,Vector3(width*0.8,cab_height*0.42,0.04),Vector3(0,1.1+cab_height*0.64,front+0.08),glass)
	for side in [-1,1]:
		Geo.box(n,Vector3(0.05,cab_height*0.4,0.9),Vector3(side*width*0.481,1.1+cab_height*0.64,front+0.85),glass)
		Geo.box(n,Vector3(0.45,0.18,0.06),Vector3(side*width*0.3,1.1,front-0.025),Geo.mat(Color("d5efff"),0,0.5,3))
		Geo.box(n,Vector3(0.4,0.18,0.06),Vector3(side*width*0.3,0.95,length/2),Geo.mat(Color("ff4343"),0,0.5,3))
		var axles=[front+1.15,length/2-1.15] if pickup else [front+1.3,length/2-2.0,length/2-0.7]
		if id=="semi": axles.append(front+3.7)
		for z in axles:
			var wheel=Geo.cylinder(n,0.43 if pickup else 0.55,0.28,Vector3(side*(width/2-0.1),0.43 if pickup else 0.55,z),dark)
			wheel.rotation.z=PI/2
			var hub=Geo.cylinder(n,0.25,0.30,Vector3(side*(width/2-0.1),0.43 if pickup else 0.55,z),steel)
			hub.rotation.z=PI/2
	var cargo_length=length-2.7
	if pickup:
		Geo.box(n,Vector3(width,0.15,cargo_length),Vector3(0,1.0,1.2),paint)
		for side in [-1,1]: Geo.box(n,Vector3(0.1,0.65,cargo_length),Vector3(side*(width/2-0.05),1.35,1.2),paint)
		Geo.box(n,Vector3(width,0.65,0.1),Vector3(0,1.35,length/2-0.05),paint)
	elif id=="tanker":
		var tank=Geo.cylinder(n,width*0.48,cargo_length,Vector3(0,2.35,1.3),steel)
		tank.rotation.x=PI/2
		for z in [0.0,2.8]:
			Geo.box(n,Vector3(0.5,0.14,0.55),Vector3(0,3.63,z),dark)
		for side in [-1,1]: Geo.box(n,Vector3(0.07,0.15,cargo_length),Vector3(side*width*0.49,2.4,1.3),Geo.mat(Color("eab761")))
	else:
		Geo.box(n,Vector3(width,spec.height-1.12,cargo_length),Vector3(0,(spec.height+1.12)/2,1.3),paint)
		for side in [-1,1]:
			for z in range(int(cargo_length*2)):
				Geo.box(n,Vector3(0.045,spec.height-1.4,0.045),Vector3(side*width/2,(spec.height+1.12)/2,front+2.7+z*0.5),steel)
		Geo.box(n,Vector3(width*0.9,spec.height-1.4,0.04),Vector3(0,(spec.height+1.12)/2,length/2+0.02),dark)
		for x in [-0.25,0.25]: Geo.box(n,Vector3(0.07,spec.height-1.5,0.05),Vector3(x,(spec.height+1.12)/2,length/2+0.05),steel)
	return n

func _expansion_landmark(n: Node3D, index: int, side: int) -> void:
	var landmark=Node3D.new()
	landmark.name="Landmark_"+course.id+str(side)
	n.add_child(landmark)
	landmark.position=Vector3(side*(28+index%4*7),-9,0)
	if course.id=="skyway":
		var steel=Geo.mat(Color("c4d6df"),0.55,0.45)
		Geo.box(landmark,Vector3(4,80,5),Vector3(0,12,0),steel)
		Geo.box(landmark,Vector3(5,0.4,6),Vector3(0,53,0),Geo.mat(Color("65cffa"),0,0.5,3))
		Geo.link(landmark,Vector3(0,48,0),Vector3(-side*12,9,18),0.12,steel)
		Geo.sphere(landmark,14,Vector3(side*12,-22,-5),Geo.mat(Color("c0dbe3"),0,1),Vector3(2,0.4,1))
	elif course.id=="volcano":
		var basalt=Geo.mat(Color("302b38"),0.2,0.95)
		for j in 3:
			Geo.cylinder(landmark,4.0-j*0.7,25+j*9,Vector3(side*j*11,6+j*4,0),basalt)
			Geo.link(landmark,Vector3(side*j*11-2,0,0),Vector3(side*j*11+1,22+j*7,1),0.28,Geo.mat(Color("ff692c"),0,1,3))
		Geo.box(landmark,Vector3(35,0.1,32),Vector3(side*14,-2,0),Geo.mat(Color("b93618"),0,1,1.3))
	elif course.id=="mesa":
		var sand=Geo.mat(Color("c28258"),0,1)
		for x in [-8,8]: Geo.wedge(landmark,Vector3(8,38,15),Vector3(x,14,0),sand)
		Geo.box(landmark,Vector3(26,6,13),Vector3(0,33,0),Geo.mat(Color("e1ae75"),0,1))
	else:
		for j in 4:
			var ice=Geo.wedge(landmark,Vector3(8,28+j*7,11),Vector3(side*j*9,9+j*3,j*3),Geo.mat(Color("86c8e4") if j%2 else Color("d4edf7"),0.35,0.28))
			ice.rotation.z=side*0.14
