extends RefCounted
## Local career ledger. Points and spendable money are intentionally separate.
const BIKES = [
	{"id":"rr09","name":"RR-09 街头先锋","tag":"STREET / BALANCED","price":0,"speed":74.0,"boost":99.0,"accel":17.0,"handling":10.5,"armor":1.0,"color":Color("f26942"),"shape":0,"desc":"免费起始座驾。速度与操控均衡，适合学习贴身战斗。"},
	{"id":"lynx","name":"LYNX 轻骑","tag":"AGILITY / CONTROL","price":2400,"speed":77.0,"boost":103.0,"accel":21.0,"handling":12.4,"armor":1.06,"color":Color("52dbc0"),"shape":1,"desc":"轻量车架，转向灵活、加速更快；装甲略薄。"},
	{"id":"titan","name":"TITAN 铁卫","tag":"ARMOR / COMBAT","price":5600,"speed":79.0,"boost":105.0,"accel":16.0,"handling":9.8,"armor":0.73,"color":Color("eab14d"),"shape":2,"desc":"厚重侧甲和护杠，承受伤害降低 27%；走位要提前。"},
	{"id":"spectre","name":"SPECTRE 幻影","tag":"SPEED / PRECISION","price":9800,"speed":85.0,"boost":114.0,"accel":23.0,"handling":11.3,"armor":1.12,"color":Color("ad89ff"),"shape":3,"desc":"空气动力尾翼与竞速整流罩，极速最高；失误代价也更大。"}
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
