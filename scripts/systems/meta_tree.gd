extends RefCounted
## Kalıcı bilet geliştirme ağacı. Yalnızca biletle alınır; prestijde sıfırlanmaz.
## Sefer içi nakit mağazasından (run_shop.gd) tamamen ayrıdır.

const BRANCH_ORDER := ["kaynak", "top", "tahta", "otomasyon", "koleksiyon", "bilet", "kolaylik"]


static func level(game, id: String) -> int:
	return int(game.meta["tree"].get(id, 0))


static func node(id: String) -> Dictionary:
	return GameData.tree_by_id[id]


static func max_level(id: String) -> int:
	return (node(id)["costs"] as Array).size()


static func next_cost(game, id: String) -> int:
	var lv := level(game, id)
	var costs: Array = node(id)["costs"]
	if lv >= costs.size():
		return -1
	return int(costs[lv])


static func prereq_ok(game, id: String) -> bool:
	var pre: Variant = node(id).get("prereq")
	if pre == null or String(pre) == "":
		return true
	return level(game, String(pre)) > 0


## Döner: "" (alınabilir) veya engel nedeni anahtarı
static func block_reason(game, id: String) -> String:
	if level(game, id) >= max_level(id):
		return "tree.maxed"
	if not prereq_ok(game, id):
		return "tree.need_prereq"
	if int(game.meta["tickets"]) < next_cost(game, id):
		return "tree.need_tickets"
	return ""


static func buy(game, id: String) -> bool:
	if block_reason(game, id) != "":
		return false
	var c := next_cost(game, id)
	game.meta["tickets"] = int(game.meta["tickets"]) - c
	game.meta["tree"][id] = level(game, id) + 1
	game.meta["stats"]["tickets_spent"] = int(game.meta["stats"]["tickets_spent"]) + c
	_apply_immediate(game, id)
	game.changed.emit()
	game.save_now()
	return true


## Başlangıç bonusları satın alındığı an bugünkü sefere de uygulanır (gün kapanışından hemen sonra
## alınan bir geliştirme, oyuncuyu bir gün bekletmez). Kalıcı oran/yuva/hız etkileri zaten anlık hesaplanır.
static func _apply_immediate(game, id: String) -> void:
	var r: Dictionary = game.run
	var lv := level(game, id)
	match id:
		"auto_ready":
			if int(r["up"]["auto_unlock"]) == 0:
				r["up"]["auto_unlock"] = 1
				r["auto_on"] = true
		"start_ball":
			r["ball_level"] = maxi(int(r["ball_level"]), mini(1 + 3 * lv, game.ball_cap()))
		"start_board":
			var old_win: float = float(game.probabilities()["win"])
			var nb := maxi(int(r["board_level"]), mini(1 + lv, game.board_cap()))
			if nb != int(r["board_level"]):
				r["board_level"] = nb
				game.notify_layout_changed()
				game.board_changed.emit(old_win, float(game.probabilities()["win"]))
		"start_cash":
			# yalnızca günün ilk atışından önce: aradaki fark eklenir
			if int(r["shots_today"]) == 0:
				var base: float = game.x() * float(GameData.eco["start_cash"]) * game.day_price()
				r["cash"] = float(r["cash"]) + base * (pow(2.0, lv) - pow(2.0, lv - 1))
		"free_shots":
			r["free_shots"] = int(r["free_shots"]) + 10
		"peg_gift":
			var commons := GameData.pegs_of_rarity("common")
			var pid: String = commons[game.rng.randi_range(0, commons.size() - 1)]["id"]
			r["pegs"][pid] = int(r["pegs"].get(pid, 0)) + 1


static func branch_nodes(branch: String) -> Array:
	var out: Array = []
	for n in GameData.tree:
		if n["branch"] == branch:
			out.append(n)
	return out


## Düğümün seviye başına etkisini açıklayan metin argümanları
static func effect_args(id: String, lv: int) -> Dictionary:
	var fx: Dictionary = GameData.eco["tree_effects"].get(id, {})
	var args := {"lv": lv}
	match id:
		"start_cash":
			args["v"] = int(pow(2.0, lv))
		"free_shots":
			args["v"] = 10 * lv
		"job_pay":
			args["v"] = int(round((1.0 + float(fx["per_level"]) * lv) * 100.0))
		"start_ball":
			args["v"] = 1 + 3 * lv
		"auto_speed_perm":
			args["v"] = int(round(float(fx["per_level"]) * lv * 100.0))
		"air_perm":
			args["v"] = 2 * lv
		"start_board":
			args["v"] = 1 + lv
		"start_sockets":
			args["v"] = lv
		"peg_gift":
			args["v"] = lv
		"ball_slot_cost", "peg_slot_cost":
			args["v"] = int(round(float(fx["per_level"]) * lv * 100.0))
		"card_size":
			args["v"] = int(fx["per_level"]) * lv
		"prestige_bonus":
			args["v"] = int(round(float(fx["per_level"]) * lv * 100.0))
		"ball_luck", "peg_luck":
			var w: Array = fx["weights"][mini(lv, (fx["weights"] as Array).size() - 1)]
			var tot := 0.0
			for v in w:
				tot += float(v)
			args["c"] = int(round(float(w[0]) / tot * 100.0))
			args["r"] = int(round(float(w[1]) / tot * 100.0))
			args["e"] = int(round(float(w[2]) / tot * 100.0))
			args["l"] = int(round(float(w[3]) / tot * 100.0))
	return args
