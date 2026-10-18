extends Button
## Kare ikon karosu (ağaç düğümü, başarım, top): yalnızca ikon ve köşede kısa rozet ("1/5", "MAKS", "✓").
## Durum renkleri: kilitli (koyu), açık (camgöbeği), alınabilir (yeşil), tamamlanmış (altın).

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const STATE_COLORS := {
	"locked": Color("2a2f52"),
	"open": Color("1f6f78"),
	"ready": Color("23a05a"),
	"done": Color("c9921c"),
	"owned": Color("3a46a8"),
}

var _icon: Control
var _badge: Label
var _state := ""
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func setup(icon_kind: String, tile_size: float = 64.0, tint: Color = Color(0, 0, 0, 0)) -> void:
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(tile_size, tile_size)
	size = Vector2(tile_size, tile_size)
	text = ""
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -6
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_icon = Icon.make(icon_kind, tile_size * 0.62, tint)
	cc.add_child(_icon)
	_badge = UI.title("", 15, UI.TEXT, 5)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge.offset_right = -6
	_badge.offset_bottom = -6
	add_child(_badge)
	set_state("open", "")


func set_icon(kind: String) -> void:
	_icon.set_kind(kind)


func set_state(state: String, badge: String, dim_icon: bool = false) -> void:
	if state != _state:
		_state = state
		var c: Color = STATE_COLORS.get(state, STATE_COLORS["open"])
		add_theme_stylebox_override("normal", UI.chunky(c, false, 0, 6))
		add_theme_stylebox_override("hover", UI.chunky(c.lightened(0.15), false, 0, 6))
		add_theme_stylebox_override("pressed", UI.chunky(c.darkened(0.1), true, 0, 6))
		add_theme_stylebox_override("disabled", UI.chunky(c, false, 0, 6))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_badge.text = badge
	_badge.add_theme_color_override("font_color", UI.GOLD if badge == Loc.t("tile.max") else UI.TEXT)
	_icon.modulate = Color(1, 1, 1, 0.35) if dim_icon else Color.WHITE


func _draw() -> void:
	if selected:
		# karo kenarları kırpıldığı için seçim çerçevesi içeride çizilir
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, UI.GOLD, false, 4.0)
		draw_rect(r.grow(-4), Color.WHITE, false, 2.0)
