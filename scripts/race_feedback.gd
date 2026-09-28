extends RefCounted
## Presentation-only state: never awards money, changes pursuit rules or advances time.
const RED = Color("ff627c")
const BLUE = Color("72adff")
const GREEN = Color("8cf2c4")

static func pursuit(active: bool, capture: float, down: bool, progress: float, escaped_age: float, clock: float, motion: bool) -> Dictionary:
	var mode="clear"
	if active:
		mode="danger" if capture>0 or down else ("escaping" if progress>0 else "chase")
	elif escaped_age>=0 and escaped_age<3.5: mode="escaped"
	var pulse=0.5+0.5*sin(clock*TAU*1.25) if motion else 0.5
	return {"mode":mode,"visible":mode!="clear","pulse":pulse,
		"tint":(0.045+0.105*pulse) if active else 0.0,
		"color":GREEN if mode in ["escaping","escaped"] else RED,
		"title":{"clear":"","chase":"警方追捕","danger":"被捕危险","escaping":"正在脱逃","escaped":"追捕解除"}[mode],
		"icon":"cuffs" if mode=="danger" else ("check" if mode=="escaped" else "siren")}

static func result(reason: String, rank: int, cause: String = "") -> Dictionary:
	match reason:
		"finished":
			if rank==1: return {"title":"CHAMPION","subtitle":"冠军属于你","badge":"01 / 冠军","icon":"trophy","color":Color("ffd487"),"tip":"率先冲线 · 奖金已结算，去车库升级下一场的座驾。"}
			if rank<=3: return {"title":"PODIUM FINISH","subtitle":"登上领奖台","badge":"TOP 3 / 领奖台","icon":"trophy","color":Color("7be3ff"),"tip":"领奖台完赛 · 善用氮气与脱逃窗口，向冠军发起挑战。"}
			return {"title":"RACE COMPLETE","subtitle":"冲线完成 · 奖金到账","badge":"FINISH / 完赛","icon":"flag","color":GREEN,"tip":"完成全程 · 保住车况、减少摔车，下次争取更高名次。"}
		"busted": return {"title":"BUSTED","subtitle":"被警方截停 · 本场退赛","badge":"POLICE / 被捕","icon":"cuffs","color":RED,"tip":"倒地时被警员抓获 · 在警车散热时拉开距离，保持 2.5 秒脱逃。"}
		_: return {"title":"WRECKED","subtitle":"车况耗尽 · 本场退赛","badge":"DNF / 撞毁","icon":"wreck","color":Color("ffae65"),"tip":"最后受损："+(cause if not cause.is_empty() else "车况耗尽")+" · 注意避让车流，升级装甲与落地缓冲。"}

static func start_signal(remaining: float) -> Dictionary:
	var count=clampi(ceili(remaining),0,4)
	return {"count":count,"lit":clampi(4-count,0,3),"label":"就位" if count==4 else (str(count) if count>0 else "GO!"),"go":remaining<=0}
