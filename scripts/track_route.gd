extends RefCounted
## Arc-length-sampled 2D routes. Closed circuits use race distance for laps,
## never an artificially elongated silhouette. Open routes use seeded walks.
const STEP=5.0
const MAX_CURVATURE=0.018 # Safety bound, not an enforced heading direction.
const PROFILES=[
	{"span":5400.0,"style":"港岛闭环 / 不规则环湾","closed":true,"seed":901,"knots":[[0,0],[0,2],[1,3.4],[3.2,3.1],[4.1,1.5],[3.3,-0.3],[1,-1.0]]},
	{"span":4800.0,"style":"峡谷探路 / 随机走向","closed":false,"seed":1777,"turn":75.0},
	{"span":5200.0,"style":"雪岭穿越 / 不规则远征","closed":false,"seed":3181,"turn":78.0},
	{"span":6200.0,"style":"都市环线 / 圆角街区","closed":true,"seed":47,"knots":[[0,0],[0,2.5],[0.8,3.3],[3.8,3.3],[4.5,2.5],[4.5,0],[3.7,-0.8],[0.8,-0.8]]},
	{"span":6800.0,"style":"海湾环岸 / C 湾闭环","closed":true,"seed":772,"knots":[[0,0],[0,2],[1,3.5],[3.4,4],[5,3],[5.4,1],[4.5,-1],[2.6,-1.6]]},
	{"span":7200.0,"style":"风机三叶 / 丘陵闭环","closed":true,"seed":855,"knots":[[0,0],[-0.8,1.7],[0,3],[1.4,2.8],[2,1.8],[3.6,2.8],[4.6,2],[4.1,0.5],[2.8,0],[2.7,-1.8],[1,-2.1],[0.3,-1]]},
	{"span":5800.0,"style":"矿坑肾形 / 内湾闭环","closed":true,"seed":498,"knots":[[0,0],[0,2.5],[1.5,3.6],[3.6,3.1],[4.2,1.3],[2.6,0.6],[2.6,-1.0],[1,-1.6]]},
	{"span":6600.0,"style":"雨脊迷途 / 随机变向","closed":false,"seed":9213,"turn":82.0},
	{"span":8600.0,"style":"云端双翼 / 非对称闭环","closed":true,"seed":2026,"knots":[[0,0],[-0.3,1.8],[0.8,3.8],[2.4,4.0],[3.2,2.4],[2.6,1.2],[4.1,0.5],[4.5,-1.2],[3.3,-2.3],[1.7,-1.8],[1.5,-0.5]]},
	{"span":8200.0,"style":"火山环口 / 火山口闭环","closed":true,"seed":911,"knots":[[0,0],[-0.1,2.1],[1,3.8],[3.1,4.2],[4.5,2.8],[4.1,1.3],[4.8,-0.3],[3.2,-1.7],[1.2,-1.5]]},
	{"span":9000.0,"style":"荒原远征 / 随机折向","closed":false,"seed":3179,"turn":85.0},
	{"span":9400.0,"style":"冰川多湾 / 冰谷闭环","closed":true,"seed":1123,"knots":[[0,0],[0,2],[1.1,3.3],[2.2,2.7],[2.6,1.7],[4,2.3],[5,1.2],[4.6,-0.6],[3,-1.2],[1.8,-0.6],[0.5,-1.3]]}
]
var points=PackedVector2Array()
var headings=PackedFloat64Array()
var length=0.0
var lap_length=0.0
var closed=false
var course_index=0
var bounds=Rect2()
var winding=0.0

