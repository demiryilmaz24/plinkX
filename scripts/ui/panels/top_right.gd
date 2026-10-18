extends VBoxContainer
## Sağ üst: küçük bilet rozeti + iki ikon düğme (Başarımlar, Menü). Altında ince şerit: MAX serisi yıldızları
## ve Şans Kartı çubuğu. Koleksiyon (kavanoz), hikâye (zarf) ve borç defteri masadaki nesnelerden açılır;
## Bilet Ağacı ve istatistikler gün sonu ekranındadır.

signal open_screen(id)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const BUTTONS := ["achievements", "settings"]

var ticket_icon: Control
var _tickets: Label
var _card_bar: ProgressBar
var _streak: Label
var _pop := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var row := UI.hbox(4)
	add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.style(Color("5a1f6e"), UI.ORANGE, 0, 1, 6))
	badge.tooltip_text = Loc.t("top.tickets_tip", {"n": int(GameData.eco["tickets"]["jackpot_streak"])})
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(badge)
	var bh := UI.hbox(6)
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bh)
	ticket_icon = Icon.make("ticket", 33)
	bh.add_child(ticket_icon)
	_tickets = UI.title("0", 22, UI.ORANGE, 4)
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tickets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(_tickets)
	for id in BUTTONS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(42, 46)
		b.tooltip_text = Loc.t("top.btn." + id)
		UI.paint_button(b, Color("3f49b8"))
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.offset_bottom = -3
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cc)
		cc.add_child(Icon.make("menu:" + id, 30))
		b.pressed.connect(_emit_open.bind(id))
		row.add_child(b)
	# ince şerit: MAX serisi + Şans Kartı
	var strip := UI.hbox(6)
	strip.tooltip_text = badge.tooltip_text
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(strip)
	_streak = UI.title("", 11, UI.GOLD, 2)
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_streak)
	strip.add_child(Icon.make("card", 14))
	_card_bar = UI.progress(8, UI.PINK)
	_card_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_card_bar)


func _emit_open(id: String) -> void:
	open_screen.emit(id)


func pop() -> void:
	_pop = 0.4


func ticket_center() -> Vector2:
	return ticket_icon.get_global_rect().get_center()


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop -= delta
		var k := sin(clampf(_pop / 0.4, 0.0, 1.0) * PI)
		ticket_icon.pivot_offset = ticket_icon.size / 2.0
		ticket_icon.scale = Vector2.ONE * (1.0 + 0.4 * k)


func refresh() -> void:
	_tickets.text = str(int(Game.meta["tickets"]))
	var csize := Game.card_size()
	_card_bar.max_value = csize
	_card_bar.value = int(Game.meta["card_holes"])
	_card_bar.tooltip_text = Loc.t("left.card", {"h": int(Game.meta["card_holes"]), "s": csize})
	var need := int(GameData.eco["tickets"]["jackpot_streak"])
	var st := int(Game.run["streak"])
	var dots := ""
	for i in range(need):
		dots += "★" if i < st else "☆"
	_streak.text = dots
