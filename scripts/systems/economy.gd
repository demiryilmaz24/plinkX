extends RefCounted
## Merkezi ekonomi hesapları. Fiyatlar, çarpanlar ve ödemeler YALNIZCA burada hesaplanır ve
## tüm katsayılar data/economy.json dosyasından okunur.
##
## Sonuç tanımı (X = masa bahsi = atış ücreti):
##   Ücretli atış: ücret atış anında düşülür. İnişte bakiyeye (ücret + net sonuç) eklenir.
##   Pozitif aralık: net = aralık_net × X × top_seviyesi_çarpanı × cila × top_türü × çivi_çarpanı
##   Negatif aralık: net = aralık_net × X × top_türü_kayıp × çivi_kayıp   (top seviyesi kaybı etkilemez)
##   Ücretsiz atış (ikram) ve bonus toplar: yalnızca pozitif sonuç öder, kayıpta ceza yoktur.


static func eco() -> Dictionary:
	return GameData.eco


static func x() -> float:
	return GameData.x_value()


# ---------------------------------------------------------------- seviyeler

## Top seviyesi çarpanı: büyüme^(seviye-1). Yalnızca pozitif ödemeyi büyütür.
static func ball_level_mult(level: int) -> float:
	return pow(float(eco()["ball_level"]["mult_growth"]), level - 1)


## level -> level+1 maliyeti
static func ball_level_cost(level: int, price: float) -> float:
	var b: Dictionary = eco()["ball_level"]
	return price * x() * float(b["cost_base"]) * pow(float(b["cost_growth"]), level - 1)


static func board_level_cost(level: int, price: float) -> float:
	var b: Dictionary = eco()["board_level_cost"]
	return price * x() * float(b["base"]) * pow(float(b["growth"]), level - 1)


# ---------------------------------------------------------------- yükseltmeler

static func upgrade_def(key: String) -> Dictionary:
	return eco()["upgrades"][key]


## Seviye level'den level+1'e geçiş maliyeti.
static func upgrade_cost(key: String, level: int, price: float) -> float:
	var u := upgrade_def(key)
	if key == "batch":
		var costs: Array = u["costs"]
		return price * x() * float(costs[mini(level + 1, costs.size() - 1)])
	if key == "auto_unlock":
		return price * x() * float(u["cost"])
	return price * x() * float(u["cost_base"]) * pow(float(u["cost_growth"]), level)


static func air_limit(level: int, tree_bonus: int) -> int:
	var u := upgrade_def("air")
	return int(u["base"]) + int(u["per_level"]) * level + tree_bonus


static func auto_interval(level: int, tree_level: int) -> float:
	var u := upgrade_def("auto_speed")
	var per: float = float(eco()["tree_effects"]["auto_speed_perm"]["per_level"])
	return float(u["base_interval"]) * pow(float(u["factor"]), level) * (1.0 - per * tree_level)


static func polish_mult(level: int) -> float:
	return 1.0 + float(upgrade_def("polish")["per_level"]) * level


static func batch_size(level: int) -> int:
	var sizes: Array = upgrade_def("batch")["sizes"]
	return int(sizes[clampi(level, 0, sizes.size() - 1)])


static func sockets(level: int, tree_bonus: int) -> int:
	return int(upgrade_def("sockets")["base"]) + level + tree_bonus


# ---------------------------------------------------------------- slotlar

static func ball_slot_cost(spins_today: int, price: float, discount_level: int) -> float:
	var s: Dictionary = eco()["ball_slot"]
	var disc: float = float(eco()["tree_effects"]["ball_slot_cost"]["per_level"]) * discount_level
	return price * x() * float(s["cost_base"]) * pow(float(s["cost_growth"]), spins_today) * (1.0 - disc)


static func peg_slot_cost(spins_today: int, price: float, discount_level: int) -> float:
	var s: Dictionary = eco()["peg_slot"]
	var disc: float = float(eco()["tree_effects"]["peg_slot_cost"]["per_level"]) * discount_level
	return price * x() * float(s["cost_base"]) * pow(float(s["cost_growth"]), spins_today) * (1.0 - disc)


static func ball_slot_weights(luck_level: int) -> Array:
	var w: Array = eco()["tree_effects"]["ball_luck"]["weights"]
	return w[clampi(luck_level, 0, w.size() - 1)]


