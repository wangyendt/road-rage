extends RefCounted
## Shared plan-view metre coordinates. d is horizontal arc length, not a display graph.
const STEP=5.0
# amplitude (radians), waves, phase, second harmonic, long-direction bias.
const PROFILES=[
	[0.42,0.80,0.10,0.08,0.03],[0.54,1.35,0.40,0.07,-0.03],
	[0.48,1.05,1.30,0.08,0.02],[0.36,1.70,0.90,0.10,0.04],
	[0.52,0.65,-0.50,0.06,0.08],[0.48,1.80,0.10,0.06,-0.02],
	[0.45,1.25,2.10,0.12,0.02],[0.52,1.60,1.20,0.08,-0.03],
	[0.42,0.90,2.70,0.08,0.0],[0.51,1.15,-0.80,0.09,0.04],
	[0.50,1.95,2.30,0.05,-0.04],[0.46,0.72,1.00,0.10,-0.02]]
var points=PackedVector2Array()
var length=0.0
var course_index=0
var bounds=Rect2()
func build(index: int, metres: float) -> void:
	course_index=index
	length=metres
	points=PackedVector2Array([Vector2.ZERO])
	for i in ceili(length/STEP):
		var a=i*STEP
		var ds=minf(STEP,length-a)
		var angle=heading(a+ds*0.5)
		points.append(points[-1]+Vector2(sin(angle),cos(angle))*ds)
	bounds=Rect2(points[0],Vector2.ZERO)
	for p in points: bounds=bounds.expand(p)
func heading(d: float) -> float:
	var p=PROFILES[course_index]
	var t=clampf(d/maxf(length,1),0,1)
	return p[0]*sin(TAU*p[1]*t+p[2])+p[3]*sin(TAU*(p[1]+0.8)*t-p[2])+p[4]
func point(d: float, lane: float = 0) -> Vector2:
	var at=clampf(d,0,length)
	var i=mini(int(at/STEP),points.size()-2)
	var a=i*STEP
	var p=points[i].lerp(points[i+1],(at-a)/maxf(0.001,minf(STEP,length-a)))
	var angle=heading(at)
	p+=Vector2(sin(angle),cos(angle))*(d-at)
	return p+Vector2(cos(angle),-sin(angle))*lane
func project(d: float, lane: float, rect: Rect2) -> Vector2:
	var scale=minf(rect.size.x/maxf(bounds.size.x,1),rect.size.y/maxf(bounds.size.y,1))
	var p=(point(d,lane)-bounds.get_center())*scale
	return rect.get_center()+Vector2(p.x,-p.y)
