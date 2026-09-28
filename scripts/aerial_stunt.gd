extends RefCounted
## Cosmetic rider animation, not a crash or an invulnerability state.
const GRAVITY = preload("res://scripts/ride_physics.gd").GRAVITY
const BONUS = 300
var active = false
var stage = ""
var extension = 0.0
var age = 0.0
var return_age = 0.0
var return_duration = 0.4
var return_from = 0.0
var peak_extension = 0.0
var last_launch = -1
var pending_bonus = false

# Road-aware look-ahead handles both descent and an uphill landing ahead.
static func contact_eta(road, at: float, speed: float, height_y: float, velocity: float) -> float:
	for i in range(1,31):
		var t=i*0.05
		if height_y+velocity*t-0.5*GRAVITY*t*t<=road.height_at(at+speed*t): return t
	return 1.5

func start(launch: int, eta: float) -> bool:
	if active or pending_bonus or launch==last_launch or eta<1.0: return false
	active=true
	stage="离座"
	extension=0
	age=0
	peak_extension=0
	last_launch=launch
	return true

func step(dt: float, eta: float) -> void:
	if not active: return
	age+=dt
	if stage!="回座" and (age>=0.9 or eta<=0.55):
		stage="回座"
		return_age=0
		return_from=extension
		return_duration=clampf(minf(0.4,eta*0.7),0.04,0.4)
	if stage=="回座":
		return_age+=dt
		# Re-estimate if an approaching slope shortens the remaining flight.
		var left=maxf(0.001,return_duration-return_age)
		if eta<left: return_age=maxf(return_age,return_duration-eta*0.7)
		extension=return_from*(1-smoothstep(0,return_duration,return_age))
		if return_age>=return_duration:
			active=false
			extension=0
			stage="已回座"
			pending_bonus=peak_extension>=0.8
	else:
		extension=smoothstep(0,0.35,age)
		peak_extension=maxf(peak_extension,extension)
		if age>=0.35: stage="展体"

func land() -> bool:
	# A shortened/interrupted trick still mounts safely, but earns no trick points.
	var award=pending_bonus
	cancel()
	return award

func cancel() -> void:
	active=false
	pending_bonus=false
	extension=0
	stage=""
	age=0
