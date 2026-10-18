extends RefCounted
## Top koleksiyonu ve Top Slotu. Top türleri kalıcıdır; prestijde kaybolmaz.
## Kopya kuralı: sahip olunan tür tekrar gelirse oyuncuya "zaten sende" denir ve satışa yönlendirilir;
## satmazsa kopya Ustalık yıldızı olarak kalır (+1, en fazla max_mastery; yıldızlar topun özelliğini güçlendirir).
## Yıldızları dolu bir kopyanın saklanacak bir faydası yoktur: yalnızca satılabilir, satılmazsa otomatik satılır (settle).

const Eco := preload("res://scripts/systems/economy.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")
const Outcome := preload("res://scripts/systems/outcome_model.gd")


static func owned(game, bid: String) -> bool:
	return game.meta["balls"].has(bid)


static func stars(game, bid: String) -> int:
	return int(game.meta["balls"].get(bid, 0))


static func spin_cost(game) -> float:
	return Eco.ball_slot_cost(int(game.run["ball_spins"]), game.day_price(), MetaTree.level(game, "ball_slot_cost"))


static func odds(game) -> Array:
	var w := Eco.ball_slot_weights(MetaTree.level(game, "ball_luck"))
	var tot := 0.0
	for v in w:
		tot += float(v)
	var out: Array = []
	for v in w:
		out.append(float(v) / tot)
	return out


## Döner: {ok, reason, ball, rarity, new, star, maxed, cost}
##   new: koleksiyona yeni eklendi · star > 0: kopya, yeni ustalık yıldızı · maxed: kopya, yıldızlar zaten dolu
static func spin(game) -> Dictionary:
	var cost := spin_cost(game)
	if float(game.run["cash"]) < cost:
		return {"ok": false, "reason": "slot.no_cash"}
	game.run["cash"] = float(game.run["cash"]) - cost
	game.run["ball_spins"] = int(game.run["ball_spins"]) + 1
	game.meta["stats"]["ball_spins"] = int(game.meta["stats"]["ball_spins"]) + 1
	var rar := PegSystem.roll_rarity(game, Eco.ball_slot_weights(MetaTree.level(game, "ball_luck")))
	var pool := GameData.balls_of_rarity(rar)
	var ball: Dictionary = pool[game.rng.randi_range(0, pool.size() - 1)]
	var bid: String = ball["id"]
	var res := {"ok": true, "ball": bid, "rarity": rar, "cost": cost, "new": false, "star": 0, "maxed": false}
	var max_m: int = int(GameData.eco["ball_slot"]["max_mastery"])
	if not owned(game, bid):
		game.meta["balls"][bid] = 0
		res["new"] = true
	elif stars(game, bid) < max_m:
		game.meta["balls"][bid] = stars(game, bid) + 1
		res["star"] = stars(game, bid)
	else:
		res["maxed"] = true
	game.changed.emit()
	game.save_now()
	return res


static func select(game, bid: String) -> void:
	if not owned(game, bid):
		return
	game.meta["selected_ball"] = bid
	game.notify_layout_changed()


## Topun özelliklerini gösterim için satırlara çevirir: [[anahtar, değer metni], ...]
static func trait_lines(bid: String, star_count: int) -> Array:
	var p := Eco.ball_params(bid, star_count)
	var lines: Array = []
	if float(p["pos_mult"]) != 1.0:
		lines.append(["trait.pos_mult", float(p["pos_mult"])])
	if float(p["w_mult"]) != 1.0:
		lines.append(["trait.w_mult", float(p["w_mult"])])
	if float(p["max_mult"]) != 1.0:
		lines.append(["trait.max_mult", float(p["max_mult"])])
	if float(p["loss_mult"]) != 1.0:
		lines.append(["trait.loss_mult", float(p["loss_mult"])])
	if float(p["bias"]) != 0.5:
		lines.append(["trait.bias", float(p["bias"])])
	if float(p["split_chance"]) > 0.0:
		lines.append(["trait.split_chance", float(p["split_chance"])])
	if float(p["rebirth_chance"]) > 0.0:
		lines.append(["trait.rebirth_chance", float(p["rebirth_chance"])])
	return lines


