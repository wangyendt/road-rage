extends RefCounted
## Presentation only; displayed counts never mutate the career ledger.
static func reveal(time: float, delay: float = 0.0, duration: float = 0.6) -> float:
	var p=clampf((time-delay)/maxf(duration,0.001),0,1)
	return 1-pow(1-p,3)

static func count(value: int, time: float, delay: float = 0.15, duration: float = 1.1) -> int:
	return int(round(value*reveal(time,delay,duration)))

static func offset(time: float, shake: bool) -> Vector2:
	var landing=48*(1-reveal(time,0,0.65))
	var impact=sin(time*38)*5*exp(-time*9) if shake else 0.0
	return Vector2(impact,landing)
