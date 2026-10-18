extends Control
## Ana menü: Devam Et / Yeni Oyun / Ayarlar / Oyundan Çık. Arkada dekoratif, kendiliğinden oynayan mini tahta.

signal continue_pressed
signal new_game_pressed
signal settings_pressed
signal quit_pressed
signal language_pressed

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const ROWS := 9
const SX := 40.0
const SY := 38.0

var _t := 0.0
var _balls: Array = []
var _spawn := 0.0
var _rng := RandomNumberGenerator.new()
var _logo: Control
var _continue_btn: Button
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_font = UI.display_font()
	# arkadaki gerçek sahne (oda, masa, Kader Tahtası) görünür; sol yarı okunaklılık için koyulaşır
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_shade.bind(shade))
	add_child(shade)
	var col := UI.vbox(14)
	col.anchor_left = 0.05
	col.anchor_right = 0.05
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = 0
	col.offset_right = 520
	col.offset_top = -300
	col.offset_bottom = 300
	add_child(col)
	_logo = Control.new()
	_logo.custom_minimum_size = Vector2(520, 150)
	_logo.draw.connect(_draw_logo)
	col.add_child(_logo)
	var sub := UI.title(Loc.t("menu.subtitle"), 22, UI.MUTED, 4)
	col.add_child(sub)
	col.add_child(_gap(18))
	_continue_btn = _menu_button(Loc.t("menu.continue"), UI.GOLD, Color("3a1800"), "play", func(): continue_pressed.emit())
	col.add_child(_continue_btn)
	col.add_child(_menu_button(Loc.t("menu.new_game"), UI.PINK, Color.WHITE, "ball:kaucuk", func(): new_game_pressed.emit()))
	col.add_child(_menu_button(Loc.t("menu.settings"), Color("4656d6"), Color.WHITE, "gear", func(): settings_pressed.emit()))
	col.add_child(_menu_button(Loc.t("menu.quit"), UI.CORAL, Color.WHITE, "stop", func(): quit_pressed.emit()))
	# dil düğmesi (sağ alt): öteki dilin adını gösterir
	var other := "tr" if Loc.lang == "en" else "en"
	var lb := Button.new()
	lb.focus_mode = Control.FOCUS_NONE
	lb.text = Loc.t("lang." + other)
	lb.add_theme_font_size_override("font_size", 22)
	UI.paint_button(lb, Color("4656d6"))
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBox = lb.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = 46
		sb.content_margin_right = 14
		lb.add_theme_stylebox_override(st, sb)
	var gi := Icon.make("x:globe", 30)
	gi.position = Vector2(10, 8)
	lb.add_child(gi)
	lb.anchor_left = 1.0
	lb.anchor_right = 1.0
	lb.anchor_top = 1.0
	lb.anchor_bottom = 1.0
	lb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lb.offset_right = -16
	lb.offset_bottom = -12
	lb.custom_minimum_size = Vector2(0, 48)
	lb.pressed.connect(func(): language_pressed.emit())
	add_child(lb)
	var foot := UI.label(Loc.t("menu.footer"), 11, UI.DIM)
	foot.anchor_left = 0.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 24
	foot.offset_top = -36
	foot.offset_bottom = -12
	add_child(foot)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _menu_button(text_: String, color: Color, font_col: Color, icon_kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.text = text_
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 22)
	UI.paint_button(b, color, font_col)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = 70
		b.add_theme_stylebox_override(st, sb)
	var ic := Icon.make(icon_kind, 36, Color.WHITE if icon_kind == "stop" else Color(0, 0, 0, 0))
	ic.position = Vector2(14, 9)
	b.add_child(ic)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("buy", 1.0, -6.0))
	return b


func set_can_continue(on: bool) -> void:
	_continue_btn.visible = on


func _process(delta: float) -> void:
	_t += delta
	_logo.queue_redraw()


func _draw_shade(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w * 0.62, 0), Vector2(w * 0.62, h), Vector2(0, h)]),
		PackedColorArray([Color(0.06, 0.03, 0.14, 0.92), Color(0.06, 0.03, 0.14, 0.0), Color(0.06, 0.03, 0.14, 0.0), Color(0.06, 0.03, 0.14, 0.92)]))


func _draw_logo() -> void:
	var txt := Loc.t("game.title")
	var fs := 88
	if _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 440.0:
		fs = 66
	var bob := sin(_t * 1.6) * 6.0
	var pos := Vector2(0, 100 + bob)
	_logo.draw_string_outline(_font, pos + Vector2(6, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color(0, 0, 0, 0.35))
	_logo.draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color("2a0f3d"))
	_logo.draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD)
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	Icon.draw_sprite(_logo, "ball:kaucuk", Rect2(Vector2(w + 14, 22 + bob * 1.4), Vector2(60, 60)))
	Icon.draw_ticket(_logo, Vector2(w - 10, 130 - bob), 44.0)
