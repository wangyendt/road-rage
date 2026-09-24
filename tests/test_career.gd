extends SceneTree
const Economy=preload("res://scripts/economy.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value:
		passed+=1
		print("PASS CAREER ",message)
	else:
		failed+=1
		push_error("FAIL CAREER "+message)
func fresh() -> void:
	game.start_race()
	game.state="race"
	game.set_process(false)
	game.police.enabled=false
	game.damage_cooldown=0
func step(seconds: float) -> void:
	for i in int(seconds*60): game._process(1.0/60)
func run() -> void:
	var ledger=Economy.new()
	check(ledger.cash==1000 and ledger.equipped=="rr09","new career grants starter bike and 1000 cash")
	ledger.select("lynx")
	check(ledger.cash==1000 and ledger.owned.size()==1,"insufficient funds never buys or deducts")
	ledger.award(2000)
	ledger.select("lynx")
	check(ledger.cash==600 and ledger.equipped=="lynx" and ledger.owned.size()==2,"purchase deducts exact price and equips")
	ledger.select("lynx")
	check(ledger.cash==600,"owned bike is not charged twice")
	ledger.select("rr09")
	check(ledger.equipped=="rr09" and ledger.cash==600,"switching owned motorcycles is free")
	ledger.select("invalid")
	check(ledger.owned.size()==2 and ledger.cash==600,"invalid model cannot affect wallet")
	var receipt=ledger.fine(900)
	check(receipt.paid==600 and ledger.cash==0 and ledger.debt==300,"unpaid fine becomes debt without negative cash")
	var income=ledger.award(1000)
	check(income.debt_paid==300 and ledger.debt==0 and ledger.cash==700,"future prizes pay outstanding fines first")
	check(Economy.prize(1,16,3)>Economy.prize(2,16,3) and Economy.prize(2,16,3)>Economy.prize(3,16,3),"podium prize rewards rank")
	check(Economy.prize(1,16,5)>Economy.prize(1,2,1),"larger and harder races pay more")
	check(Economy.prize(0,16,3)==0 and Economy.prize(17,16,3)==0,"invalid rank never awards cash")
	var file=ConfigFile.new()
	ledger.save_config(file)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
	var temp_path="res://builds/test-career.cfg"
	var save_error=file.save(temp_path)
	var disk=ConfigFile.new()
	var load_error=disk.load(temp_path)
	var persisted=Economy.new()
	persisted.load_config(disk)
	check(save_error==OK and load_error==OK and persisted.cash==ledger.cash and persisted.owned==ledger.owned,"career survives real disk save and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	var restored=Economy.new()
	restored.load_config(file)
	check(restored.cash==ledger.cash and restored.owned==ledger.owned and restored.equipped==ledger.equipped,"career wallet and bikes survive configuration round trip")
	file.set_value("career","owned",["invalid","spectre","spectre"])
	file.set_value("career","equipped","invalid")
	restored.load_config(file)
	check(restored.owned==["rr09","spectre"] and restored.equipped=="rr09","invalid saved bike IDs and duplicates are sanitized")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	game.economy=Economy.new()
	game.set_process(false)
	check(game.world.finish_line.get_child_count()==96,"physical checkerboard finish line covers the roadway")
	check(game.world.spectators.size()==48,"finish festival has 48 cheering spectators")
	game.world.update_track(game.track_length-50,game.track_length,1.2)
	check(game.world.finish_gate.visible,"finish line and spectators appear before crossing")
	var pose=game.world.spectators[0].arm.rotation.z
	game.world.update_track(game.track_length-50,game.track_length,1.7)
	check(game.world.spectators[0].arm.rotation.z!=pose,"spectators actually wave rather than remaining static")
	game.economy.cash=20000
	game.ui_action("garage")
	game.ui_action("bike:titan")
	check(game.active_bike.id=="titan" and game.player.model_shape==2,"garage selection changes actual 3D motorcycle")
	fresh()
	game.take_damage(10,"test")
	check(is_equal_approx(game.health,100-10*game.Data.difficulty(game.active_level).damage*0.73),"equipped armor changes actual damage")
	game.to_menu()
	game.ui_action("garage")
	game.ui_action("bike:spectre")
	fresh()
	game.traffic_timer=INF
	game.pickup_timer=INF
	for car in game.traffic: car.node.queue_free()
	game.traffic.clear()
	game.damage_cooldown=1000
	step(6)
	check(game.speed>82,"upgraded engine changes actual race speed")
	var before=game.economy.cash
	game.distance=game.track_length
	game.finish_race("finished")
	var rewarded=game.economy.cash
	check(rewarded>before and game.race_income.gross>0,"finishing a race credits spendable money")
	game.finish_race("finished")
	check(game.economy.cash==rewarded,"duplicate finish call cannot pay twice")
	fresh()
	before=game.economy.cash
	game.finish_race("wrecked")
	check(game.economy.cash==before and game.race_income.gross==0,"wrecked race grants no prize")
	fresh()
	game.arrest_player()
	check(game.state=="race","mounted rider cannot be arrested")
	game.trigger_crash()
	game.arrest_player()
	check(game.state=="race","airborne rider cannot be arrested")
	step(1.1)
	before=game.economy.cash
	game.arrest_player()
	check(game.state=="finished" and game.finish_reason=="busted" and game.economy.cash<before,"grounded arrest ends race and deducts fine")
	var fined=game.economy.cash
	game.arrest_player()
	check(game.economy.cash==fined and game.race_income.gross==0,"one arrest means one fine and no podium prize")
	fresh()
	game.trigger_crash()
	game.damage_cooldown=10000
	step(4.0)
	game.arrest_player()
	check(game.state=="race" and game.player.recovery_time==0,"getting back on the motorcycle escapes arrest eligibility")
	# Exercise real police collision and on-foot capture, not just the receipt API.
	fresh()
	game.police.enabled=true
	game.police.next_distance=INF
	game.speed=40
	var cop=game.police.spawn(game.distance,game.lane)
	cop.speed=40
	cop.cooldown=0
	game.police.update(1.0/60)
	check(game.player.recovery_time>0,"police contact can knock a mounted rider off the bike")
	game.police.enabled=false
	step(1.0)
	game.police.enabled=true
	cop.distance=game.distance+3
	cop.lane=game.lane+2
	cop.speed=0
	for i in 100:
		if game.state=="race": game._process(1.0/60)
	check(game.finish_reason=="busted" and cop.on_foot,"officer exits police car and captures grounded rider")
	fresh()
	game.police.enabled=true
	game.distance=700
	game.police.update(1.0/60)
	check(game.police.units.size()==1,"pursuit appears through normal race progression")
	var cop_distance=game.police.units[0].distance
	game.back()
	step(1)
	check(game.police.units[0].distance==cop_distance,"pause freezes police pursuit")
	game.to_menu()
	check(game.police.units.is_empty(),"leaving race cleans up all police")
	print("CAREER_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	game.queue_free()
	await create_timer(0.5).timeout
	quit(1 if failed else 0)
