extends Control
## Piksel sanat sahnesi: oda (güne göre değişir, bkz. themes.gd / room_painter.gd), masa, masa üstü nesneler ve
## Kader Tahtası dolabı.
## Yarım çözünürlüklü bir SubViewport içinde çizilir ve en-yakın filtreyle büyütülür (gerçek pikseller).
## Masa üstü nesneler hikâyeye aittir ve tıklanabilir: kavanoz = koleksiyon, zarf = hikâye, defter = istatistik,
## masa takvimi = günün bilgisi. Dolap masanın üstünde durur ve duvara doğru yükselir (tahta büyük görünsün diye).

signal prop_clicked(id)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const BoardView := preload("res://scripts/board/board_view.gd")
const Geo := preload("res://scripts/board/board_geometry.gd")
const Themes := preload("res://scripts/stage/themes.gd")
const RoomPainter := preload("res://scripts/stage/room_painter.gd")


## Sabit oda katmanı (duvar, zemin, sabit süsler): yalnızca boyut veya oda değişince yeniden çizilir.
class RoomBack extends Control:
	const RP := preload("res://scripts/stage/room_painter.gd")
	var table_rect := Rect2()
	var tier := 0

	func _draw() -> void:
		RP.back(self, size, table_rect, tier)

# 3 tonlu rampalar (koyu, orta, açık)
const OUT := Color("1a0c08")
const WOOD := [Color("7a4022"), Color("a35a30"), Color("c47843"), Color("dc9a5e")]
const WOOD_EDGE := [Color("4a2412"), Color("68361b"), Color("8a4a26")]

var board: Control
var table_rect := Rect2()
var cabinet_area := Rect2()
var cabinet_rect := Rect2()
var _props: Dictionary = {}     # id -> Rect2
var _hover := ""
var _t := 0.0
var _grain: Array = []          # [Rect2, Color]
var _font: Font
var _back: RoomBack
var tier := -1
var _phone_src: Image
var _phone_tex: Texture2D
const PHONE_W := 46.0   # telefonun sahne pikseli genişliği


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = UI.display_font()
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://assets/art/props/phone.png"):
		_phone_src = (load("res://assets/art/props/phone.png") as Texture2D).get_image()
		_phone_tex = _fit_tex(_phone_src, PHONE_W)
	_back = RoomBack.new()
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_back)
	board = BoardView.new()
	add_child(board)
	resized.connect(_relayout)


## Masa alanını ve dolabın sığacağı alanı sahne koordinatlarında ayarlar (ana arayüz hesaplar).
## Dolap alanı masanın üst kenarını aşabilir: dolap masada durur, tepesi duvara doğru uzanır.
func set_layout(table: Rect2, cab_area: Rect2) -> void:
	table_rect = Rect2(table.position.round(), table.size.round())
	cabinet_area = Rect2(cab_area.position.round(), cab_area.size.round())
	_relayout()


func _relayout() -> void:
	if table_rect.size.x <= 0:
		return
	var t := table_rect
	var area := cabinet_area
	var ch := area.size.y
	var cw := ch * Geo.SIZE.x / Geo.SIZE.y
	var side_room := 70.0
	if cw > t.size.x - side_room * 2:
		cw = t.size.x - side_room * 2
		ch = cw * Geo.SIZE.y / Geo.SIZE.x
	cabinet_rect = Rect2(Vector2(t.get_center().x - cw / 2.0, area.end.y - ch), Vector2(cw, ch)).abs()
	cabinet_rect = Rect2(cabinet_rect.position.round(), cabinet_rect.size.round())
	board.position = cabinet_rect.position
	board.size = cabinet_rect.size
	var lx := t.position.x + 8
	var rx := cabinet_rect.end.x + 8
	var side_w := cabinet_rect.position.x - t.position.x - 16
	var env := Rect2(Vector2(rx + side_w * 0.5 - 34, t.position.y + 22), Vector2(68, 44))
	var ps := _phone_tex.get_size() if _phone_tex else Vector2(PHONE_W, 40)
	_props = {
		"calendar": Rect2(Vector2(lx + side_w * 0.5 - 27, t.position.y + 16), Vector2(54, 62)),
		"notebook": Rect2(Vector2(lx + side_w * 0.5 - 32, t.end.y - 110), Vector2(64, 82)),
		"envelope": env,
		"jar": Rect2(Vector2(rx + side_w * 0.5 - 28, t.end.y - 118), Vector2(56, 90)),
		"phone": Rect2(Vector2(roundf(env.get_center().x - ps.x / 2.0), env.end.y + 22), ps),
	}
	_make_grain()
	_back.table_rect = table_rect
	_back.queue_redraw()
	queue_redraw()


