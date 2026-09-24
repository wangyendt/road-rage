extends Control
## Resolution-independent, keyboard/gamepad-accessible arcade interface.
const Data = preload("res://scripts/game_data.gd")
const Controls = preload("res://scripts/controls.gd")
const INK = Color("101c2d")
const WHITE = Color("e9f3f3")
const MUTED = Color("a0b5c2")
const ORANGE = Color("ff8257")
const CYAN = Color("8be7ec")
var game: Node
var title_font: SystemFont
var body_font: SystemFont
var number_font: SystemFont
var buttons: Array[Dictionary] = []
var selected = 0
var ui_scale = 1.0
var ui_offset = Vector2.ZERO
var mouse = Vector2(-100,-100)
var mouse_active = false

func _ready() -> void:
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["DIN Condensed","Arial Narrow","sans-serif"])
	title_font.font_weight = 800
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	number_font = SystemFont.new()
	number_font.font_names = PackedStringArray(["DIN Alternate","Arial","sans-serif"])
	number_font.font_weight = 700
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = (event.position-ui_offset)/ui_scale
		mouse_active = true
		for i in buttons.size():
			if buttons[i].rect.has_point(mouse): selected = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at = (event.position-ui_offset)/ui_scale
		for button in buttons:
			if button.rect.has_point(at):
				game.ui_action(button.action)
				accept_event()
				break

func activate_selected() -> void:
	if buttons.size()>0:
		game.ui_action(buttons[clampi(selected,0,buttons.size()-1)].action)

func move_selection(delta: int) -> void:
	mouse_active = false
	if buttons.size()>0:
		selected = posmod(selected+delta,buttons.size())
		game.sound.sfx("click",-12)

func _draw() -> void:
	if not game or not title_font: return
	var dimensions = get_viewport_rect().size
	ui_scale = minf(dimensions.x/1440.0,dimensions.y/900.0)
	ui_offset = (dimensions-Vector2(1440,900)*ui_scale)*0.5
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	buttons.clear()
	match game.state:
		"menu": _menu()
		"setup": _setup()
		"roster": _roster()
		"profile": _profile()
		"bindings": _bindings()
		"race", "countdown": _race()
		"paused":
			_race(false)
			_pause()
		"settings": _settings()
		"help": _help()
		"finished": _results()
	if game.sound.muted:
		_text("声音已静音  /  M 恢复",Vector2(1190,878),15,MUTED)

