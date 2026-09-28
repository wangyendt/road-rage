extends RefCounted
## Local career ledger. Points and spendable money are intentionally separate.
const BIKES = [
	{"id":"rr09","name":"RR-09 街头先锋","tag":"STREET / BALANCED","price":0,"speed":74.0,"boost":99.0,"accel":17.0,"handling":10.5,"armor":1.0,"color":Color("f26942"),"restitution":0.24,"air_control":0.35,"shape":0,"desc":"免费起始座驾。速度与操控均衡，适合学习贴身战斗。"},
	{"id":"lynx","name":"LYNX 轻骑","tag":"AGILITY / CONTROL","price":2400,"speed":77.0,"boost":103.0,"accel":21.0,"handling":12.4,"armor":1.06,"color":Color("52dbc0"),"restitution":0.28,"air_control":0.35,"shape":1,"desc":"轻量车架，转向灵活、加速更快；装甲略薄。"},
	{"id":"titan","name":"TITAN 铁卫","tag":"ARMOR / COMBAT","price":5600,"speed":79.0,"boost":105.0,"accel":16.0,"handling":9.8,"armor":0.73,"color":Color("eab14d"),"restitution":0.18,"air_control":0.35,"shape":2,"desc":"厚重侧甲和护杠，承受伤害降低 27%；走位要提前。"},
	{"id":"spectre","name":"SPECTRE 幻影","tag":"SPEED / PRECISION","price":9800,"speed":85.0,"boost":114.0,"accel":23.0,"handling":11.3,"armor":1.12,"color":Color("ad89ff"),"restitution":0.22,"air_control":0.35,"shape":3,"desc":"空气动力尾翼与竞速整流罩，高速竞赛；失误代价也更大。"},
	{"id":"nomad","name":"NOMAD 越野行者","tag":"RALLY / SUSPENSION","price":4200,"speed":76.0,"boost":102.0,"accel":19.0,"handling":11.6,"armor":0.93,"suspension":27.0,"grip":1.2,"color":Color("d9e898"),"restitution":0.34,"air_control":0.35,"shape":4,"desc":"拉力风挡与高位护泥板。长行程悬挂吸收落地冲击，碎石路更稳。"},
	{"id":"comet","name":"COMET 电光","tag":"ELECTRIC / ACCEL","price":7200,"speed":81.0,"boost":110.0,"accel":29.0,"handling":12.8,"armor":1.14,"suspension":19.0,"grip":1.05,"color":Color("79c8ff"),"restitution":0.26,"air_control":0.35,"shape":5,"desc":"封闭电池车身，瞬间加速擅长出弯；注意避让车流。"},
	{"id":"mammoth","name":"MAMMOTH 远征","tag":"TOURING / ENDURANCE","price":8400,"speed":80.0,"boost":107.0,"accel":18.0,"handling":10.1,"armor":0.68,"suspension":25.0,"grip":1.12,"color":Color("de9b6f"),"restitution":0.20,"air_control":0.35,"shape":6,"desc":"双侧边箱与高风挡。耐撞、落地稳，代价是转向较慢。"},
	{"id":"falcon","name":"FALCON 隼影","tag":"HYPER / AERO","price":14500,"speed":91.0,"boost":122.0,"accel":25.0,"handling":11.8,"armor":1.2,"suspension":21.0,"grip":1.08,"color":Color("f278b1"),"restitution":0.30,"air_control":0.35,"shape":7,"desc":"低风阻整流罩与双翼。最高极速更易冲坡起飞，适合高手。"},
	{"id":"spring","name":"SPRING 弹簧侠","tag":"REBOUND / STUNT","price":6800,"speed":79.0,"boost":108.0,"accel":22.0,"handling":11.5,"armor":0.95,"suspension":36.0,"grip":1.10,"restitution":0.68,"air_control":0.55,"color":Color("ffba58"),"shape":8,"desc":"外露长弹簧。落地连弹更高，需提前留出空中走线。"},
	{"id":"anvil","name":"ANVIL 镇山","tag":"DAMPING / ARMOR","price":11200,"speed":83.0,"boost":112.0,"accel":19.0,"handling":10.2,"armor":0.64,"suspension":43.0,"grip":1.22,"restitution":0.16,"air_control":0.30,"color":Color("a3b9d2"),"shape":9,"desc":"液压吸震与厚重护板。落地更稳，反弹低，适合陡坡。"},
	{"id":"kestrel","name":"KESTREL 空隼","tag":"AERO / AIR CONTROL","price":16800,"speed":89.0,"boost":120.0,"accel":26.0,"handling":12.3,"armor":1.08,"suspension":37.0,"grip":1.04,"restitution":0.52,"air_control":0.78,"color":Color("66dced"),"shape":10,"desc":"侧翼与分体尾架。空中转向灵活，中等弹性兼顾飞跃。"},
	{"id":"rover","name":"ROVER 巡界者","tag":"RALLY / ENDURANCE","price":12600,"speed":85.0,"boost":114.0,"accel":23.0,"handling":11.7,"armor":0.80,"suspension":40.0,"grip":1.30,"restitution":0.38,"air_control":0.48,"color":Color("b3df9b"),"shape":11,"desc":"双后避震和防滚架。碎石抓地更强，长距离起伏稳定。"}


]
var cash = 1000
var debt = 0
var owned: Array[String] = ["rr09"]
var equipped = "rr09"
var total_prizes = 0
var total_fines = 0

