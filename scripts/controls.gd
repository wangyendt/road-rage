extends RefCounted
const ORDER = ["steer_left","steer_right","brake","boost","attack_left","attack_right","attack_auto","pause_game","show_roster","toggle_map","toggle_mirror"]
const LABELS = {"steer_left":"向左转向","steer_right":"向右转向","brake":"刹车","boost":"氮气加速","attack_left":"向左攻击","attack_right":"向右攻击","attack_auto":"自动选边攻击","pause_game":"暂停 / 继续","show_roster":"车手信息","toggle_map":"显示小地图","toggle_mirror":"显示后视镜"}
const DEFAULTS = {"steer_left":KEY_A,"steer_right":KEY_D,"brake":KEY_S,"boost":KEY_SPACE,"attack_left":KEY_J,"attack_right":KEY_K,"attack_auto":KEY_SHIFT,"pause_game":KEY_P,"show_roster":KEY_TAB,"toggle_map":KEY_V,"toggle_mirror":KEY_B}
const RESERVED = [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_F11,KEY_M,KEY_R]
var keys: Dictionary = DEFAULTS.duplicate()

func apply() -> void:
	for action in ORDER:
		if not InputMap.has_action(action): InputMap.add_action(action,0.16)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = int(keys[action])
		InputMap.action_add_event(action,event)
	for row in [["steer_left",KEY_LEFT],["steer_right",KEY_RIGHT],["brake",KEY_DOWN]]:
		var event = InputEventKey.new()
		event.physical_keycode = row[1]
		InputMap.action_add_event(row[0],event)
	for row in [["steer_left",JOY_AXIS_LEFT_X,-1.0],["steer_right",JOY_AXIS_LEFT_X,1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0],["boost",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = row[1]
		event.axis_value = row[2]
		InputMap.action_add_event(row[0],event)
	for row in [["boost",JOY_BUTTON_A],["attack_left",JOY_BUTTON_LEFT_SHOULDER],["attack_right",JOY_BUTTON_RIGHT_SHOULDER],["pause_game",JOY_BUTTON_START],["show_roster",JOY_BUTTON_BACK]]:
		var event = InputEventJoypadButton.new()
		event.button_index = row[1]
		InputMap.action_add_event(row[0],event)

func rebind(action: String, key: int) -> String:
	if not keys.has(action) or key==0: return "请选择有效按键"
	if key in RESERVED: return "此键保留给菜单、方向键或系统快捷键"
	var old = keys[action]
	var swapped = ""
	for other in ORDER:
		if other!=action and keys[other]==key:
			keys[other] = old
			swapped = "；已与「"+LABELS[other]+"」交换"
	keys[action] = key
	apply()
	return "已设为 "+label(action)+swapped

func label(action: String) -> String:
	var key = int(keys.get(action,KEY_NONE))
	if key==KEY_SPACE: return "SPACE"
	if key==KEY_SHIFT: return "SHIFT"
	if key==KEY_TAB: return "TAB"
	return OS.get_keycode_string(key).to_upper()

func load_config(file: ConfigFile) -> void:
	keys = DEFAULTS.duplicate()
	var loaded: Dictionary = {}
	var used: Array[int] = []
	for action in ORDER:
		var key = int(file.get_value("keys",action,DEFAULTS[action]))
		if key<=0 or key in RESERVED or key in used:
			keys = DEFAULTS.duplicate()
			apply()
			return
		loaded[action] = key
		used.append(key)
	keys = loaded
	apply()

func save_config(file: ConfigFile) -> void:
	for action in ORDER: file.set_value("keys",action,keys[action])
