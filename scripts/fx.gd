extends Node3D
const Geo = preload("res://scripts/geo.gd")

func burst(pos: Vector3, color: Color, heavy: bool = false) -> void:
	if DisplayServer.get_name()=="headless": return
	var p = CPUParticles3D.new()
	p.position = pos
	p.amount = 46 if heavy else 25
	p.lifetime = 0.65 if heavy else 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0,1,0.2)
	p.spread = 155
	p.gravity = Vector3(0,-16,20)
	p.initial_velocity_min = 4
	p.initial_velocity_max = 14 if heavy else 9
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.1
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.06,0.06,0.32)
	mesh.material = Geo.mat(color,0,0.5,3)
	p.mesh = mesh
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func slash(pos: Vector3, side: int) -> void:
	if DisplayServer.get_name()=="headless": return
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 14:
		var a = -0.95+i/14.0*1.9
		var b = -0.95+(i+1)/14.0*1.9
		var p1 = Vector3(cos(a)*1.2*side,0,sin(a)*1.2)
		var p2 = Vector3(cos(a)*2.8*side,0,sin(a)*2.8)
		var p3 = Vector3(cos(b)*2.8*side,0,sin(b)*2.8)
		var p4 = Vector3(cos(b)*1.2*side,0,sin(b)*1.2)
		for v in [p1,p2,p3,p1,p3,p4]: mesh.surface_add_vertex(v)
	mesh.surface_end()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.65,0.96,1,0.65)
	material.emission_enabled = true
	material.emission = Color("96ecff")
	material.emission_energy_multiplier = 2.0
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.z = side*0.15
	add_child(mi)
	var tween = create_tween()
	tween.tween_property(material,"albedo_color:a",0.0,0.22)
	tween.tween_callback(mi.queue_free)

func clear_effects() -> void:
	for child in get_children():
		child.queue_free()