## Gün değişip yeni odaya geçildiğinde temayı yeniler.
func _check_tier() -> void:
	var nt := Themes.current()
	if nt == tier:
		return
	tier = nt
	_back.tier = tier
	if table_rect.size.x > 0:
		_make_grain()
	_back.queue_redraw()


func _make_grain() -> void:
	_grain.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	var t := table_rect.grow(-4)
	var plank := 22.0
	var y := t.position.y + plank
	while y < t.end.y:
		y += plank
	for i in range(int(t.size.x * t.size.y / 520.0)):
		var gx := rng.randf_range(t.position.x, t.end.x - 20)
		var gy := float(int(rng.randf_range(t.position.y, t.end.y)))
		var gl := rng.randf_range(6, 34)
		var top: Array = Themes.table(maxi(tier, 0))["top"]
		var col: Color = top[0] if rng.randf() < 0.65 else top[3]
		_grain.append([Rect2(Vector2(int(gx), gy), Vector2(int(gl), 1)), col])


func _process(delta: float) -> void:
	_check_tier()
	_t += delta
	if not bool(Game.settings.get("reduced_motion", false)) or int(_t * 2.0) % 2 == 0:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		var h := ""
		for id in _props.keys():
			if (_props[id] as Rect2).grow(4).has_point(mm.position):
				h = id
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
			queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _hover != "":
		prop_clicked.emit(_hover)
		accept_event()


# =================================================================== çizim

func _draw() -> void:
	if table_rect.size.x <= 0:
		return
	var reduced: bool = bool(Game.settings.get("reduced_motion", false))
	var tr := maxi(tier, 0)
	RoomPainter.fx(self, size, table_rect, cabinet_rect, tr, _t, reduced)
	RoomPainter.table(self, size, table_rect, tr, _grain, 0.0 if reduced else _t)
	RoomPainter.lamp(self, table_rect, tr, 0.0 if reduced else _t)
	# dolabın masaya düşen gölgesi
	draw_rect(Rect2(cabinet_rect.position + Vector2(5, 6), cabinet_rect.size), Color(0, 0, 0, 0.35))
	var cal: Rect2 = _props["calendar"]
	var nb: Rect2 = _props["notebook"]
	var env: Rect2 = _props["envelope"]
	var jar: Rect2 = _props["jar"]
	var ph: Rect2 = _props["phone"]
	var cols: Array = []
	for bid in Game.meta["balls"].keys():
		cols.append(UI.ball_color(bid))
	RoomPainter.decor(self, Rect2(Vector2(cal.position.x, cal.end.y + 6), Vector2(cal.size.x, nb.position.y - cal.end.y - 12)),
		Rect2(Vector2(env.position.x, ph.end.y + 6), Vector2(env.size.x, jar.position.y - ph.end.y - 12)), tr, 0.0 if reduced else _t, cols)
	_draw_phone(ph, reduced)
	_draw_calendar(_props["calendar"])
	_draw_notebook(_props["notebook"])
	_draw_envelope(_props["envelope"])
	_draw_jar(_props["jar"])
	if _hover != "":
		var r: Rect2 = _props[_hover]
		draw_rect(r.grow(3), Color(1, 1, 1, 0.9), false, 1.0)


