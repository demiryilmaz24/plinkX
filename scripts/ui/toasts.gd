extends VBoxContainer
## Kısa bildirimler (üst orta). Yoğun atışta ekranı kapatmamak için en fazla 5 tane gösterilir.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const MAX_TOASTS := 3

var _items: Array = []   # [{node, t}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END


func show_toast(text: String, kind: String = "info") -> void:
	# aynı metin zaten görünüyorsa tekrarlama
	for it in _items:
		if it["text"] == text:
			it["t"] = 0.0
			return
	var col := UI.INFO
	match kind:
		"good":
			col = UI.GOOD
		"warn":
			col = UI.WARN
		"bad":
			col = UI.BAD
		"ticket":
			col = UI.TICKET
	var p := UI.panel(Color("1d2266"), col, 6, 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "ticket":
		h.add_child(Icon.make("ticket", 22))
	var l := UI.title(text, 11, UI.TEXT, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	p.add_child(h)
	add_child(p)
	_items.append({"node": p, "t": 0.0, "text": text})
	while _items.size() > MAX_TOASTS:
		var old: Dictionary = _items.pop_front()
		old["node"].queue_free()


func _process(delta: float) -> void:
	var keep: Array = []
	for it in _items:
		it["t"] += delta
		var t: float = it["t"]
		var node: Control = it["node"]
		if t > 2.6:
			node.queue_free()
			continue
		node.modulate.a = clampf((2.6 - t) / 0.5, 0.0, 1.0)
		keep.append(it)
	_items = keep
