extends RefCounted
## Distance controls amplitude; radial source/listener velocity controls Doppler pitch.
static func sample(offset: Vector2, source_velocity: Vector2, listener_velocity: Vector2) -> Dictionary:
	var distance=offset.length()
	var direction=-offset/maxf(distance,0.5)
	var c=343.0
	var numerator=maxf(80,c-listener_velocity.dot(direction))
	var denominator=maxf(80,c-source_velocity.dot(direction))
	var pitch=clampf(numerator/denominator,0.78,1.28)
	var gain=1.0/sqrt(1+pow(distance/24.0,2))
	gain*=1-smoothstep(240,360,distance)
	return {"distance":distance,"gain":gain,"pitch":pitch}
