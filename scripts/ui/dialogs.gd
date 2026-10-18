extends Control
## Modal pencere katmanı: hikâye, prestij onayı, ayarlar, onay pencereleri.

const UI := preload("res://scripts/ui/ui_kit.gd")

var _stack: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return not _stack.is_empty()


## İçerik düğümü verilen bir modal açar. Döner: modal kök düğümü (close() ile kapatılır).
func open(content: Control, width: float = 560.0, border: Color = UI.BRASS) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.12, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	var st := UI.style(Color("272c78"), border, 20, 4, 22)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size.x = width
	center.add_child(p)
	p.add_child(content)
	add_child(root)
	_stack.append(root)
	return root


func close(root: Control) -> void:
	_stack.erase(root)
	root.queue_free()


func close_top() -> void:
	if not _stack.is_empty():
		close(_stack.back())


## Basit onay penceresi
func confirm(title: String, body: String, ok_text: String, on_ok: Callable, danger: bool = false) -> void:
	var v := UI.vbox(12)
	v.add_child(UI.title(title, 26, UI.GOLD, 6))
	var b := UI.wrap_label(body, 15, UI.TEXT)
	b.custom_minimum_size.x = 440
	v.add_child(b)
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	var root_ref: Array = [null]
	h.add_child(UI.button(Loc.t("common.cancel"), _close_ref.bind(root_ref), 120))
	var okb := UI.button(ok_text, _confirm_ok.bind(root_ref, on_ok), 200)
	UI.paint_button(okb, UI.CORAL if danger else UI.GOLD, Color.WHITE if danger else Color("3a1800"))
	h.add_child(okb)
	v.add_child(h)
	root_ref[0] = open(v, 520.0, UI.BAD if danger else UI.BRASS)


func _close_ref(root_ref: Array) -> void:
	close(root_ref[0])


func _confirm_ok(root_ref: Array, on_ok: Callable) -> void:
	close(root_ref[0])
	on_ok.call()