## Görseli verilen genişliğe alan ortalamasıyla küçültür, kenarı keskinleştirip koyulaştırır (piksel sanat nesnesi).
static func _fit_tex(src: Image, w: float) -> Texture2D:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var k := w / float(img.get_width())
	var nw := int(round(img.get_width() * k))
	var nh := int(round(img.get_height() * k))
	img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var ref := img.duplicate() as Image
	for y in range(nh):
		for x in range(nw):
			var c := ref.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			c.a = 1.0
			var edge := x == 0 or y == 0 or x == nw - 1 or y == nh - 1
			if not edge:
				edge = ref.get_pixel(x - 1, y).a < 0.5 or ref.get_pixel(x + 1, y).a < 0.5 or ref.get_pixel(x, y - 1).a < 0.5 or ref.get_pixel(x, y + 1).a < 0.5
			img.set_pixel(x, y, c.darkened(0.55) if edge else c)
	return ImageTexture.create_from_image(img)


## Telefon: çalarken iki kısa zil aralığında titrer, iki yanında zil dalgaları, altında arayana göre renkli ışık
## (iyi arama altın, Sadık Bey kırmızı).
func _draw_phone(r: Rect2, reduced: bool) -> void:
	var ringing: bool = not Game.ringing.is_empty()
	var off := Vector2.ZERO
	var buzzing := false
	if ringing:
		var ph := fposmod(_t, 1.3)
		buzzing = ph < 0.42 or (ph > 0.62 and ph < 1.04)
		var good := String(Game.ringing["kind"]) == "good"
		var gc := Color(1.0, 0.82, 0.25) if good else Color(1.0, 0.22, 0.18)
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		for i in range(3):
			_ellipse(r.get_center() + Vector2(0, 4), r.size.x * (0.95 - i * 0.18), r.size.y * (0.8 - i * 0.15), Color(gc, 0.06 + 0.05 * pulse))
		if buzzing and not reduced:
			off = Vector2(1.0 if int(_t * 34.0) % 2 == 0 else -1.0, -1.0 if int(_t * 17.0) % 2 == 0 else 0.0)
			for side in [-1.0, 1.0]:
				for k in range(3):
					var c := Vector2(r.get_center().x + side * (r.size.x * 0.5 + 2.0), r.position.y + 6.0)
					var a0 := PI - 0.7 if side < 0.0 else -0.7
					draw_arc(c, 4.0 + k * 4.0, a0, a0 + 1.4, 8, Color(gc, 0.9 - k * 0.25), 1.0)
	_ellipse(Vector2(r.get_center().x + 3, r.end.y - 1), r.size.x * 0.5, 4, Color(0, 0, 0, 0.3))
	if _phone_tex:
		draw_texture(_phone_tex, (r.position + off).floor())
	else:
		draw_rect(Rect2(r.position + off, r.size), Color("c0281e"))


## Tam çözünürlüklü yazı katmanı için yazılar (sahne koordinatında): nesne etiketleri ve üzerine gelme adı.
func text_items() -> Array:
	var out: Array = []
	if table_rect.size.x <= 0:
		return out
	var cal: Rect2 = _props["calendar"]
	var page := Rect2(cal.position + Vector2(0, 6), Vector2(cal.size.x, cal.size.y - 14))
	out.append({"t": Loc.t("prop.calendar_head"), "p": Vector2(page.get_center().x, page.position.y + 7), "s": 11, "c": Color("fff3d6")})
	var free: bool = Game.is_free_mode()
	out.append({"t": "∞" if free else str(Game.day()), "p": Vector2(page.get_center().x, page.position.y + 13 + (page.size.y - 13) / 2.0),
		"s": 44, "c": Color("2a1830"), "o": Color(0, 0, 0, 0)})
	if not free:
		out.append({"t": "/%d" % GameData.day_count(), "p": Vector2(page.end.x - 3, page.end.y - 7), "s": 11, "c": Color("8a6a50"), "a": "r", "o": Color(0, 0, 0, 0)})
	var nb: Rect2 = _props["notebook"]
	var cover := Rect2(nb.position, Vector2(nb.size.x - 6, nb.size.y))
	out.append({"t": Loc.t("prop.notebook_label"), "p": Vector2(cover.get_center().x, cover.position.y + 24), "s": 11, "c": Color("5a2a12"), "o": Color(0, 0, 0, 0)})
	if not Game.ringing.is_empty():
		var pr: Rect2 = _props["phone"]
		var good := String(Game.ringing["kind"]) == "good"
		var col := Color("ffd23f") if good else Color("ff5a4a")
		col.a = 0.65 + 0.35 * sin(_t * 9.0)
		out.append({"t": Loc.t("phone.ringing"), "p": Vector2(pr.get_center().x, pr.position.y - 12), "s": 22, "c": col, "box": true})
		out.append({"t": Loc.t("char." + String(Game.ringing["who"])), "p": Vector2(pr.get_center().x, pr.end.y + 9), "s": 11, "c": col, "box": true})
	if _hover != "":
		var r: Rect2 = _props[_hover]
		var txt := Loc.t("prop." + _hover)
		if _hover == "calendar":
			txt = Loc.t("top.free_mode") if free else Loc.t("top.day_short", {"d": Game.day(), "n": GameData.day_count(), "t": Loc.t("story.day%d.title" % Game.day())})
		out.append({"t": txt, "p": Vector2(r.get_center().x, r.position.y - 10), "s": 22, "c": UI.GOLD, "box": true})
	return out


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := i * TAU / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _shadow(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.3))