## Topun gücü: güncel tahta seviyesinde (top seviyesi 1, çivisiz) atış başına beklenen net getirinin
## Demir'e oranı - 1 (ör. 0,35 = %35 daha kârlı). Gösterim içindir; nadirlik arttıkça büyür.
static func power(game, bid: String, st: int = -1) -> float:
	if st < 0:
		st = stars(game, bid) if owned(game, bid) else 0
	var lv := int(game.run["board_level"])
	var base := _ev(lv, Eco.ball_params(GameData.starter_ball_id(), 0))
	var ev := _ev(lv, Eco.ball_params(bid, st))
	return ev / maxf(base, 0.0001) - 1.0


static func _ev(level: int, p: Dictionary) -> float:
	var pr: Dictionary = Outcome.band_probabilities(level, float(p["bias"]), {})["types"]
	var iv: Dictionary = GameData.eco["intervals"]
	var pos := float(p["pos_mult"]) * (float(pr["M"]) * float(iv["M"]["net"]) * float(p["max_mult"]) + float(pr["W"]) * float(iv["W"]["net"]) * float(p["w_mult"]))
	var neg := float(p["loss_mult"]) * (float(pr["L"]) * float(iv["L"]["net"]) + float(pr["E"]) * float(iv["E"]["net"]))
	var bonus := float(p["split_chance"]) + (float(pr["L"]) + float(pr["E"])) * float(p["rebirth_chance"])
	return pos * (1.0 + bonus) + neg


## Sonuç, zaten sahip olunan bir topun kopyası mı?
static func is_duplicate(res: Dictionary) -> bool:
	return bool(res.get("ok", false)) and not bool(res.get("new", false))


## Çark ödülünü satma fiyatı: o açılışın ücreti × nadirlik oranı (economy.json → ball_slot.sell). Satılmışsa 0.
static func sell_price(res: Dictionary) -> float:
	if not bool(res.get("ok", false)) or bool(res.get("sold", false)):
		return 0.0
	var ratios: Array = GameData.eco["ball_slot"]["sell"]
	return float(res["cost"]) * float(ratios[GameData.rarity_index(String(res["rarity"]))])


## Ödülü geri alır (yeni top koleksiyondan çıkar / kopyanın verdiği yıldız geri alınır; yıldızı dolu kopyada
## geri alınacak bir şey yoktur) ve fiyatı nakde ekler.
## fallback: satılan top seçiliyse geri dönülecek top. Döner: kazanılan nakit (0 = satılamadı).
static func sell(game, res: Dictionary, fallback: String) -> float:
	var price := sell_price(res)
	if price <= 0.0:
		return 0.0
	var bid: String = res["ball"]
	if bool(res["new"]):
		game.meta["balls"].erase(bid)
		if game.selected_ball() == bid:
			game.meta["selected_ball"] = fallback if owned(game, fallback) else GameData.starter_ball_id()
			game.notify_layout_changed()
	elif int(res["star"]) > 0:
		game.meta["balls"][bid] = maxi(0, stars(game, bid) - 1)
		game.notify_layout_changed()
	game.run["cash"] = float(game.run["cash"]) + price
	res["sold"] = true
	game.changed.emit()
	game.save_now()
	return price


## Pencere kapanırken ya da yeni açılıştan önce: yıldızları dolu kopya satılmadıysa otomatik satılır
## (saklamanın faydası yok, değeri kaybolmasın). Döner: kazanılan nakit (0 = gerek yok).
static func settle(game, res: Dictionary) -> float:
	if res.is_empty() or not bool(res.get("maxed", false)):
		return 0.0
	return sell(game, res, "")
