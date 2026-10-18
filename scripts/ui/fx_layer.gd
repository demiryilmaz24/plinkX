extends Control
## Görsel efekt katmanı: Jackpot kutlaması, MAX kıvılcımı, nadir slot patlaması, sayaca uçan biletler.
## Azaltılmış hareket açıksa parçacık sayısı ve süreler kısılır, ekran sarsılmaz.

signal ticket_arrived

const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Fmt := preload("res://scripts/util/fmt.gd")

const GRAVITY := 490.0
const K := 0.5   # yarım çözünürlüklü piksel katmanı ölçeği
const MAX_PARTS := 420

var shake_target: Control
var ticket_target := Vector2.ZERO
var _parts: Array = []
var _jp_t := 0.0
var _jp_amount := 0.0
var _jp_tickets := 0
var _shake_t := 0.0
var _was_active := false
var _font: Font
var _rng := RandomNumberGenerator.new()
const GEM_COLORS := [Color("ff4fb4"), Color("2ee59d"), Color("38c6f4"), Color("9d5cff"), Color("ffcc33")]
# Ateş Modu: ekran kenarlarında piksel alevler
const FIRE := [Color("8a1414"), Color("d23a12"), Color("ff7a1a"), Color("ffc23d"), Color("fff3a0")]
var _boost_on := false
var _boost_fade := 0.0
var _boost_time := 0.0
const CONFETTI := [Color("ff4fb4"), Color("2ee59d"), Color("38c6f4"), Color("ffcc33"), Color("ff8a1f"), Color("ffffff")]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UI.display_font()
	_rng.randomize()


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


## Bir noktadan parçacık patlaması. dir_bias: ana yön (ör. yukarı), spread: açı genişliği.
func burst(at: Vector2, count: int, kinds: Array, speed: float = 420.0, dir: float = -PI / 2.0, spread: float = TAU, tint: Color = Color(0, 0, 0, 0)) -> void:
	var n := int(count * (0.3 if _reduced() else 1.0))
	speed *= K
	for i in range(n):
		if _parts.size() >= MAX_PARTS:
			_parts.pop_front()
		var a := dir + _rng.randf_range(-spread / 2.0, spread / 2.0)
		var sp := speed * _rng.randf_range(0.35, 1.0)
		var kind: String = kinds[_rng.randi() % kinds.size()]
		var col: Color = tint if tint.a > 0.0 else (GEM_COLORS[_rng.randi() % GEM_COLORS.size()] if kind == "gem" else CONFETTI[_rng.randi() % CONFETTI.size()])
		_parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "rot": _rng.randf() * TAU,
			"vr": _rng.randf_range(-9.0, 9.0), "t": 0.0, "life": _rng.randf_range(1.0, 1.9) * (0.6 if _reduced() else 1.0),
			"kind": kind, "col": col, "s": (_rng.randf_range(14.0, 26.0) if kind != "confetti" else _rng.randf_range(8.0, 14.0)) * K})


func jackpot(amount: float, tickets: int) -> void:
	_jp_t = 2.8 if not _reduced() else 1.4
	_jp_amount = amount
	_jp_tickets = tickets
	var c := size / 2.0
	burst(c, 150, ["coin", "coin", "gem", "gem", "ticket", "confetti", "confetti", "spark"], 1000.0)
	burst(Vector2(0, size.y), 60, ["coin", "gem", "confetti"], 1250.0, -PI / 3.0, 0.7)
	burst(Vector2(size.x, size.y), 60, ["coin", "gem", "confetti"], 1250.0, -2.0 * PI / 3.0, 0.7)
	if not _reduced():
		_shake_t = 0.6


func max_win(at: Vector2) -> void:
	burst(at, 16, ["spark", "spark", "coin"], 300.0, -PI / 2.0, PI * 0.9, UI.GOLD)


