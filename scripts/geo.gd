extends RefCounted
## Reusable, original procedural geometry. No external art assets.

static var materials: Dictionary = {}
static var boxes: Dictionary = {}

static func mat(color: Color, metal: float = 0.0, rough: float = 0.5, emission: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(metal) + str(rough) + str(emission)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	materials[key] = m
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var key = str(size)
	if not boxes.has(key):
		var mesh = BoxMesh.new()
		mesh.size = size
		boxes[key] = mesh
	var mi = MeshInstance3D.new()
	mi.mesh = boxes[key]
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func link(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> MeshInstance3D:
	var mi = box(parent, Vector3(width, a.distance_to(b), width), (a+b)*0.5, material)
	align_link(mi, a, b)
	return mi

static func align_link(mi: Node3D, a: Vector3, b: Vector3) -> void:
	mi.position = (a+b)*0.5
	var dir = (b-a).normalized()
	mi.quaternion = Quaternion(Vector3.UP, dir)

static func wedge(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh = PrismMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi
