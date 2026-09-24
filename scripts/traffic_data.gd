extends RefCounted
## Dimensions include the body and define the actual swept collision envelope.
const MODELS = [
	{"id":"sedan","name":"旅行轿车","width":1.95,"length":4.1,"height":1.75,"speed":40.0},
	{"id":"hatch","name":"两厢小车","width":1.82,"length":3.4,"height":1.72,"speed":43.0},
	{"id":"suv","name":"越野 SUV","width":2.1,"length":4.7,"height":2.25,"speed":37.0},
	{"id":"taxi","name":"城市出租车","width":1.95,"length":4.1,"height":2.0,"speed":42.0},
	{"id":"van","name":"厢式货车","width":2.1,"length":5.1,"height":2.8,"speed":35.0},
	{"id":"pickup","name":"双排皮卡","width":2.15,"length":5.3,"height":2.1,"speed":38.0},
	{"id":"boxtruck","name":"物流箱式重卡","width":2.6,"length":8.8,"height":3.9,"speed":30.0},
	{"id":"tanker","name":"银色槽罐车","width":2.6,"length":10.2,"height":3.7,"speed":28.0},
	{"id":"semi","name":"集装箱半挂","width":2.65,"length":13.4,"height":4.1,"speed":27.0}
]
static func choose(rng: RandomNumberGenerator, course_id: String) -> Dictionary:
	var pool=[0,0,1,2,3,4,5,6,7,8]
	if course_id=="quarry": pool=[2,4,5,6,6,7,8,8]
	elif course_id=="neon": pool=[0,0,1,3,3,4,6]
	return MODELS[pool[rng.randi_range(0,pool.size()-1)]]
