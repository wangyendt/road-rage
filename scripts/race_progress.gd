extends RefCounted
## One metre-based source of truth for the kilometre HUD and every rider's axis.
static func measure(distance_m: float, length_m: float) -> Dictionary:
	var length=maxf(0.001,length_m)
	var travelled=clampf(distance_m,0,length)
	return {"metres":travelled,"total_km":length/1000.0,"travelled_km":travelled/1000.0,"remaining_km":maxf(0,length-travelled)/1000.0,"fraction":travelled/length,"percent":100.0*travelled/length}

static func field(standings: Array[Dictionary], length_m: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rider in standings:
		var row=rider.duplicate()
		row.merge(measure(float(rider.distance),length_m))
		rows.append(row)
	return rows

static func axis_x(fraction: float, left: float, width: float) -> float:
	return left+clampf(fraction,0,1)*width