## Masa takvimi: ahşap ayak, spiral halkalar, kırmızı başlık ve günün büyük numarası (Serbest Mod'da ∞)
func _draw_calendar(r: Rect2) -> void:
	_shadow(r)
	# ayak (eğik ahşap altlık)
	var base := Rect2(r.position + Vector2(-3, r.size.y - 10), Vector2(r.size.x + 6, 10))
	draw_rect(base.grow(1), OUT)
	draw_rect(base, WOOD_EDGE[1])
	draw_rect(Rect2(base.position, Vector2(base.size.x, 2)), WOOD_EDGE[2])
	# arkadaki sayfa yığını
	var page := Rect2(r.position + Vector2(0, 6), Vector2(r.size.x, r.size.y - 14))
	for k in range(3, 0, -1):
		var pr := Rect2(page.position + Vector2(k, -k + 2), page.size)
		draw_rect(pr.grow(1), OUT)
		draw_rect(pr, Color("e6dcc4").darkened(0.08 * k))
	draw_rect(page.grow(1), OUT)
	draw_rect(page, Color("fbf4e2"))
	draw_rect(Rect2(page.position + Vector2(0, page.size.y - 3), Vector2(page.size.x, 3)), Color("e0d3b0"))
	# başlık şeridi
	var head := Rect2(page.position, Vector2(page.size.x, 13))
	draw_rect(head, Color("c62a3e"))
	draw_rect(Rect2(head.position, Vector2(head.size.x, 2)), Color("ff5a6a"))
	draw_rect(Rect2(head.position + Vector2(0, head.size.y - 2), Vector2(head.size.x, 2)), Color("8a1426"))
	# spiral halkalar
	for i in range(5):
		var x := page.position.x + 6 + i * (page.size.x - 12) / 4.0
		draw_rect(Rect2(x - 1, page.position.y - 4, 3, 7), OUT)
		draw_rect(Rect2(x, page.position.y - 3, 1, 5), Color("c9ccd8"))


## Borç defteri: mavi kapak, etiket, lastik bant
func _draw_notebook(r: Rect2) -> void:
	_shadow(r)
	draw_rect(r.grow(1), OUT)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 6, 3), Vector2(6, r.size.y - 4)), Color("f1e3c2"))
	for i in range(0, int(r.size.y) - 6, 3):
		draw_rect(Rect2(r.end.x - 6, r.position.y + 4 + i, 5, 1), Color("cdb98f"))
	var cover := Rect2(r.position, Vector2(r.size.x - 6, r.size.y))
	draw_rect(cover, Color("2f5fa8"))
	draw_rect(Rect2(cover.position, Vector2(cover.size.x, 2)), Color("4f86d6"))
	draw_rect(Rect2(cover.position, Vector2(3, cover.size.y)), Color("23497f"))
	draw_rect(Rect2(cover.position + Vector2(0, cover.size.y - 3), Vector2(cover.size.x, 3)), Color("1d3d6b"))
	var lab := Rect2(cover.position + Vector2(10, 14), Vector2(cover.size.x - 20, 20))
	draw_rect(lab.grow(1), OUT)
	draw_rect(lab, Color("f4ead0"))
	draw_rect(Rect2(cover.end.x - 14, cover.position.y, 3, cover.size.y), Color("b32a3a"))
	# üstte bozuk paralar
	for i in range(3):
		var cc := Vector2(cover.position.x + 14 + i * 3, cover.end.y - 14 - i * 3)
		_ellipse(cc, 8, 4, OUT)
		_ellipse(cc, 7, 3, Color("e3b341"))
		draw_rect(Rect2(cc.x - 3, cc.y - 1, 3, 1), Color("fff1a8"))


