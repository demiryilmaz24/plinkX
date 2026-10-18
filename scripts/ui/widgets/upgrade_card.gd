extends Button
## Resimli yükseltme kartı: ikon, kısa ad, fiyat, seviye çubuğu. Tıklayınca satın alır.
## Açıklamalar kartta değil, araç ipucunda (fare üstüne gelince) gösterilir.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var accent := UI.SKY
var _icon_bg: Panel
var _icon: Control
var _lock: Control
var _title: Label
var _price_row: HBoxContainer
var _coin: Control
var _price: Label
var _level: Label
var _bar: ProgressBar
var _flash := 0.0


func setup(icon_kind: String, title_text: String, accent_color: Color) -> void:
	accent = accent_color
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 62)
	text = ""
	_apply_style(true)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 7)
	m.add_theme_constant_override("margin_bottom", 11)
	add_child(m)
	var h := UI.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	_icon_bg = Panel.new()
	_icon_bg.custom_minimum_size = Vector2(44, 44)
	_icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_bg.add_theme_stylebox_override("panel", UI.style(accent.darkened(0.45), accent, 12, 2, 0))
	h.add_child(_icon_bg)
	_icon = Icon.make(icon_kind, 36)
	_icon.position = Vector2(4, 4)
	_icon_bg.add_child(_icon)
	_lock = Icon.make("lock", 20, Color.WHITE)
	_lock.position = Vector2(26, 26)
	_lock.visible = false
	_icon_bg.add_child(_lock)
	var v := UI.vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var top := UI.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = UI.title(title_text, 11, UI.TEXT, 2)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	top.add_child(_title)
	_level = UI.title("", 11, UI.MUTED, 2)
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_level)
	v.add_child(top)
	_price_row = UI.hbox(4)
	_price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin = Icon.make("coin", 16)
	_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_price_row.add_child(_coin)
	_price = UI.title("", 22, UI.GOLD, 4)
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_row.add_child(_price)
	v.add_child(_price_row)
	_bar = UI.progress(6, accent)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar)


func _apply_style(active: bool) -> void:
	var bg := Color("343c9a") if active else Color("252a6a")
	add_theme_stylebox_override("normal", UI.chunky(bg, false, 14, 8))
	add_theme_stylebox_override("hover", UI.chunky(bg.lightened(0.12), false, 14, 8))
	add_theme_stylebox_override("pressed", UI.chunky(bg.darkened(0.1), true, 14, 8))
	add_theme_stylebox_override("disabled", UI.chunky(bg, false, 14, 8))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## price_text boşsa fiyat satırı gizlenir. locked_text doluysa kilit gösterilir.
func set_state(price_text: String, affordable: bool, level_text: String, ratio: float, locked_text: String = "", tip: String = "") -> void:
	var locked := locked_text != ""
	_lock.visible = locked
	_icon.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
	_level.text = level_text
	_bar.value = clampf(ratio, 0.0, 1.0)
	_bar.visible = ratio >= 0.0
	if locked:
		_coin.visible = false
		_price.text = locked_text
		_price.add_theme_color_override("font_color", UI.MUTED)
	else:
		_coin.visible = price_text != "" and not price_text.begins_with("—")
		_price.text = price_text
		_price.add_theme_color_override("font_color", UI.GOLD if affordable else UI.CORAL)
	_apply_style(not locked and affordable)
	_title.add_theme_color_override("font_color", UI.TEXT if not locked else UI.MUTED)
	if tooltip_text != tip:
		tooltip_text = tip


func flash() -> void:
	_flash = 0.35


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(1, 1, 1).lerp(Color(1.5, 1.4, 0.9), clampf(_flash / 0.35, 0.0, 1.0))
		if _flash <= 0.0:
			modulate = Color.WHITE
