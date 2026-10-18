extends PanelContainer
## Sağdaki küçük bilgi penceresi: başlık, büyük ikon, en fazla iki kısa satır, ilerleme ve tek eylem düğmesi.
## Uzun açıklama yok; okunması kolay, kısa bilgi.

signal action_pressed

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const TraitChips := preload("res://scripts/ui/widgets/trait_chips.gd")

var _title: Label
var _sub: Label
var _icon: Control
var _line1: Label
var _line2: Label
var _bar: ProgressBar
var _bar_text: Label
var _btn: Button
var _btn_icon: Control
var _btn_label: Label
var _chips: Control


func _ready() -> void:
	custom_minimum_size = Vector2(270, 0)
	add_theme_stylebox_override("panel", UI.style(Color("2b3170"), UI.GOLD, 0, 1, 16))
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	_title = UI.title("", 22, UI.TEXT, 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_sub = UI.title("", 11, UI.MUTED, 2)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)
	var ic := CenterContainer.new()
	ic.custom_minimum_size.y = 120
	_icon = Icon.make("ticket", 108)
	_icon.fit = 1.15
	ic.add_child(_icon)
	v.add_child(ic)
	_chips = TraitChips.new()
	_chips.font_size = 22
	_chips.custom_minimum_size.x = 236
	v.add_child(_chips)
	_line1 = UI.title("", 22, UI.TEXT, 4)
	_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line1.custom_minimum_size.x = 230
	v.add_child(_line1)
	_line2 = UI.title("", 11, UI.MUTED, 2)
	_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line2.custom_minimum_size.x = 230
	v.add_child(_line2)
	var bh := Control.new()
	bh.custom_minimum_size = Vector2(0, 24)
	_bar = UI.progress(24, UI.MINT)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bh.add_child(_bar)
	_bar_text = UI.title("", 11, UI.TEXT, 2)
	_bar_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(_bar_text)
	v.add_child(bh)
	_btn = Button.new()
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.custom_minimum_size = Vector2(0, 64)
	_btn.pressed.connect(func(): action_pressed.emit())
	var bc := CenterContainer.new()
	bc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bc.offset_bottom = -6
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(bc)
	var bhb := UI.hbox(10)
	bhb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(bhb)
	_btn_icon = Icon.make("ticket", 40)
	bhb.add_child(_btn_icon)
	_btn_label = UI.title("", 22, UI.TEXT, 4)
	_btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bhb.add_child(_btn_label)
	v.add_child(_btn)


## data: {title, sub, icon, tint, traits ([top_id, yıldız] → yetenek çipleri), line1, line2, bar (0..1 veya -1), bar_text,
##        button (metin, boşsa gizli), button_icon (""=yok), button_color, button_enabled}
func show_data(d: Dictionary) -> void:
	_title.text = d.get("title", "")
	_sub.text = d.get("sub", "")
	_sub.visible = _sub.text != ""
	_sub.add_theme_color_override("font_color", d.get("sub_color", UI.MUTED))
	var t: Color = d.get("tint", Color(0, 0, 0, 0))
	_icon.set_kind(d.get("icon", "ticket"))
	_icon.tint = t if t.a > 0.0 else Color.WHITE
	_icon._custom_tint = t.a > 0.0
	_icon.queue_redraw()
	var tr: Array = d.get("traits", [])
	_chips.visible = not tr.is_empty()
	if not tr.is_empty():
		_chips.show_ball(String(tr[0]), int(tr[1]))
	_line1.text = d.get("line1", "")
	_line1.visible = _line1.text != ""
	_line2.text = d.get("line2", "")
	_line2.visible = _line2.text != ""
	var bar: float = d.get("bar", -1.0)
	_bar.get_parent().visible = bar >= 0.0
	_bar.value = clampf(bar, 0.0, 1.0)
	_bar_text.text = d.get("bar_text", "")
	var bt: String = d.get("button", "")
	_btn.visible = bt != ""
	_btn_label.text = bt
	var bi: String = d.get("button_icon", "")
	_btn_icon.visible = bi != ""
	if bi != "":
		_btn_icon.set_kind(bi)
	var enabled: bool = d.get("button_enabled", true)
	_btn.disabled = not enabled
	UI.paint_button(_btn, d.get("button_color", UI.MINT))
