extends Control
## Resolution-independent, keyboard/gamepad-accessible arcade interface.
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
	_button("help","驾驶指南",Rect2(68,630,362,52),false,"CONTROLS")
	_button("settings","游戏设置",Rect2(68,695,362,52),false,"SETTINGS")
	_button("quit","退出游戏",Rect2(68,760,362,44),false,"QUIT")
	_text("BEST  %06d" % game.best_score,Vector2(68,853),16,MUTED,number_font)
	_text("离线单机  /  原创 3D 街机竞速",Vector2(263,853),14,MUTED)
	_text("THE HARBOR RUN",Vector2(1101,84),26,WHITE,title_font)
	_text("黄昏港湾 · 5.4 KM",Vector2(1100,112),17,MUTED)
	draw_line(Vector2(1100,131),Vector2(1369,131),Color(0.7,0.85,0.9,0.3),1,true)
	_text("6 RIDERS",Vector2(1100,159),17,CYAN,number_font)
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
	var sectors = ["01  /  临港起跑","02  /  霓虹立交","03  /  决胜直道"]
	_text(sectors[mini(2,int(game.distance/1800))],Vector2(48,99),19,CYAN)
	var rank = game.rank_now()
	_text("%02d"%rank,Vector2(48,202),77,WHITE,number_font)
	_text("/ 06",Vector2(144,199),27,MUTED,number_font)
	_text("当前名次",Vector2(49,227),14,MUTED)
	_text("%06d"%game.score,Vector2(49,280),33,WHITE,number_font)
	_text("SCORE",Vector2(49,302),13,MUTED,number_font)
	# Track progression, with actual sector boundaries.
	var start = Vector2(350,54)
	var w = 696.0
	draw_line(start,start+Vector2(w,0),Color(0.4,0.55,0.63,0.55),4,true)
	draw_line(start,start+Vector2(w*clampf(game.distance/game.TRACK_LENGTH,0,1),0),CYAN,4,true)
	for i in 4:
		var pos = start+Vector2(w*i/3,0)
		draw_circle(pos,4,CYAN if i*1800<=game.distance else MUTED)
	draw_circle(start+Vector2(w*clampf(game.distance/game.TRACK_LENGTH,0,1),0),7,WHITE)
	_text("HARBOR RUN",Vector2(350,86),14,MUTED,number_font)
	_text("%.2f / 5.40 KM"%(game.distance/1000),Vector2(879,86),16,WHITE,number_font)
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
	_text("SPACE  氮气加速",Vector2(775,824),14,WHITE)
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
	_center("A D  转向    S  刹车    J K  攻击    SHIFT  自动选边    ESC  暂停",Vector2(724,889),13,MUTED)
	if game.combo>1 and game.combo_time>0:
		_text("%d×"%game.combo,Vector2(1280,255),57,ORANGE,number_font)
		_text("连击",Vector2(1300,282),16,WHITE)
		var fraction = game.combo_time/5
		draw_line(Vector2(1280,300),Vector2(1280+90*fraction,300),ORANGE,3,true)
	_draw_rival_markers()
	if game.message_time>0 and game.state=="race":
		var a = minf(game.message_time*3,1)
		var color = game.message_color
		color.a = a
		_center(game.message,Vector2(720,204),32,color)
		_center(game.message_sub,Vector2(720,237),15,Color(0.9,0.96,0.96,a))
	if game.elapsed<7 and game.state=="race" and game.message_time<=0:
		_center("自动油门 · 先用 A / D 靠近对手，再按 J / K 出击",Vector2(720,240),19,WHITE)
	if game.state=="countdown":
		var n = ceili(game.countdown)
		draw_circle(Vector2(720,391),79,Color(0.03,0.09,0.15,0.75))
		_center(str(mini(3,n)),Vector2(720,429),112,WHITE,number_font)
		_center("准备出发",Vector2(720,527),26,CYAN)
		_center("自动油门  /  A D 转向  /  J K 攻击  /  空格加速",Vector2(720,567),18,WHITE)

