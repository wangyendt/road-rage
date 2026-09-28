extends RefCounted
## Shape + symbol + color: readable without relying on color alone.
const Geo = preload("res://scripts/geo.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
static func color(kind: String) -> Color:
	return Color("91ed76") if kind=="repair" else (Color("ffd04e") if kind=="coin" else Color("56cfff"))
static func build(kind: String) -> Node3D:
	var root=Node3D.new()
	root.name="Pickup_"+kind
	var paint=Geo.mat(color(kind),0.3,0.35,0.8)
	var ink=Geo.mat(Color("102438"),0.2,0.5)
	var white=Geo.mat(Color("f5ffed"),0,0.4,0.4)
	if kind=="repair":
		Geo.box(root,Vector3(1.65,1.15,0.55),Vector3.ZERO,paint)
		Geo.box(root,Vector3(0.65,0.24,0.3),Vector3(0,0.7,0),ink)
		Geo.box(root,Vector3(0.84,0.26,0.08),Vector3(0,0,0.32),white)
		Geo.box(root,Vector3(0.26,0.83,0.08),Vector3(0,0,0.32),white)
	elif kind=="nitro":
		for x in [-0.43,0.43]:
			Geo.cylinder(root,0.30,1.4,Vector3(x,0,0),paint)
			Geo.cylinder(root,0.15,0.25,Vector3(x,0.82,0),ink)
			Geo.box(root,Vector3(0.56,0.16,0.61),Vector3(x,-0.36,0),white)
		var bolt=[Vector3(0.17,0.5,0.39),Vector3(-0.20,0.02,0.39),Vector3(0.15,0.02,0.39),Vector3(-0.17,-0.48,0.39)]
		for i in 3: Geo.link(root,bolt[i],bolt[i+1],0.15,white)
	else:
		var disk=Geo.cylinder(root,0.85,0.22,Vector3.ZERO,paint)
		disk.rotation.x=PI/2
		var inset=Geo.cylinder(root,0.65,0.24,Vector3.ZERO,Geo.mat(Color("b57924"),0.6,0.4))
		inset.rotation.x=PI/2
		var symbol=Label3D.new()
		symbol.text="$"
		symbol.font_size=80
		symbol.pixel_size=0.018
		symbol.position=Vector3(0,0,0.14)
		symbol.modulate=Color("fff4bd")
		root.add_child(symbol)
	var label=Label3D.new()
	label.name="Legend"
	label.font=FONT
	label.text={"repair":"修复 +25","nitro":"氮气 +35","coin":"金币 $100"}[kind]
	label.font_size=48
	label.pixel_size=0.014
	label.position.y=1.3
	label.outline_size=12
	label.modulate=color(kind)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root
