extends RefCounted
## Prestij = Günü Kapat. Yeni hikâye gününe geçişle aynı eylemdir.
## Sıfırlananlar: sefer nakdi, top/tahta seviyeleri, nakit yükseltmeleri, çivi envanteri ve yerleşimi.
## Korunanlar: top koleksiyonu, biletler, kalıcı ağaç, başarımlar, ödenmiş borç.

const Eco := preload("res://scripts/systems/economy.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const RunShop := preload("res://scripts/systems/run_shop.gd")


static func preview(game) -> Dictionary:
	var free: bool = game.is_free_mode()
	var d: int = game.day()
	var can: bool = game.installment_done()
	var pt := Eco.prestige_tickets(d, float(game.run["profit"]), game.target(), free, MetaTree.level(game, "prestige_bonus"))
	var up_levels := 0
	for k in game.run["up"].keys():
		if k != "auto_unlock":
			up_levels += int(game.run["up"][k])
	var pegs_owned := 0
	for v in game.run["pegs"].values():
		pegs_owned += int(v)
	var res := {
		"can": can,
		"free_mode": free,
		"day": d,
		"target": game.target(),
		"paid": float(game.run["installment"]),
		"debt_left": game.debt_left(),
		"profit": float(game.run["profit"]),
		"tickets_run": int(game.run["tickets_run"]),
		"prestige": pt,
		"reset": {
			"cash": float(game.run["cash"]),
			"ball_level": int(game.run["ball_level"]),
			"board_level": int(game.run["board_level"]),
			"upgrades": up_levels,
			"auto": int(game.run["up"]["auto_unlock"]),
			"pegs": pegs_owned,
			"placed": game.run["layout"].size(),
		},
		"keep": {
			"balls": game.meta["balls"].size(),
			"tickets": int(game.meta["tickets"]) + int(pt["total"]),
			"achievements": game.meta["achievements"].size(),
			"tree": _tree_levels(game),
			"debt_paid": float(game.meta["debt_paid"]),
		},
		"final_day": not free and d >= GameData.day_count(),
		"next": {},
	}
	if not free and d < GameData.day_count():
		var nd := d + 1
		var info := GameData.day_info(nd)
		var unlocks: Array = []
		for key in ["auto_speed", "auto_batch", "polish", "air", "sockets"]:
			if RunShop.unlock_day(key) == nd:
				unlocks.append(key)
		var days: Array = Eco.upgrade_def("batch")["unlock_days"]
		var sizes: Array = Eco.upgrade_def("batch")["sizes"]
		for i in range(days.size()):
			if int(days[i]) == nd:
				unlocks.append("batch:%d" % int(sizes[i]))
		res["next"] = {
			"day": nd,
			"target": float(info["target"]),
			"ball_cap": int(info["ball_cap"]),
			"board_cap": int(info["board_cap"]),
			"ball_cap_now": game.ball_cap(),
			"board_cap_now": game.board_cap(),
			"unlocks": unlocks,
			"start_ball": mini(1 + 3 * MetaTree.level(game, "start_ball"), int(info["ball_cap"])),
			"start_board": mini(1 + MetaTree.level(game, "start_board"), int(info["board_cap"])),
		}
	return res


static func _tree_levels(game) -> int:
	var n := 0
	for v in game.meta["tree"].values():
		n += int(v)
	return n


static func apply(game) -> void:
	var pv := preview(game)
	if not bool(pv["can"]):
		return
	game.add_tickets(int(pv["prestige"]["total"]), "prestige")
	var st: Dictionary = game.meta["stats"]
	if float(game.run["profit"]) > float(st["run_profit_best"]):
		st["run_profit_best"] = float(game.run["profit"])
	if bool(pv["free_mode"]):
		st["free_prestiges"] = int(st["free_prestiges"]) + 1
		if float(game.run["profit"]) > float(st["free_profit_best"]):
			st["free_profit_best"] = float(game.run["profit"])
	else:
		st["days_closed"] = int(st["days_closed"]) + 1
		if game.day() >= GameData.day_count():
			game.meta["free_mode"] = true
		else:
			game.meta["day"] = game.day() + 1
	game.start_run(true)
	game.save_now()