func build(index: int, metres: float) -> void:
	course_index=clampi(index,0,PROFILES.size()-1)
	length=maxf(metres,100)
	var profile=PROFILES[course_index]
	closed=profile.closed
	lap_length=float(profile.span) if closed else length
	var controls=PackedVector2Array()
	if profile.has("knots"):
		for pair in profile.knots: controls.append(Vector2(pair[0],pair[1]))
	else:
		controls=_walk(profile,int(ceil(length/700.0)))
	var dense=PackedVector2Array()
	var segments=controls.size() if closed else controls.size()-1
	for i in segments:
		var a=controls[posmod(i-1,controls.size())] if closed or i>0 else controls[0]*2-controls[1]
		var b=controls[i]
		var c=controls[(i+1)%controls.size()]
		var e=controls[(i+2)%controls.size()] if closed or i+2<controls.size() else c*2-b
		var samples=maxi(120,ceili(lap_length/segments))
		for j in samples:
			var t=float(j)/samples
			dense.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-e)*t*t+(-a+3*b-3*c+e)*t*t*t))
	dense.append(controls[0] if closed else controls[-1])
	var lengths=PackedFloat64Array([0.0])
	for i in range(1,dense.size()): lengths.append(lengths[-1]+dense[i].distance_to(dense[i-1]))
	var factor=lap_length/lengths[-1]
	var facing=(dense[1]-dense[0]).angle()-PI/2
	var origin=dense[0]
	for i in dense.size(): dense[i]=(dense[i]-origin).rotated(-facing)*factor
	for i in lengths.size(): lengths[i]*=factor
	points=PackedVector2Array()
	var cursor=0
	var count=ceili(lap_length/STEP)
	for i in count+1:
		var d=minf(i*STEP,lap_length)
		while cursor+1<lengths.size()-1 and lengths[cursor+1]<d: cursor+=1
		points.append(dense[cursor].lerp(dense[cursor+1],(d-lengths[cursor])/maxf(0.000001,lengths[cursor+1]-lengths[cursor])))
	headings=PackedFloat64Array()
	for i in points.size():
		var tangent: Vector2
		if closed and (i==0 or i==count): tangent=points[1]-points[count-1]
		else: tangent=points[mini(i+1,count)]-points[maxi(i-1,0)]
		var angle=atan2(tangent.x,tangent.y)
		if i>0: angle=headings[-1]+wrapf(angle-headings[-1],-PI,PI)
		headings.append(angle)
	winding=headings[-1]-headings[0] if closed else 0.0
	bounds=Rect2(points[0],Vector2.ZERO)
	for p in points: bounds=bounds.expand(p)

func _walk(profile: Dictionary, count: int) -> PackedVector2Array:
	# Deterministic self-avoiding random walk, with no privileged north direction.
	# Local corners remain bounded; the accumulated heading is free to circle back.
	var rng=RandomNumberGenerator.new()
	rng.seed=profile.seed
	var path=PackedVector2Array([Vector2.ZERO,Vector2(0,1)])
	var angle=0.0
	for i in count:
		var candidate=Vector2.ZERO
		var chosen=angle
		for attempt in 100:
			chosen=angle+deg_to_rad(rng.randf_range(-profile.turn,profile.turn))
			candidate=path[-1]+Vector2(sin(chosen),cos(chosen))*rng.randf_range(0.9,1.5)
			var clear=true
			for k in range(path.size()-2):
				if Geometry2D.segment_intersects_segment(path[-1],candidate,path[k],path[k+1])!=null or Geometry2D.get_closest_point_to_segment(candidate,path[k],path[k+1]).distance_to(candidate)<0.7:
					clear=false
					break
			if clear: break
			if attempt==99:
				# Restart with a deterministic next seed rather than accepting a crossing.
				var retry=profile.duplicate()
				retry.seed+=101
				return _walk(retry,count)
		path.append(candidate)
		angle=chosen
	return path

func _at(d: float) -> float:
	return fposmod(d,lap_length) if closed else clampf(d,0,lap_length)
func heading(d: float) -> float:
	var at=_at(d)
	var i=mini(int(at/STEP),points.size()-2)
	var t=(at-i*STEP)/maxf(0.001,minf(STEP,lap_length-i*STEP))
	return lerpf(headings[i],headings[i+1],t)+(floor(d/lap_length)*winding if closed else 0.0)
func curvature(d: float) -> float:
	return wrapf(heading(d+0.5)-heading(d-0.5),-PI,PI)
func point(d: float, lane: float = 0) -> Vector2:
	var at=_at(d)
	var i=mini(int(at/STEP),points.size()-2)
	var p=points[i].lerp(points[i+1],(at-i*STEP)/maxf(0.001,minf(STEP,lap_length-i*STEP)))
	var angle=heading(d)
	if not closed: p+=Vector2(sin(angle),cos(angle))*(d-at)
	return p+Vector2(cos(angle),-sin(angle))*lane
func project(d: float, lane: float, rect: Rect2) -> Vector2:
	var scale=minf(rect.size.x/maxf(bounds.size.x,1),rect.size.y/maxf(bounds.size.y,1))
	var p=(point(d,lane)-bounds.get_center())*scale
	return rect.get_center()+Vector2(p.x,-p.y)
func lap(d: float) -> int:
	return mini(int(maxf(d,0)/lap_length)+1,maxi(1,roundi(length/lap_length)))

func gap(other: float, observer: float) -> float:
	return wrapf(other-observer,-lap_length/2,lap_length/2) if closed else other-observer
