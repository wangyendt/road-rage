extends RefCounted
## Bounded nonlinear pace compensation. Distances are NEVER teleported.
## Speed differences shrink gradually, while end-game skill still matters.
const Data = preload("res://scripts/game_data.gd")

static func target_speed(level: int, profile: Dictionary, gap_to_anchor: float, remaining: float, boosting: bool = false) -> float:
	var d = Data.difficulty(level)
	var base = d.pace + (profile.pace-0.82)*13.0
	var correction = 0.0
	if gap_to_anchor < -22.0:
		correction = d.catchup * tanh((-gap_to_anchor-22.0)/145.0)
	elif gap_to_anchor > 38.0:
		correction = -d.leader_drag * tanh((gap_to_anchor-38.0)/170.0)
	# Reduce, do not abruptly disable, compensation near the finish.
	var finish_factor = lerpf(0.68,1.0,clampf(remaining/650.0,0,1))
	var sprint = 4.0*(1.0-clampf(remaining/1100.0,0,1)) if level==5 else 0.0
	var target = base + correction*finish_factor + sprint + ((22.0 if level==5 else 13.0) if boosting else 0.0)
	return clampf(target,49.0,(124.0 if level==5 else 112.0) if boosting else 106.0)

static func player_assist(leader_gap: float, remaining: float) -> float:
	# Slight engine/recharge help after setbacks; no free teleport or forced victory.
	return 7.0*tanh(maxf(0,leader_gap-65.0)/170.0)*lerpf(0.55,1.0,clampf(remaining/650.0,0,1))

static func boost_reason(level: int, gap_to_player: float, next_gap: float, remaining: float, nitro: float, elapsed: float) -> String:
	if level<5:
		return "追赶" if nitro>40 and (gap_to_player< -9 or remaining<650) else ""
	if elapsed<2.0: return ""
	if remaining<1100 and nitro>=18: return "终点冲刺"
	# Preserve a useful reserve on the approach to the final sprint.
	var reserve=65.0 if remaining<1700 else 42.0
	if nitro<reserve: return ""
	if gap_to_player< -12: return "追赶"
	if next_gap>0 and next_gap<95: return "超车"
	if gap_to_player>=0 and gap_to_player<75: return "防守"
	if nitro>=90: return "直道提速"
	return ""
