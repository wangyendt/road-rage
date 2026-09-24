extends RefCounted
const Weapons=preload("res://scripts/weapons.gd")
## Original rider identities and genuinely different race locations.
const COURSES = [
	{"id":"harbor","name":"港湾高架","en":"HARBOR RUN","length":5400.0,"subtitle":"落日海湾 / 跨海桥梁","description":"宽阔高架与长直道，适合贴身缠斗和氮气超车。","color":Color("ffad78"),"curve":[31.0,0.0017,12.0,0.0039],"traffic":1.0},
	{"id":"canyon","name":"赤岩峡谷","en":"RED ROCK PASS","length":4800.0,"subtitle":"荒漠峡谷 / 砂岩山脊","description":"蜿蜒峡谷与低矮岩壁，连续转向考验走线。","color":Color("ec9c59"),"curve":[72.0,0.0012,31.0,0.0032],"traffic":0.78},
	{"id":"alpine","name":"雪岭林道","en":"ALPINE RIDGE","length":5200.0,"subtitle":"高山针叶林 / 远眺雪峰","description":"冷色山地、大片针叶林和长弯道，保持节奏最重要。","color":Color("a6e4d4"),"curve":[90.0,0.0010,22.0,0.0028],"traffic":0.65},
	{"id":"neon","name":"霓虹都市","en":"NEON AFTERHOURS","length":6200.0,"subtitle":"夜间高速 / 霓虹天际线","description":"灯光隧廊与密集车流；利用后视镜防住追击。","color":Color("c8a4ff"),"curve":[25.0,0.0022,18.0,0.0044],"traffic":1.22},
	{"id":"coast","name":"海崖天际线","en":"COASTLINE FLIGHT","length":6800.0,"subtitle":"海崖起伏 / 跨谷飞跃","description":"掠过海岸与石拱。高速越过坡顶会离地，落地前留好走线。","color":Color("64dcca"),"curve":[65.0,0.0018,18.0,0.006],"traffic":0.85,"theme":0},
	{"id":"windfarm","name":"风车丘陵","en":"TURBINE HILLS","length":7200.0,"subtitle":"连绵丘陵 / 巨型风机","description":"连续波浪坡与风机群。长行程悬挂更适合反复腾空。","color":Color("d0e597"),"curve":[75.0,0.0014,20.0,0.0045],"traffic":0.8,"theme":2},
	{"id":"quarry","name":"矿场运输线","en":"QUARRY EXPRESS","length":5800.0,"subtitle":"施工收窄 / 碎石坡道","description":"重卡、锥桶与碎石路交替出现；提前减速通过窄口。","color":Color("ffbf67"),"curve":[65.0,0.0021,28.0,0.005],"traffic":1.12,"theme":1},
	{"id":"storm","name":"雨雾山脊","en":"STORM RIDGE","length":6600.0,"subtitle":"湿滑山路 / 急弯长坡","description":"冷雨中的高差山路，抓地力降低。坡顶加速前先看前方。","color":Color("90bced"),"curve":[88.0,0.0018,30.0,0.006],"traffic":0.75,"theme":3}

]
const LEVEL_NAMES = ["新手巡游","轻松竞速","街头高手","职业对抗","传奇极限"]
const LEVEL_DESCRIPTIONS = [
	"反应较慢，出手间隔长；适合练习驾驶与攻击。",
	"会避让交通，偶尔使用氮气追赶。",
	"会寻找尾流、打断玩家，并在长直道超车。",
	"更快反应、更积极选线，频繁反击与战术氮气。",
	"非线性强化：预判避让、佯攻走位、末段冲刺；失误会被抓住。"
]
static func difficulty(level: int) -> Dictionary:
	var n = clampi(level,1,5)-1
	return {"pace":[63.5,67.5,71.5,74.8,78.8][n],"reaction":[1.2,1.0,0.8,0.63,0.43][n],"attack_cd":[7.5,6.0,4.8,3.8,2.65][n],"lookahead":[16.0,22.0,29.0,37.0,48.0][n],"handling":[2.4,2.8,3.4,4.0,5.0][n],"nitro":[0.15,0.30,0.48,0.70,0.96][n],"damage":[0.78,0.90,1.0,1.10,1.22][n],"catchup":[24.0,26.0,28.0,31.0,34.0][n],"leader_drag":[22.0,21.0,20.0,19.0,18.0][n]}

