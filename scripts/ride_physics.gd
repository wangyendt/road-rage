extends RefCounted
## Track-coordinate suspension/contact solver. No scripted jump impulse:
## a crest releases contact when its downward acceleration exceeds gravity.
## Fixed substeps keep flight stable independently of render frame rate.
const GRAVITY = 19.6 # Arcade tuning (2g); metres and seconds throughout.
var y = 0.0
var velocity = 0.0
var airborne = false
var height = 0.0
var air_time = 0.0
var peak = 0.0
var pitch = 0.0
var compression = 0.0
var launches = 0
var longest_air = 0.0
var flight_start = 0.0

func reset(road, d: float, speed: float = 0.0) -> void:
	y=road.height_at(d)
	velocity=road.slope_at(d)*speed
	airborne=false
	height=0
	air_time=0
	peak=0
	pitch=atan(road.slope_at(d))
	compression=0

func step(road, from: float, to: float, speed: float, dt: float, recovering: bool = false) -> Dictionary:
	var event={"landed":false,"impact":0.0,"time":0.0,"peak":0.0,"distance":0.0}
	if dt<=0: return event
	if recovering and not airborne:
		reset(road,to,speed)
		return event
	var count=maxi(1,ceili(dt*120.0))
	var h=dt/count
	for i in count:
		var a=lerpf(from,to,float(i)/count)
		var b=lerpf(from,to,float(i+1)/count)
		var ground=road.height_at(b)
		if not airborne:
			y=road.height_at(a)
			velocity=road.slope_at(a)*speed
		var predicted=y+velocity*h-0.5*GRAVITY*h*h
		if not airborne and speed>18 and predicted>ground+0.0001:
			airborne=true
			flight_start=a
			air_time=0
			peak=0
			launches+=1
		if airborne:
			y=predicted
			velocity-=GRAVITY*h
			air_time+=h
			peak=maxf(peak,y-ground)
			if y<=ground:
				var impact=maxf(0,road.slope_at(b)*speed-velocity)
				event={"landed":true,"impact":impact,"time":air_time,"peak":peak,"distance":b-flight_start}
				longest_air=maxf(longest_air,air_time)
				compression=clampf(impact/75.0,0.03,0.28)
				airborne=false
				y=ground
				velocity=road.slope_at(b)*speed
		else:
			y=ground
			velocity=road.slope_at(b)*speed
		height=maxf(0,y-ground)
		pitch=lerpf(pitch,clampf(atan2(velocity,maxf(speed,12)),-0.55,0.55),1-exp(-h*9))
		compression=move_toward(compression,0,h*0.6)
	return event
