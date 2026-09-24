extends RefCounted
## Fictional arcade melee equipment; all dimensions are gameplay tuning.
const ROSTER = ["saber","spear","sword","halberd","axe","yue","hook","fork","nunchaku","whip","chain","mace","hammer","staff","three_section"]
# id, name, archetype, hp damage, player damage, lateral reach, longitudinal reach,
# cooldown, animation duration, stagger, lateral shove, color, description
const ROWS = [
	["fists","拳击","punch",1,8.0,2.85,3.8,0.43,0.32,0.32,0.7,"93e2df","出手快，贴近对手打出连续两击。"],
	["kick","踢击","kick",1,11.0,3.5,4.1,0.62,0.46,0.50,1.25,"ffb076","侧踢距离更远，能把对手推离走线。"],
	["saber","弧刃刀","blade",1,13.0,3.9,5.0,0.52,0.38,0.48,0.65,"ffb26f","弧形刀刃，快挥横斩，攻防均衡。"],
	["spear","破风长枪","pole",1,14.0,5.3,6.7,0.80,0.56,0.48,0.7,"9ddde8","长柄尖锋，攻击距离长，收招较慢。"],
	["sword","霜光剑","blade",1,14.0,4.2,5.4,0.57,0.40,0.52,0.75,"c0d5ff","直刃护手，兼具出手速度与距离。"],
	["halberd","赤焰戟","pole",2,18.0,4.9,6.0,1.05,0.65,0.65,1.1,"f78b70","长柄月刃，重击可直接打落完整耐久的 AI。"],
	["axe","裂岩斧","heavy",2,17.0,3.6,4.6,0.90,0.60,0.65,1.4,"efbd73","近身重劈，击退强，但连续出手较慢。"],
	["yue","金轮钺","heavy",2,18.0,3.8,4.8,1.00,0.65,0.70,1.25,"e8cb79","宽刃重兵器，用时机换取一次强打击。"],
	["hook","回锋钩","hook",1,13.0,4.1,5.0,0.66,0.45,0.80,-0.8,"bda8ed","命中会把对手拉向自己，利于接下一击。"],
	["fork","疾风叉","pole",1,14.0,5.0,6.3,0.79,0.56,0.58,1.0,"9be0c0","三叉尖锋，远距离打断对手走线。"],
	["nunchaku","双节棍","flex",1,12.0,3.7,4.6,0.46,0.35,0.38,0.55,"f3d58a","双棍连链，节奏快，适合贴身连击。"],
	["whip","疾雷皮鞭","flex",1,11.0,5.4,6.4,0.73,0.53,0.85,0.55,"e9a8d6","柔性鞭梢甩击，远距压制与较长硬直。"],
	["chain","铁链","flex",1,14.0,4.6,5.6,0.67,0.48,0.63,0.85,"a9becd","链节随挥动展开，范围与力量兼顾。"],
	["mace","狼牙棒","heavy",2,18.0,3.9,4.9,1.00,0.62,0.72,1.4,"dcb095","带钝角突起的重棒，重击强、空挥风险高。"],
	["hammer","震荡战锤","heavy",2,19.0,3.5,4.5,1.10,0.68,0.85,1.6,"95cde2","最强击退，最慢收招，要先找准近身机会。"],
	["staff","短棍","staff",1,12.0,3.6,4.5,0.48,0.35,0.45,0.75,"a6d79b","轻便直棍，稳定、迅速、易于连击。"],
	["three_section","三节棍","flex",1,15.0,4.8,5.8,0.76,0.54,0.63,1.0,"cfb1ef","三段棍体与软链展开，覆盖更宽的横扫范围。"]
]
static func data(id: String) -> Dictionary:
	var row=ROWS[0]
	for candidate in ROWS:
		if candidate[0]==id:
			row=candidate
			break
	return {"id":row[0],"name":row[1],"kind":row[2],"damage":row[3],"rider_damage":row[4],"reach":row[5],"length":row[6],"cooldown":row[7],"duration":row[8],"stagger":row[9],"shove":row[10],"color":Color(row[11]),"description":row[12]}
static func armed(id: String) -> bool:
	return id in ROSTER
static func reaches(id: String, dx: float, dz: float, dy: float, side: int = 0) -> bool:
	var w=data(id)
	return absf(dx)<w.reach and absf(dz)<w.length and absf(dy)<1.4 and (side==0 or dx*side>=-0.25)
