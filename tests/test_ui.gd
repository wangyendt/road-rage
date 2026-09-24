extends SceneTree
var game: Node
var passed = 0
var failed = 0
func _init() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS UI ",label)
	else:
		failed += 1
		push_error("FAIL UI "+label)
func click(action: String) -> void:
	await process_frame
	await process_frame
	for button in game.hud.buttons:
		if button.action == action:
			var point = button.rect.get_center()*game.hud.ui_scale+game.hud.ui_offset
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = point
			root.push_input(event,true)
			event = event.duplicate()
			event.pressed = false
			root.push_input(event,true)
			await process_frame
			return
	check(false,"button exists: "+action)
func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory = ProjectSettings.globalize_path("res://builds/test-screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+"/"+name+".png")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await create_timer(0.5).timeout
	await click("help")
	check(game.state=="help","mouse opens driving guide")
	await capture("controls")
	await key(KEY_ESCAPE)
	check(game.state=="menu","Escape returns from guide")
	await click("settings")
	check(game.state=="settings","mouse opens settings")
	game.settings.volume = 1.0
	await click("volume")
	check(game.settings.volume==0.0,"volume cycles from full to silent")
	game.settings.volume = 0.8
	var music_before = game.settings.music
	await click("music")
	check(game.settings.music!=music_before,"music toggle works")
	await click("music")
	await capture("settings")
	await click("back")
	await key(KEY_ENTER)
	check(game.state=="countdown","Enter starts race")
	await key(KEY_ESCAPE)
	check(game.state=="paused","Escape pauses countdown")
	await click("settings")
	await key(KEY_ESCAPE)
	await click("resume")
	check(game.state=="countdown","mouse resumes countdown after settings")
	await create_timer(3.7).timeout
	check(game.state=="race","countdown reaches race in live rendered app")
	await key(KEY_P)
	check(game.state=="paused","P pauses race")
	await capture("pause")
	await click("menu")
	check(game.state=="menu","mouse returns to main menu")
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(game.state=="help","keyboard navigation selects and activates menu item")
	await key(KEY_M)
	check(game.sound.muted,"M mutes audio")
	print("UI_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.queue_free()
	await create_timer(1.0).timeout
	quit(1 if failed else 0)