func slot_reveal(rarity: String, at: Vector2) -> void:
	match rarity:
		"legendary":
			burst(at, 70, ["gem", "spark", "confetti", "coin"], 620.0)
		"epic":
			burst(at, 36, ["gem", "spark", "confetti"], 480.0, -PI / 2.0, TAU, UI.PURPLE)
		"rare":
			burst(at, 14, ["spark"], 300.0, -PI / 2.0, TAU, UI.SKY)


## Bilet(ler) kaynaktan sayaca uçar; varınca ticket_arrived yayılır.
func ticket_fly(from: Vector2, n: int) -> void:
	for i in range(clampi(n, 1, 6)):
		_parts.append({"p": from, "from": from + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-20, 20)),
			"t": -i * 0.08, "life": 0.75, "kind": "fly", "rot": 0.0, "vr": 0.0, "v": Vector2.ZERO,
			"col": UI.TICKET, "s": 34.0 * K})


func _process(delta: float) -> void:
	var keep: Array = []
	for q in _parts:
		q["t"] += delta
		if q["kind"] == "fly":
			if q["t"] < 0.0:
				keep.append(q)
				continue
			var k: float = clampf(q["t"] / q["life"], 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			var from: Vector2 = q["from"]
			var mid := (from + ticket_target) / 2.0 + Vector2(0, -80)
			q["p"] = from.lerp(mid, e).lerp(mid.lerp(ticket_target, e), e)
			if k >= 1.0:
				ticket_arrived.emit()
				continue
			keep.append(q)
			continue
		if q["t"] >= q["life"]:
			continue
		q["v"] += Vector2(0, GRAVITY) * delta
		q["v"] *= 0.992
		q["p"] += q["v"] * delta
		q["rot"] += q["vr"] * delta
		keep.append(q)
	_parts = keep
	if _jp_t > 0.0:
		_jp_t -= delta
	if _shake_t > 0.0 and shake_target:
		_shake_t -= delta
		var a := 9.0 * clampf(_shake_t / 0.6, 0.0, 1.0)
		shake_target.position = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
		if _shake_t <= 0.0:
			shake_target.position = Vector2.ZERO
	_boost_fade = move_toward(_boost_fade, 1.0 if _boost_on else 0.0, delta * (3.0 if _boost_on else 1.5))
	if _boost_fade > 0.0:
		_boost_time += delta
	var active := not _parts.is_empty() or _jp_t > 0.0 or _boost_fade > 0.0
	if active or _was_active:
		queue_redraw()
	_was_active = active


func shake(secs: float) -> void:
	if not _reduced():
		_shake_t = maxf(_shake_t, secs)


## Ateş Modu başlar/biter (ekran kenarı alevleri ve üstte sayaçlı başlık)
func start_boost() -> void:
	_boost_on = true
	_boost_time = 0.0
	if not _reduced():
		_shake_t = maxf(_shake_t, 0.25)
	burst(Vector2(size.x / 2.0, size.y), 60, ["spark", "confetti"], 320.0, -PI / 2.0, 1.4, Color("ff9a2a"))


func stop_boost() -> void:
	_boost_on = false


## Kenarlardan içeri uzanan, titreşen piksel alevler (yarım çözünürlük, 2 piksellik sütunlar).
func _draw_fire_frame() -> void:
	var a := _boost_fade
	var t := _boost_time * (0.4 if _reduced() else 1.0)
	var w := size.x
	var h := size.y
	var bands := FIRE.size()
	# alt ve üst kenar
	var x := 0.0
	while x < w:
		var hb := (12.0 + 7.0 * sin(x * 0.11 + t * 9.0) + 5.0 * sin(x * 0.27 - t * 13.0) + 3.0 * sin(x * 0.053 + t * 4.0)) * a
		var ht := hb * 0.6 + 2.0 * sin(x * 0.19 + t * 11.0) * a
		for b in range(bands):
			var k := 1.0 - float(b) / bands
			var c: Color = FIRE[b]
			c.a = 0.88
			var lb := floorf(hb * k)
			if lb > 0:
				draw_rect(Rect2(x, h - lb, 2, lb), c)
			var lt := floorf(ht * k)
			if lt > 0:
				draw_rect(Rect2(x, 0, 2, lt), c)
		x += 2.0
	# sol ve sağ kenar
	var y := 0.0
	while y < h:
		var hl := (9.0 + 6.0 * sin(y * 0.13 - t * 10.0) + 4.0 * sin(y * 0.31 + t * 12.0)) * a
		var hr := (9.0 + 6.0 * sin(y * 0.12 + t * 9.5 + 2.0) + 4.0 * sin(y * 0.29 - t * 11.0)) * a
		for b in range(bands):
			var k2 := 1.0 - float(b) / bands
			var c2: Color = FIRE[b]
			c2.a = 0.85
			var ll := floorf(hl * k2)
			if ll > 0:
				draw_rect(Rect2(0, y, ll, 2), c2)
			var lr := floorf(hr * k2)
			if lr > 0:
				draw_rect(Rect2(w - lr, y, lr, 2), c2)
		y += 2.0
	# yükselen kıvılcımlar
	for i in range(48):
		var hx := fposmod(float(i) * 0.6180339 * w + sin(t * 2.0 + i) * 6.0, w)
		var u := fposmod(t * (0.35 + fposmod(i * 0.37, 1.0) * 0.5) + fposmod(i * 0.123, 1.0), 1.0)
		var py := h - u * h * 0.45
		var c3: Color = FIRE[4].lerp(FIRE[0], u)
		c3.a = (1.0 - u) * a
		draw_rect(Rect2(floorf(hx), floorf(py), 2 if u < 0.5 else 1, 2 if u < 0.5 else 1), c3)


func _draw() -> void:
	if _boost_fade > 0.0:
		_draw_fire_frame()
	if _jp_t > 0.0:
		_draw_jackpot()
	for q in _parts:
		var p: Vector2 = q["p"]
		var alpha := 1.0
		if q["kind"] != "fly":
			alpha = clampf((q["life"] - q["t"]) / 0.4, 0.0, 1.0)
		var s: float = q["s"]
		var rot: float = q["rot"]
		match q["kind"]:
			"coin":
				draw_set_transform(p, 0.0, Vector2(maxf(0.25, absf(cos(rot))), 1.0))
				Icon.draw_icon(self, "coin", Vector2.ZERO, s, Color(1, 0.85, 0.25, alpha))
			"gem":
				draw_set_transform(p, rot * 0.3, Vector2.ONE)
				var col: Color = q["col"]
				col.a = alpha
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s * 0.55), Vector2(s * 0.4, 0), Vector2(0, s * 0.55), Vector2(-s * 0.4, 0)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s * 0.55), Vector2(s * 0.15, -s * 0.05), Vector2(-s * 0.15, -s * 0.05)]), Color(1, 1, 1, 0.6 * alpha))
			"ticket", "fly":
				draw_set_transform(p, rot * 0.2, Vector2.ONE)
				Icon.draw_ticket(self, Vector2.ZERO, s)
			"confetti":
				draw_set_transform(p, rot, Vector2(1.0, absf(sin(rot * 1.7)) * 0.8 + 0.2))
				var cc: Color = q["col"]
				cc.a = alpha
				draw_rect(Rect2(Vector2(-s / 2.0, -s / 4.0), Vector2(s, s / 2.0)), cc)
			"spark":
				draw_set_transform(p, rot * 0.2, Vector2.ONE)
				var sc: Color = q["col"] if q["col"].a > 0.0 else Color.WHITE
				sc.a = alpha
				var pts := PackedVector2Array()
				for i in range(8):
					var a := i * PI / 4.0
					pts.append(Vector2(cos(a), sin(a)) * (s * 0.5 if i % 2 == 0 else s * 0.15))
				draw_colored_polygon(pts, sc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_jackpot() -> void:
	var total := 2.8 if not _reduced() else 1.4
	var age := total - _jp_t
	var c := size / 2.0 + Vector2(0, -20)
	var fade := clampf(_jp_t / 0.5, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)
	# arka plan karartma ve dönen ışınlar
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.0, 0.15, 0.35 * fade))
	var rays := 16
	var spin := age * (0.6 if not _reduced() else 0.0)
	for i in range(rays):
		var a0 := spin + i * TAU / rays
		var a1 := a0 + TAU / rays * 0.5
		var R := size.length()
		var col: Color = GEM_COLORS[i % GEM_COLORS.size()]
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * R, c + Vector2(cos(a1), sin(a1)) * R]), Color(col, 0.16 * fade))
	if _jp_tickets > 0:
		var tw := UI.display_font().get_string_size("+%d" % _jp_tickets, HORIZONTAL_ALIGNMENT_LEFT, -1, 33).x / 2.0
		Icon.draw_ticket(self, c + Vector2(10 - tw / 2.0 - 14, 60), 20)


