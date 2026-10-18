extends Control
## Ekran geçişleri (piksel sanat, tam ekran):
##  "night": gün kapanırken üstten basamaklı gece perdesi iner, yıldızlar ve ay belirir, büyük yazı.
##  "day":   yeni gün başlarken alttan gün doğumu yükselir, güneş ve büyük takvim yaprağı (gün numarası).
## Ekran tamamen kapandığında mid çağrılır (içerik orada değiştirilir), sonra perde açılır ve end çağrılır.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const TextLayer := preload("res://scripts/ui/text_layer.gd")

const STEP := 12.0      # basamak genişliği (piksel)

var _kind := ""
var _t := 0.0
var _dur := 2.2
var _title := ""
var _sub := ""
var _mid: Callable
var _end: Callable
var _mid_done := false
var _stars: Array = []
## Gün doğumu geçişinde ek satır (ör. "YENİ ODA: Kırmızı Salon"); play() sonrası temizlenir.
var badge := ""
var _badge_now := ""


var _sadik: Texture2D


func _ready() -> void:
	_sadik = load("res://assets/art/portrait_sadik.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(90):
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf() * TAU, 2.0 if rng.randf() < 0.75 else 4.0])


func is_playing() -> bool:
	return visible


func play(kind: String, title: String, sub: String, mid: Callable, end: Callable = Callable()) -> void:
	_kind = kind
	_title = title
	_sub = sub
	_mid = mid
	_end = end
	_t = 0.0
	_mid_done = false
	_badge_now = badge
	badge = ""
	_dur = 0.8 if bool(Game.settings.get("reduced_motion", false)) else 2.2
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("day" if kind == "day" else "pay", 0.8 if kind == "night" else 1.0, -4.0)


## 0: açık, 1: tamamen kapalı. Kapanış %30, bekleme %40, açılış %30.
func _cover() -> float:
	var k := _t / _dur
	if k < 0.3:
		var a := k / 0.3
		return 1.0 - pow(1.0 - a, 3.0)
	if k < 0.7:
		return 1.0
	var b := (k - 0.7) / 0.3
	return 1.0 - b * b * b


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not _mid_done and _t >= _dur * 0.32:
		_mid_done = true
		if _mid.is_valid():
			_mid.call()
	if _t >= _dur:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _end.is_valid():
			_end.call()
		return
	queue_redraw()


func _draw() -> void:
	var c := _cover()
	if c <= 0.0:
		return
	if _kind == "day":
		_draw_day(c)
	else:
		_draw_night(c)


## Basamaklı kenarlı dolgu: from_top ise üstten aşağı, değilse alttan yukarı.
func _stepped(h: float, col: Color, from_top: bool, phase: float) -> void:
	var cols := int(ceil(size.x / STEP))
	for i in range(cols):
		var wob := (sin(i * 0.9 + phase) * 0.5 + 0.5) * STEP * 2.0
		var hh := clampf(h - wob, 0.0, size.y)
		hh = floorf(hh / 4.0) * 4.0
		if from_top:
			draw_rect(Rect2(i * STEP, 0, STEP, hh), col)
		else:
			draw_rect(Rect2(i * STEP, size.y - hh, STEP, hh), col)


func _draw_night(c: float) -> void:
	var h := c * (size.y + STEP * 3.0)
	# üç tonlu gece perdesi (açık kenar, koyu gövde)
	_stepped(h, Color("3a2a7a"), true, 0.0)
	_stepped(h - 10.0, Color("221a52"), true, 1.3)
	_stepped(h - 22.0, Color("120c30"), true, 2.1)
	if c < 0.97:
		return
	var tw := Time.get_ticks_msec() / 1000.0
	for s in _stars:
		var p := Vector2((s[0] as Vector2).x * size.x, (s[0] as Vector2).y * size.y).floor()
		var on := sin(tw * 2.5 + float(s[1])) > -0.3
		var sz: float = s[2]
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 0.95, 0.8, 0.9 if on else 0.35))
	# Sadık Bey taksiti almaya gelir: portre (tam 2 katla) ve köşesinde ay
	var pc := Vector2(size.x / 2.0, size.y * 0.33).floor()
	if _sadik:
		var ps := _sadik.get_size() * 2.0
		var pr := Rect2(pc - ps / 2.0, ps)
		draw_rect(pr.grow(6), Color("e8b030"))
		draw_rect(pr.grow(4), Color("1a1440"))
		draw_texture_rect(_sadik, pr, false)
		pc = pr.position + Vector2(pr.size.x, 0)
	draw_circle(pc, 52.0, Color(1.0, 0.9, 0.5, 0.08))
	Icon.draw_pixel_icon(self, "moon", Rect2(pc - Vector2(36, 36), Vector2(72, 72)), 24)
	TextLayer.draw_item(self, {"t": _title, "p": Vector2(size.x / 2.0, size.y * 0.33 + 160), "s": 44, "c": UI.GOLD})
	if _sub != "":
		TextLayer.draw_item(self, {"t": _sub, "p": Vector2(size.x / 2.0, size.y * 0.33 + 204), "s": 22, "c": Color("cfc6ff")})


func _draw_day(c: float) -> void:
	var h := c * (size.y + STEP * 3.0)
	_stepped(h, Color("ffd9a0"), false, 0.4)
	_stepped(h - 10.0, Color("ff9e6b"), false, 1.7)
	_stepped(h - 22.0, Color("e8607a"), false, 2.6)
	if c < 0.97:
		return
	# güneş ışınları
	var sc := Vector2(size.x / 2.0, size.y * 0.42)
	var age := _t - _dur * 0.3
	for i in range(12):
		var a0 := age * 0.4 + i * TAU / 12.0
		var a1 := a0 + TAU / 24.0
		var R := size.length()
		draw_colored_polygon(PackedVector2Array([sc, sc + Vector2(cos(a0), sin(a0)) * R, sc + Vector2(cos(a1), sin(a1)) * R]), Color(1.0, 0.95, 0.7, 0.12))
	# takvim yaprağı
	var page := Rect2(sc - Vector2(84, 96), Vector2(168, 180))
	draw_rect(page.grow(6), Color("1a0c08"))
	draw_rect(page, Color("fbf4e2"))
	draw_rect(Rect2(page.position, Vector2(page.size.x, 40)), Color("c62a3e"))
	draw_rect(Rect2(page.position, Vector2(page.size.x, 6)), Color("ff5a6a"))
	for i in range(5):
		var x := page.position.x + 18 + i * (page.size.x - 36) / 4.0
		draw_rect(Rect2(x - 4, page.position.y - 14, 8, 22), Color("1a0c08"))
		draw_rect(Rect2(x - 2, page.position.y - 12, 4, 18), Color("c9ccd8"))
	TextLayer.draw_item(self, {"t": Loc.t("prop.calendar_head"), "p": Vector2(sc.x, page.position.y + 22), "s": 22, "c": Color("fff3d6"), "o": Color(0, 0, 0, 0)})
	TextLayer.draw_item(self, {"t": _title, "p": Vector2(sc.x, page.position.y + 108), "s": 88, "c": Color("2a1830"), "o": Color(0, 0, 0, 0)})
	if _sub != "":
		TextLayer.draw_item(self, {"t": _sub, "p": Vector2(sc.x, page.end.y + 44), "s": 33, "c": Color.WHITE})
	if _badge_now != "":
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - (age - 0.2) * 4.0) if age > 0.2 else 0.0
		if pop > 0.0:
			TextLayer.draw_item(self, {"t": _badge_now, "p": Vector2(sc.x, page.end.y + 96), "s": 33, "c": Color("ffd23f"), "box": true, "scale": pop})
