extends RefCounted
## Sefer içi nakit mağazası. Satın alınanlar prestij/gün kapanışında sıfırlanır.
## Gün kilitleri (unlock_day) ve günlük seviye tavanları (level_day_caps) burada uygulanır;
## bunlar kalıcı bilet ağacından tamamen ayrı kurallardır.

const Eco := preload("res://scripts/systems/economy.gd")
const Outcome := preload("res://scripts/systems/outcome_model.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")

const GROUPS := [
	["ball", ["ball_level", "batch", "air", "polish"]],
	["board", ["board_level", "sockets"]],
	["auto", ["auto_unlock", "auto_speed", "auto_batch"]],
]


static func level(game, key: String) -> int:
	match key:
		"ball_level":
			return int(game.run["ball_level"])
		"board_level":
			return int(game.run["board_level"])
	return int(game.run["up"][key])


## Bugün izin verilen en yüksek seviye (gün tavanı) ve mutlak en yüksek seviye.
static func caps(game, key: String) -> Vector2i:
	var free: bool = game.is_free_mode()
	var d: int = game.day()
	match key:
		"ball_level":
			return Vector2i(game.ball_cap(), 1000000)
		"board_level":
			return Vector2i(game.board_cap(), Outcome.max_board_level())
		"batch":
			var sizes: Array = Eco.upgrade_def("batch")["sizes"]
			var days: Array = Eco.upgrade_def("batch")["unlock_days"]
			var today := 0
			for i in range(sizes.size()):
				if free or d >= int(days[i]):
					today = i
			return Vector2i(today, sizes.size() - 1)
		"auto_unlock":
			return Vector2i(1, 1)
	var u := Eco.upgrade_def(key)
	var mx: int = int(u["max_level"])
	if free:
		return Vector2i(mx, mx)
	var dc: Array = u["level_day_caps"]
	return Vector2i(mini(mx, int(dc[clampi(d, 1, dc.size()) - 1])), mx)


static func unlock_day(key: String) -> int:
	match key:
		"ball_level", "board_level":
			return 1
		"batch":
			return 1
	return int(Eco.upgrade_def(key).get("unlock_day", 1))


static func cost(game, key: String) -> float:
	var lv := level(game, key)
	var price: float = game.day_price()
	match key:
		"ball_level":
			return Eco.ball_level_cost(lv, price)
		"board_level":
			return Eco.board_level_cost(lv, price)
	return Eco.upgrade_cost(key, lv, price)


## Bir sonraki günün tavanı (kilitli satırlarda "yarın" bilgisi için)
static func next_day_cap(game, key: String) -> int:
	if game.is_free_mode() or game.day() >= GameData.day_count():
		return -1
	var d: int = game.day() + 1
	match key:
		"ball_level":
			return int(GameData.day_info(d)["ball_cap"])
		"board_level":
			return int(GameData.day_info(d)["board_cap"])
		"batch":
			var days: Array = Eco.upgrade_def("batch")["unlock_days"]
			var t := 0
			for i in range(days.size()):
				if d >= int(days[i]):
					t = i
			return t
		"auto_unlock":
			return 1
	var u := Eco.upgrade_def(key)
	var dc: Array = u["level_day_caps"]
	return mini(int(u["max_level"]), int(dc[clampi(d, 1, dc.size()) - 1]))


## Döner: {key, level, cap, max, cost, block, block_args, now, next}
static func info(game, key: String) -> Dictionary:
	var lv := level(game, key)
	var c := caps(game, key)
	var res := {"key": key, "level": lv, "cap": c.x, "max": c.y, "cost": cost(game, key),
		"block": "", "block_args": {}, "now": "", "next": ""}
	if key == "batch":
		# batch seviyesi = açılmış boy sayısı - 1; sonraki boyun gün kilidi
		var days: Array = Eco.upgrade_def("batch")["unlock_days"]
		if lv >= c.y:
			res["block"] = "shop.maxed"
		elif not game.is_free_mode() and game.day() < int(days[lv + 1]):
			res["block"] = "shop.unlock_day"
			res["block_args"] = {"day": int(days[lv + 1])}
	elif key in ["auto_speed", "auto_batch"] and int(game.run["up"]["auto_unlock"]) == 0:
		res["block"] = "shop.need_auto"
	elif not game.is_free_mode() and game.day() < unlock_day(key):
		res["block"] = "shop.unlock_day"
		res["block_args"] = {"day": unlock_day(key)}
	elif lv >= c.y:
		res["block"] = "shop.maxed"
	elif lv >= c.x:
		res["block"] = "shop.day_cap"
		var nd := next_day_cap(game, key)
		res["block_args"] = {"cap": c.x, "next": nd}
	_effects(game, key, lv, res)
	return res