## Jackpot ve Ateş Modu yazıları tam çözünürlüklü yazı katmanında çizilir (fx koordinatında öğeler).
func text_items() -> Array:
	var out: Array = []
	if _boost_fade > 0.0 and Game.boost_left > 0.0:
		# tahta tabelasının üstündeki duvar şeridinde tek satırlık kutu: "ATEŞ MODU 12 · Hız ×2 • Hava sınırı yok"
		var a := _boost_fade
		var flick := 0.85 + 0.15 * sin(_boost_time * 17.0)
		var top := Color(1.0, 0.85 * flick, 0.25, a)
		var title := Loc.t("phone.boost_title", {"s": int(ceil(Game.boost_left))})
		var info := Loc.t("phone.boost_info", {"x": Fmt.dec(float(GameData.eco["phone"]["boost_speed"]), 0)})
		var f := UI.display_font()
		# genişlik sabit kalsın diye sayaç iki haneli ölçülür
		var tw := f.get_string_size(Loc.t("phone.boost_title", {"s": 88}), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(33)).x * K
		var iw := f.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(22)).x * K
		var gap := 9.0
		var x0 := floorf(size.x / 2.0 - (tw + gap + iw) / 2.0)
		var cy := 10.0
		out.append({"rect": Rect2(x0 - 6, 1, tw + gap + iw + 12, 18), "c": Color(0.18, 0.04, 0.02, 0.92 * a), "bc": Color(1.0, 0.5, 0.1, a)})
		out.append({"t": title, "p": Vector2(x0, cy), "a": "l", "s": 33, "c": top, "o": Color(0.35, 0.02, 0.0, a)})
		out.append({"t": info, "p": Vector2(x0 + tw + gap, cy + 0.5), "a": "l", "s": 22, "c": Color(1, 0.95, 0.8, a), "o": Color(0.35, 0.02, 0.0, a)})
	if _jp_t <= 0.0:
		return out
	var total := 2.8 if not _reduced() else 1.4
	var age := total - _jp_t
	var c := size / 2.0 + Vector2(0, -20)
	var fade := clampf(_jp_t / 0.5, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)
	var pop := 1.0
	if not _reduced():
		pop = 1.0 + 0.6 * exp(-age * 5.0) * absf(cos(age * 14.0))
	var hue := fmod(age * 0.6, 1.0)
	out.append({"t": Loc.t("board.jackpot"), "p": c, "s": 88, "c": Color.from_hsv(hue, 0.65, 1.0, fade), "scale": pop,
		"o": Color(0.1, 0.0, 0.2, fade)})
	out.append({"t": "+" + Fmt.money(_jp_amount), "p": c + Vector2(0, 34), "s": 44, "c": Color(UI.GOLD, fade), "o": Color(0.1, 0.0, 0.2, fade)})
	if _jp_tickets > 0:
		out.append({"t": "+%d" % _jp_tickets, "p": c + Vector2(10, 60), "s": 33, "c": Color(UI.ORANGE, fade), "o": Color(0.1, 0.0, 0.2, fade)})
	return out
