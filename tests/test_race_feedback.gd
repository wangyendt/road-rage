extends "res://tests/test_ui.gd"
const Feedback = preload("res://scripts/race_feedback.gd")
const Acoustics = preload("res://scripts/siren_acoustics.gd")
func advance(seconds: float) -> void:
	for i in roundi(seconds*60): game._process(1.0/60)
func run() -> void:
	check(not Feedback.pursuit(false,0,false,0,99,0,true).visible,"no chase and old escape hides indicator")
	check(Feedback.pursuit(true,0,false,0,99,0,true).mode=="chase","chase icon")
	check(Feedback.pursuit(true,0,true,0,99,0,true).icon=="cuffs","downed danger icon")
	check(Feedback.pursuit(true,0.1,false,0,99,0,true).mode=="danger","arrest takes priority")
	check(Feedback.pursuit(true,0,false,0.5,99,0,true).mode=="escaping","escape hold state")
	check(Feedback.pursuit(false,0,false,0,2,0,true).icon=="check","escaped confirmation")
	check(not Feedback.pursuit(false,0,false,0,3.5,0,true).visible,"escape confirmation expires")
	var low=Feedback.pursuit(true,0,false,0,99,0.6,true)
	var high=Feedback.pursuit(true,0,false,0,99,0.2,true)
	check(low.tint<high.tint and high.tint<=0.15,"local flash is smoothly bounded")
	check(Feedback.pursuit(true,0,false,0,99,0,false)==Feedback.pursuit(true,0,false,0,99,1,false),"reduced motion freezes police feedback")
	check(Feedback.start_signal(3.5).lit==0,"staging has no red lights")
	for i in 3:
		check(Feedback.start_signal(3-i).lit==i+1,"red light synchronizes with tick %d"%i)
	check(Feedback.start_signal(0).go and Feedback.start_signal(0).lit==3,"green GO lights")
	var styles=[]
	for item in [["finished",1],["finished",2],["finished",5],["busted",9],["wrecked",9]]:
		styles.append(Feedback.result(item[0],item[1]).title)
	check(styles.size()==5 and styles.count("BUSTED")==1 and styles.count("WRECKED")==1,"five clear result presentations")
	check(Feedback.result("wrecked",4,"重落地").tip.contains("重落地"),"actual terminal damage reason shown")
	var approaching=Acoustics.sample(Vector2(0,-70),Vector2(0,95),Vector2(0,60))
	var receding=Acoustics.sample(Vector2(0,-70),Vector2(0,60),Vector2(0,95))
	check(approaching.pitch>1 and receding.pitch<1,"radial relative speed controls Doppler")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.start_race()
	advance(0.8)
	check(game.sound.countdown_cues==["count"],"first start tick emitted exactly once")
	game.back()
	var remaining=game.countdown
	advance(1.5)
	check(game.countdown==remaining and game.sound.countdown_cues.size()==1,"pause freezes start and prevents duplicate beep")
	game.ui_action("resume")
	advance(2.8)
	check(game.state=="race" and game.sound.countdown_cues==["count","count","count","go"],"resume finishes three ticks and one GO")
	advance(0.2)
	check(game.sound.countdown_cues.size()==4,"GO never repeats")
	game.police.reset()
	game.police.next_distance=INF
	game.distance=1500
	game.speed=85
	var cop=game.police.spawn(1475,-6)
	game.police.update(0.01)
	check(game.police.urgency>0 and game.police.pan<0,"near police feed yelp blend and left positioning")
	game.speed=100
	cop.distance=game.distance-160
	cop.engaged=true
	game.police.update(2.6)
	check(game.police.escapes==1 and is_equal_approx(game.police.escaped_at,game.elapsed),"escape timestamp matches actual successful escape")
	check(game.hud._pursuit_feedback().mode=="escaped","escaped icon survives inactive pursuit")
	game.start_race()
	check(game.police.escaped_at<0 and game.sound.countdown_cues.is_empty(),"retry clears escape and start feedback")
	game.state="race"
	game.health=1
	game.take_damage(20,"撞上车辆")
	game.finish_race("wrecked")
	check(game.last_damage_cause=="撞上车辆" and game.race_fine.gross==0 and game.race_income.gross==0,"collision failure keeps cause, no fine or prize")
	var cash=game.economy.cash
	advance(3)
	check(game.economy.cash==cash,"result presentation is financially inert")
	game.start_race()
	check(game.last_damage_cause.is_empty(),"new race clears old wreck reason")
	for i in 120: game.sound.update_world_audio(3000,1,true,1.0/60,1.2,1,-0.6)
	check(game.sound.siren_urgency>0.99 and game.sound.siren_pan< -0.59,"siren envelope and pan converge")
	for i in 120: game.sound.update_world_audio(3000,1,false,1.0/60,1.2,1,-0.6)
	check(game.sound.siren_gain<0.001 and game.sound.siren_urgency<0.003,"pause or finish fades both siren layers")
	print("RACE_FEEDBACK_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