func _draw_rival_markers() -> void:
	for r in game.rivals:
		var gap = r.distance-game.distance
		if gap < -3 or gap>90 or r.hp<=0: continue
		var pos = r.node.position+Vector3(0,3.1,0)
		if game.camera.is_position_behind(pos): continue
		var screen = (game.camera.unproject_position(pos)-ui_offset)/ui_scale
		if screen.x<60 or screen.x>1380 or screen.y<140 or screen.y>725: continue
		var warning = r.windup>0
		var color = ORANGE if warning else r.color
		var ready = absf(r.lane-game.lane)<3.5 and absf(gap)<6.4
		_center("攻击预警 !" if warning else r.name,screen,15,color,body_font if warning else number_font)
		for i in 2:
			draw_rect(Rect2(screen+Vector2(-24+i*27,8),Vector2(21,4)),color if r.hp>i else Color("344757"))
		if ready:
			_center("[ J ]" if r.lane<game.lane else "[ K ]",screen+Vector2(0,-25),23,CYAN,number_font)

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
	_shade(0.83)
	_text("TUNE YOUR RIDE",Vector2(290,152),57,WHITE,title_font)
	_text("游戏设置",Vector2(292,202),24,CYAN)
	var s = game.settings
	_button("volume","主音量",Rect2(292,246,856,62),false,"%d%%"%roundi(s.volume*100))
	_button("music","电子配乐",Rect2(292,325,856,62),false,"开启" if s.music else "关闭")
	_button("shake","镜头震动",Rect2(292,404,856,62),false,"开启" if s.shake else "关闭")
	_button("quality","渲染质量",Rect2(292,483,856,62),false,"精致 · 阴影 / 辉光" if s.quality else "流畅 · 低负载")
	_button("difficulty","比赛难度",Rect2(292,562,856,62),false,"硬核" if s.hard else "街机 · 推荐")
	_text("音量每次增加 20%，满格后回到静音。设置自动保存。",Vector2(292,671),17,MUTED)
	_text("F11 全屏切换   /   M 一键静音   /   低配 Mac 可选「流畅」",Vector2(292,707),16,MUTED)
	_button("back","返回",Rect2(292,753,250,55),true,"ESC")

func _help() -> void:
	_shade(0.88)
	_text("LEARN THE STREETS",Vector2(180,136),56,WHITE,title_font)
	_text("驾驶指南",Vector2(180,184),24,CYAN)
	var rows = [["A / D  或  ← / →","左右转向","左摇杆"],["S / ↓","刹车 · 松开恢复自动油门","LT"],["SPACE","按住氮气加速 · 松开恢复","RT / A"],["J / K","向左 / 向右攻击，连击两次击倒","LB / RB"],["SHIFT","自动选择最近对手的攻击方向","—"],["ESC / P","暂停 / 继续","START"],["M / F11","静音 / 全屏","—"]]
	for i in rows.size():
		var y = 246+i*57
		draw_line(Vector2(180,y+20),Vector2(1260,y+20),Color(0.4,0.6,0.7,0.18),1)
		_text(rows[i][0],Vector2(185,y),18,WHITE)
		_text(rows[i][1],Vector2(480,y),18,MUTED)
		_text(rows[i][2],Vector2(1115,y),17,CYAN)
	_text("赢法",Vector2(185,704),22,ORANGE)
	_text("5.4 公里，6 名车手。避开交通，贴近对手出击，抢先通过终点。",Vector2(270,704),18,WHITE)
	_text("青色圆环补氮气，绿色十字修装甲；擦身和命中也能获得氮气。",Vector2(270,740),17,MUTED)
	_button("back","准备好了",Rect2(180,791,275,57),true,"ESC")

func _results() -> void:
	_shade(0.79)
	var win = game.finish_reason=="finished"
	var champ = win and game.final_rank==1
	_text("RACE COMPLETE" if win else "RIDE ENDED",Vector2(168,135),56,WHITE,title_font)
	_text("冠军属于你" if champ else ("漂亮冲线" if win else "下次，再快一点"),Vector2(168,191),34,ORANGE)
	_text("港湾高架 / HARBOR RUN",Vector2(170,232),18,MUTED)
	_panel(Rect2(170,275,1100,300),Color(0.04,0.09,0.15,0.9),12,Color("334c5a"))
	_text("最终名次" if win else "比赛进度",Vector2(205,319),17,MUTED)
	_text("%02d"%game.final_rank if win else "%d%%"%int(game.distance/game.TRACK_LENGTH*100),Vector2(205,458),128,ORANGE,number_font)
	if win: _text("/ 06",Vector2(390,456),35,MUTED,number_font)
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
	_text("原创场景 · 原创合成音效与配乐 · 本地记录",Vector2(173,834),15,MUTED)

func _time(value: float) -> String:
	return "%02d:%02d.%02d"%[int(value)/60,int(value)%60,int(fmod(value,1)*100)]
