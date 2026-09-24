extends Node3D
const Geo = preload("res://scripts/geo.gd")
var game: Node
var units: Array[Dictionary] = []
var next_distance = 650.0
var capture = 0.0
var intensity = 0.0
var enabled = true
var status = ""

func reset() -> void:
	for unit in units: unit.node.queue_free()
	units.clear()
	next_distance=650
	capture=0
	intensity=0
	status=""

func spawn(at: float, x: float) -> Dictionary:
	var root = Node3D.new()
	add_child(root)
	var car=game.world.car(Color("eceff1"))
	root.add_child(car)
	var dark=Geo.mat(Color("152336"),0.5,0.35)
	for side in [-1,1]:
		Geo.box(car,Vector3(0.025,0.38,2.7),Vector3(side*0.99,0.85,0),dark)
		var text=Label3D.new()
		text.text="POLICE"
		text.font_size=46
		text.pixel_size=0.009
		text.position=Vector3(side*1.01,0.90,0)
		text.rotation.y=side*PI/2
		car.add_child(text)
	Geo.box(car,Vector3(1.3,0.12,0.3),Vector3(0,1.82,0),dark)
	var red=Geo.box(car,Vector3(0.56,0.19,0.26),Vector3(-0.34,1.97,0),Geo.mat(Color("ff2447"),0,0.4,6))
	var blue=Geo.box(car,Vector3(0.56,0.19,0.26),Vector3(0.34,1.97,0),Geo.mat(Color("349cff"),0,0.4,6))
	var officer=Node3D.new()
	root.add_child(officer)
	Geo.box(officer,Vector3(0.55,0.66,0.34),Vector3(0,1.19,0),dark)
	Geo.sphere(officer,0.22,Vector3(0,1.75,0),Geo.mat(Color("be9173")))
	Geo.box(officer,Vector3(0.47,0.12,0.42),Vector3(0,1.92,0),dark)
	Geo.box(officer,Vector3(0.12,0.14,0.03),Vector3(-0.13,1.35,-0.18),Geo.mat(Color("efd283"),0.6))
	var legs=[]
	for side in [-1,1]:
		var leg=Node3D.new()
		officer.add_child(leg)
		leg.position=Vector3(side*0.16,0.88,0)
		Geo.box(leg,Vector3(0.19,0.78,0.23),Vector3(0,-0.39,0),dark)
		legs.append(leg)
		Geo.link(officer,Vector3(side*0.3,1.43,0),Vector3(side*0.4,0.96,-0.18),0.14,dark)
	officer.visible=false
	var u={"node":root,"car":car,"red":red,"blue":blue,"officer":officer,"legs":legs,"distance":at,"lane":x,"speed":85.0,"cooldown":2.0,"think":0.0,"target_lane":x,"on_foot":false,"foot_distance":at,"foot_lane":x}
	units.append(u)
	return u

func update(dt: float) -> void:
	intensity=0
	status=""
	if not enabled: return
	if game.distance>=next_distance and game.track_length-game.distance>500 and units.is_empty():
		spawn(game.distance-145,clampf(game.lane+3,-7,7))
		next_distance=game.distance+1450
		game.announce("警车正在追来","拉开距离！倒地时被警员抓住将被罚款并退赛",Color("ff8c92"),3.5)
	var arresting=false
	for i in range(units.size()-1,-1,-1):
		var u=units[i]
		var gap=game.distance-u.distance
		if gap>300 or game.distance>=game.track_length:
			u.node.queue_free()
			units.remove_at(i)
			continue
		intensity=maxf(intensity,clampf(1-absf(gap)/190,0,1))
		status="警车追捕 · 拉开距离"
		u.cooldown=maxf(0,u.cooldown-dt)
		u.think-=dt
		var recovering=game.player.recovery_time>0
		var grounded=recovering and game.player.recovery_elapsed>=0.85
		if u.think<=0:
			u.think=1.0
			u.target_lane=game.lane
		if recovering and absf(gap)<22:
			u.speed=move_toward(u.speed,0,dt*130)
		else:
			var target=clampf(game.speed+gap*0.55,35,91+game.active_level*1.4)
			u.speed=move_toward(u.speed,target,dt*30)
		if not u.on_foot:
			u.distance+=u.speed*dt
			u.lane=move_toward(u.lane,u.target_lane,dt*2.2)
		if not recovering and absf(game.distance-u.distance)<3.6 and absf(game.lane-u.lane)<1.6 and u.cooldown<=0:
			u.cooldown=6
			game.take_damage(23,"警车撞击")
			if game.player.recovery_time>0: u.speed*=0.15
		if grounded and absf(game.distance-u.distance)<17 and u.speed<18 and not u.on_foot:
			u.on_foot=true
			u.foot_distance=u.distance
			u.foot_lane=u.lane+(-1.6 if game.lane+game.player.rider.position.x<u.lane else 1.6)
		if u.on_foot:
			if not recovering:
				u.on_foot=false
				u.cooldown=4
			else:
				var rider=game.player.rider.position
				var target=Vector2(game.lane+rider.x,game.distance-rider.z)
				var foot=Vector2(u.foot_lane,u.foot_distance).move_toward(target,dt*6.5)
				u.foot_lane=foot.x
				u.foot_distance=foot.y
				if grounded and foot.distance_to(target)<1.5: arresting=true
				status="警员下车 · 正在接近倒地车手"
				for j in 2: u.legs[j].rotation.x=sin(game.total_time*17+j*PI)*0.55
		update_visual(u)
	capture=minf(0.65,capture+dt) if arresting else maxf(0,capture-dt*2)
	if capture>=0.65: game.arrest_player()

func update_visual(u: Dictionary) -> void:
	u.car.position=game.world.relative_position(u.lane,u.distance,game.distance)
	u.car.rotation.y=game.world.yaw_at(u.distance)
	u.red.visible=fmod(game.total_time,0.28)<0.14
	u.blue.visible=not u.red.visible
	u.officer.visible=u.on_foot
	u.officer.position=game.world.relative_position(u.foot_lane,u.foot_distance,game.distance)
	if u.on_foot:
		var target=game.player.position+game.player.rider.position
		var flat_target=Vector3(target.x,u.officer.position.y,target.z)
		if u.officer.position.distance_to(flat_target)>0.05: u.officer.look_at(flat_target)
