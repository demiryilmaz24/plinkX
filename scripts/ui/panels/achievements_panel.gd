extends HBoxContainer
## Başarımlar: ikon ızgarası + sağda kısa bilgi kartı (ad, tek satır hedef, ilerleme, bilet ödülü).

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Achievements := preload("res://scripts/systems/achievements.gd")
const Tile := preload("res://scripts/ui/widgets/icon_tile.gd")
const InfoCard := preload("res://scripts/ui/widgets/info_card.gd")

const COLS := 7

var _tiles: Dictionary = {}
var _info: Control
var _sel := ""
var _count: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("2f3d66"), Color("4f6aa8"), 0, 1, 14))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(frame)
	var v := UI.vbox(10)
	frame.add_child(v)
	_count = UI.title("", 20, UI.GOLD, 5)
	v.add_child(_count)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for a in GameData.achievements:
		var id: String = a["id"]
		var t := Tile.new()
		t.setup("ach:" + String(a["stat"]), 66.0)
		t.pressed.connect(_select.bind(id))
		grid.add_child(t)
		_tiles[id] = t
	_info = InfoCard.new()
	add_child(_info)
	_select(GameData.achievements[0]["id"])


func _select(id: String) -> void:
	if _sel != "":
		_tiles[_sel].selected = false
	_sel = id
	_tiles[id].selected = true
	Sfx.play("tick", 1.1, -10.0)
	refresh()


static func _fmt_value(a: Dictionary, v: float) -> String:
	return Fmt.money(v) if String(a["stat"]).contains("profit") else Fmt.num(floor(v))


func refresh() -> void:
	var done := 0
	for a in GameData.achievements:
		var id: String = a["id"]
		var ok: bool = Game.meta["achievements"].has(id)
		if ok:
			done += 1
		var cur := Achievements.stat_value(Game, a["stat"])
		var target: float = float(a["value"])
		var badge := "✓" if ok else ("" if target <= 1.0 else "%d%%" % int(clampf(cur / target, 0.0, 0.99) * 100.0))
		_tiles[id].set_state("done" if ok else ("owned" if bool(a["free_mode"]) else "open"), badge, not ok)
	_count.text = Loc.t("info.ach_count", {"a": done, "b": GameData.achievements.size()})
	var a: Dictionary = GameData.achievements_by_id[_sel]
	var ok2: bool = Game.meta["achievements"].has(_sel)
	var cur2 := Achievements.stat_value(Game, a["stat"])
	var tgt: float = float(a["value"])
	_info.show_data({
		"title": Loc.t("ach." + _sel + ".name"),
		"sub": Loc.t("ach.free") if bool(a["free_mode"]) else "",
		"sub_color": UI.SKY,
		"icon": "ach:" + String(a["stat"]),
		"line1": Loc.t("ach." + _sel + ".desc", {"v": _fmt_value(a, tgt)}),
		"bar": 1.0 if ok2 else clampf(cur2 / maxf(tgt, 1.0), 0.0, 1.0),
		"bar_text": Loc.t("info.done") if ok2 else "%s / %s" % [_fmt_value(a, cur2), _fmt_value(a, tgt)],
		"button": "+%d" % int(a["tickets"]),
		"button_icon": "ticket",
		"button_color": UI.ORANGE if ok2 else Color("4a5274"),
		"button_enabled": false,
	})
