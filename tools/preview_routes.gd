extends SceneTree
const Route=preload("res://scripts/track_route.gd")
const Data=preload("res://scripts/game_data.gd")
class Atlas extends Control:
	var font=load("res://assets/fonts/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1050),Color("09131f"))
		draw_string(font,Vector2(36,46),"ROAD RAGE  /  环线与随机远征",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("e7f2fa"))
		draw_string(font,Vector2(36,80),"短程实际俯视路线 · 闭环起终点重合 · 圆点起点 / 方块终点",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("91acbc"))
		for i in 12:
			var p=Vector2(32+(i%4)*350,106+int(i/4)*308)
			var color=Data.COURSES[i].color
			draw_rect(Rect2(p,Vector2(326,290)),Color("132331"))
			draw_string(font,p+Vector2(14,29),Data.COURSES[i].name,HORIZONTAL_ALIGNMENT_LEFT,-1,22,color)
			draw_string(font,p+Vector2(14,53),Route.PROFILES[i].style,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("91acbc"))
			var route=Route.new()
			route.build(i,Data.race_length(i,0))
			var rect=Rect2(p+Vector2(22,75),Vector2(280,191))
			var points=PackedVector2Array()
			for n in 1001: points.append(route.project(route.length*n/1000.0,0,rect))
			draw_polyline(points,Color(color,0.15),11,true)
			draw_polyline(points,color,3,true)
			draw_circle(points[0],5,Color("ffffff"))
			draw_rect(Rect2(points[-1]-Vector2(4,4),Vector2(8,8)),Color("ffffff"))
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1050)
	root.add_child(Atlas.new())
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/test-screenshots")
	root.get_texture().get_image().save_png("res://builds/test-screenshots/v49-route-atlas.png")
	quit()