## Sadık Bey'in zarfı: krem zarf, kapak çizgisi, kırmızı mühür
func _draw_envelope(r: Rect2) -> void:
	_shadow(r)
	draw_rect(r.grow(1), OUT)
	draw_rect(r, Color("efe0bb"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("fff3d6"))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), Color("cdb98f"))
	var c := r.get_center()
	draw_line(r.position + Vector2(1, 1), c + Vector2(0, 4), Color("cdb98f"), 1.0)
	draw_line(Vector2(r.end.x - 1, r.position.y + 1), c + Vector2(0, 4), Color("cdb98f"), 1.0)
	var pulse := 1.0 + (0.08 * sin(_t * 3.0) if not Game.meta["story_seen"].has(str(Game.day())) else 0.0)
	draw_circle(c + Vector2(0, 4), 8.0 * pulse, OUT)
	draw_circle(c + Vector2(0, 4), 7.0 * pulse, Color("b51f2a"))
	draw_circle(c + Vector2(-2, 2), 2.0, Color("e0505a"))
	# mühürdeki "S" harfi (piksel)
	for q in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2), Vector2(1, 3), Vector2(0, 3), Vector2(-1, 3)]:
		draw_rect(Rect2((c + Vector2(0, 3) + q).floor(), Vector2(1, 1)), Color("ffd0d0"))


## Dedenin bilye kavanozu: cam, kapak, içinde renkli bilyeler (sahip olunan topların renkleri)
func _draw_jar(r: Rect2) -> void:
	_ellipse(Vector2(r.get_center().x + 3, r.end.y + 2), r.size.x * 0.5, 6, Color(0, 0, 0, 0.3))
	var body := Rect2(r.position + Vector2(0, 14), Vector2(r.size.x, r.size.y - 14))
	draw_rect(body, Color(0.75, 0.92, 1.0, 0.22))
	draw_rect(body.grow(1), OUT, false, 1.0)
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 3), Vector2(body.size.x, 3)), Color(0.55, 0.75, 0.85, 0.5))
	# bilyeler
	var owned: Array = Game.meta["balls"].keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := 10 + owned.size() * 2
	for i in range(count):
		var bid: String = owned[i % owned.size()]
		var row := i / 5
		var col := i % 5
		var p := Vector2(body.position.x + 7 + col * 10 + (row % 2) * 4, body.end.y - 7 - row * 8)
		if p.y < body.position.y + 6:
			break
		var bc := UI.ball_color(bid)
		draw_circle(p, 4.5, bc.darkened(0.45))
		draw_circle(p + Vector2(-0.5, -0.5), 3.5, bc)
		draw_rect(Rect2(p.x - 2, p.y - 2, 1, 1), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(body.position + Vector2(4, 4), Vector2(3, body.size.y - 10)), Color(1, 1, 1, 0.35))
	# kapak
	var lid := Rect2(r.position + Vector2(-2, 4), Vector2(r.size.x + 4, 12))
	draw_rect(lid.grow(1), OUT)
	draw_rect(lid, Color("c8a24a"))
	draw_rect(Rect2(lid.position, Vector2(lid.size.x, 2)), Color("ecd27a"))
	draw_rect(Rect2(lid.position + Vector2(0, lid.size.y - 3), Vector2(lid.size.x, 3)), Color("8f6d26"))
	for i in range(0, int(lid.size.x), 4):
		draw_rect(Rect2(lid.position.x + i, lid.position.y + 3, 1, lid.size.y - 6), Color("a8842f"))
