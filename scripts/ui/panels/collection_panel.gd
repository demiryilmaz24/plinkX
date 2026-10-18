extends HBoxContainer
## Top koleksiyonu: top ikonları ızgarası + sağda kısa bilgi kartı (ad, nadirlik, özellik, ilk MAX bonusu, Seç).

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const BallCollection := preload("res://scripts/systems/ball_collection.gd")
const Tile := preload("res://scripts/ui/widgets/icon_tile.gd")
const InfoCard := preload("res://scripts/ui/widgets/info_card.gd")

const COLS := 4
const SILHOUETTE := Color("15183a")

var _tiles: Dictionary = {}
var _info: Control
var _sel := ""


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("2f3d66"), Color("4f6aa8"), 0, 1, 16))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(frame)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var cc := CenterContainer.new()
	frame.add_child(cc)
	cc.add_child(grid)
	for b in GameData.balls:
		var id: String = b["id"]
		var t := Tile.new()
		t.setup("ball:" + id, 116.0)
		t.pressed.connect(_select.bind(id))
		grid.add_child(t)
		_tiles[id] = t
	_info = InfoCard.new()
	_info.action_pressed.connect(_on_select_ball)
	add_child(_info)
	_select(Game.selected_ball())


func _select(id: String) -> void:
	if _sel != "":
		_tiles[_sel].selected = false
	_sel = id
	_tiles[id].selected = true
	Sfx.play("tick", 1.1, -10.0)
	refresh()


func _on_select_ball() -> void:
	BallCollection.select(Game, _sel)
	Sfx.play("buy", 1.1, -6.0)
	refresh()


static func trait_text(line: Array) -> String:
	var key: String = line[0]
	var val: float = line[1]
	var shown := Fmt.mult(val)
	if key == "trait.bias" or key.ends_with("chance"):
		shown = Fmt.pct(val, 0)
	return Loc.t(key, {"v": shown})


func refresh() -> void:
	for b in GameData.balls:
		var id: String = b["id"]
		var owned := BallCollection.owned(Game, id)
		var st := BallCollection.stars(Game, id)
		var state := "locked"
		if owned:
			state = "ready" if Game.selected_ball() == id else "owned"
		var badge := "?" if not owned else ("★%d" % st if st > 0 else "")
		_tiles[id].set_state(state, badge, false)
		_tiles[id].set_icon("ball:" + id)
		_tiles[id].get_child(0).get_child(0).tint = SILHOUETTE
		_tiles[id].get_child(0).get_child(0)._custom_tint = not owned
		_tiles[id].get_child(0).get_child(0).queue_redraw()
	var b: Dictionary = GameData.balls_by_id[_sel]
	var rar: String = b["rarity"]
	var owned2 := BallCollection.owned(Game, _sel)
	if not owned2:
		_info.show_data({"title": Loc.t("coll.unknown"), "sub": Loc.t("rarity." + rar), "sub_color": UI.rarity_color(rar),
			"icon": "ball:" + _sel, "tint": SILHOUETTE, "traits": [_sel, 0], "line2": Loc.t("coll.unknown_desc")})
		return
	var bonus: int = int(GameData.eco["tickets"]["first_max_bonus"][rar])
	var fm := bool(Game.meta["first_max"].get(_sel, false))
	var selected := Game.selected_ball() == _sel
	_info.show_data({
		"title": Loc.t("ball." + _sel + ".name"),
		"sub": Loc.t("rarity." + rar) + ("  ★%d" % BallCollection.stars(Game, _sel) if BallCollection.stars(Game, _sel) > 0 else ""),
		"sub_color": UI.rarity_color(rar),
		"icon": "ball:" + _sel,
		"traits": [_sel, BallCollection.stars(Game, _sel)],
		"line2": Loc.t("coll.first_max_done") if fm else Loc.t("info.first_max", {"n": bonus}),
		"button": Loc.t("info.selected") if selected else Loc.t("info.select"),
		"button_icon": "check" if selected else "",
		"button_color": UI.GOLD_DARK if selected else UI.MINT,
		"button_enabled": not selected,
	})