static func riders() -> Array[Dictionary]:
	var rows = [
		["NOVA","林 星","上海",26,"尾流猎手","RR-12 流星",0.80,0.82,0.64,"eecf62","读懂前车的节奏，才有最干净的超车。"],
		["GHOST","祁 影","台北",29,"冷静追击","VX-7 幽灵",0.86,0.91,0.43,"70c9d2","不急于出手，在你犯错之后才开氮气。"],
		["VIPER","Alex Vega","马德里",31,"贴身压迫","V4 毒牙",0.83,0.72,0.97,"b989ed","始终保持在你的盲区，等待一次重击。"],
		["ECHO","陈 回","香港",24,"弯道专家","K-8 回声",0.73,0.99,0.52,"ece7d7","擅长连续变线，不会轻易被车流困住。"],
		["ROOK","Marcus Cole","底特律",34,"强硬突围","R-900 铁堡",0.79,0.70,0.92,"ed6584","宁愿正面迎战，也不把赛道拱手让人。"],
		["KITE","叶 筝","杭州",25,"灵活穿梭","S-6 风筝",0.77,0.96,0.58,"84d8a5","速度不是全部，一条空隙就足够。"],
		["ATLAS","Omar Haddad","卡萨布兰卡",36,"长途耐力","GT-11 远山",0.91,0.74,0.50,"e1a469","懂得保存氮气，把最后一击留给终点。"],
		["EMBER","Mia Torres","墨西哥城",27,"激进进攻","F-3 余烬",0.82,0.81,0.94,"fa8159","每次被超车，都是重新进攻的信号。"],
		["DRIFT","高 岚","成都",28,"路线预判","TR-8 流岚",0.75,0.98,0.65,"92afee","会提前观察车流，往往比你先找到出口。"],
		["BOLT","Tariq Mensah","阿克拉",23,"爆发冲刺","N-5 闪电",0.99,0.73,0.71,"dcc45d","直道就是舞台，氮气就是聚光灯。"],
		["RAVEN","Lena Novak","布拉格",30,"盲区缠斗","RV-6 夜鸦",0.84,0.88,0.89,"a297d7","一旦贴上来，就要认真看后视镜。"],
		["TIDE","周 澜","厦门",32,"均衡全能","W-9 潮汐",0.85,0.86,0.70,"5bc7c3","不赌一次冒险，用稳定的节奏赢一整场。"],
		["RUST","Ivan Petrov","索非亚",39,"老练反击","M-4 锈铁",0.79,0.84,0.88,"bd917a","经历过太多摔车，回到车上才算真正开始。"],
		["PIXEL","Sam Park","首尔",22,"敏捷闪避","P-2 像素",0.81,1.0,0.55,"e992cf","习惯快速阅读局势，遇到拥堵就换一条线。"],
		["APEX","Ren Sato","大阪",33,"终点猎手","AX-01 巅峰",1.0,0.95,0.91,"ef6b61","会追赶，也懂得领跑；最后四百米尤其危险。"]
	]
	var out: Array[Dictionary] = []
	for i in rows.size():
		var r = rows[i]
		out.append({"weapon":Weapons.ROSTER[i],"id":i,"name":r[0],"full_name":r[1],"city":r[2],"age":r[3],"style":r[4],"bike":r[5],"pace":r[6],"handling":r[7],"aggression":r[8],"color":Color(r[9]),"bio":r[10]})
	return out
