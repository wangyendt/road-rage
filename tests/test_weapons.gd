extends SceneTree
const Weapons=preload("res://scripts/weapons.gd")
const Loadout=preload("res://scripts/loadout.gd")
const Controls=preload("res://scripts/controls.gd")
var game: Node
var passed=0
var failed=0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS WEAPONS ",label)
	else:
		failed+=1
		push_error("FAIL WEAPONS "+label)
func fresh() -> void:
	game.race_options={"course":0,"ai_count":15,"difficulty":3}
	game.start_race()
	game.state="race"
	game.set_process(false)
	game.police.enabled=false
	game.traffic_timer=INF
	game.pickup_timer=INF
	for r in game.rivals: r.distance=1000+r.id*10
	game.player.animate(0,0,0,false,0)
func equip(id: String) -> void:
	game.loadout.acquire(id)
	game.player.set_weapon(game.loadout.current)
	game.attack_cooldown=0
	game.player.attack_time=0
func target(index: int, x: float, d: float = 0.0) -> Dictionary:
	var r=game.rivals[index]
	r.lane=x
	r.distance=d
	r.ride.reset(game.world,d,0)
	return r
func run() -> void:
	var bag=Loadout.new()
	check(bag.items==["fists","kick"] and bag.current=="fists","new loadout contains only permanent punch and kick")
	check(bag.cycle()=="kick" and bag.cycle()=="fists","unarmed player can cycle between fists and feet")
	check(not bag.acquire("invalid") and bag.items.size()==2,"unknown equipment is rejected")
	var enemy=Loadout.new("spear")
	check(bag.take_from(enemy)=="spear" and bag.current=="spear","capture auto equips the defeated rider's weapon")
	check(enemy.items==["fists","kick"] and enemy.current=="fists","capture disarms the original owner")
	check(bag.take_from(enemy).is_empty() and bag.items.size()==3,"unarmed victim cannot duplicate loot")
	bag.acquire("spear")
	check(bag.items.size()==3,"duplicate weapon types do not grow inventory")
	for id in Weapons.ROSTER: bag.acquire(id)
	check(bag.items.size()==17,"inventory can hold every weapon plus both unarmed styles")
	var visited: Array[String]=[]
	for i in 17: visited.append(bag.cycle())
	check(visited.size()==17 and "fists" in visited and "whip" in visited,"full inventory remains cyclic with fists always reachable")
	var keyfile=ConfigFile.new()
	for action in Controls.ORDER:
		if action!="cycle_weapon": keyfile.set_value("keys",action,KEY_Q if action=="attack_left" else Controls.DEFAULTS[action])
	var controls=Controls.new()
	controls.load_config(keyfile)
	check(controls.keys.attack_left==KEY_Q and controls.keys.cycle_weapon!=KEY_Q,"old saves using Q keep their binding and gain a free weapon key")
	controls.rebind("cycle_weapon",KEY_X)
	var saved=ConfigFile.new()
	controls.save_config(saved)
	var restored=Controls.new()
	restored.load_config(saved)
	check(restored.keys.cycle_weapon==KEY_X,"weapon binding survives saving and reload")
	game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	fresh()
	check(game.loadout.items.size()==2 and game.player.equipped_weapon=="fists" and not game.player.weapon_visual.visible,"race starts with visibly empty hands")
	var distinct: Dictionary={}
	for r in game.rivals: distinct[r.loadout.current]=true
	check(distinct.size()==15,"fifteen riders receive fifteen distinct armed loadouts")
	var matches=true
	for r in game.rivals:
		if r.node.equipped_weapon!=r.profile.weapon: matches=false
	check(matches,"rider identity and actual 3D weapon agree")
	var r=target(1,2.0)
	var voices=game.sound.rider_hit_count
	game.attack(-1)
	check(r.hp==2 and game.sound.rider_hit_count==voices,"wrong-side swing neither damages nor voices a hit")
	game.attack_cooldown=0
	game.attack(1)
	check(r.hp==1 and game.loadout.items.size()==2,"first punch wounds but does not award an undefeated opponent's weapon")
	check(game.sound.last_rider_hit.id==r.id and not game.sound.last_rider_hit.heavy,"hit grunt identifies the actual struck rider")
	game.attack_cooldown=0
	game.attack(1)
	check(r.hp<=0 and game.loadout.current=="spear" and game.weapons_claimed==1,"second punch knocks down and steals the spear")
	check(r.loadout.current=="fists" and r.node.equipped_weapon=="fists","defeated AI loses both equipment state and model")
	check(game.sound.last_rider_hit.heavy,"knockdown plays the heavier rider response")
	check(game.claim_weapon(r).is_empty() and game.weapons_claimed==1,"same knockdown cannot award a weapon twice")
	r.node.animate(4,0,0,false,0)
	check(r.node.recovery_time==0 and r.node.equipped_weapon=="fists","remount does not regenerate the stolen weapon")
	game.attack_cooldown=0
	game.player.attack_time=0
	game.cycle_weapon()
	check(game.loadout.current=="fists" and not game.player.weapon_visual.visible,"cycling away from loot hides the weapon for unarmed combat")
	game.cycle_weapon()
	game.player.swing(-1)
	game.player.animate(0.2,60,0,false,0)
	check(game.loadout.current=="kick" and absf(game.player.legs[0].rotation.z)>0.8,"kick uses a visibly extended leg rather than a hand swing")
	var held=game.loadout.current
	game.cycle_weapon()
	check(game.loadout.current==held,"cycling cannot cancel an attack animation")
	fresh()
	r=target(0,4.5)
	game.attack(1)
	check(r.hp==2,"bare fists cannot reach a distant lane")
	equip("spear")
	game.attack(1)
	check(r.hp==1,"long spear reaches the same distant rider")
	fresh()
	r=target(0,2.0)
	equip("axe")
	game.attack(1)
	check(r.hp<=0 and game.attack_cooldown>0.8,"heavy axe trades long recovery for a one-hit knockdown")
	var equipped=game.loadout.current
	game.player.attack_time=0
	game.cycle_weapon()
	check(game.loadout.current==equipped,"loot does not bypass heavy-weapon cooldown through switching")
	fresh()
	r=target(0,3.0)
	equip("hook")
	game.attack(1)
	check(r.lane<3.0 and r.stun>=0.7,"hook pulls the victim closer and applies its longer stagger")
	fresh()
	r=target(0,2.0)
	r.ride.y=4
	equip("spear")
	game.attack(1)
	check(r.hp==2,"weapons cannot hit a rider on a different vertical level")
	fresh()
	r=target(0,2.0)
	r.hit_cd=1.5
	voices=game.sound.rider_hit_count
	game.attack(1)
	check(r.hp==2 and game.sound.rider_hit_count==voices,"remount protection also blocks player weapon damage and grunt")
	fresh()
	var attacker=target(3,2.0)
	attacker.target_id=-1
	game._resolve_ai_attack(attacker)
	check(game.health==82 and game.sound.last_rider_hit.id==-1,"AI halberd applies its own damage and player grunt")
	voices=game.sound.rider_hit_count
	game._resolve_ai_attack(attacker)
	check(game.sound.rider_hit_count==voices and game.health==82,"invulnerability rejects both repeated damage and fake hit voices")
	fresh()
	attacker=target(3,2)
	var victim=target(0,3.8)
	attacker.target_id=0
	game._resolve_ai_attack(attacker)
	check(victim.hp<=0 and game.sound.last_rider_hit.id==0,"AI-to-AI heavy strike has the victim's reaction sound")
	check(game.loadout.items.size()==2,"player does not receive weapons from AI-versus-AI knockdowns")
	fresh()
	equip("whip")
	game.trigger_crash()
	game.player.animate(4,0,0,false,0)
	check(game.loadout.current=="whip" and game.player.weapon_visual.visible,"player retains acquired weapons across a crash and remount")
	game.back()
	game.cycle_weapon()
	check(game.loadout.current=="whip","paused race ignores weapon switching")
	game.start_race()
	check(game.loadout.items==["fists","kick"] and game.weapons_claimed==0,"new race clears loot and restores fists only start")
	var all_models=true
	for id in Weapons.ROSTER:
		game.player.set_weapon(id)
		game.player.swing(-1)
		game.player.animate(0.14,60,0,false,1)
		if not game.player.weapon_visual.visible or game.player.weapon_visual.get_child_count()==0: all_models=false
	check(all_models,"all fifteen melee models build and animate in either hand")
	game.player.set_weapon("whip")
	var before=game.player.weapon_visual.links.back().position
	game.player.weapon_visual.pose(1,1)
	check(before.distance_to(game.player.weapon_visual.links.back().position)>0.2,"flexible whip visibly unfurls during a swing")
	voices=game.sound.rider_hit_count
	game.sound.rider_hit(2,200,true)
	check(game.sound.rider_hit_count==voices,"distant AI fights do not flood the mix with grunts")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("WEAPON_TEST_RESULTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
