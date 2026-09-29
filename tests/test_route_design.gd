extends SceneTree
const Route=preload("res://scripts/track_route.gd")
const Data=preload("res://scripts/game_data.gd")
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		push_error("FAIL "+label)
func run() -> void:
	for course in 12:
		for choice in 3:
			var route=Route.new()
			route.build(course,Data.race_length(course,choice))
			var tag="%s / %s"%[Data.COURSES[course].id,Data.DISTANCE_NAMES[choice]]
			var k=0.0
			var metres=true
			var returned=false
			for d in range(5,int(route.lap_length),5):
				k=maxf(k,absf(route.curvature(d)))
				metres=metres and absf(route.point(d+1).distance_to(route.point(d))-1)<0.006
				returned=returned or cos(route.heading(d))< -0.1
			check(returned or route.bounds.size.x>route.bounds.size.y,tag+" truly turns back or traverses sideways, not a northbound wavy graph")
			check(k<Route.MAX_CURVATURE and k>0.0001,tag+" actual curvature remains drivable in all directions")
			check(metres,tag+" sampled geometry retains metre arc length")
			var duplicate=Route.new()
			duplicate.build(course,route.length)
			check(duplicate.points==route.points,tag+" seed and authored route regenerate identically")
			var coherent=true
			for fraction in [0.07,0.19,0.37,0.64,0.83,0.98]:
				var d=route.lap_length*fraction
				var rect=Rect2(0,0,220,180)
				var sx=route.project(d,1,rect).distance_to(route.project(d,0,rect))
				var sy=route.project(d+1,0,rect).distance_to(route.project(d,0,rect))
				coherent=coherent and absf(sx/sy-1)<0.01 and rect.grow(0.1).has_point(route.project(d,0,rect))
			check(coherent,tag+" minimap remains equal-scale at each direction of travel")
			var topology=true
			if route.closed:
				topology=route.point(0).distance_to(route.point(route.lap_length))<0.001 and absf(wrapf(route.heading(0)-route.heading(route.lap_length),-PI,PI))<0.001
				for d in [0.0,100.0,route.lap_length-1]: topology=topology and route.point(d).distance_to(route.point(d+route.lap_length))<0.001
			else:
				# Reject actual ribbon crossings, not just control-polygon crossings.
				for a in range(0,int(route.lap_length)-25,25):
					for b in range(a+100,int(route.lap_length)-25,25):
						if Geometry2D.segment_intersects_segment(route.point(a),route.point(a+25),route.point(b),route.point(b+25))!=null: topology=false
			check(topology,tag+" closed seams coincide or open walk has no accidental road crossing")
			print("ROUTE_METRICS ",JSON.stringify({"course":tag,"closed":route.closed,"min_radius_m":1/maxf(k,0.000001),"aspect":route.bounds.size.x/route.bounds.size.y}))
	print("ROUTE_DESIGN_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
