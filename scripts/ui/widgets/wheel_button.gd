extends Button
## Sağ sütundaki küçük çark düğmesi (Top Çarkı / Çivi Çarkı): içindekileri sırayla gösteren canlı sprite,
## kısa ad, fiyat ve nadirlik oranlarını renkli şerit olarak gösterir. Tıklayınca kasa açma penceresi açılır.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const BallCollection := preload("res://scripts/systems/ball_collection.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")

const SILHOUETTE := Color("15183a")

var kind := "ball"
var _t := 0.0
var _idx := 0
var _cost: Label
var _odds: Array = []


func setup(kind_: String) -> void:
	kind = kind_
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 74)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.paint_button(self, Color("6b2cc4") if kind == "ball" else Color("1c7f8f"))
	var v := UI.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 70
	v.offset_top = 10
	v.offset_right = -8
	v.offset_bottom = -22
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var t := UI.title(Loc.t("wheel.%s_title" % kind), 11, UI.TEXT, 2)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var row := UI.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icon.make("coin", 14))
	_cost = UI.title("", 22, UI.GOLD, 4)
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_cost)
	v.add_child(row)
	tooltip_text = Loc.t("slots.%s_desc" % kind, {"m": int(GameData.eco["ball_slot"]["max_mastery"]),
		"p": int(round(float(GameData.eco["peg_slot"]["dup_refund"]) * 100.0))})


func _pool() -> Array:
	var out: Array = []
	if kind == "ball":
		for b in GameData.balls:
			out.append(String(b["id"]))
	else:
		for p in GameData.pegs:
			out.append(String(p["id"]))
	return out


func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.2:
		_t = 0.0
		_idx += 1
	queue_redraw()


func _draw() -> void:
	var pool := _pool()
	var id: String = pool[_idx % pool.size()]
	var k := ("ball:" if kind == "ball" else "peg:") + id
	var tint := Color(0, 0, 0, 0)
	var c := Vector2(36, 32)
	# arkada nadirlik renginde bantlı ışık
	var rar: String = (GameData.balls_by_id[id] if kind == "ball" else GameData.pegs_by_id[id])["rarity"]
	var rc := UI.rarity_color(rar)
	for i in range(3):
		draw_circle(c, 26.0 - i * 7.0, Color(rc, 0.12 + 0.06 * i))
	Icon.draw_sprite(self, k, Rect2(c - Vector2(24, 24), Vector2(48, 48)), tint, 0.0, 1.3)
	# nadirlik oranı şeridi
	var odds: Array = BallCollection.odds(Game) if kind == "ball" else PegSystem.odds(Game)
	var x := 10.0
	var w2 := size.x - 20.0
	var y := size.y - 16.0
	draw_rect(Rect2(x - 2, y - 2, w2 + 4, 10), Color("140b2e"))
	var rars: Array = GameData.eco["rarities"]
	for i in range(odds.size()):
		var seg := w2 * float(odds[i])
		draw_rect(Rect2(x, y, maxf(seg, 2.0), 6), UI.rarity_color(rars[i]))
		draw_rect(Rect2(x, y, maxf(seg, 2.0), 2), UI.rarity_color(rars[i]).lightened(0.4))
		x += seg


func refresh() -> void:
	var c: float = BallCollection.spin_cost(Game) if kind == "ball" else PegSystem.spin_cost(Game)
	_cost.text = Fmt.money(c)
	_cost.add_theme_color_override("font_color", UI.GOLD if float(Game.run["cash"]) >= c else UI.BAD)