static func peg_slot_weights(luck_level: int) -> Array:
	var w: Array = eco()["tree_effects"]["peg_luck"]["weights"]
	return w[clampi(luck_level, 0, w.size() - 1)]


# ---------------------------------------------------------------- top türleri

## Top türü parametreleri (ustalık yıldızları dahil).
static func ball_params(ball_id: String, stars: int) -> Dictionary:
	var b: Dictionary = GameData.balls_by_id[ball_id]
	var p := {"pos_mult": 1.0, "w_mult": 1.0, "max_mult": 1.0, "loss_mult": 1.0, "bias": 0.5,
		"split_chance": 0.0, "rebirth_chance": 0.0}
	for k in p.keys():
		if b.has(k):
			p[k] = float(b[k])
	var star: Dictionary = b.get("star", {})
	for k in star.keys():
		p[k] = float(p[k]) + float(star[k]) * stars
	p["bias"] = minf(float(p["bias"]), float(eco()["bias_cap"]))
	return p


# ---------------------------------------------------------------- ödeme

## Bir topun iniş sonucunu hesaplar. flight: BallFlight; itype: aralık türü.
## Döner: {net, credit, type, positive, max, parts}
static func resolve(flight, itype: String) -> Dictionary:
	var iv: Dictionary = eco()["intervals"][itype]
	var net_x: float = float(iv["net"])
	var positive: bool = iv["positive"]
	var is_max: bool = iv["max"]
	var p: Dictionary = flight.params
	var net := 0.0
	var parts: Array = []
	if positive:
		var type_mult: float = float(p["max_mult"]) if is_max else float(p["w_mult"])
		var peg_mult: float = flight.peg_prod * (1.0 + flight.peg_add + (flight.peg_max_add if is_max else 0.0))
		net = net_x * flight.stake * flight.ball_mult * flight.polish * float(p["pos_mult"]) * type_mult * peg_mult
		parts = [
			["base", net_x],
			["ball_level", flight.ball_mult],
			["polish", flight.polish],
			["ball_type", float(p["pos_mult"]) * type_mult],
			["pegs", peg_mult],
		]
	else:
		net = net_x * flight.stake * float(p["loss_mult"]) * flight.peg_loss_mult
		parts = [["base", net_x], ["ball_type", float(p["loss_mult"])], ["pegs", flight.peg_loss_mult]]
	var credit := 0.0
	if flight.free or flight.bonus:
		# Ücretsiz/bonus toplar: yalnızca kazanç öder.
		net = maxf(net, 0.0)
		credit = net
	else:
		credit = flight.cost_paid + net
	return {"net": net, "credit": credit, "type": itype, "positive": positive, "max": is_max, "parts": parts}


## Jackpot nakdi: tetikleyen topun MAX ödemesinin sabit katı.
static func jackpot_cash(max_net: float) -> float:
	return float(eco()["tickets"]["jackpot_cash_max_payouts"]) * maxf(max_net, 0.0)


# ---------------------------------------------------------------- biletler

## Günün k. Şans Kartı için gereken delik (k: bugün tamamlanan kart sayısı).
static func card_size(cards_done_today: int, tree_level: int) -> int:
	var t: Dictionary = eco()["tickets"]
	var per: int = int(eco()["tree_effects"]["card_size"]["per_level"])
	return int(t["card_base"]) - per * tree_level + int(t["card_step"]) * cards_done_today


## Prestij bileti: {base, perf, bonus_pct, total}
static func prestige_tickets(day: int, profit: float, target: float, free_mode: bool, bonus_level: int) -> Dictionary:
	var t: Dictionary = eco()["tickets"]
	var base := 0
	var ref := target
	if free_mode:
		ref = float(t["free_mode_ref_target"]) * x()
	else:
		var bases: Array = t["prestige_base"]
		base = int(bases[clampi(day, 1, bases.size()) - 1])
	var perf := 0
	if ref > 0.0:
		perf = mini(int(floor(float(t["prestige_perf_k"]) * sqrt(maxf(profit, 0.0) / ref))), int(t["prestige_perf_cap"]))
	var bonus_pct: float = float(eco()["tree_effects"]["prestige_bonus"]["per_level"]) * bonus_level
	var total := int(floor((base + perf) * (1.0 + bonus_pct)))
	return {"base": base, "perf": perf, "bonus_pct": bonus_pct, "total": total}
