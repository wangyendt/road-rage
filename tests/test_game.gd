extends SceneTree
## Integration tests against the real game coordinator, without rendering or saved-state writes.
var passed = 0
var failed = 0
var game: Node

func _init() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error("FAIL "+label)

func step(frames: int) -> void:
	for i in frames:
		game._process(1.0/60.0)

func fresh() -> void:
	game.race_options = {"course":0,"ai_count":5,"difficulty":3}
	game.start_race()
	game.settings.hard = false
	game.state = "race"
	game.countdown = 0

func run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	check(game.state == "menu","boots into menu")
	check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("SFX")>=0,"music and effects buses exist")
	game.race_options = {"course":0,"ai_count":5,"difficulty":3}
	game.start_race()
	check(game.state == "countdown" and game.rivals.size()==5,"race begins with countdown and five rivals")
	game.back()
	var count = game.countdown
	step(60)
	check(game.state=="paused" and game.countdown==count,"pause freezes countdown")
	game.ui_action("settings")
	game.back()
	game.back()
	check(game.state=="countdown","settings return and resume preserve countdown")
	step(212)
	check(game.state=="race","countdown transitions into racing")
	step(240)
	check(game.distance>100 and game.speed>65,"automatic throttle advances down track")
	game.back()
	var pos = game.distance
	var race_time = game.elapsed
	step(60)
	check(game.distance==pos and game.elapsed==race_time,"pause freezes race simulation and timer")
	game.back()
	Input.action_press("steer_right")
	step(30)
	Input.action_release("steer_right")
	check(game.lane>2,"steering responds to input actions")
	Input.action_press("brake")
	step(100)
	Input.action_release("brake")
	check(game.speed<30,"braking reduces speed")
	fresh()
	game.speed = 74
	Input.action_press("boost")
	step(60)
	check(game.speed>85 and game.nitro<80,"nitro increases speed and consumes reserve")
	step(240)
	check(game.boost_lock and not game.boost_active,"holding depleted nitro does not stutter-retrigger")
	Input.action_release("boost")
	step(120)
	check(not game.boost_lock and game.nitro>10,"release regenerates and unlocks nitro")
	fresh()
	# Put one opponent beside us, all others out of melee range.
	for r in game.rivals: r.distance = 1000
	var target = game.rivals[0]
	target.distance = 0
	target.lane = -2
	game.attack(1)
	check(target.hp==2,"wrong-side attack misses")
	game.attack_cooldown = 0
	game.attack(-1)
	check(target.hp==1 and game.hits==1 and game.combo==1,"first strike damages and builds combo")
	game.attack(-1)
	check(target.hp==1,"attack cooldown prevents instant double hit")
	game.attack_cooldown = 0
	game.attack(-1)
	check(target.hp==0 and game.takedowns==1 and target.stun>2,"second strike knocks down opponent")
	check(game.score>=600 and game.combo==2,"knockdown grants combo score")
	game.take_damage(23,"test impact")
	check(game.health==77,"traffic-scale damage is applied")
	game.take_damage(23,"test immunity")
	check(game.health==77,"damage invulnerability prevents repeated contact drain")
	fresh()
	game.health = 50
	game._spawn_pickup(0,0,"repair")
	step(1)
	check(game.health==75,"repair pickup restores health")
	fresh()
	game.nitro = 20
	game._spawn_pickup(0,0,"nitro")
	step(1)
	check(game.nitro>=55 and game.score==50,"nitro pickup restores charge and grants score")
	fresh()
	game.speed = 74
	game._spawn_traffic(0,0)
	step(1)
	check(game.health==77 and game.speed<50,"traffic collision damages and slows bike")
	fresh()
	game.speed = 74
	game._spawn_traffic(-4.1,2.1,"sedan")
	step(1)
	check(game.near_misses==1 and game.score==100,"close safe overtake earns near-miss bonus")
	fresh()
	game.distance = 5399.5
	game.speed = 74
	for r in game.rivals: r.distance=5000
	step(1)
	check(game.state=="finished" and game.final_rank==1 and game.finish_reason=="finished","finish line produces first-place result")
	check(game.score>=4600,"finish grants position and durability bonus")
	game.ui_action("retry")
	check(game.state=="countdown" and game.distance==0 and game.health==100 and game.score==0,"retry fully resets race")
	fresh()
	game.health = 1
	game.take_damage(8,"test wreck")
	step(1)
	check(game.state=="finished" and game.finish_reason=="wrecked","zero durability produces defeat result")
	game.to_menu()
	check(game.state=="menu" and game.rivals.is_empty() and game.traffic.is_empty(),"return to menu clears race entities")
	print("TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.queue_free()
	await create_timer(1.4).timeout
	quit(1 if failed else 0)
