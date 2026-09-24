extends "res://tests/test_ui.gd"
const Progress=preload("res://scripts/race_progress.gd")
func run() -> void:
	var m=Progress.measure(2700,5400)
	check(m.travelled_km==2.7 and m.remaining_km==2.7 and m.percent==50,"metres convert to travelled/remaining kilometres and percent")
	m=Progress.measure(-50,5400)
	check(m.metres==0 and m.remaining_km==5.4 and m.fraction==0,"pre-start distance clamps to starting point")
	m=Progress.measure(5600,5400)
	check(m.travelled_km==5.4 and m.remaining_km==0 and m.percent==100,"post-finish distance cannot exceed 100 percent or go negative")
	check(Progress.axis_x(0,171,126)==171 and Progress.axis_x(1,171,126)==297,"number axis uses exact start and finish coordinates")
	check(Progress.axis_x(0.25,0,400)==100,"rider marker position is proportional to kilometres")
	check(is_finite(Progress.measure(0,0).fraction),"invalid zero length is safe")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.set_process(false)
	game.race_options={"course":0,"ai_count":15,"difficulty":3}
	game.start_race()
	game.police.enabled=false
	await process_frame
	await capture("v31-start-axis")
	var rows=Progress.field(game.standings(),game.track_length)
	check(rows.size()==16,"all fifteen AI plus player appear on shared axis")
	var ids={}
	for row in rows: ids[row.id]=true
	check(ids.size()==16,"clustered start does not merge or discard any rider")
	game.state="race"
	game.distance=2700
	game.speed=74
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	for i in game.rivals.size(): game.rivals[i].distance=300+i*330
	game._process(1.0/60)
	game.message_time=0
	await capture("v31-progress")
	rows=Progress.field(game.standings(),game.track_length)
	var ordered=true
	for i in range(1,rows.size()):
		if rows[i].fraction>rows[i-1].fraction: ordered=false
	check(ordered,"rank order matches kilometre positions")
	var last_id=game.rivals[14].id
	await click("profile:%d"%last_id)
	check(game.state=="profile" and game.selected_profile==last_id,"axis row remains clickable for precise rider kilometres")
	await capture("v31-profile-km")
	await key(KEY_ESCAPE)
	check(game.state=="paused","closing progress profile returns to paused race")
	var before=game.distance
	for i in 60: game._process(1.0/60)
	check(game.distance==before,"paused number axis does not advance")
	await key(KEY_ESCAPE)
	check(game.state=="race","resume returns to race with progress intact")
	game.rivals[0].distance=game.track_length+50
	game.rivals[0].finished=true
	game.distance=game.track_length-1
	rows=Progress.field(game.standings(),game.track_length)
	check(rows[0].finished and rows[0].remaining_km==0 and rows[0].fraction==1,"finished AI stays at end of axis with zero remaining")
	game.world.update_track(game.distance,game.track_length,game.total_time)
	game.hud.queue_redraw()
	await capture("v31-near-finish")
	for course in 4:
		game.race_options.course=course
		game.start_race()
		m=Progress.measure(game.track_length*0.25,game.track_length)
		check(is_equal_approx(m.percent,25) and is_equal_approx(m.remaining_km,game.track_length*0.75/1000),"course %d uses its actual total length"%course)
	game.race_options.ai_count=1
	game.start_race()
	check(Progress.field(game.standings(),game.track_length).size()==2,"minimum grid removes unused rider rows")
	print("PROGRESS_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.sound.shutdown()
	game.queue_free()
	await create_timer(0.6).timeout
	quit(1 if failed else 0)
