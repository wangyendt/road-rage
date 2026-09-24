extends Node3D
const Geo=preload("res://scripts/geo.gd")
const Weapons=preload("res://scripts/weapons.gd")
var weapon_id="fists"
var links: Array[Node3D] = []
var length=1.6
func build(id: String) -> void:
	weapon_id=id
	name="Weapon_"+id
	var spec=Weapons.data(id)
	visible=Weapons.armed(id)
	if not visible: return
	var metal=Geo.mat(Color("cadce0"),0.8,0.25)
	var dark=Geo.mat(Color("27353e"),0.4,0.65)
	var grip=Geo.mat(Color("714c39"),0.1,0.85)
	var trim=Geo.mat(spec.color,0.5,0.3,0.7)
	length=2.1 if spec.kind=="pole" else 1.4
	if spec.kind=="flex":
		Geo.cylinder(self,0.055,0.37,Vector3(0,0.05,0),grip)
		var count=18 if id=="whip" else (12 if id=="chain" else (6 if id=="nunchaku" else 10))
		length=2.4 if id=="whip" else (2.0 if id in ["chain","three_section"] else 1.35)
		for i in count:
			var segment=Geo.box(self,Vector3(0.065,1,0.065),Vector3.ZERO,trim if id=="whip" else metal)
			if id=="nunchaku" and i>=3: segment.material_override=grip
			if id=="three_section" and i%4<3: segment.material_override=grip
			links.append(segment)
		pose(0,0)
		return
	var shaft=0.45 if spec.kind=="blade" else length
	Geo.cylinder(self,0.055 if spec.kind!="heavy" else 0.072,shaft,Vector3(0,0.02 if spec.kind=="blade" else length*0.35,0),grip)
	Geo.cylinder(self,0.074,0.24,Vector3(0,0,0),dark)
	var top=length*0.85
	match id:
		"saber":
			for i in 7:
				var part=Geo.box(self,Vector3(0.16,0.2,0.045),Vector3(float(i*i)*0.007,0.3+i*0.17,0),metal)
				part.rotation.z=-i*0.055
			Geo.box(self,Vector3(0.35,0.07,0.12),Vector3(0,0.24,0),trim)
		"sword":
			Geo.wedge(self,Vector3(0.16,1.2,0.06),Vector3(0,0.85,0),metal)
			Geo.box(self,Vector3(0.50,0.06,0.10),Vector3(0,0.26,0),trim)
		"spear", "halberd":
			Geo.wedge(self,Vector3(0.23,0.55,0.09),Vector3(0,top+0.14,0),metal)
			if id=="halberd":
				Geo.wedge(self,Vector3(0.55,0.62,0.08),Vector3(0.21,top-0.18,0),trim)
				Geo.box(self,Vector3(0.50,0.07,0.07),Vector3(0,top-0.37,0),metal)
		"axe":
			Geo.wedge(self,Vector3(0.64,0.5,0.14),Vector3(0.22,top-0.18,0),metal)
			Geo.box(self,Vector3(0.32,0.18,0.18),Vector3(-0.12,top-0.18,0),trim)
		"yue":
			Geo.sphere(self,0.42,Vector3(0,top-0.12,0),trim,Vector3(1,0.75,0.16))
			Geo.wedge(self,Vector3(0.86,0.28,0.10),Vector3(0,top-0.29,0),metal)
		"hook":
			for i in 9:
				var a=float(i)/9*PI*1.25
				var b=float(i+1)/9*PI*1.25
				Geo.link(self,Vector3(sin(a)*0.28,top+cos(a)*0.28,0),Vector3(sin(b)*0.28,top+cos(b)*0.28,0),0.075,metal)
		"fork":
			Geo.box(self,Vector3(0.65,0.09,0.08),Vector3(0,top-0.13,0),trim)
			for x in [-0.28,0,0.28]: Geo.wedge(self,Vector3(0.09,0.50,0.075),Vector3(x,top+0.09,0),metal)
		"mace":
			Geo.cylinder(self,0.18,0.60,Vector3(0,top-0.1,0),metal)
			for y in [top-0.30,top-0.1,top+0.1]:
				for side in [-1,1]: Geo.box(self,Vector3(0.17,0.09,0.11),Vector3(side*0.22,y,0),trim)
		"hammer":
			Geo.box(self,Vector3(0.77,0.40,0.36),Vector3(0,top-0.1,0),metal)
			for side in [-1,1]: Geo.box(self,Vector3(0.08,0.44,0.40),Vector3(side*0.38,top-0.1,0),trim)
		"staff":
			for y in [0.4,0.8,1.1]: Geo.cylinder(self,0.061,0.1,Vector3(0,y,0),trim)
	Geo.sphere(self,0.075,Vector3(0,-length*0.15,0),trim)

func pose(time: float, swing: float) -> void:
	if links.is_empty(): return
	var previous=Vector3(0,0.21,0)
	for i in links.size():
		var t=float(i+1)/links.size()
		var extend=0.35+0.65*swing
		var point=Vector3(sin(t*4+time*12)*(0.05+0.25*swing)*t,0.21+t*length*extend,-t*t*length*(1-swing)*0.75)
		Geo.align_link(links[i],previous,point)
		links[i].scale.y=previous.distance_to(point)
		previous=point