func _text(value: String, pos: Vector2, size: int = 20, color: Color = WHITE, font: Font = null) -> void:
	draw_string(font if font else body_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(value: String, center: Vector2, size: int, color: Color = WHITE, font: Font = null) -> void:
	var f = font if font else body_font
	var width = f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(value,center-Vector2(width/2,0),size,color,f)

func _panel(rect: Rect2, color: Color, radius: int = 10, border: Color = Color.TRANSPARENT) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border.a>0:
		sb.set_border_width_all(1)
		sb.border_color = border
	draw_style_box(sb,rect)

func _button(action: String, label: String, rect: Rect2, primary: bool = false, hint: String = "") -> void:
	var index = buttons.size()
	var focus = index == selected
	var bg = Color(0.07,0.13,0.21,0.86)
	if primary: bg = ORANGE
	elif focus: bg = Color("2c4856")
	var fg = INK if primary else WHITE
	_panel(rect,bg,5,WHITE if focus else Color(0.6,0.8,0.9,0.16))
	if focus: draw_rect(Rect2(rect.position+Vector2(0,8),Vector2(3,rect.size.y-16)),INK if primary else CYAN)
	_text(label,rect.position+Vector2(23,rect.size.y*0.5+8),22,fg)
	if not hint.is_empty():
		var width = body_font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		_text(hint,rect.position+Vector2(rect.size.x-width-20,rect.size.y*.5+5),15,fg if primary else MUTED)
	buttons.append({"action":action,"rect":rect})

func _shade(alpha: float = 0.75) -> void:
	draw_rect(Rect2(-ui_offset/ui_scale,get_viewport_rect().size/ui_scale),Color(0.025,0.055,0.1,alpha))

func _menu() -> void:
	# A left-weighted cinematic scrim keeps the procedural hero bike visible.
	draw_rect(Rect2(-ui_offset.x/ui_scale,-ui_offset.y/ui_scale,560+ui_offset.x/ui_scale,900+ui_offset.y*2/ui_scale),Color(0.025,0.055,0.1,0.82))
	for i in 32:
		draw_rect(Rect2(560+i*15,0,15,900),Color(0.025,0.055,0.1,0.82*(1-float(i)/32)))
	_panel(Rect2(64,48,38,34),ORANGE,3)
	_text("R",Vector2(75,74),27,INK,title_font)
	_text("ROAD RAGE  /  ORIGINAL ARCADE",Vector2(117,72),16,MUTED,number_font)
	_text("FULL THROTTLE. NO APOLOGIES.",Vector2(68,153),17,CYAN,number_font)
	_text("ROAD",Vector2(59,288),156,WHITE,title_font)
	_text("RAGE",Vector2(59,420),174,ORANGE,title_font)
	_text("极 限 狂 飙",Vector2(68,467),29,WHITE)
	_text("抢占赛道。放倒对手。第一个冲线。",Vector2(68,510),18,MUTED)
	_button("start","开始狂飙",Rect2(68,550,362,64),true,"ENTER  →")
	_button("roster","车手档案",Rect2(68,630,362,52),false,"15 RIDERS")
	_button("settings","游戏设置",Rect2(68,695,173,52))
	_button("help","驾驶指南",Rect2(255,695,175,52))
	_button("quit","退出游戏",Rect2(68,760,362,44),false,"QUIT")
	_text("BEST  %06d" % game.best_score,Vector2(68,853),16,MUTED,number_font)
	_text("离线单机  /  原创 3D 街机竞速",Vector2(263,853),14,MUTED)
	_text(Data.COURSES[game.race_options.course].en,Vector2(1040,84),26,WHITE,title_font)
	_text("%s · %.1f KM"%[Data.COURSES[game.race_options.course].name,Data.COURSES[game.race_options.course].length/1000],Vector2(1040,112),17,MUTED)
	draw_line(Vector2(1100,131),Vector2(1369,131),Color(0.7,0.85,0.9,0.3),1,true)
	_text("UP TO 16 RIDERS",Vector2(1040,159),17,CYAN,number_font)
	_text("1 FINISH LINE",Vector2(1234,159),17,WHITE,number_font)
	_panel(Rect2(1102,757,266,85),Color(0.04,0.1,0.17,0.7),5)
	_text("你的座驾",Vector2(1121,784),14,MUTED)
	_text("RR–09 / INTERCEPTOR",Vector2(1121,819),25,WHITE,title_font)

func _race(interactive: bool = true) -> void:
	# Peripheral speed streaks leave the road and collision cues unobstructed.
	if game.boost_active and game.state == "race":
		for i in 25:
			var angle = i*2.39996
			var radius = 430+fmod(game.total_time*720+i*91,360)
			var dir = Vector2(cos(angle),sin(angle)*0.7)
			draw_line(Vector2(720,440)+dir*radius,Vector2(720,440)+dir*(radius+55),Color(0.7,0.94,1,0.3),1.4,true)
	_panel(Rect2(32,28,243,97),Color(0.04,0.09,0.15,0.78),7)
	_text("ROAD RAGE",Vector2(48,61),27,WHITE,title_font)
	var sectors = ["01 / "+game.world.course.name,"02 / 中段追逐","03 / 终点决战"]
	_text(sectors[mini(2,int(game.distance/(game.track_length/3)))],Vector2(48,99),19,CYAN)
	var rank = game.rank_now()
	_text("%02d"%rank,Vector2(48,202),77,WHITE,number_font)
	_text("/ %02d"%(game.rivals.size()+1),Vector2(144,199),27,MUTED,number_font)
	_text("当前名次",Vector2(49,227),14,MUTED)
	_text("%06d"%game.score,Vector2(49,280),33,WHITE,number_font)
	_text("SCORE",Vector2(49,302),13,MUTED,number_font)
	# Track progression, with actual sector boundaries.
	var start = Vector2(350,54)
	var w = 696.0
	draw_line(start,start+Vector2(w,0),Color(0.4,0.55,0.63,0.55),4,true)
	draw_line(start,start+Vector2(w*clampf(game.distance/game.track_length,0,1),0),CYAN,4,true)
	for i in 4:
		var pos = start+Vector2(w*i/3,0)
		draw_circle(pos,4,CYAN if i*game.track_length/3<=game.distance else MUTED)
	draw_circle(start+Vector2(w*clampf(game.distance/game.track_length,0,1),0),7,WHITE)
	_text(game.world.course.en+" / LV.%d"%game.active_level,Vector2(350,86),14,MUTED,number_font)
	_text("%.2f / %.2f KM"%[game.distance/1000,game.track_length/1000],Vector2(879,86),16,WHITE,number_font)
	_text(_time(game.elapsed),Vector2(1138,70),37,WHITE,number_font)
	_text("RACE TIME",Vector2(1150,94),12,MUTED,number_font)
	if interactive: _button("back","Ⅱ",Rect2(1350,32,52,46))
	# Durability and nitro: separated spatially from speed.
	_panel(Rect2(32,764,300,103),Color(0.04,0.09,0.15,0.83),7)
	_text("车体耐久",Vector2(50,794),16,MUTED)
	_text("%03d"%ceili(game.health),Vector2(249,796),23,WHITE,number_font)
	for i in 10:
		var col = ORANGE if game.health<30 else WHITE
		draw_rect(Rect2(51+i*25,811,19,13),col if game.health>i*10 else Color("2b4150"))
	_text("击倒 %02d   ·   擦身 %02d"%[game.takedowns,game.near_misses],Vector2(50,850),14,MUTED)
	_panel(Rect2(480,799,466,65),Color(0.04,0.09,0.15,0.85),7)
	_text("NITRO",Vector2(500,826),17,CYAN,number_font)
	_text(game.controls.label("boost")+"  氮气加速",Vector2(775,824),14,WHITE)
	draw_rect(Rect2(500,839,423,7),Color("284350"))
	draw_rect(Rect2(500,839,423*game.nitro/100,7),CYAN if not game.boost_active else WHITE)
	if game.boost_active: _center("超 频 加 速",Vector2(713,777),22,CYAN)
	var c = Vector2(1274,755)
	draw_circle(c,100,Color(0.04,0.09,0.15,0.83))
	draw_arc(c,88,PI*0.72,PI*2.28,65,Color("334c5a"),4,true)
	draw_arc(c,88,PI*0.72,PI*0.72+PI*1.56*game.speed/99,65,ORANGE if game.boost_active else CYAN,5,true)
	for i in 21:
		var a = PI*.72+PI*1.56*i/20
		var dir = Vector2(cos(a),sin(a))
		draw_line(c+dir*77,c+dir*(69 if i%5==0 else 73),MUTED,1,true)
	_center("%03d"%int(game.speed*3.6),c+Vector2(0,20),58,WHITE,number_font)
	_center("KM/H",c+Vector2(0,46),14,MUTED,number_font)
	_center("N" if game.speed<1 else "G%d"%clampi(int(game.speed/16)+1,1,6),c+Vector2(0,-40),18,ORANGE,number_font)
	_center("%s/%s 转向   %s 刹车   %s/%s 攻击   %s 氮气   %s 车手信息   ESC 暂停"%[game.controls.label("steer_left"),game.controls.label("steer_right"),game.controls.label("brake"),game.controls.label("attack_left"),game.controls.label("attack_right"),game.controls.label("boost"),game.controls.label("show_roster")],Vector2(724,889),13,MUTED)
	if game.combo>1 and game.combo_time>0:
		_text("%d×"%game.combo,Vector2(1280,255),57,ORANGE,number_font)
		_text("连击",Vector2(1300,282),16,WHITE)
		var fraction = game.combo_time/5
		draw_line(Vector2(1280,300),Vector2(1280+90*fraction,300),ORANGE,3,true)
	_draw_rival_markers()
	_standings_board(interactive)
	if game.settings.map: _minimap()
	if game.settings.mirror: _rear_view()
	if game.message_time>0 and game.state=="race":
		var a = minf(game.message_time*3,1)
		var color = game.message_color
		color.a = a
		_center(game.message,Vector2(720,288),32,color)
		_center(game.message_sub,Vector2(720,321),15,Color(0.9,0.96,0.96,a))
	if game.elapsed<7 and game.state=="race" and game.message_time<=0:
		_center("自动油门 · 靠近对手后，按 %s / %s 出击"%[game.controls.label("attack_left"),game.controls.label("attack_right")],Vector2(720,320),19,WHITE)
	if game.player.recovery_time>0:
		_panel(Rect2(475,660,490,96),Color(0.04,0.08,0.14,0.88),8)
		_center(game.player.recovery_stage,Vector2(720,693),26,ORANGE)
		_center("自动恢复中 · 对手仍在前进",Vector2(720,720),15,MUTED)
		draw_rect(Rect2(496,736,448,5),Color("304958"))
		draw_rect(Rect2(496,736,448*(1-game.player.recovery_time/game.player.recovery_duration),5),ORANGE)
	elif game.catchup_help>2:
		_center("追赶辅助生效 · 引擎响应与氮气恢复提升",Vector2(720,756),14,CYAN)
	if game.state=="countdown":
		var n = ceili(game.countdown)
		draw_circle(Vector2(720,391),79,Color(0.03,0.09,0.15,0.75))
		_center(str(mini(3,n)),Vector2(720,429),112,WHITE,number_font)
		_center("准备出发",Vector2(720,527),26,CYAN)
		_center("自动油门  /  %s %s 转向  /  %s %s 攻击  /  %s 加速"%[game.controls.label("steer_left"),game.controls.label("steer_right"),game.controls.label("attack_left"),game.controls.label("attack_right"),game.controls.label("boost")],Vector2(720,567),18,WHITE)

func _draw_rival_markers() -> void:
	var candidates = game.rivals.duplicate()
	candidates.sort_custom(func(a,b): return absf(a.distance-game.distance)<absf(b.distance-game.distance))
	var occupied: Array[Rect2] = []
	for r in candidates:
		var gap = r.distance-game.distance
		if gap < -3 or gap>55 or r.hp<=0: continue
		var pos = r.node.position+Vector3(0,3.1,0)
		if game.camera.is_position_behind(pos): continue
		var screen = (game.camera.unproject_position(pos)-ui_offset)/ui_scale
		if screen.x<60 or screen.x>1380 or screen.y<140 or screen.y>725: continue
		var label_rect = Rect2(screen-Vector2(52,28),Vector2(104,48))
		var overlaps = false
		for used in occupied:
			if label_rect.intersects(used): overlaps = true
		if overlaps or occupied.size()>=4: continue
		occupied.append(label_rect)
		var warning = r.windup>0
		var color = ORANGE if warning else r.color
		var ready = absf(r.lane-game.lane)<3.5 and absf(gap)<6.4
		_center(("瞄准你 !" if r.target_id==-1 else "交战中") if warning else r.name,screen,15,color,body_font if warning else number_font)
		for i in 2:
			draw_rect(Rect2(screen+Vector2(-24+i*27,8),Vector2(21,4)),color if r.hp>i else Color("344757"))
		if ready:
			_center("[ %s ]"%game.controls.label("attack_left" if r.lane<game.lane else "attack_right"),screen+Vector2(0,-25),23,CYAN,number_font)

func _pause() -> void:
	buttons.clear()
	_shade(0.75)
	_panel(Rect2(458,205,524,523),Color(0.035,0.08,0.13,0.95),13,Color("304856"))
	_center("PIT STOP",Vector2(720,290),55,WHITE,title_font)
	_center("比赛已暂停",Vector2(720,331),20,MUTED)
	_button("resume","继续狂飙",Rect2(522,371,396,61),true,"ESC")
	_button("retry","重新开始",Rect2(522,448,396,55),false,"RESTART")
	_button("settings","游戏设置",Rect2(522,518,396,55))
	_button("menu","返回主菜单",Rect2(522,588,396,55))
	_center("切换窗口时自动暂停，不丢失比赛进度。",Vector2(720,689),15,MUTED)

func _settings() -> void:
	_shade(0.87)
	_text("TUNE YOUR RIDE",Vector2(292,116),53,WHITE,title_font)
	_text("游戏设置",Vector2(292,158),23,CYAN)
	var rows = [["volume","主音量","%d%%"%roundi(game.settings.volume*100)],["music","电子配乐","开启" if game.settings.music else "关闭"],["shake","镜头震动","开启" if game.settings.shake else "关闭"],["quality","渲染质量","精致 · 120 FPS 上限" if game.settings.quality else "流畅 · 60 FPS 上限"],["map","赛道小地图","显示" if game.settings.map else "隐藏"],["mirror","实时后视镜","显示" if game.settings.mirror else "隐藏"],["bindings","修改快捷键","KEY BINDINGS  →"]]
	for i in rows.size(): _button(rows[i][0],rows[i][1],Rect2(292,201+i*68,856,53),false,rows[i][2])
	_text("AI 数量、场景和五档难度在赛前设置；快捷键会自动保存。",Vector2(292,727),16,MUTED)
	_button("back","返回",Rect2(292,766,250,55),true,"ESC")

func _help() -> void:
	_shade(0.88)
	_text("LEARN THE STREETS",Vector2(180,136),56,WHITE,title_font)
	_text("驾驶指南",Vector2(180,184),24,CYAN)
	var rows = [[game.controls.label("steer_left")+" / "+game.controls.label("steer_right"),"左右转向（方向键也可用）","左摇杆"],[game.controls.label("brake"),"刹车 · 松开恢复自动油门","LT"],[game.controls.label("boost"),"按住氮气加速 · 松开恢复","RT / A"],[game.controls.label("attack_left")+" / "+game.controls.label("attack_right"),"左右攻击，连续命中击倒","LB / RB"],[game.controls.label("attack_auto"),"自动选择攻击方向","—"],[game.controls.label("show_roster"),"查看车手信息（自动暂停）","BACK"],["ESC / "+game.controls.label("pause_game"),"暂停 / 继续；M 静音，F11 全屏","START"]]
	for i in rows.size():
		var y = 246+i*57
		draw_line(Vector2(180,y+20),Vector2(1260,y+20),Color(0.4,0.6,0.7,0.18),1)
		_text(rows[i][0],Vector2(185,y),18,WHITE)
		_text(rows[i][1],Vector2(480,y),18,MUTED)
		_text(rows[i][2],Vector2(1115,y),17,CYAN)
	_text("赢法",Vector2(185,704),22,ORANGE)
	_text("四个场景，最多 15 名 AI。摔车后会自动起身、找车，仍有机会追回。",Vector2(270,704),18,WHITE)
	_text("青色圆环补氮气，绿色十字修装甲；地图与后视镜可在设置中开关。",Vector2(270,740),17,MUTED)
	_button("back","准备好了",Rect2(180,791,275,57),true,"ESC")

func _results() -> void:
	_shade(0.79)
	var win = game.finish_reason=="finished"
	var champ = win and game.final_rank==1
	_text("RACE COMPLETE" if win else "RIDE ENDED",Vector2(168,135),56,WHITE,title_font)
	_text("冠军属于你" if champ else ("漂亮冲线" if win else "下次，再快一点"),Vector2(168,191),34,ORANGE)
	_text(game.world.course.name+" / "+game.world.course.en+"  ·  LV.%d"%game.active_level,Vector2(170,232),18,MUTED)
	_panel(Rect2(170,275,1100,300),Color(0.04,0.09,0.15,0.9),12,Color("334c5a"))
	_text("最终名次" if win else "比赛进度",Vector2(205,319),17,MUTED)
	_text("%02d"%game.final_rank if win else "%d%%"%int(game.distance/game.track_length*100),Vector2(205,458),128,ORANGE,number_font)
	if win: _text("/ %02d"%(game.rivals.size()+1),Vector2(390,456),35,MUTED,number_font)
	_text("TOTAL SCORE",Vector2(578,322),18,MUTED,number_font)
	_text("%06d"%game.score,Vector2(575,404),72,WHITE,number_font)
	_text("个人最佳  %06d"%game.best_score,Vector2(580,448),17,CYAN)
	draw_line(Vector2(205,482),Vector2(1230,482),Color("334c5a"),1)
	_text("用时  "+_time(game.elapsed),Vector2(206,533),21,WHITE)
	_text("击倒  %02d"%game.takedowns,Vector2(515,533),21,WHITE)
	_text("命中  %02d"%game.hits,Vector2(771,533),21,WHITE)
	_text("擦身  %02d"%game.near_misses,Vector2(1027,533),21,WHITE)
	_text("连击和击倒大幅加分；保住车体，冲线还有额外奖励。",Vector2(173,625),18,MUTED)
	_button("retry","再来一场",Rect2(170,687,345,65),true,"R / ENTER")
	_button("menu","返回主菜单",Rect2(539,687,300,65))
	_button("roster","车手档案",Rect2(863,687,300,65))
	_text("原创场景 · 原创合成音效与配乐 · 本地记录",Vector2(173,834),15,MUTED)

func _time(value: float) -> String:
	return "%02d:%02d.%02d"%[int(value)/60,int(value)%60,int(fmod(value,1)*100)]

func _paragraph(value: String, pos: Vector2, width: float, size: int = 17, color: Color = MUTED) -> void:
	var line = ""
	var y = pos.y
	for letter in value:
		if body_font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			_text(line,Vector2(pos.x,y),size,color)
			y += size*1.7
			line = ""
		line += letter
	_text(line,Vector2(pos.x,y),size,color)

func _hotspot(action: String, rect: Rect2) -> bool:
	var focused = buttons.size()==selected
	buttons.append({"action":action,"rect":rect})
	return focused

func _avatar(id: int, rect: Rect2) -> void:
	var profile = game.profiles[clampi(id,0,14)]
	var c = rect.get_center()
	var z = rect.size.x/100.0
	_panel(rect,Color(profile.color,0.16),int(9*z))
	var skin = [Color("d8a07d"),Color("b8795c"),Color("ebbd95"),Color("815440"),Color("ba8768")][id%5]
	var hair = [Color("202430"),Color("413128"),Color("785d49"),Color("152c37")][id%4]
	# A distinct face, hairline, jacket, and accent for each original rider.
	draw_colored_polygon(PackedVector2Array([c+Vector2(-37,50)*z,c+Vector2(37,50)*z,c+Vector2(29,28)*z,c+Vector2(-29,28)*z]),profile.color.darkened(0.35))
	draw_rect(Rect2(c+Vector2(-8,17)*z,Vector2(16,17)*z),skin.darkened(0.10))
	draw_circle(c+Vector2(0,-4)*z,25*z,skin)
	draw_circle(c+Vector2(0,-17)*z,24*z,hair)
	draw_rect(Rect2(c+Vector2(-23,-18)*z,Vector2(46,17)*z),hair)
	draw_circle(c+Vector2(0,-1)*z,22*z,skin)
	if id%3==0:
		draw_colored_polygon(PackedVector2Array([c+Vector2(-24,-13)*z,c+Vector2(18,-25)*z,c+Vector2(24,-13)*z,c+Vector2(-14,-3)*z]),hair)
	elif id%3==1:
		draw_rect(Rect2(c+Vector2(-24,-22)*z,Vector2(48,11)*z),profile.color)
	else:
		draw_arc(c+Vector2(0,-5)*z,23*z,PI,TAU,18,hair,9*z,true)
	for side in [-1,1]:
		draw_line(c+Vector2(side*6,-5)*z,c+Vector2(side*15,-7+(id%2)*3)*z,hair,maxf(1,2*z),true)
		draw_circle(c+Vector2(side*10,0)*z,1.7*z,INK)
	draw_line(c+Vector2(-6,13)*z,c+Vector2(7,11+(id%3))*z,skin.darkened(0.6),maxf(1,1.7*z),true)
	draw_line(c+Vector2(-14,31)*z,c+Vector2(0,43)*z,WHITE,2*z,true)
	draw_line(c+Vector2(14,31)*z,c+Vector2(0,43)*z,WHITE,2*z,true)
	if rect.size.x>45: _center("%02d"%(id+1),Vector2(c.x,rect.end.y-5*z),int(12*z),WHITE,number_font)

func _setup() -> void:
	_shade(0.86)
	_text("BUILD YOUR RACE",Vector2(72,119),57,WHITE,title_font)
	_text("赛前设置  /  选择路线、对手与挑战等级",Vector2(74,160),22,CYAN)
	for i in Data.COURSES.size():
		var course = Data.COURSES[i]
		var rect = Rect2(72+(i%2)*391,205+int(i/2)*233,369,210)
		var focused = _hotspot("course:%d"%i,rect)
		_panel(rect,Color(0.045,0.10,0.16,0.94),8,course.color if game.race_options.course==i or focused else Color("314653"))
		_text(course.en,rect.position+Vector2(20,38),27,course.color,title_font)
		_text(course.name,rect.position+Vector2(20,72),23,WHITE)
		_text("%.1f KM"%(course.length/1000),rect.position+Vector2(263,72),18,MUTED,number_font)
		_paragraph(course.description,rect.position+Vector2(20,117),320,16,MUTED)
		_text(course.subtitle,rect.position+Vector2(20,186),14,course.color)
		if game.race_options.course==i: _text("已选",rect.position+Vector2(302,36),15,CYAN)
	_panel(Rect2(889,205,475,443),Color(0.035,0.075,0.13,0.95),10,Color("314653"))
	_text("AI 参赛车手",Vector2(918,248),21,WHITE)
	_button("ai_minus","−",Rect2(920,270,65,56))
	_center("%02d"%game.race_options.ai_count,Vector2(1121,314),47,CYAN,number_font)
	_button("ai_plus","+",Rect2(1260,270,65,56))
	_text("加上你，共 %d 人同场"%(game.race_options.ai_count+1),Vector2(918,356),16,MUTED)
	_button("ai_max","满员 15 AI",Rect2(1140,339,190,36))
	_text("AI 难度",Vector2(918,416),21,WHITE)
	_button("level_minus","−",Rect2(920,440,65,50))
	_center("%d / 5"%game.race_options.difficulty,Vector2(1124,478),37,ORANGE,number_font)
	_button("level_plus","+",Rect2(1260,440,65,50))
	_text(Data.LEVEL_NAMES[game.race_options.difficulty-1],Vector2(920,530),23,ORANGE)
	_paragraph(Data.LEVEL_DESCRIPTIONS[game.race_options.difficulty-1],Vector2(920,567),400,16,MUTED)
	_text("动态竞争：不瞬移、不锁死名次。落后可追回，领先也要防守。",Vector2(76,697),18,MUTED)
	_button("race_begin","开始竞赛",Rect2(72,748,360,65),true,"GO  →")
	_button("roster","查看车手",Rect2(456,748,260,65))
	_button("back","返回",Rect2(740,748,210,65),false,"ESC")
	_text("所选场景会同时切换真实赛道形状、路边模型、光照与比赛长度。",Vector2(76,862),15,MUTED)

func _roster() -> void:
	_shade(0.92)
	_text("MEET YOUR RIVALS",Vector2(76,113),54,WHITE,title_font)
	_text("15 名原创车手  /  属性影响实际驾驶与战斗行为",Vector2(78,155),20,CYAN)
	for i in game.profiles.size():
		var profile = game.profiles[i]
		var rect = Rect2(78+(i%5)*260,196+int(i/5)*182,241,161)
		var focused = _hotspot("profile:%d"%i,rect)
		_panel(rect,Color(0.06,0.12,0.18,0.96),7,profile.color if focused else Color("2b4452"))
		_avatar(i,Rect2(rect.position+Vector2(11,15),Vector2(63,63)))
		_text(profile.name,rect.position+Vector2(85,42),27,profile.color,title_font)
		_text(profile.full_name,rect.position+Vector2(85,69),16,WHITE)
		_text(profile.style,rect.position+Vector2(14,107),16,MUTED)
		var active = i<(game.rivals.size() if not game.menu_backdrop() else game.race_options.ai_count)
		_text("参赛中" if active else "候补车手",rect.position+Vector2(143,107),13,CYAN if active else MUTED)
		for j in 3:
			var value = [profile.pace,profile.handling,profile.aggression][j]
			draw_rect(Rect2(rect.position+Vector2(14+j*73,130),Vector2(61,5)),Color("2c404d"))
			draw_rect(Rect2(rect.position+Vector2(14+j*73,130),Vector2(61*value,5)),profile.color)
		_text("极速    操控    攻击",rect.position+Vector2(14,152),11,MUTED)
	_button("back","返回",Rect2(78,785,255,57),true,"ESC")
	_text("点击头像查看资料；比赛内打开档案时自动暂停。",Vector2(370,821),17,MUTED)

func _profile() -> void:
	_shade(0.93)
	var p = game.profiles[game.selected_profile]
	_text("RIDER DOSSIER",Vector2(180,136),46,WHITE,title_font)
	_avatar(p.id,Rect2(183,229,244,244))
	_text(p.name,Vector2(482,263),74,p.color,title_font)
	_text(p.full_name+"  /  "+p.city+"  /  %d 岁"%p.age,Vector2(486,312),24,WHITE)
	_text(p.style+"  ·  "+p.bike,Vector2(486,355),20,CYAN)
	_paragraph(p.bio,Vector2(486,403),690,20,MUTED)
	for j in 3:
		var y = 488+j*59
		_text(["极速倾向","操控精度","进攻倾向"][j],Vector2(488,y),18,MUTED)
		var value = [p.pace,p.handling,p.aggression][j]
		draw_rect(Rect2(610,y-13,443,10),Color("2c404d"))
		draw_rect(Rect2(610,y-13,443*value,10),p.color)
		_text("%d"%int(value*100),Vector2(1080,y),21,WHITE,number_font)
	if not game.rivals.is_empty() and p.id<game.rivals.size():
		var r = game.rivals[p.id]
		_text("本场：%d km/h  ·  氮气 %d%%  ·  摔车 %d 次  ·  有效攻击 %d 次"%[r.speed*3.6,r.nitro,r.crashes,r.attacks],Vector2(185,690),19,WHITE)
		_text("状态："+(r.node.recovery_stage if r.node.recovery_time>0 else ("已冲线" if r.finished else "竞速中")),Vector2(185,726),18,p.color)
	_button("back","返回车手列表",Rect2(184,780,310,58),true,"ESC")

func _bindings() -> void:
	_shade(0.94)
	_text("MAKE IT YOURS",Vector2(120,127),53,WHITE,title_font)
	_text("快捷键设置",Vector2(122,176),25,CYAN)
	for i in Controls.ORDER.size():
		var action = Controls.ORDER[i]
		var rect = Rect2(120+int(i/6)*650,229+(i%6)*70,594,56)
		_button("bind:"+action,Controls.LABELS[action],rect,game.rebinding==action,"等待按键…" if game.rebinding==action else game.controls.label(action))
	_paragraph(game.binding_message,Vector2(123,693),1180,18,ORANGE if not game.rebinding.is_empty() else CYAN)
	_text("保留键：ESC、Enter、方向键、F11、M、R。菜单导航不受游戏改键影响。",Vector2(123,736),16,MUTED)
	_button("back","返回",Rect2(120,781,250,57),true,"ESC")
	_button("reset_keys","恢复默认按键",Rect2(396,781,290,57))

func _standings_board(interactive: bool) -> void:
	var rows = game.standings()
	var height = 43+rows.size()*22
	_panel(Rect2(32,334,243,height),Color(0.035,0.08,0.14,0.82),7)
	_text("实时排名",Vector2(47,358),15,WHITE)
	_text("差距 / m",Vector2(206,358),12,MUTED)
	for i in rows.size():
		var r = rows[i]
		var y = 370+i*22
		if r.id==-1: draw_rect(Rect2(39,y-2,229,22),Color(1,0.48,0.3,0.18))
		_text("%02d"%(i+1),Vector2(45,y+14),13,r.color,number_font)
		if r.id>=0:
			_avatar(r.id,Rect2(72,y,19,19))
			if interactive: _hotspot("profile:%d"%r.id,Rect2(39,y-2,229,22))
		else: draw_circle(Vector2(81,y+10),6,ORANGE)
		_text(r.name,Vector2(99,y+14),15,r.color,number_font)
		var gap = r.distance-game.distance
		var text = "你" if r.id==-1 else ("冲线" if r.finished else ("倒地" if r.recovering else "%+d"%roundi(gap)))
		_text(text,Vector2(209,y+14),12,WHITE if r.id==-1 else MUTED)

func _minimap() -> void:
	var rect = Rect2(1175,330,232,277)
	_panel(rect,Color(0.03,0.08,0.14,0.86),8,Color("334c5b"))
	_text("赛道地图",rect.position+Vector2(15,25),16,WHITE)
	_text(game.controls.label("toggle_map"),rect.position+Vector2(199,25),14,CYAN,number_font)
	var points = PackedVector2Array()
	for i in 100: points.append(_map_position(float(i)/99*game.track_length,0,rect))
	draw_polyline(points,Color("294453"),8,true)
	draw_polyline(points,Color("78959e"),2,true)
	for r in game.rivals:
		var pos = _map_position(r.distance,r.lane,rect)
		draw_circle(pos,3.8,r.color.darkened(0.35) if r.node.recovery_time>0 else r.color)
		if r.finished: draw_arc(pos,6,0,TAU,12,r.color,1,true)
	var player_pos = _map_position(game.distance,game.lane,rect)
	draw_circle(player_pos,7,INK)
	draw_circle(player_pos,5,ORANGE)
	_text("你",player_pos+Vector2(10,5),13,WHITE)
	_text("FINISH",_map_position(game.track_length,0,rect)+Vector2(-24,-11),12,CYAN,number_font)
	_text("橙点：你  /  彩点：对手",rect.position+Vector2(15,258),12,MUTED)

func _map_position(at: float, lane: float, rect: Rect2) -> Vector2:
	var t = clampf(at/game.track_length,0,1)
	var x = game.world.center_at(t*game.track_length)
	var extent = game.world.course.curve[0]+game.world.course.curve[2]
	return Vector2(rect.position.x+rect.size.x*0.5+x/maxf(extent,1)*70+lane*0.55,rect.position.y+231-t*175)

func _rear_view() -> void:
	var rect = Rect2(516,106,420,125)
	_panel(Rect2(rect.position-Vector2(4,4),rect.size+Vector2(8,8)),Color("142934"),8,Color("577a83"))
	# Flip the rear-camera texture like a real mirror. UI stays unflipped.
	draw_set_transform(ui_offset+Vector2(rect.end.x,rect.position.y)*ui_scale,0,Vector2(-ui_scale,ui_scale))
	draw_texture_rect(game.mirror_view.get_texture(),Rect2(Vector2.ZERO,rect.size),false)
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	var behind: Array[Dictionary] = []
	for r in game.rivals:
		if r.distance<game.distance and game.distance-r.distance<160: behind.append(r)
	behind.sort_custom(func(a,b): return a.distance>b.distance)
	var label = "后方暂无近距离追兵"
	if not behind.is_empty(): label = "%s  距离 %dm"%[behind[0].name,game.distance-behind[0].distance]
	_center("REAR VIEW  /  "+label,Vector2(726,249),13,MUTED,body_font)