func bike(id: String = "") -> Dictionary:
	if id.is_empty(): id=equipped
	for item in BIKES:
		if item.id==id: return item
	return BIKES[0]

func select(id: String) -> String:
	var item = bike(id)
	if item.id!=id: return "没有这台摩托"
	if id in owned:
		equipped=id
		return "已换上 "+item.name
	if debt>0: return "先完成比赛，用奖金结清待缴罚款"
	if cash<item.price: return "余额不足，还差 $%d"%(item.price-cash)
	cash-=item.price
	owned.append(id)
	equipped=id
	return "购买成功，已换上 "+item.name

static func prize(rank: int, field: int, level: int) -> int:
	if rank<1 or rank>field: return 0
	var base = [3000,1900,1200][rank-1] if rank<=3 else (650 if rank<=ceili(field*0.5) else 250)
	var grid_factor = 0.45+0.55*clampf(float(field-1)/15,0,1)
	return int(round(base*grid_factor*(0.8+clampi(level,1,5)*0.1)/10))*10

func award(amount: int) -> Dictionary:
	amount=maxi(0,amount)
	var repayment=mini(debt,amount)
	debt-=repayment
	cash+=amount-repayment
	total_prizes+=amount
	return {"gross":amount,"debt_paid":repayment,"net":amount-repayment}

func fine(amount: int) -> Dictionary:
	amount=maxi(0,amount)
	var paid=mini(cash,amount)
	cash-=paid
	debt+=amount-paid
	total_fines+=amount
	return {"gross":amount,"paid":paid,"unpaid":amount-paid}

func save_config(file: ConfigFile) -> void:
	for key in ["cash","debt","owned","equipped","total_prizes","total_fines"]:
		file.set_value("career",key,get(key))

func load_config(file: ConfigFile) -> void:
	cash=clampi(int(file.get_value("career","cash",1000)),0,100000000)
	debt=clampi(int(file.get_value("career","debt",0)),0,100000000)
	total_prizes=maxi(0,int(file.get_value("career","total_prizes",0)))
	total_fines=maxi(0,int(file.get_value("career","total_fines",0)))
	owned=["rr09"]
	var saved=file.get_value("career","owned",[])
	if saved is Array:
		for id in saved:
			if id is String and bike(id).id==id and id not in owned: owned.append(id)
	var chosen=str(file.get_value("career","equipped","rr09"))
	equipped=chosen if chosen in owned else "rr09"
