extends Control
## Resolution-independent, keyboard/gamepad-accessible arcade interface.
const TrackRoute = preload("res://scripts/track_route.gd")
var route_previews: Dictionary={}
const Weapons = preload("res://scripts/weapons.gd")
const Data = preload("res://scripts/game_data.gd")
const Feedback = preload("res://scripts/race_feedback.gd")
const Motion = preload("res://scripts/result_motion.gd")
const Progress = preload("res://scripts/race_progress.gd")
const Controls = preload("res://scripts/controls.gd")
const INK = Color("081321")
const WHITE = Color("f0f4fa")
const MUTED = Color("a1b6ce")
const ORANGE = Color("ff9452")
const CYAN = Color("7be3ff")
# Side-rail cockpit: keep x=390..1090 clear for racing / landing decisions.
const FLIGHT_RECT = Rect2(1100,250,307,72)
const PURSUIT_RECT = Rect2(1100,550,307,96)
const MAP_RECT = Rect2(1175,332,232,205)
var game: Node
var title_font: SystemFont
var body_font: Font
var number_font: SystemFont
var buttons: Array[Dictionary] = []
var selected = 0
var ui_scale = 1.0
var ui_offset = Vector2.ZERO
var mouse = Vector2(-100,-100)
var mouse_active = false
var content_alpha = 1.0
var ui_clock = 0.0
var focus_glow: Dictionary = {}

func _ready() -> void:
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["DIN Condensed","Arial Narrow","sans-serif"])
	title_font.font_weight = 800
	var chinese=FontVariation.new()
	chinese.base_font=load("res://assets/fonts/NotoSansSC.ttf")
	chinese.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):450.0}
	body_font=chinese
	title_font.fallbacks=[body_font]
	number_font = SystemFont.new()
	number_font.font_names = PackedStringArray(["DIN Alternate","Arial","sans-serif"])
	number_font.font_weight = 700
	number_font.fallbacks=[body_font]
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(dt: float) -> void:
	if not game: return
	if game.settings.shake: ui_clock+=minf(dt,0.05)
	for i in buttons.size():
		var action=buttons[i].action
		focus_glow[action]=move_toward(float(focus_glow.get(action,0)),1.0 if i==selected else 0.0,dt*9)
	queue_redraw()

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
	content_alpha=1
	match game.state:
		"menu": _menu()
		"setup": _setup()
		"roster": _roster()
		"profile": _profile()
		"bindings": _bindings()
		"garage": _garage()
		"race", "countdown", "falling": _race()
		"paused":
			_race(false)
			_pause()
		"settings": _settings()
		"help": _help()
		"finished": _results()
	if game.sound.muted:
		_text("声音已静音  /  M 恢复",Vector2(1190,878),15,MUTED)