static func _effects(game, key: String, lv: int, res: Dictionary) -> void:
	match key:
		"ball_level":
			res["now"] = Fmt.mult(Eco.ball_level_mult(lv))
			res["next"] = Fmt.mult(Eco.ball_level_mult(lv + 1))
		"board_level":
			res["now"] = Fmt.pct(float(game.probabilities(lv)["win"]))
			if lv < Outcome.max_board_level():
				res["next"] = Fmt.pct(float(game.probabilities(lv + 1)["win"]))
		"batch":
			res["now"] = "×%d" % Eco.batch_size(lv)
			res["next"] = "×%d" % Eco.batch_size(lv + 1)
		"air":
			res["now"] = str(game.air_limit())
			res["next"] = str(game.air_limit() + int(Eco.upgrade_def("air")["per_level"]))
		"polish":
			res["now"] = Fmt.mult(Eco.polish_mult(lv))
			res["next"] = Fmt.mult(Eco.polish_mult(lv + 1))
		"sockets":
			res["now"] = str(game.sockets())
			res["next"] = str(game.sockets() + 1)
		"auto_unlock":
			res["now"] = Loc.t("common.off") if lv == 0 else Loc.t("common.on")
			res["next"] = Loc.t("common.on")
		"auto_speed":
			res["now"] = Fmt.secs(game.auto_interval())
			res["next"] = Fmt.secs(Eco.auto_interval(lv + 1, MetaTree.level(game, "auto_speed_perm")))
		"auto_batch":
			res["now"] = str(1 + lv)
			res["next"] = str(2 + lv)


static func buy(game, key: String) -> bool:
	var inf := info(game, key)
	if inf["block"] != "":
		return false
	var c: float = inf["cost"]
	if float(game.run["cash"]) < c:
		game.toast.emit(Loc.t("toast.no_cash_buy"), "warn")
		return false
	game.run["cash"] = float(game.run["cash"]) - c
	game.meta["stats"]["cash_spent_shop"] = float(game.meta["stats"]["cash_spent_shop"]) + c
	match key:
		"ball_level":
			game.run["ball_level"] = int(game.run["ball_level"]) + 1
			_track_best(game, "ball_level_best", int(game.run["ball_level"]))
		"board_level":
			var old_win: float = float(game.probabilities()["win"])
			game.run["board_level"] = int(game.run["board_level"]) + 1
			_track_best(game, "board_level_best", int(game.run["board_level"]))
			game.notify_layout_changed()
			game.board_changed.emit(old_win, float(game.probabilities()["win"]))
		"auto_unlock":
			game.run["up"]["auto_unlock"] = 1
			game.run["auto_on"] = true
		_:
			game.run["up"][key] = int(game.run["up"][key]) + 1
	game.changed.emit()
	return true


## Toplu satın alma (bilet ağacı: Toplu Alım). n<=0 ise alınabildiği kadar.
static func buy_many(game, key: String, n: int) -> int:
	var bought := 0
	while n <= 0 or bought < n:
		if not buy(game, key):
			break
		bought += 1
		if bought >= 500:
			break
	return bought


static func _track_best(game, stat: String, v: int) -> void:
	var st: Dictionary = game.meta["stats"]
	if v > int(st.get(stat, 0)):
		st[stat] = v
	if game.is_free_mode():
		var fk := "free_" + stat
		if v > int(st.get(fk, 0)):
			st[fk] = v
