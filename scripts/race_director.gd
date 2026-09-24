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
	var target = base + correction*finish_factor + (13.0 if boosting else 0.0)
	return clampf(target,49.0,112.0 if boosting else 106.0)

static func player_assist(leader_gap: float, remaining: float) -> float:
	# Slight engine/recharge help after setbacks; no free teleport or forced victory.
	return 7.0*tanh(maxf(0,leader_gap-65.0)/170.0)*lerpf(0.55,1.0,clampf(remaining/650.0,0,1))
