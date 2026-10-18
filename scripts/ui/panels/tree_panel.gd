extends HBoxContainer
## Kalıcı BİLET ağacı: bağlantı çizgili ikon ızgarası + sağda kısa bilgi kartı.
## Düğümde yalnızca ikon ve seviye ("1/5", "MAKS"); tıklayınca sağda ad, tek satır etki ve Al düğmesi.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const Tile := preload("res://scripts/ui/widgets/icon_tile.gd")
const InfoCard := preload("res://scripts/ui/widgets/info_card.gd")

const TILE := 64.0
const CELL := Vector2(78, 104)
const PAD := Vector2(22, 22)

var _canvas: Control
var _tiles: Dictionary = {}
var _info: Control
var _sel := ""


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("2f3d66"), Color("4f6aa8"), 0, 1, 10))
	add_child(frame)
	_canvas = Control.new()
	var cols := 0
	var rows := 0
	for n in GameData.tree:
		cols = maxi(cols, int(n["pos"][0]) + 1)
		rows = maxi(rows, int(n["pos"][1]) + 1)
	_canvas.custom_minimum_size = Vector2(PAD.x * 2 + (cols - 1) * CELL.x + TILE, PAD.y * 2 + (rows - 1) * CELL.y + TILE)
	_canvas.draw.connect(_draw_links)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := CenterContainer.new()
	frame.add_child(center)
	center.add_child(_canvas)
	for n in GameData.tree:
		var id: String = n["id"]
		var t := Tile.new()
		t.setup("tree:" + id, TILE)
		t.position = _tile_pos(n)
		t.pressed.connect(_select.bind(id))
		_canvas.add_child(t)
		_tiles[id] = t
	_info = InfoCard.new()
	_info.action_pressed.connect(_on_buy)
	add_child(_info)
	_select(GameData.tree[0]["id"])


func _tile_pos(n: Dictionary) -> Vector2:
	return PAD + Vector2(float(n["pos"][0]) * CELL.x, float(n["pos"][1]) * CELL.y)


## Dik açılı bağlantılar: ebeveynin altından aşağı, yatay, çocuğun üstüne.
func _draw_links() -> void:
	for n in GameData.tree:
		var pre: Variant = n.get("prereq")
		if pre == null or String(pre) == "":
			continue
		var parent: Dictionary = GameData.tree_by_id[String(pre)]
		var a := _tile_pos(parent) + Vector2(TILE / 2.0, TILE)
		var b := _tile_pos(n) + Vector2(TILE / 2.0, 0)
		var mid := a.y + (b.y - a.y) / 2.0
		var lit := MetaTree.level(Game, String(pre)) > 0
		var col := Color("4fd18b") if lit else Color("1c2747")
		var pts := [a, Vector2(a.x, mid), Vector2(b.x, mid), b]
		for i in range(3):
			_canvas.draw_line(pts[i], pts[i + 1], Color("0f1428"), 9.0)
		for i in range(3):
			_canvas.draw_line(pts[i], pts[i + 1], col, 5.0)


func _select(id: String) -> void:
	if _sel != "" and _tiles.has(_sel):
		_tiles[_sel].selected = false
	_sel = id
	_tiles[id].selected = true
	Sfx.play("tick", 1.1, -10.0)
	refresh()


func _on_buy() -> void:
	if MetaTree.buy(Game, _sel):
		Sfx.play("ticket", 0.8, -4.0)
	else:
		Sfx.play("error", 1.0, -10.0)
	refresh()


func refresh() -> void:
	for n in GameData.tree:
		var id: String = n["id"]
		var lv := MetaTree.level(Game, id)
		var mx := MetaTree.max_level(id)
		var why := MetaTree.block_reason(Game, id)
		var state := "open"
		if lv >= mx:
			state = "done"
		elif why == "tree.need_prereq":
			state = "locked"
		elif why == "":
			state = "ready"
		elif lv > 0:
			state = "owned"
		var badge := Loc.t("tile.max") if lv >= mx else "%d/%d" % [lv, mx]
		_tiles[id].set_state(state, badge, state == "locked")
	_canvas.queue_redraw()
	_refresh_info()


func _refresh_info() -> void:
	var id := _sel
	var lv := MetaTree.level(Game, id)
	var mx := MetaTree.max_level(id)
	var why := MetaTree.block_reason(Game, id)
	var d := {
		"title": Loc.t("tree." + id + ".name"),
		"sub": Loc.t("info.level", {"l": lv, "m": mx}),
		"icon": "tree:" + id,
		"line1": Loc.t("tree." + id + ".desc", MetaTree.effect_args(id, mini(lv + 1, mx))),
		"line2": Loc.t("info.now", {"v": Loc.t("tree." + id + ".desc", MetaTree.effect_args(id, lv))}) if lv > 0 and lv < mx else "",
	}
	if lv >= mx:
		d["button"] = Loc.t("tile.max")
		d["button_icon"] = "star"
		d["button_color"] = UI.GOLD_DARK
		d["button_enabled"] = false
	elif why == "tree.need_prereq":
		var pre: String = MetaTree.node(id)["prereq"]
		d["button"] = Loc.t("info.first", {"p": Loc.t("tree." + pre + ".name")})
		d["button_icon"] = "lock"
		d["button_color"] = Color("4a5274")
		d["button_enabled"] = false
	else:
		d["button"] = str(MetaTree.next_cost(Game, id))
		d["button_icon"] = "ticket"
		d["button_color"] = UI.MINT if why == "" else Color("4a5274")
		d["button_enabled"] = why == ""
	_info.show_data(d)
