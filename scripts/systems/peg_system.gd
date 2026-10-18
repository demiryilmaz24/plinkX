extends RefCounted
## Çivi Slotu, günlük çivi envanteri ve tahtaya yerleştirme kuralları.
## Kurallar (arayüzde de gösterilir):
##  - Özel çiviler yalnızca min_place_row. sıradan (ekranda 4.) itibaren, topun çarpabildiği konumlara konur.
##  - Her konuma en fazla 1 özel çivi.
##  - Tahtadaki özel çivi sayısı Çivi Yuvası sayısını aşamaz.
##  - Bir türden, envanterde sahip olunan adet kadar yerleştirilebilir.
##  - Envanter yığın sınırı nadirliğe göre: Sıradan 4, Ender 3, Destansı 2, Efsanevi 1.
##    Sınırdaki bir türden kopya gelirse çevirme ücretinin bir kısmı iade edilir.
##  - Çiviler çarpmada tükenmez; gün kapanınca envanter ve yerleşim sıfırlanır.

const Eco := preload("res://scripts/systems/economy.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const Fmt := preload("res://scripts/util/fmt.gd")


static func key_of(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func min_row() -> int:
	return int(GameData.eco["min_place_row"])


static func stack_cap(pid: String) -> int:
	var caps: Array = GameData.eco["peg_slot"]["stack_caps"]
	return int(caps[GameData.rarity_index(GameData.pegs_by_id[pid]["rarity"])])


static func owned(game, pid: String) -> int:
	return int(game.run["pegs"].get(pid, 0))


static func placed_count(game, pid: String = "") -> int:
	var n := 0
	for v in game.run["layout"].values():
		if pid == "" or v == pid:
			n += 1
	return n


static func is_placeable_cell(cell: Vector2i) -> bool:
	return cell.x >= min_row() and cell.x < GameData.rows() and cell.y >= 0 and cell.y <= cell.x


# ------------------------------------------------------------------ slot

static func spin_cost(game) -> float:
	return Eco.peg_slot_cost(int(game.run["peg_spins"]), game.day_price(), MetaTree.level(game, "peg_slot_cost"))


static func odds(game) -> Array:
	var w := Eco.peg_slot_weights(MetaTree.level(game, "peg_luck"))
	var tot := 0.0
	for v in w:
		tot += float(v)
	var out: Array = []
	for v in w:
		out.append(float(v) / tot)
	return out


static func roll_rarity(game, weights: Array) -> String:
	var tot := 0.0
	for v in weights:
		tot += float(v)
	var x: float = game.rng.randf() * tot
	var rar: Array = GameData.eco["rarities"]
	for i in range(weights.size()):
		x -= float(weights[i])
		if x < 0.0:
			return rar[i]
	return rar[rar.size() - 1]


## Döner: {ok, reason, peg, rarity, new, dup_refund, cost}
static func spin(game) -> Dictionary:
	var cost := spin_cost(game)
	if float(game.run["cash"]) < cost:
		return {"ok": false, "reason": "slot.no_cash"}
	game.run["cash"] = float(game.run["cash"]) - cost
	game.run["peg_spins"] = int(game.run["peg_spins"]) + 1
	game.meta["stats"]["peg_spins"] = int(game.meta["stats"]["peg_spins"]) + 1
	var rar := roll_rarity(game, Eco.peg_slot_weights(MetaTree.level(game, "peg_luck")))
	var pool := GameData.pegs_of_rarity(rar)
	var peg: Dictionary = pool[game.rng.randi_range(0, pool.size() - 1)]
	var pid: String = peg["id"]
	var res := {"ok": true, "peg": pid, "rarity": rar, "cost": cost, "new": false, "dup_refund": 0.0}
	var have := owned(game, pid)
	if have < stack_cap(pid):
		game.run["pegs"][pid] = have + 1
		res["new"] = have == 0
		res["count"] = have + 1
	else:
		var refund := cost * float(GameData.eco["peg_slot"]["dup_refund"])
		game.run["cash"] = float(game.run["cash"]) + refund
		res["dup_refund"] = refund
		res["count"] = have
	game.changed.emit()
	return res


## Çark ödülünü satma fiyatı (economy.json → peg_slot.sell). Yığın sınırında otomatik iade edilen sonuç satılamaz.
static func sell_price(res: Dictionary) -> float:
	if not bool(res.get("ok", false)) or bool(res.get("sold", false)) or float(res.get("dup_refund", 0.0)) > 0.0:
		return 0.0
	var ratios: Array = GameData.eco["peg_slot"]["sell"]
	return float(res["cost"]) * float(ratios[GameData.rarity_index(String(res["rarity"]))])


## Kazanılan çiviyi envanterden çıkarıp fiyatı nakde ekler. Döner: kazanılan nakit (0 = satılamadı).
static func sell(game, res: Dictionary) -> float:
	var price := sell_price(res)
	var pid: String = res.get("peg", "")
	if price <= 0.0 or owned(game, pid) <= 0:
		return 0.0
	var left := owned(game, pid) - 1
	if left <= 0:
		game.run["pegs"].erase(pid)
	else:
		game.run["pegs"][pid] = left
	# tahtadaki fazlası kaldırılır (envanterden fazla çivi dizili kalamaz)
	if placed_count(game, pid) > left:
		for k in game.run["layout"].keys():
			if game.run["layout"][k] == pid:
				game.run["layout"].erase(k)
				break
		game.rebuild_layout_cells()
		game.notify_layout_changed()
	game.run["cash"] = float(game.run["cash"]) + price
	res["sold"] = true
	game.changed.emit()
	return price


# ------------------------------------------------------------------ yerleştirme

## Döner: "" (konabilir) veya neden anahtarı
static func can_place(game, cell: Vector2i, pid: String) -> String:
	if not game.edit_mode:
		return "pegs.need_edit"
	if not is_placeable_cell(cell):
		return "pegs.bad_cell"
	if game.run["layout"].has(key_of(cell)):
		return "pegs.occupied"
	if placed_count(game) >= game.sockets():
		return "pegs.no_socket"
	if placed_count(game, pid) >= owned(game, pid):
		return "pegs.none_left"
	return ""


static func place(game, cell: Vector2i, pid: String) -> String:
	var why := can_place(game, cell, pid)
	if why != "":
		return why
	game.run["layout"][key_of(cell)] = pid
	game.rebuild_layout_cells()
	game.notify_layout_changed()
	return ""


static func remove(game, cell: Vector2i) -> bool:
	if not game.edit_mode:
		return false
	var k := key_of(cell)
	if not game.run["layout"].has(k):
		return false
	game.run["layout"].erase(k)
	game.rebuild_layout_cells()
	game.notify_layout_changed()
	return true


static func clear_layout(game) -> void:
	if not game.edit_mode:
		return
	game.run["layout"].clear()
	game.rebuild_layout_cells()
	game.notify_layout_changed()


## Kalıp Defteri (bilet ağacı): yerleşimi kalıcı olarak hatırla
static func save_template(game) -> void:
	game.meta["peg_template"] = game.run["layout"].duplicate()
	game.toast.emit(Loc.t("toast.template_saved"), "info")


## Kayıtlı kalıbı, envanterde bulunan çivilerle olabildiğince uygular.
static func restore_saved_layout(game) -> int:
	var tpl: Dictionary = game.meta.get("peg_template", {})
	var placed := 0
	for k in tpl.keys():
		var pid: String = tpl[k]
		if game.run["layout"].has(k):
			continue
		if placed_count(game) >= game.sockets():
			break
		if placed_count(game, pid) >= owned(game, pid):
			continue
		var parts: PackedStringArray = String(k).split(",")
		if not is_placeable_cell(Vector2i(int(parts[0]), int(parts[1]))):
			continue
		game.run["layout"][k] = pid
		placed += 1
	return placed


## Açıklama metni için veri değerlerinden argüman üretir (metin sayıları veriden gelir).
static func desc_args(pid: String) -> Dictionary:
	var p: Dictionary = GameData.pegs_by_id[pid]
	var a := {}
	if p.has("add"):
		a["v"] = Fmt.pct(float(p["add"]), 0)
	elif p.has("bias"):
		a["v"] = Fmt.pct(float(p["bias"]), 0)
	elif p.has("loss_mult"):
		a["v"] = Fmt.pct(1.0 - float(p["loss_mult"]), 0)
	elif p.has("split"):
		a["v"] = Fmt.pct(float(p["split"]), 0)
	elif p.has("mult"):
		a["v"] = Fmt.mult(float(p["mult"]))
	elif p.has("max_add"):
		a["v"] = Fmt.pct(float(p["max_add"]), 0)
	elif p.has("ticket_chance"):
		a["v"] = Fmt.pct(float(p["ticket_chance"]), 2)
		a["cap"] = int(p.get("daily_cap", 0))
	return a
