extends "res://tests/test_ui.gd"
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.start_race()
	var rect=game.hud.MAP_RECT
	var a=game.hud._map_position(1500,0,rect)
	var b=game.hud._map_position(1500,1,rect)
	var c=game.hud._map_position(1501,0,rect)
	var wx=game.world.relative_position(1,1500,1500).length()
	var wz=game.world.relative_position(0,1501,1500).length()
	var ratio=(b-a).length()/wx/((c-a).length()/wz)
	print("MAP_AXIS_SCALE_RATIO ",ratio)
	check(absf(ratio-1)<0.02,"map must use the same scale along and across the actual road")
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.2).timeout
	quit(1 if failed else 0)