func _text(value: String, pos: Vector2, size: int = 20, color: Color = WHITE, font: Font = null) -> void:
	color.a*=content_alpha
	draw_string(font if font else body_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(value: String, center: Vector2, size: int, color: Color = WHITE, font: Font = null) -> void:
	var f = font if font else body_font
	var width = f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(value,center-Vector2(width/2,0),size,color,f)

func _cut_shape(rect: Rect2, cut: float = 10.0) -> PackedVector2Array:
	var p=rect.position
	var e=rect.end
	var c=minf(cut,minf(rect.size.x,rect.size.y)*0.24)
	return PackedVector2Array([p+Vector2(c,0),Vector2(e.x, p.y),Vector2(e.x,e.y-c),e-Vector2(c,0),Vector2(p.x,e.y),p+Vector2(0,c)])

func _panel(rect: Rect2, color: Color, radius: int = 10, border: Color = Color.TRANSPARENT) -> void:
	color.a*=content_alpha
	border.a*=content_alpha
	var shape=_cut_shape(rect,float(radius)+3)
	draw_colored_polygon(shape,color)
	var line=shape.duplicate()
	line.append(shape[0])
	draw_polyline(line,border if border.a>0 else Color(0.45,0.66,0.82,0.16*content_alpha),1,true)
	if rect.size.x>100 and rect.size.y>45:
		var edge=border if border.a>0 else CYAN
		edge.a=0.55*content_alpha
		draw_line(rect.position+Vector2(13,1),rect.position+Vector2(minf(rect.size.x*0.35,90),1),edge,2,true)

func _button(action: String, label: String, rect: Rect2, primary: bool = false, hint: String = "") -> void:
	var index=buttons.size()
	var focus=index==selected
	var glow=float(focus_glow.get(action,1.0 if focus else 0.0)) if game.settings.shake else (1.0 if focus else 0.0)
	var accent=ORANGE if primary else CYAN
	var bg=Color("13283d").lerp(Color("284b68"),glow)
	if primary: bg=ORANGE.lerp(Color("ffcf91"),glow*0.38)
	var fg=INK if primary else WHITE
	_panel(Rect2(rect.position+Vector2(0,4),rect.size),Color(0.0,0.02,0.05,0.5),9)
	_panel(rect,bg,9,accent if primary or focus else Color("3b5872"))
	# A racing-stripe end cap; label and hit target never shift during hover.
	if rect.size.x>110:
		for i in 3:
			var end=rect.end-Vector2(10+i*5,6)
			draw_line(end-Vector2(0,9),end-Vector2(4,0),Color(fg,0.28),1.4,true)
	if focus:
		draw_line(rect.position+Vector2(10,rect.size.y-2),rect.position+Vector2(rect.size.x-13,rect.size.y-2),accent if not primary else INK,2,true)
	var hint_width=body_font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x if not hint.is_empty() else 0.0
	var size=22
	var available=rect.size.x-40-(hint_width+18 if hint_width>0 else 0)
	while size>15 and body_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>available: size-=1
	if rect.size.x<100: _center(label,rect.get_center()+Vector2(0,8),24,fg)
	else: _text(label,rect.position+Vector2(20,rect.size.y*0.5+8),size,fg)
	if not hint.is_empty(): _text(hint,rect.position+Vector2(rect.size.x-hint_width-23,rect.size.y*.5+5),14,fg if primary else MUTED)
	buttons.append({"action":action,"rect":rect})

func _shade(alpha: float = 0.75) -> void:
	draw_rect(Rect2(-ui_offset/ui_scale,get_viewport_rect().size/ui_scale),Color(0.015,0.035,0.075,alpha))
	if game.state not in ["race","countdown","paused","finished"]:
		for i in 9:
			var x=fposmod(i*210+ui_clock*18,1900)-200
			draw_line(Vector2(x,0),Vector2(x-370,900),Color(0.33,0.6,0.82,0.035),2,true)
		for i in 5:
			var x=1130+i*42
			draw_colored_polygon(PackedVector2Array([Vector2(x,18),Vector2(x+24,18),Vector2(x-2,52),Vector2(x-26,52)]),Color(1,0.56,0.29,0.18))
		draw_line(Vector2(34,56),Vector2(34,842),Color(CYAN,0.20),1,true)
		draw_line(Vector2(34,842),Vector2(52,866),ORANGE,2,true)

func _menu() -> void:
	# A left-weighted cinematic scrim keeps the procedural hero bike visible.
	_shade(0.20)
	draw_rect(Rect2(-ui_offset.x/ui_scale,-ui_offset.y/ui_scale,560+ui_offset.x/ui_scale,900+ui_offset.y*2/ui_scale),Color(0.025,0.055,0.1,0.82))
	for i in 32:
		draw_rect(Rect2(560+i*15,0,15,900),Color(0.025,0.055,0.1,0.82*(1-float(i)/32)))
	_panel(Rect2(64,48,38,34),ORANGE,3)
	_text("R",Vector2(75,74),27,INK,title_font)
	_text("ROAD RAGE  /  FLIGHT DIVISION",Vector2(117,72),16,MUTED,number_font)
	_text("BOOST. LAUNCH. REBOUND.",Vector2(68,153),17,CYAN,number_font)
	_text("ROAD",Vector2(59,288),156,WHITE,title_font)
	_text("RAGE",Vector2(62,423),174,Color(0.38,0.13,0.08,0.8),title_font)
	_text("RAGE",Vector2(59,420),174,ORANGE,title_font)
	for i in 4: draw_line(Vector2(438+i*20,301),Vector2(398+i*20,413),Color(ORANGE,0.25),6,true)
	_text("极 限 狂 飙",Vector2(68,467),29,WHITE)
	_text("冲上云端，触底反弹，再抢下第一。",Vector2(68,510),18,MUTED)
	_button("start","开始狂飙",Rect2(68,550,362,64),true,"ENTER  →")
	_button("roster","车手档案",Rect2(68,630,362,52),false,"15 RIDERS")
	_button("settings","游戏设置",Rect2(68,695,173,52))
	_button("help","驾驶指南",Rect2(255,695,175,52))
	_button("quit","退出游戏",Rect2(68,760,362,44),false,"QUIT")
	_text("BEST  %06d" % game.best_score,Vector2(68,853),16,MUTED,number_font)
	_text("离线单机  /  原创 3D 街机竞速",Vector2(263,853),14,MUTED)
	_text(Data.COURSES[game.race_options.course].en,Vector2(1040,84),26,WHITE,title_font)
	_text("%s · %.1f KM"%[Data.COURSES[game.race_options.course].name,Data.race_length(game.race_options.course,game.race_options.get("distance",0))/1000],Vector2(1040,112),17,MUTED)
	draw_line(Vector2(1100,131),Vector2(1369,131),Color(0.7,0.85,0.9,0.3),1,true)
	_text("UP TO 16 RIDERS",Vector2(1040,159),17,CYAN,number_font)
	_text("12 COURSES",Vector2(1234,159),17,WHITE,number_font)
	_panel(Rect2(1102,757,266,85),Color(0.04,0.1,0.17,0.7),5)
	_text("你的座驾",Vector2(1121,784),14,MUTED)
	_text(game.economy.bike().name,Vector2(1121,819),22,WHITE,title_font)
	_panel(Rect2(1040,220,327,113),Color(0.04,0.1,0.17,0.9),8)
	_text("可用余额  $%d"%game.economy.cash,Vector2(1060,263),26,CYAN,number_font)
	_text("待缴罚款  $%d"%game.economy.debt,Vector2(1060,300),17,MUTED)
	_button("garage","车库 / 摩托商店",Rect2(1040,350,327,57),true,"SHOP")

func _race(interactive: bool = true) -> void:
	if game.world.course.id=="storm" and game.state=="race":
		for i in 44:
			var rain=Vector2(fmod(i*173.0+game.total_time*75,1440),fmod(i*139.0+game.total_time*610,900))
			draw_line(rain,rain+Vector2(-5,23),Color(0.70,0.86,1,0.13),1,true)
	# Twin edge wind tunnels: no lines across the central road or rider.
	if game.boost_visual>0 and game.state=="race" and game.settings.shake:
		for side in [-1,1]:
			for i in 42:
				var travel=fmod(game.elapsed*1.9+i*0.137,1.0)
				var x=lerpf(390,0,travel) if side<0 else lerpf(1050,1440,travel)
				var y=100+fmod(i*113.0,650)
				var v=Vector2(side*(70+travel*220),(y-405)*0.18)
				var opacity=sin(travel*PI)*game.boost_visual
				draw_line(Vector2(x,y),Vector2(x,y)+v,Color(CYAN,opacity*0.23),10,true)
				draw_line(Vector2(x,y),Vector2(x,y)+v,Color(WHITE,opacity*0.78),2.2,true)
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
	_distance_header()
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
	if game.wrong_way(): _center("逆行 ↑↑ · 极速 +8% · 注意迎面车辆",Vector2(713,777),18,ORANGE)
	elif game.boost_active: _center("超 频 加 速",Vector2(713,777),22,CYAN)
	var c = Vector2(1274,755)
	draw_circle(c,100,Color(0.04,0.09,0.15,0.83))
	draw_arc(c,88,PI*0.72,PI*2.28,65,Color("334c5a"),4,true)
	draw_arc(c,88,PI*0.72,PI*0.72+PI*1.56*clampf(game.speed/game.active_bike.boost,0,1),65,ORANGE if game.boost_active else CYAN,5,true)
	for i in 21:
		var a = PI*.72+PI*1.56*i/20
		var dir = Vector2(cos(a),sin(a))
		draw_line(c+dir*77,c+dir*(69 if i%5==0 else 73),MUTED,1,true)
	_center("%03d"%int(game.speed*3.6),c+Vector2(0,20),58,WHITE,number_font)
	_center("KM/H",c+Vector2(0,46),14,MUTED,number_font)
	_center("N" if game.speed<1 else "G%d"%clampi(int(game.speed/16)+1,1,6),c+Vector2(0,-40),18,ORANGE,number_font)
	_center("%s/%s 转向   %s 刹车   %s/%s 攻击   %s 氮气   %s 车手信息   ESC 暂停"%[game.controls.label("steer_left"),game.controls.label("steer_right"),game.controls.label("brake"),game.controls.label("attack_left"),game.controls.label("attack_right"),game.controls.label("boost"),game.controls.label("show_roster")],Vector2(724,889),13,MUTED)
	if game.combo>1 and game.combo_time>0:
		_text("%d×"%game.combo,Vector2(205,268),42,ORANGE,number_font)
		_text("连击",Vector2(253,292),16,WHITE)
		var fraction = game.combo_time/5
		draw_line(Vector2(205,301),Vector2(205+90*fraction,301),ORANGE,3,true)
	if game.state=="falling":
		_panel(FLIGHT_RECT,Color(0.03,0.10,0.16,0.8),7,CYAN)
		_text("坠海中 · 脱离路面",Vector2(1114,276),19,CYAN)
		_text("落入海面将终止比赛",Vector2(1114,305),14,WHITE)
	elif game.ride.airborne and game.ride.height>0.3 and game.player.recovery_time<=0:
		_panel(FLIGHT_RECT,Color(0.03,0.10,0.16,0.72),7,CYAN)
		_text("展体 / "+game.stunt.stage if game.stunt.active else "腾空",Vector2(1114,272),16,CYAN)
		_text("%.1fm · %.1fs"%[game.ride.height,game.ride.air_time],Vector2(1250,272),16,WHITE)
		var hint=game.controls.label("aerial_stunt")+" 展体 · 自动回座 · 落地无损"
		if game.stunt.active: hint="人车分离 · 自动回座中"
		elif game.stunt.pending_bonus: hint="已回座 · 落地追加 +300 分"
		elif game.stunt_notice>0: hint="特技完成 +300 分 / 氮气 +12"
		elif game.stunt.last_launch==game.ride.launches: hint="本次已施展 · 等待下次起飞"
		_text(hint,Vector2(1114,303),13,WHITE)
	elif game.stunt_notice>0:
		_text("展体成功 +300 分 / +12 氮气",Vector2(1114,291),14,CYAN)
	elif not game.race_rules.air_walls and absf(game.lane)>game.world.road_half_width(game.distance):
		_panel(FLIGHT_RECT,Color(0.03,0.10,0.16,0.8),7,ORANGE)
		_text("路肩 / 非铺装",Vector2(1114,276),18,ORANGE)
		_text("减速中 · 回到路面恢复速度",Vector2(1114,304),13,WHITE)
	elif not game.world.road_hint(game.distance).is_empty():
		_text(game.world.road_hint(game.distance),Vector2(1114,291),14,ORANGE)
	_weapon_hud(interactive)
	_draw_rival_markers()
	_panel(Rect2(308,111,187,47),Color(0.04,0.09,0.15,0.86),6)
	_text("钱包  $%d"%game.economy.cash,Vector2(320,141),18,CYAN,number_font)
	_standings_board(interactive)
	if game.settings.map: _minimap()
	if game.settings.mirror: _rear_view()
	if game.message_time>0 and game.state=="race" and game.rebound_timer<=0:
		var a = minf(game.message_time*3,1)
		var color = game.message_color
		color.a = a
		_center(game.message,Vector2(720,288),32,color)
		_center(game.message_sub,Vector2(720,321),15,Color(0.9,0.96,0.96,a))
	if game.rebound_timer>0 and game.state in ["race","paused"]: _rebound_pop()
	if game.elapsed<7 and game.state=="race" and game.message_time<=0:
		_center("自动油门 · 靠近对手后，按 %s / %s 出击"%[game.controls.label("attack_left"),game.controls.label("attack_right")],Vector2(720,320),19,WHITE)
	if game.state in ["race","paused"]: _pursuit_indicator()
	if game.player.recovery_time>0:
		_panel(Rect2(475,660,490,96),Color(0.04,0.08,0.14,0.88),8)
		_center(game.player.recovery_stage,Vector2(720,693),26,ORANGE)
		_center("自动恢复中 · 对手仍在前进",Vector2(720,720),15,MUTED)
		draw_rect(Rect2(496,736,448,5),Color("304958"))
		draw_rect(Rect2(496,736,448*(1-game.player.recovery_time/game.player.recovery_duration),5),ORANGE)
	elif game.catchup_help>2 and not game.ride.airborne:
		_center("追赶辅助生效 · 引擎响应与氮气恢复提升",Vector2(720,756),14,CYAN)
	if game.state=="countdown" or (game.state=="race" and game.elapsed<0.85): _start_lights()

func _pursuit_feedback() -> Dictionary:
	return Feedback.pursuit(game.police.pursuit_active,game.police.capture,game.player.recovery_time>0,game.police.escape_progress,game.elapsed-game.police.escaped_at,game.elapsed,game.settings.shake)

func _pursuit_indicator() -> void:
	var f=_pursuit_feedback()
	if not f.visible: return
	var color: Color=f.color
	_panel(PURSUIT_RECT,Color(0.04,0.07,0.12,0.80),8,color.darkened(0.3))
	var red=Color(Feedback.RED,0.3+f.pulse*0.55)
	var blue=Color(Feedback.BLUE,0.85-f.pulse*0.55)
	draw_line(Vector2(1110,552),Vector2(1246,552),color if f.mode=="escaped" else red,3,true)
	draw_line(Vector2(1258,552),Vector2(1397,552),color if f.mode=="escaped" else blue,3,true)
	_status_icon(f.icon,Vector2(1128,580),17,color)
	_text(f.title,Vector2(1155,580),17,color)
	var label="后方" if game.police.lead_distance>=0 else "前方"
	if f.mode!="escaped":
		_text("%s %dm"%[label,roundi(absf(game.police.lead_distance))],Vector2(1305,580),12,WHITE)
	var hint="拉开 %dm / 保持 2.5s"%int(game.police.escape_required)
	var detail="警车散热时加速脱逃"
	var progress=game.police.escape_progress
	if f.mode=="danger":
		hint="被捕罚款 $%d"%(350+game.active_level*150)
		detail="倒地危险 · 恢复骑行后脱离抓捕"
		progress=game.police.capture/0.65
	elif f.mode=="escaped":
		hint="脱逃成功 +300 分"
		detail="警方脱离追踪 · 继续冲线"
		progress=1
	_text(hint,Vector2(1114,603),14,WHITE)
	_text(detail,Vector2(1114,623),12,MUTED)
	draw_rect(Rect2(1114,635,278,3),Color("294052"))
	draw_rect(Rect2(1114,635,278*clampf(progress,0,1),3),color)

func _start_lights() -> void:
	var remaining=game.countdown if game.state=="countdown" else -game.elapsed
	var lights=Feedback.start_signal(remaining)
	var green=Feedback.GREEN
	var alpha=1.0 if not lights.go else clampf(1-game.elapsed/0.85,0,1)
	var color=green if lights.go else Feedback.RED
	_panel(Rect2(557,345,326,79),Color(INK,0.94*alpha),12,Color(color,0.3*alpha))
	for i in 3:
		var c=Vector2(630+i*90,384)
		var lit=lights.go or i<lights.lit
		draw_circle(c,29,Color(Color("02080e"),alpha))
		draw_circle(c,23,Color(color if lit else Color("25303b"),alpha))
		if lit:
			draw_arc(c,27,0,TAU,36,Color(color,0.3*alpha),2,true)
			# LED matrix rather than a flat colored disc.
			for x in range(-2,3):
				for y in range(-2,3):
					if x*x+y*y<=5: draw_circle(c+Vector2(x,y)*7,1.6,Color(WHITE,0.42*alpha))
	var phase=1-fmod(maxf(0,remaining),1)
	var size=72+(int(8*(1-phase)) if game.settings.shake and not lights.go else 0)
	_center(lights.label,Vector2(720,513),size,Color(green if lights.go else WHITE,alpha),number_font)
	_center("全速出击" if lights.go else "绿灯亮起后自动起步",Vector2(720,546),18,Color(green if lights.go else MUTED,alpha))
	if not lights.go:
		_center("%s %s 转向  /  %s %s 攻击  /  %s 氮气"%[game.controls.label("steer_left"),game.controls.label("steer_right"),game.controls.label("attack_left"),game.controls.label("attack_right"),game.controls.label("boost")],Vector2(720,578),16,WHITE)

func _status_icon(kind: String, c: Vector2, radius: float, color: Color) -> void:
	# Hand-drawn vector pictograms remain crisp and do not depend on emoji fonts.
	var z=radius/24.0
	var width=maxf(1.5,2.4*z)
	match kind:
		"sea":
			for row in 3:
				var wave=PackedVector2Array()
				for i in 33: wave.append(c+Vector2(-24+i*1.5,row*10-10+sin(i*TAU/16)*3)*z)
				draw_polyline(wave,color,width,true)
		"siren":
			draw_arc(c+Vector2(0,3)*z,14*z,PI,TAU,24,color,width,true)
			draw_line(c+Vector2(-14,3)*z,c+Vector2(-14,12)*z,color,width,true)
			draw_line(c+Vector2(14,3)*z,c+Vector2(14,12)*z,color,width,true)
			draw_line(c+Vector2(-19,14)*z,c+Vector2(19,14)*z,color,width*1.5,true)
			for angle in [PI*1.15,PI*1.5,PI*1.85]:
				draw_line(c+Vector2.from_angle(angle)*19*z,c+Vector2.from_angle(angle)*25*z,color,width,true)
			draw_line(c+Vector2(4,-5)*z,c+Vector2(7,4)*z,WHITE,width,true)
		"cuffs":
			for side in [-1,1]:
				draw_arc(c+Vector2(side*13,side*4)*z,9*z,0,TAU,28,color,width,true)
				draw_line(c+Vector2(side*19,-8+side*4)*z,c+Vector2(side*16,-3+side*4)*z,color,width,true)
			draw_line(c+Vector2(-4,-4)*z,c+Vector2(4,4)*z,color,width,true)
		"check":
			draw_arc(c,23*z,0,TAU,40,color,width,true)
			draw_polyline(PackedVector2Array([c+Vector2(-12,0)*z,c+Vector2(-3,9)*z,c+Vector2(13,-10)*z]),color,width*1.5,true)
		"trophy":
			draw_polyline(PackedVector2Array([c+Vector2(-13,-18)*z,c+Vector2(-10,1)*z,c+Vector2(0,10)*z,c+Vector2(10,1)*z,c+Vector2(13,-18)*z,c+Vector2(-13,-18)*z]),color,width,true)
			for side in [-1,1]: draw_arc(c+Vector2(side*13,-10)*z,8*z,-PI/2,PI/2,20,color,width,true)
			draw_line(c+Vector2(0,10)*z,c+Vector2(0,20)*z,color,width,true)
			draw_line(c+Vector2(-11,21)*z,c+Vector2(11,21)*z,color,width,true)
		"flag":
			draw_line(c+Vector2(-18,-22)*z,c+Vector2(-18,23)*z,color,width,true)
			for x in 4:
				for y in 3: draw_rect(Rect2(c+Vector2(-16+x*9,-22+y*9)*z,Vector2(9,9)*z),color if (x+y)%2==0 else Color("243b53"))
		"wreck":
			for side in [-1,1]: draw_arc(c+Vector2(side*16,12)*z,7*z,0,TAU,24,color,width,true)
			draw_polyline(PackedVector2Array([c+Vector2(-16,12)*z,c+Vector2(-7,-1)*z,c+Vector2(-1,9)*z]),color,width,true)
			draw_polyline(PackedVector2Array([c+Vector2(16,12)*z,c+Vector2(11,-4)*z,c+Vector2(17,-7)*z]),color,width,true)
			draw_polyline(PackedVector2Array([c+Vector2(2,-23)*z,c+Vector2(-4,-12)*z,c+Vector2(5,-12)*z,c+Vector2(-1,-3)*z]),color,width,true)

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
		var label_rect = Rect2(screen-Vector2(65,28),Vector2(130,67))
		var overlaps = false
		for used in occupied:
			if label_rect.intersects(used): overlaps = true
		if overlaps or occupied.size()>=4: continue
		occupied.append(label_rect)
		var warning = r.windup>0
		var color = ORANGE if warning else r.color
		var ready = Weapons.reaches(game.loadout.current,r.lane-game.lane,gap,r.ride.y-game.ride.y)
		_center(("瞄准你 !" if r.target_id==-1 else "交战中") if warning else r.name+(" · N₂" if r.burst>0 else ""),screen,15,CYAN if r.burst>0 and not warning else color,body_font if warning else number_font)
		if absf(gap)<24: _center(Weapons.data(r.loadout.current).name,screen+Vector2(0,29),12,MUTED)
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
	var rows = [["volume","主音量","%d%%"%roundi(game.settings.volume*100)],["music","电子配乐","开启" if game.settings.music else "关闭"],["shake","震动 / 动效 / 氮气气流","开启" if game.settings.shake else "关闭"],["quality","渲染质量","精致 · 120 FPS 上限" if game.settings.quality else "流畅 · 60 FPS 上限"],["map","赛道小地图","显示" if game.settings.map else "隐藏"],["mirror","实时后视镜","显示" if game.settings.mirror else "隐藏"],["air_walls","赛道空气墙 · 下局生效","✓ 开启" if game.settings.air_walls else "— 关闭 / 可驶出道路"],["oncoming","对向车道 · 下局生效","✓ 开启 / 右侧通行" if game.settings.oncoming else "— 关闭"],["bindings","修改快捷键","KEY BINDINGS  →"]]
	for i in rows.size(): _button(rows[i][0],rows[i][1],Rect2(292,191+i*56,856,46),false,rows[i][2])
	_text("空气墙 / 对向车流从下一场生效；关闭空气墙可撞楼或坠海。",Vector2(292,727),16,MUTED)
	_button("back","返回",Rect2(292,766,250,55),true,"ESC")

func _help() -> void:
	_shade(0.88)
	_text("LEARN THE STREETS",Vector2(180,136),56,WHITE,title_font)
	_text("驾驶指南",Vector2(180,184),24,CYAN)
	var rows = [[game.controls.label("steer_left")+" / "+game.controls.label("steer_right"),"左右转向（方向键也可用）","左摇杆"],[game.controls.label("brake"),"刹车 · 松开恢复自动油门","LT"],[game.controls.label("boost"),"按住氮气加速 · 松开恢复","RT / A"],[game.controls.label("attack_left")+" / "+game.controls.label("attack_right"),"左右攻击，连续命中击倒","LB / RB"],[game.controls.label("attack_auto"),"自动选择攻击方向","—"],[game.controls.label("show_roster"),"查看车手信息（自动暂停）","BACK"],[game.controls.label("cycle_weapon"),"切换拳击 / 踢击 / 夺来的武器","Y"],[game.controls.label("aerial_stunt"),"空中离座展体 · 自动回座 · 所有地图落地无车损","X"],["ESC / "+game.controls.label("pause_game"),"暂停 / 继续；M 静音，F11 全屏","START"]]
	for i in rows.size():
		var y = 232+i*51
		draw_line(Vector2(180,y+20),Vector2(1260,y+20),Color(0.4,0.6,0.7,0.18),1)
		_text(rows[i][0],Vector2(185,y),18,WHITE)
		_text(rows[i][1],Vector2(480,y),18,MUTED)
		_text(rows[i][2],Vector2(1115,y),17,CYAN)
	_text("赢法",Vector2(185,704),22,ORANGE)
	_text("开局只有拳脚；亲手击倒持械 AI，自动夺取并装备其武器。",Vector2(270,704),18,WHITE)
	_text("切换不打断攻击收招；摔车保留库存，每局重新从拳脚开始。",Vector2(270,740),17,MUTED)
	_text("补给：绿箱 +25 耐久 / 蓝瓶 +35 氮气 / 金币 $100；维修免费，被捕按难度罚 $500–1100。",Vector2(185,771),14,CYAN)
	_button("back","准备好了",Rect2(180,791,275,57),true,"ESC")

func _results() -> void:
	var t=game.result_time if game.settings.shake else 2.0
	var style=Feedback.result(game.finish_reason,game.final_rank,game.last_damage_cause)
	_shade(0.79)
	_results_backdrop(t,game.finish_reason=="finished")
	var offset=Motion.offset(t,game.settings.shake)
	draw_set_transform(ui_offset+offset*ui_scale,0,Vector2.ONE*ui_scale)
	content_alpha=0.08+Motion.reveal(t,0,0.45)*0.92
	var win = game.finish_reason=="finished"
	var busted=game.finish_reason=="busted"
	_text(style.title,Vector2(168,135),56,WHITE,title_font)
	_text(style.subtitle,Vector2(168,191),34,style.color)
	_panel(Rect2(1028,77,242,163),Color(INK,0.8),12,Color(style.color,0.5))
	_status_icon(style.icon,Vector2(1149,138),39,Color(style.color,content_alpha))
	_center(style.badge,Vector2(1149,213),16,style.color)
	_text(game.world.course.name+" / "+game.world.course.en+"  ·  LV.%d"%game.active_level,Vector2(170,232),18,MUTED)
	_panel(Rect2(170,275,1100,300),Color(0.04,0.09,0.15,0.9),12,Color(style.color,0.55))
	_text("最终名次" if win else "比赛进度",Vector2(205,319),17,MUTED)
	_text("%02d"%game.final_rank if win else "%d%%"%int(game.distance/game.track_length*100),Vector2(205,458),128,style.color,number_font)
	if win: _text("/ %02d"%(game.rivals.size()+1),Vector2(390,456),35,MUTED,number_font)
	_text("TOTAL SCORE",Vector2(578,322),18,MUTED,number_font)
	_text("%06d"%Motion.count(game.score,t),Vector2(575,404),72,WHITE,number_font)
	_text("个人最佳  %06d"%game.best_score,Vector2(580,448),17,CYAN)
	draw_line(Vector2(205,482),Vector2(1230,482),Color("334c5a"),1)
	_text("用时  "+_time(game.elapsed),Vector2(206,533),21,WHITE)
	_text("击倒  %02d"%game.takedowns,Vector2(515,533),21,WHITE)
	_text("命中  %02d"%game.hits,Vector2(771,533),21,WHITE)
	_text("擦身  %02d"%game.near_misses,Vector2(1027,533),21,WHITE)
	if busted:
		_text("罚款 $%d  /  已扣 $%d  /  待缴 $%d"%[Motion.count(game.race_fine.gross,t,0.3,0.8),Motion.count(game.race_fine.paid,t,0.3,0.8),Motion.count(game.race_fine.unpaid,t,0.3,0.8)],Vector2(173,613),23,ORANGE)
	elif win:
		_text("比赛奖金 $%d  /  抵扣欠款 $%d  /  实际入账 $%d"%[Motion.count(game.race_income.gross,t,0.4,1.0),Motion.count(game.race_income.debt_paid,t,0.4,1.0),Motion.count(game.race_income.net,t,0.4,1.0)],Vector2(173,613),22,CYAN)
	else:
		_text("未完成比赛 · 本场无奖金 / 无新增罚款",Vector2(173,613),23,style.color)
	_text("钱包 $%d   ·   待缴罚款 $%d   ·   本场维修 $0（免费）"%[game.economy.cash,game.economy.debt],Vector2(173,652),18,MUTED)
	_text("脱逃 %02d · 最远 %.0fm"%[game.police.escapes,game.best_jump],Vector2(969,448),16,CYAN)
	_text("路上金币 $%d（已结算）"%game.race_cash,Vector2(969,419),16,ORANGE)
	_text("夺取武器 %02d"%game.weapons_claimed,Vector2(969,390),16,CYAN)
	_text("飞跃 %02d / 反弹 %02d / 特技 %02d"%[game.jumps,game.bounces,game.stunts],Vector2(969,353),16,CYAN)
	# Controls keep stable hitboxes throughout the entrance animation.
	content_alpha=1
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	_button("retry","再来一场",Rect2(170,687,345,65),true,"R / ENTER")
	draw_line(Vector2(170,759),Vector2(170+345*Motion.reveal(t,0.3,0.7),759),CYAN if win else ORANGE,2,true)
	_button("menu","返回主菜单",Rect2(539,687,300,65))
	_button("garage","车库 / 换车",Rect2(863,687,300,65))
	var km=Progress.measure(game.distance,game.track_length)
	_text("本场里程 %.3f / %.3f km   ·   距终点 %.3f km   ·   完成 %.1f%%"%[km.travelled_km,km.total_km,km.remaining_km,km.percent],Vector2(173,790),18,CYAN)
	_text(style.tip,Vector2(173,834),16,style.color)

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
	for slot in 4:
		var i=game.course_page*4+slot
		if i>=Data.COURSES.size(): break
		var course = Data.COURSES[i]
		var rect = Rect2(72+(slot%2)*391,205+int(slot/2)*233,369,210)
		var focused = _hotspot("course:%d"%i,rect)
		_panel(rect,Color(0.045,0.10,0.16,0.94),8,course.color if game.race_options.course==i or focused else Color("314653"))
		_text(course.en,rect.position+Vector2(20,38),27,course.color,title_font)
		_text(course.name,rect.position+Vector2(20,72),23,WHITE)
		_text("%.1f KM"%(Data.race_length(i,game.race_options.get("distance",0))/1000),rect.position+Vector2(263,72),18,MUTED,number_font)
		_paragraph(course.description,rect.position+Vector2(20,109),240,15,MUTED)
		_route_preview(i,Rect2(rect.position+Vector2(280,92),Vector2(65,72)))
		_text(("闭环 · %d 圈 / "%[1,2,4][game.race_options.get("distance",0)] if TrackRoute.PROFILES[i].closed else "单程 · ")+course.subtitle,rect.position+Vector2(20,186),12,course.color)
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
	_button("courses_prev","← 上一页",Rect2(900,670,145,44))
	_text("%d / %d"%[game.course_page+1,ceili(Data.COURSES.size()/4.0)],Vector2(1074,700),20,CYAN,number_font)
	_button("courses_next","更多地图 →",Rect2(1180,670,184,44))
	for choice in 3:
		_button("distance:%d"%choice,Data.DISTANCE_NAMES[choice]+" ×%d"%[1,2,4][choice],Rect2(72+choice*255,666,241,49),game.race_options.get("distance",0)==choice)
	_button("race_begin","开始竞赛",Rect2(72,748,360,65),true,"GO  →")
	_button("roster","查看车手",Rect2(456,748,260,65))
	_button("back","返回",Rect2(740,748,210,65),false,"ESC")
	_text("赛程同步终点、地形与纪录；最高难度建议升级摩托，留好氮气应对末段冲刺。",Vector2(76,862),15,MUTED)

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
		var weapon_id=game.rivals[i].loadout.current if i<game.rivals.size() else profile.weapon
		_text(Weapons.data(weapon_id).name,rect.position+Vector2(85,89),12,profile.color)
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
	var weapon=Weapons.data(game.rivals[p.id].loadout.current if not game.rivals.is_empty() and p.id<game.rivals.size() else p.weapon)
	_text("当前武器：%s  /  距离 %.1fm  /  间隔 %.2fs"%[weapon.name,weapon.reach,weapon.cooldown],Vector2(486,445),17,weapon.color)
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
		_text("状态："+(r.node.recovery_stage if r.node.recovery_time>0 else ("已冲线" if r.finished else ("氮气 / "+r.boost_reason if r.burst>0 else "竞速中")))+" · 氮气发动 %d 次"%r.boosts_used,Vector2(185,726),18,p.color)
		var km=Progress.measure(r.distance,game.track_length)
		_text("已行驶 %.3f km / 剩余 %.3f km / 完成 %.1f%% / 与你相差 %+d m"%[km.travelled_km,km.remaining_km,km.percent,roundi(r.distance-game.distance)],Vector2(185,755),17,CYAN)
	_button("back","返回车手列表",Rect2(184,780,310,58),true,"ESC")

func _bindings() -> void:
	_shade(0.94)
	_text("MAKE IT YOURS",Vector2(120,127),53,WHITE,title_font)
	_text("快捷键设置",Vector2(122,176),25,CYAN)
	for i in Controls.ORDER.size():
		var action = Controls.ORDER[i]
		var rect = Rect2(120+int(i/7)*650,229+(i%7)*62,594,53)
		_button("bind:"+action,Controls.LABELS[action],rect,game.rebinding==action,"等待按键…" if game.rebinding==action else game.controls.label(action))
	_paragraph(game.binding_message,Vector2(123,693),1180,18,ORANGE if not game.rebinding.is_empty() else CYAN)
	_text("保留键：ESC、Enter、方向键、F11、M、R。菜单导航不受游戏改键影响。",Vector2(123,736),16,MUTED)
	_button("back","返回",Rect2(120,781,250,57),true,"ESC")
	_button("reset_keys","恢复默认按键",Rect2(396,781,290,57))

func _distance_header() -> void:
	var km=Progress.measure(game.distance,game.track_length)
	_panel(Rect2(304,18,764,80),Color(0.035,0.08,0.14,0.9),7)
	_text("已行驶",Vector2(321,39),13,MUTED)
	_text("%.3f KM"%km.travelled_km,Vector2(321,72),31,WHITE,number_font)
	_text("距终点",Vector2(525,39),13,MUTED)
	_text("%.3f KM"%km.remaining_km,Vector2(525,72),31,CYAN,number_font)
	_text("%s %.2f KM / LV.%d"%[("%d/%d 圈"%[game.world.route.lap(game.distance),roundi(game.track_length/game.world.route.lap_length)] if game.world.route.closed else Data.DISTANCE_NAMES[game.active_distance]),km.total_km,game.active_level],Vector2(740,40),15,MUTED,number_font)
	_text("%.1f%%"%km.percent,Vector2(931,71),28,ORANGE,number_font)
	var a=Vector2(322,86)
	draw_line(a,a+Vector2(727,0),Color("304a59"),3,true)
	draw_line(a,a+Vector2(727*km.fraction,0),ORANGE,3,true)
	for i in 5: draw_line(a+Vector2(i*727.0/4,-3),a+Vector2(i*727.0/4,3),MUTED,1)

func _standings_board(interactive: bool) -> void:
	# A shared kilometre axis with one lane per rider: even 16 racers at the
	# same distance remain individually identifiable without moving their dots.
	var rows=Progress.field(game.standings(),game.track_length)
	var axis_left=171.0
	var axis_width=126.0
	var height=85+rows.size()*20
	_panel(Rect2(32,324,342,height),Color(0.035,0.08,0.14,0.92),7)
	_text("全员赛程",Vector2(47,348),17,WHITE)
	_text("剩余 KM",Vector2(311,348),11,MUTED)
	_text("共同公里数轴 · 起点 → 终点",Vector2(47,372),12,MUTED)
	for i in 3:
		var x=axis_left+axis_width*i/2
		_center("%.2f"%(game.track_length/1000*i/2),Vector2(x,391),10,CYAN,number_font)
		draw_line(Vector2(x,398),Vector2(x,398+rows.size()*20),Color(0.3,0.5,0.6,0.22),1)
	_text("差距 m",Vector2(129,391),10,MUTED)
	draw_line(Vector2(axis_left,395),Vector2(axis_left+axis_width,395),MUTED,1,true)
	for i in rows.size():
		var r=rows[i]
		var y=400+i*20
		if r.id==-1: draw_rect(Rect2(39,y-1,328,20),Color(1,0.48,0.3,0.16))
		_text("%02d"%(i+1),Vector2(43,y+13),12,r.color,number_font)
		if r.id>=0:
			_avatar(r.id,Rect2(65,y,17,17))
			if interactive: _hotspot("profile:%d"%r.id,Rect2(39,y-1,328,20))
		else: draw_circle(Vector2(74,y+8),5,ORANGE)
		_text(r.name,Vector2(87,y+13),14,r.color,number_font)
		var gap_label="—" if r.id==-1 else "%+d"%roundi(r.distance-game.distance)
		_text(gap_label,Vector2(165-number_font.get_string_size(gap_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x,y+13),10,MUTED,number_font)
		var x=Progress.axis_x(r.fraction,axis_left,axis_width)
		draw_line(Vector2(axis_left,y+8),Vector2(axis_left+axis_width,y+8),Color("284352"),1,true)
		draw_line(Vector2(axis_left,y+8),Vector2(x,y+8),r.color.darkened(0.2),2,true)
		if r.id==-1:
			draw_colored_polygon(PackedVector2Array([Vector2(x,y+2),Vector2(x+6,y+8),Vector2(x,y+14),Vector2(x-6,y+8)]),ORANGE)
		else: draw_circle(Vector2(x,y+8),4,r.color)
		if r.recovering:
			draw_line(Vector2(x-4,y+4),Vector2(x+4,y+12),WHITE,1.5,true)
			draw_line(Vector2(x-4,y+12),Vector2(x+4,y+4),WHITE,1.5,true)
		if r.finished: draw_arc(Vector2(x,y+8),6,0,TAU,12,WHITE,1,true)
		_text("到达" if r.finished else "%.3f"%r.remaining_km,Vector2(316,y+13),12,CYAN if r.finished else (WHITE if r.id==-1 else MUTED),number_font if not r.finished else body_font)

func _minimap() -> void:
	var rect = MAP_RECT
	var f=_pursuit_feedback()
	var tint=Color(Feedback.RED,f.tint)
	var background=Color(0.03,0.08,0.14,0.86).blend(tint)
	_panel(rect,background,8,Color(Feedback.RED,0.4+f.pulse*0.4) if game.police.pursuit_active else Color("334c5b"))
	if f.visible:
		_status_icon(f.icon,rect.position+Vector2(25,22),12,f.color)
		_text(f.title,rect.position+Vector2(47,28),16,f.color)
	else: _text("赛道地图",rect.position+Vector2(15,25),16,WHITE)
	_text(game.controls.label("toggle_map"),rect.position+Vector2(199,25),14,CYAN,number_font)
	var points = PackedVector2Array()
	for i in 321: points.append(_map_position(float(i)/320*game.world.route.lap_length,0,rect))
	draw_polyline(points,Color("294453"),8,true)
	draw_polyline(points,Color("78959e").lerp(Feedback.RED,f.tint*3),2,true)
	for r in game.rivals:
		var pos = _map_position(r.distance,r.lane,rect)
		draw_circle(pos,3.8,r.color.darkened(0.35) if r.node.recovery_time>0 else r.color)
		if r.finished: draw_arc(pos,6,0,TAU,12,r.color,1,true)
	for cop in game.police.units:
		var dot=_map_position(cop.distance,cop.lane,rect)
		draw_rect(Rect2(dot-Vector2(4,4),Vector2(8,8)),Color("90e6ca") if cop.retreat else (Feedback.RED if f.pulse>=0.5 else Feedback.BLUE))
		if not cop.retreat:
			draw_arc(dot,7+f.pulse*3,0,TAU,20,Color(Feedback.RED,0.6),1.5,true)
	var player_pos = _map_position(game.distance,game.lane,rect)
	draw_circle(player_pos,7,INK)
	draw_circle(player_pos,5,ORANGE)
	_text("你",player_pos+Vector2(10,5),13,WHITE)
	var finish_label="起/终" if game.world.route.closed else "FINISH"
	var label_width=body_font.get_string_size(finish_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	var finish_pos=_map_position(game.track_length,0,rect)+Vector2(-label_width/2,-11)
	finish_pos.x=clampf(finish_pos.x,rect.position.x+8,rect.end.x-label_width-8)
	finish_pos.y=clampf(finish_pos.y,rect.position.y+47,rect.end.y-25)
	_text(finish_label,finish_pos,12,CYAN)
	_text("方框：警车 / 橙点：你" if game.police.pursuit_active else "等比路线 / 橙点：你",rect.position+Vector2(15,rect.size.y-15),12,MUTED)

func _map_position(at: float, lane: float, rect: Rect2) -> Vector2:
	# One uniform metres-to-pixels projection shared by road and all markers.
	return game.world.route.project(clampf(at,0,game.track_length),lane,Rect2(rect.position+Vector2(18,52),rect.size-Vector2(36,91)))

func _route_preview(index: int, rect: Rect2) -> void:
	var metres=Data.race_length(index,game.race_options.get("distance",0))
	var key="%d_%d"%[index,int(metres)]
	if not route_previews.has(key):
		var path=TrackRoute.new()
		path.build(index,metres)
		route_previews[key]=path
	var path=route_previews[key]
	var points=PackedVector2Array()
	for i in 161: points.append(path.project(path.lap_length*i/160.0,0,rect))
	draw_polyline(points,Data.COURSES[index].color,2,true)
	draw_circle(points[0],3,ORANGE)
	draw_circle(points[-1],3,WHITE)

func _rear_view() -> void:
	var rect = Rect2(516,106,420,125)
	_panel(Rect2(rect.position-Vector2(4,4),rect.size+Vector2(8,8)),Color("142934"),8,Color("577a83"))
	# Flip the rear-camera texture like a real mirror. UI stays unflipped.
	draw_set_transform(ui_offset+Vector2(rect.end.x,rect.position.y)*ui_scale,0,Vector2(-ui_scale,ui_scale))
	draw_texture_rect(game.mirror_view.get_texture(),Rect2(Vector2.ZERO,rect.size),false)
	draw_set_transform(ui_offset,0,Vector2.ONE*ui_scale)
	var behind: Array[Dictionary] = []
	for r in game.rivals:
		if game.world.route.gap(r.distance,game.distance)<0 and game.world.route.gap(game.distance,r.distance)<160: behind.append(r)
	behind.sort_custom(func(a,b): return game.world.route.gap(a.distance,game.distance)>game.world.route.gap(b.distance,game.distance))
	var label = "后方暂无近距离追兵"
	if not behind.is_empty(): label = "%s  距离 %dm"%[behind[0].name,game.world.route.gap(game.distance,behind[0].distance)]
	_center("REAR VIEW  /  "+label,Vector2(726,249),13,MUTED,body_font)

func _garage() -> void:
	_shade(0.91)
	_text("BUILD YOUR LEGACY",Vector2(70,112),55,WHITE,title_font)
	_text("摩托商店 / 已拥有的车辆可以免费切换",Vector2(73,156),21,CYAN)
	_text("钱包 $%d"%game.economy.cash,Vector2(1020,110),29,ORANGE,number_font)
	_text("待缴罚款 $%d"%game.economy.debt,Vector2(1020,148),18,MUTED)
	for slot in 4:
		var i=game.bike_page*4+slot
		if i>=game.Economy.BIKES.size(): break
		var bike=game.Economy.BIKES[i]
		var x=72+slot*328
		var selected_bike=game.economy.equipped==bike.id
		_panel(Rect2(x,204,306,492),Color("122333"),9,bike.color if selected_bike else Color("304554"))
		_text(bike.tag,Vector2(x+18,238),15,bike.color,number_font)
		_text(bike.name,Vector2(x+18,275),25,WHITE)
		# Original schematic preview; the equipped bike also changes its real 3D model.
		for wheel_x in [x+69,x+237]:
			draw_circle(Vector2(wheel_x,367),30,Color("060f18"))
			draw_arc(Vector2(wheel_x,367),21,0,TAU,24,MUTED,3,true)
		draw_line(Vector2(x+69,367),Vector2(x+103,312),WHITE,7,true)
		draw_line(Vector2(x+69,367),Vector2(x+190,345),bike.color,8,true)
		draw_line(Vector2(x+190,345),Vector2(x+237,367),WHITE,7,true)
		draw_colored_polygon(PackedVector2Array([Vector2(x+88,324),Vector2(x+125,299),Vector2(x+172,326),Vector2(x+252,316),Vector2(x+219,347),Vector2(x+114,352)]),bike.color)
		if i==2: draw_rect(Rect2(x+137,331,62,30),bike.color.darkened(0.25))
		if i in [4,6]: draw_line(Vector2(x+95,315),Vector2(x+112,291),CYAN,6,true)
		if i==5: draw_rect(Rect2(x+127,323,74,27),bike.color.darkened(0.4))
		if i==6: draw_rect(Rect2(x+199,330,55,40),bike.color.darkened(0.3))
		if i>=8:
			for coil in 5: draw_line(Vector2(x+187+coil*2,346-coil*6),Vector2(x+202+coil*2,346-coil*6),CYAN,2,true)
		if i==9: draw_rect(Rect2(x+129,328,77,27),bike.color.darkened(0.3))
		if i==10: draw_colored_polygon(PackedVector2Array([Vector2(x+148,314),Vector2(x+210,281),Vector2(x+201,326)]),CYAN)
		if i==11: draw_line(Vector2(x+96,311),Vector2(x+102,291),WHITE,5,true)
		if i in [3,7]: draw_line(Vector2(x+218,300),Vector2(x+270,300),bike.color,7,true)
		_text("极速 / 氮气  %d / %d km/h"%[bike.speed*3.6,bike.boost*3.6],Vector2(x+18,426),16,WHITE)
		_text("加速 %d   操控 %.1f"%[bike.accel,bike.handling],Vector2(x+18,459),17,MUTED)
		_text("碰撞伤害 %.0f%% / 缓冲 %.0f"%[bike.armor*100,bike.get("suspension",22.0)],Vector2(x+18,488),16,MUTED)
		_text("反弹系数 %.2f  /  空控 %.0f%%"%[bike.restitution,bike.air_control*100],Vector2(x+18,518),16,CYAN)
		draw_rect(Rect2(x+18,531,268,4),Color("2a4056"))
		draw_rect(Rect2(x+18,531,268*bike.restitution/0.8,4),bike.color)
		_paragraph(bike.desc,Vector2(x+18,557),268,15,MUTED)
		var owned=bike.id in game.economy.owned
		_button("bike:"+bike.id,"驾驶中" if selected_bike else ("换上这台" if owned else "购买 $%d"%bike.price),Rect2(x+17,620,272,53),selected_bike)
	_button("bikes_prev","← 上一页",Rect2(846,817,156,55))
	_text("%d / %d"%[game.bike_page+1,ceili(game.Economy.BIKES.size()/4.0)],Vector2(1030,851),22,CYAN,number_font)
	_button("bikes_next","更多摩托 →",Rect2(1141,817,220,55))
	_text(game.garage_message,Vector2(76,739),20,CYAN)
	_text("名次越高，奖金越多；难度与参赛人数影响奖金。被捕退赛无奖金，欠款从后续奖金优先扣除。",Vector2(76,778),17,MUTED)
	_button("back","返回",Rect2(74,817,260,55),true,"ESC")

func _results_backdrop(t: float, success: bool) -> void:
	if success:
		var gold=Feedback.result(game.finish_reason,game.final_rank).color
		for i in 3:
			var radius=80+fmod(t*90+i*130,420)
			draw_arc(Vector2(1300,130),radius,0,TAU,64,Color(gold,0.12*(1-radius/520)),2,true)
		var amount=64 if game.settings.quality else 28
		for i in amount:
			var age=fmod(t+float(i)*0.037,4.6)
			var x=35+fmod(float(i)*173,1370)+sin(age*2+i)*35
			var y=-40+age*(180+float(i%7)*18)
			var col=gold if i%3==0 else (ORANGE if i%3==1 else WHITE)
			col.a=0.7*minf(1,t*3)
			var center=Vector2(x,y)
			var turn=age*2.5+i
			var quad=PackedVector2Array()
			for corner in [Vector2(-3,-7),Vector2(3,-7),Vector2(3,7),Vector2(-3,7)]: quad.append(center+corner.rotated(turn))
			draw_colored_polygon(quad,col)
	else:
		var red=Feedback.result(game.finish_reason,game.final_rank).color
		var sweep=fmod(t*150,1700)-140
		for i in 8:
			var x=sweep+i*14
			draw_line(Vector2(x,0),Vector2(x-270,900),Color(red,0.013*(8-i)),12,true)
		var strength=0.08+0.025*sin(t*2)
		draw_rect(Rect2(0,0,13,900),Color(red,strength))
		draw_rect(Rect2(1427,0,13,900),Color("588bfa")*Color(1,1,1,strength) if game.finish_reason=="busted" else Color(red,strength))
		for i in 5:
			var shift=70*(1-Motion.reveal(t,float(i)*0.05,0.5))
			draw_line(Vector2(1150+shift,290+i*24),Vector2(1350+shift,230+i*24),Color(red,0.2),3,true)

func _weapon_hud(interactive: bool) -> void:
	var w=Weapons.data(game.loadout.current)
	var rect=Rect2(997,123,410,119)
	var edge=w.color if game.weapon_notice>0 else Color("38566a")
	_panel(rect,Color(0.035,0.08,0.14,0.94),8,edge)
	if interactive: _hotspot("cycle_weapon",rect)
	_text("ARSENAL  %02d / %02d"%[game.loadout.items.find(w.id)+1,game.loadout.items.size()],rect.position+Vector2(15,25),15,w.color,number_font)
	_text(game.controls.label("cycle_weapon")+"  切换",rect.position+Vector2(306,25),15,CYAN)
	_weapon_icon(w.id,rect.position+Vector2(38,66),w.color)
	_text(w.name,rect.position+Vector2(80,67),26,WHITE)
	var next=game.loadout.items[(game.loadout.items.find(w.id)+1)%game.loadout.items.size()]
	_text("下一项："+Weapons.data(next).name,rect.position+Vector2(80,93),14,MUTED)
	var cooldown=clampf(game.attack_cooldown/w.cooldown,0,1)
	draw_rect(Rect2(rect.position+Vector2(15,108),Vector2(380,3)),Color("294454"))
	draw_rect(Rect2(rect.position+Vector2(15,108),Vector2(380*(1-cooldown),3)),w.color)

func _weapon_icon(id: String, pos: Vector2, color: Color) -> void:
	if id=="fists":
		draw_rect(Rect2(pos+Vector2(-15,-9),Vector2(30,23)),color)
		for i in 4: draw_circle(pos+Vector2(-11+i*7,-10),4.5,color)
		draw_line(pos+Vector2(-17,0),pos+Vector2(-22,10),color,7,true)
	elif id=="kick":
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-13,-19),pos+Vector2(0,-19),pos+Vector2(4,6),pos+Vector2(23,9),pos+Vector2(22,17),pos+Vector2(-12,17)]),color)
	else:
		draw_line(pos+Vector2(-15,20),pos+Vector2(10,-19),color,5,true)
		var kind=Weapons.data(id).kind
		if kind=="heavy": draw_colored_polygon(PackedVector2Array([pos+Vector2(-1,-22),pos+Vector2(24,-16),pos+Vector2(19,-3),pos+Vector2(-5,-11)]),color)
		elif kind=="flex":
			var points=PackedVector2Array()
			for i in 15: points.append(pos+Vector2(10+sin(i*0.35)*15,-19+i*2.4))
			draw_polyline(points,color,2.5,true)
		else:
			draw_line(pos+Vector2(-1,-18),pos+Vector2(18,-6),color,3,true)
			draw_colored_polygon(PackedVector2Array([pos+Vector2(5,-17),pos+Vector2(19,-31),pos+Vector2(15,-11)]),color)

