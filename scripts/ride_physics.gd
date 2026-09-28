extends RefCounted
## Arcade vertical/contact solver, fixed <= 1/120 s substeps, 2g gravity.
## Restitution reflects velocity along the road normal, preserving its tangent.
## Return horizontal impulse to the race integrator; collisions never add energy.
const GRAVITY = 19.6
const SETTLE_SPEED = 2.2
var restitution = 0.0
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
var bounce_chain = 0
var total_bounces = 0

func configure(bike: Dictionary) -> void:
	restitution=clampf(float(bike.get("restitution",0.24)),0,0.8)

func reset(road, d: float, speed: float = 0.0) -> void:
	y=road.height_at(d)
	velocity=road.slope_at(d)*speed
	airborne=false
	height=0
	air_time=0
	peak=0
	pitch=atan(road.slope_at(d))
	compression=0
	bounce_chain=0

func step(road, from: float, to: float, speed: float, dt: float, recovering: bool = false) -> Dictionary:
	var event={"landed":false,"impact":0.0,"time":0.0,"peak":0.0,"distance":0.0,"bounced":false,"chain":0,"contacts":[]}
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
		if not airborne and not recovering and speed>18 and predicted>ground+0.0001:
			airborne=true
			flight_start=a
			air_time=0
			peak=0
			bounce_chain=0
			launches+=1
		if airborne:
			y=predicted
			velocity-=GRAVITY*h
			air_time+=h
			peak=maxf(peak,y-ground)
			if y<=ground:
				var slope=road.slope_at(b)
				var normal=Vector2(-slope,1).normalized()
				var incoming=Vector2(speed,velocity)
				var impact=maxf(0,-incoming.dot(normal))
				var rebound=impact*restitution if not recovering else 0.0
				var bounces=rebound>=SETTLE_SPEED and peak>0.08
				var outgoing=incoming+normal*impact*(1.0+(restitution if bounces else 0.0))
				outgoing.x=maxf(0,outgoing.x) # No reverse racing; removes rather than adds energy.
				var contact={"forward_speed":outgoing.x,"incoming_energy":incoming.length_squared(),"outgoing_energy":outgoing.length_squared(),"landed":true,"impact":impact,"time":air_time,"peak":peak,"distance":b-flight_start,"bounced":bounces,"chain":bounce_chain,"outgoing":rebound if bounces else 0.0}
				event.contacts.append(contact)
				for key in contact: event[key]=contact[key]
				longest_air=maxf(longest_air,air_time)
				compression=clampf(impact/75.0,0.03,0.36)
				y=ground
				airborne=bounces
				velocity=outgoing.y if bounces else slope*outgoing.x
				if bounces:
					bounce_chain+=1
					total_bounces+=1
					flight_start=b
					air_time=0
					peak=0
				else: bounce_chain=0
		else:
			y=ground
			velocity=road.slope_at(b)*speed
		height=maxf(0,y-ground)
		pitch=lerpf(pitch,clampf(atan2(velocity,maxf(speed,12)),-0.85,0.85),1-exp(-h*9))
		compression=move_toward(compression,0,h*0.6)
	return event
