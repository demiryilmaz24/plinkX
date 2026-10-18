extends Control
## Tam çözünürlüklü yazı katmanı. Piksel sahne (tahta, masa nesneleri, efektler) yarım çözünürlükte
## çizildiği için oradaki yazılar bulanıklaşır; bu katman o yazıları arayüz çözünürlüğünde ve piksel
## yazı tipinin ızgarasına oturmuş boyutlarda çizer. Sağlayıcılar her kare öğe listesi döndürür:
## {t, p (arayüz koordinatında görsel orta nokta), s (boyut), c (renk), a ("c" orta / "l" sol / "r" sağ),
##  o (kontur rengi, isteğe bağlı), scale (isteğe bağlı büyütme), bold (varsayılan true)}
## Kutu öğesi: {rect, c, bc (isteğe bağlı kenar rengi)} yazılardan önce listeye konur.

const UI := preload("res://scripts/ui/ui_kit.gd")

var providers: Array = []   # Callable -> Array


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for p in providers:
		var items: Array = (p as Callable).call()
		for it in items:
			draw_item(self, it)


static func draw_item(ci: CanvasItem, it: Dictionary) -> void:
	# yazı arkası kutu öğesi: {rect, c (dolgu), bc (isteğe bağlı 2 px kenar)}
	if it.has("rect"):
		var r := Rect2((it["rect"] as Rect2).position.round(), (it["rect"] as Rect2).size.round())
		if it.has("bc"):
			ci.draw_rect(r.grow(2), it["bc"])
		ci.draw_rect(r, it["c"])
		return
	var font: Font = UI.display_font() if bool(it.get("bold", true)) else UI.body_font()
	var size := UI.fs(int(it["s"]))
	var t: String = it["t"]
	if t == "":
		return
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = it["p"]
	var x := p.x
	match String(it.get("a", "c")):
		"c":
			x -= w / 2.0
		"r":
			x -= w
	var base_y := p.y + (font.get_ascent(size) - font.get_descent(size)) / 2.0
	var col: Color = it["c"]
	if bool(it.get("box", false)):
		var h := float(size) * 0.9
		ci.draw_rect(Rect2(Vector2(roundf(x) - 6, roundf(p.y - h / 2.0) - 2), Vector2(roundf(w) + 12, roundf(h) + 4)), Color(0.08, 0.04, 0.03, 0.92))
	var oc: Color = it.get("o", Color(0.06, 0.03, 0.16, col.a))
	var sc: float = float(it.get("scale", 1.0))
	var pos := Vector2(roundf(x), roundf(base_y))
	if absf(sc - 1.0) > 0.01:
		var pivot := Vector2(x + w / 2.0, p.y)
		ci.draw_set_transform(pivot, 0.0, Vector2(sc, sc))
		pos = Vector2(-w / 2.0, base_y - p.y)
	if oc.a > 0.0:
		ci.draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.outline_for(size), oc)
	ci.draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if absf(sc - 1.0) > 0.01:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