func _rebound_pop() -> void:
	var t=clampf(1.0-game.rebound_timer/1.15,0,1)
	var alpha=pow(1-t,1.3)
	var scale=lerpf(0.82,1.48,1-pow(1-t,3)) if game.settings.shake else 1.0
	var center=Vector2(720,275)
	var radius=38+t*40 if game.settings.shake else 50
	for ring in 2:
		draw_arc(center,radius+ring*20,-PI*0.92,-PI*0.08,48,Color(ORANGE,alpha*(0.65-ring*0.2)),3-ring,true)
	if game.settings.shake:
		for ray in 12:
			var direction=Vector2.RIGHT.rotated(ray*TAU/12)
			draw_line(center+direction*(radius+10),center+direction*(radius+28+game.rebound_power*25),Color(CYAN,alpha*0.55),2,true)
	# Deliberately a playful chart-shaped impact badge, not financial advice.
	var chart=PackedVector2Array([center+Vector2(-130,12),center+Vector2(-112,25),center+Vector2(-95,10),center+Vector2(-80,17),center+Vector2(-62,-6)])
	draw_polyline(chart,Color(CYAN,alpha),3,true)
	_center("触底反弹",center+Vector2(2,2),int(27*scale),Color(0.02,0.05,0.09,alpha))
	_center("触底反弹",center,int(27*scale),Color("ffcf91")*Color(1,1,1,alpha))
	_center("REBOUND  ×%d  /  蓄势上扬"%game.rebound_chain,center+Vector2(0,32),17,Color(CYAN,alpha),number_font)
