extends Control
## Plinko tahtası görünümü: çiviler, aralık bantları, toplar, efektler ve çivi yerleştirme etkileşimi.
## Mantık Game autoload'undadır; bu düğüm yalnızca çizer ve tıklamaları iletir.

signal cell_clicked(cell, button_index)
signal cell_hovered(cell)

const Geo := preload("res://scripts/board/board_geometry.gd")
const Outcome := preload("res://scripts/systems/outcome_model.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")

const MAX_POPUPS := 36

var _scale := 1.0
var _offset := Vector2.ZERO
var _flash: Dictionary = {}       # Vector2i -> kalan süre
var _band_flash: Dictionary = {}  # bant indeksi -> kalan süre
var _popups: Array = []           # [{pos, text, color, t, life, big}]
var _jackpot_t := 0.0
var _board_glow_t := 0.0
var _hover := Vector2i(-1, -1)
var selected_peg := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	Game.peg_hit.connect(_on_peg_hit)
	Game.ball_landed.connect(_on_landed)
	Game.jackpot.connect(_on_jackpot)
	Game.bonus_ball.connect(_on_bonus_ball)
	Game.board_changed.connect(func(_a, _b): _board_glow_t = 1.2)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_scale = minf(size.x / Geo.SIZE.x, size.y / Geo.SIZE.y)
	_offset = (size - Geo.SIZE * _scale) / 2.0


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _process(delta: float) -> void:
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	for k in _band_flash.keys():
		_band_flash[k] -= delta
		if _band_flash[k] <= 0.0:
			_band_flash.erase(k)
	var keep: Array = []
	for p in _popups:
		p["t"] += delta
		if p["t"] < p["life"]:
			keep.append(p)
	_popups = keep
	_jackpot_t = maxf(0.0, _jackpot_t - delta)
	_board_glow_t = maxf(0.0, _board_glow_t - delta)
	if not _reduced():
		for f in Game.flights:
			f.trail.append(f.position_at(f.elapsed))
			if f.trail.size() > trail_len(f.ball_id):
				f.trail.pop_front()
	queue_redraw()


# ------------------------------------------------------------------ olaylar

func _on_peg_hit(_f, cell: Vector2i, pid: String) -> void:
	_flash[cell] = 0.35
	if pid == "bilet" or pid == "elmas" or pid == "altin_civi":
		Sfx.play("tick", 1.4, -6.0)


func _on_landed(f, res: Dictionary) -> void:
	var bands := Outcome.bands(int(Game.run["board_level"]))
	for i in range(bands.size()):
		if f.u >= float(bands[i]["lo"]) and f.u <= float(bands[i]["hi"]):
			_band_flash[i] = 0.45 if not bool(res["max"]) else 0.9
			break
	var change: float = float(res["change"])
	# Yoğun atışta ekranı kapatmamak için: kalabalıkta yalnızca ★MAX ve büyük kazanç yazıları gösterilir.
	var crowded: bool = Game.flights.size() > 14 or _popups.size() > 10
	var notable: bool = bool(res["max"]) or (f.bonus and change > 0.0)
	if crowded and (not notable or _popups.size() >= 4):
		_sound_for(res)
		return
	if _popups.size() >= MAX_POPUPS:
		_popups.pop_front()
	var col := UI.GOOD if change > 0.0 else (UI.BAD if change < 0.0 else UI.MUTED)
	if bool(res["max"]):
		col = UI.INTERVAL_COLORS["M"]
	var txt := Fmt.money_signed(change)
	if f.bonus and change <= 0.0:
		txt = Loc.t("board.bonus_miss")
	_popups.append({"pos": Vector2(f.landing_point().x, Geo.BAND_TOP - 30), "text": txt, "color": col, "t": 0.0,
		"life": 1.1 if not _reduced() else 0.8, "big": bool(res["max"]), "sub": _trait_sub(f, res),
		"sub_color": UI.rarity_color(GameData.balls_by_id[f.ball_id]["rarity"]).lightened(0.25)})
	_sound_for(res)


## Topun yeteneği bu sonucu değiştirdiyse kısa etiket (ör. "×1,25"): yeteneğin işe yaradığı görülür.
static func _trait_sub(f, res: Dictionary) -> String:
	var p: Dictionary = f.params
	var m := 1.0
	if bool(res["positive"]):
		m = float(p["pos_mult"]) * (float(p["max_mult"]) if bool(res["max"]) else float(p["w_mult"]))
	else:
		m = float(p["loss_mult"])
	if absf(m - 1.0) < 0.005:
		return ""
	return "×" + Fmt.dec(m, 2)


## Bonus top (İkiz / Yeniden doğuş) çıktığında tahtada kısa yazı.
func _on_bonus_ball(f, kind: String) -> void:
	if _popups.size() >= MAX_POPUPS:
		_popups.pop_front()
	var rc := UI.rarity_color(GameData.balls_by_id[f.ball_id]["rarity"])
	_popups.append({"pos": f.start_point + Vector2(0, -18), "text": Loc.t("board.bonus_" + kind), "color": rc.lightened(0.3),
		"t": 0.0, "life": 1.0 if not _reduced() else 0.7, "big": false, "sub": "", "sub_color": rc})


func _sound_for(res: Dictionary) -> void:
	if bool(res["max"]):
		Sfx.play("max", 1.0, -2.0)
	elif bool(res["positive"]):
		Sfx.play("win", randf_range(0.95, 1.08), -8.0)
	else:
		Sfx.play("loss", randf_range(0.95, 1.05), -10.0)


func _on_jackpot(_amount: float) -> void:
	_jackpot_t = 1.6 if not _reduced() else 0.6


# ------------------------------------------------------------------ giriş

func _to_board(p: Vector2) -> Vector2:
	return (p - _offset) / _scale


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		var cell := Geo.cell_at(_to_board(mm.position), GameData.rows())
		if cell != _hover:
			_hover = cell
			cell_hovered.emit(cell)
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		var cell2 := Geo.cell_at(_to_board(mb.position), GameData.rows())
		if cell2.x >= 0:
			cell_clicked.emit(cell2, mb.button_index)
			accept_event()


# ------------------------------------------------------------------ çizim

# Dolap paleti: odaya göre değişir (themes.gd). Her karede güncel temadan okunur.
const Themes := preload("res://scripts/stage/themes.gd")
var WALNUT: Array = []
var FELT: Array = []
var BRASS: Array = []
var OUTL := Color("120806")
var MARQUEE: Array = []
var _tier := -1
var _th: Dictionary = {}
var _flecks: Array = []
var _orn: Array = []   # süs öğeleri (tahta uzayında sabit konumlar)


func _apply_theme() -> void:
	var nt := Themes.current()
	if nt == _tier and not _th.is_empty():
		return
	_tier = nt
	_th = Themes.cabinet(nt)
	WALNUT = _th["body"]
	FELT = _th["felt"]
	BRASS = _th["trim"]
	OUTL = _th["outl"]
	MARQUEE = _th["marquee"]
	_flecks.clear()
	_orn.clear()


func _make_flecks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 520 if _tier < 3 else 260
	for i in range(n):
		var p := Vector2(rng.randf_range(18, 620), rng.randf_range(50, Geo.BAND_TOP - 4))
		_flecks.append([Rect2(p.round(), Vector2(2, 2)), FELT[0] if rng.randf() < 0.6 else FELT[3]])
	# yıldız/parıltı noktaları (Büyük Salon)
	for i in range(40):
		_orn.append(Vector2(rng.randf_range(24, 616), rng.randf_range(56, Geo.BAND_TOP - 12)))


func _draw() -> void:
	_apply_theme()
	if _flecks.is_empty():
		_make_flecks()
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
	var rows := GameData.rows()
	var W := Geo.SIZE.x
	var H := Geo.SIZE.y
	var tm := 0.0 if _reduced() else Time.get_ticks_msec() / 1000.0
	# gövde ve dış kontur
	draw_rect(Rect2(-4, -4, W + 8, H + 8), OUTL)
	draw_rect(Rect2(0, 0, W, H), WALNUT[1])
	for gx in [3, 7, 12, W - 6, W - 11]:
		draw_rect(Rect2(gx, 50, 2, Geo.BAND_TOP - 50), WALNUT[2])
	draw_rect(Rect2(0, 0, 4, H), WALNUT[3])
	draw_rect(Rect2(W - 4, 0, 4, H), WALNUT[0])
	# keçe oyun alanı
	var felt := Rect2(16, 48, W - 32, Geo.BAND_TOP - 48)
	draw_rect(felt.grow(3), OUTL)
	draw_rect(felt, FELT[1])
	_draw_felt_pattern(felt, tm)
	draw_rect(Rect2(felt.position, Vector2(felt.size.x, 18)), FELT[0])
	draw_rect(Rect2(felt.position + Vector2(0, 18), Vector2(felt.size.x, 4)), Color(FELT[0], 0.5))
	draw_rect(Rect2(felt.position, Vector2(6, felt.size.y)), Color(FELT[0], 0.6))
	draw_rect(Rect2(Vector2(felt.end.x - 6, felt.position.y), Vector2(6, felt.size.y)), Color(FELT[0], 0.6))
	for f in _flecks:
		draw_rect(f[0], f[1])
	if _board_glow_t > 0.0:
		draw_rect(felt.grow(-2), Color(UI.MINT, 0.25 * _board_glow_t), false, 6.0)
	_draw_side_rails(W, felt, tm)
	_draw_marquee(W, tm)
	_draw_bands(rows)
	_draw_pegs(rows)
	_draw_balls()
	_draw_overlay_fx(felt, tm)
	if _jackpot_t > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Geo.SIZE), Color(1.0, 0.85, 0.3, 0.14 * clampf(_jackpot_t / 1.6, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Keçe deseni: Kırmızı Salon kadife baklava, Gece Salonu parlayan ızgara, Büyük Salon altın kakma noktalar
func _draw_felt_pattern(felt: Rect2, tm: float) -> void:
	match _tier:
		1:
			# ince çizgili mavi keçe
			var y := felt.position.y + 24
			while y < felt.end.y:
				draw_rect(Rect2(felt.position.x, y, felt.size.x, 1), FELT[2])
				y += 24
		2:
			var yy := felt.position.y + 20
			var row := 0
			while yy < felt.end.y:
				var xx := felt.position.x + (16.0 if row % 2 == 0 else 32.0)
				while xx < felt.end.x - 8:
					draw_colored_polygon(PackedVector2Array([Vector2(xx, yy - 8), Vector2(xx + 8, yy), Vector2(xx, yy + 8), Vector2(xx - 8, yy)]), FELT[2])
					draw_rect(Rect2(xx - 1, yy - 1, 2, 2), BRASS[1])
					xx += 32.0
				yy += 16.0
				row += 1
		3:
			var a := 0.16 + 0.06 * sin(tm * 1.5)
			var gx := felt.position.x + 32
			while gx < felt.end.x:
				draw_rect(Rect2(gx, felt.position.y, 1, felt.size.y), Color(0.25, 0.94, 1.0, a))
				gx += 32
			var gy := felt.position.y + 32
			while gy < felt.end.y:
				draw_rect(Rect2(felt.position.x, gy, felt.size.x, 1), Color(1.0, 0.31, 0.85, a))
				gy += 32
		4:
			var yy2 := felt.position.y + 24
			var row2 := 0
			while yy2 < felt.end.y:
				var xx2 := felt.position.x + (20.0 if row2 % 2 == 0 else 40.0)
				while xx2 < felt.end.x - 8:
					for d in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
						draw_rect(Rect2(Vector2(xx2, yy2) + d - Vector2(1, 1), Vector2(2, 2)), Color("c8962a"))
					draw_rect(Rect2(xx2 - 1, yy2 - 1, 2, 2), Color("fff0a0"))
					xx2 += 40.0
				yy2 += 28.0
				row2 += 1


## Yan raylar: pirinç perçin (0), gümüş ray + yıldızlar (1), altın ray + süslü köşeler (2),
## kayan LED şerit (3), mücevherli altın sütunlar (4)
func _draw_side_rails(W: float, felt: Rect2, tm: float) -> void:
	for x in [10.0, W - 12.0]:
		draw_rect(Rect2(x, 52, 3, Geo.BAND_TOP - 56), BRASS[1])
	match _tier:
		0:
			for x in [10.0, W - 12.0]:
				var ry := 70.0
				while ry < Geo.BAND_TOP - 20:
					_rivet(Vector2(x + 1, ry))
					ry += 112.0
		1:
			for x in [11.0, W - 11.0]:
				var ry := 80.0
				while ry < Geo.BAND_TOP - 20:
					_star_at(Vector2(x, ry), 5.0, BRASS[3])
					ry += 70.0
		2:
			for x in [10.0, W - 12.0]:
				var ry := 70.0
				while ry < Geo.BAND_TOP - 20:
					_rivet(Vector2(x + 1, ry))
					ry += 42.0
			for c in [felt.position, Vector2(felt.end.x, felt.position.y), Vector2(felt.position.x, felt.end.y), felt.end]:
				var sx := 1.0 if c.x < W / 2.0 else -1.0
				var sy := 1.0 if c.y < Geo.BAND_TOP / 2.0 else -1.0
				draw_rect(Rect2(c.x - (0.0 if sx > 0 else 18.0), c.y - (0.0 if sy > 0 else 4.0), 18, 4), BRASS[2])
				draw_rect(Rect2(c.x - (0.0 if sx > 0 else 4.0), c.y - (0.0 if sy > 0 else 18.0), 4, 18), BRASS[2])
				draw_circle(c + Vector2(sx * 8, sy * 8), 3.0, Color("d0203c"))
		3:
			# neon tüp çerçeve + kayan LED
			var pink := Color(1.0, 0.31, 0.85)
			var cyan := Color(0.25, 0.94, 1.0)
			var pulse := 0.7 + 0.3 * sin(tm * 3.0)
			var fr := felt.grow(-3)
			draw_rect(fr, Color(cyan, 0.18 * pulse), false, 8.0)
			draw_rect(fr, Color(cyan, pulse), false, 3.0)
			draw_rect(Rect2(2, 2, W - 4, Geo.SIZE.y - 4), Color(pink, 0.2 * pulse), false, 6.0)
			draw_rect(Rect2(2, 2, W - 4, Geo.SIZE.y - 4), Color(pink, pulse), false, 2.0)
			var n := 18
			for i in range(n):
				var y := 56.0 + i * (Geo.BAND_TOP - 70.0) / (n - 1)
				var hue := fposmod(i / float(n) - tm * 0.6, 1.0)
				var c := Color.from_hsv(hue, 0.7, 1.0)
				for x in [6.0, W - 8.0]:
					draw_rect(Rect2(x - 1, y - 2, 4, 4), OUTL)
					draw_rect(Rect2(x, y - 1, 2, 2), c)
		4:
			for x in [9.0, W - 11.0]:
				draw_rect(Rect2(x - 3, 52, 9, Geo.BAND_TOP - 56), BRASS[2])
				draw_rect(Rect2(x - 3, 52, 2, Geo.BAND_TOP - 56), BRASS[3])
				var gems := [Color("d0203c"), Color("2a6ad4"), Color("16b86a")]
				var ry := 76.0
				var k := 0
				while ry < Geo.BAND_TOP - 20:
					var gc: Color = gems[k % 3]
					draw_colored_polygon(PackedVector2Array([Vector2(x + 1.5, ry - 6), Vector2(x + 6, ry), Vector2(x + 1.5, ry + 6), Vector2(x - 3, ry)]), OUTL)
					draw_colored_polygon(PackedVector2Array([Vector2(x + 1.5, ry - 5), Vector2(x + 5, ry), Vector2(x + 1.5, ry + 5), Vector2(x - 2, ry)]), gc)
					if sin(tm * 2.5 + k * 1.7) > 0.85:
						draw_rect(Rect2(x, ry - 3, 2, 2), Color.WHITE)
					ry += 52.0
					k += 1


func _star_at(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Tahtanın üstündeki hareketli süs: Büyük Salon parıltıları
func _draw_overlay_fx(felt: Rect2, tm: float) -> void:
	if _tier != 4:
		return
	for i in range(_orn.size()):
		var k := fposmod(tm * 0.5 + i * 0.137, 1.0)
		if k > 0.18:
			continue
		var s := 4.0 if k < 0.06 or k > 0.12 else 7.0
		var p: Vector2 = _orn[i]
		draw_rect(Rect2(p - Vector2(1, s / 2.0), Vector2(2, s)), Color(1, 1, 0.85, 0.9))
		draw_rect(Rect2(p - Vector2(s / 2.0, 1), Vector2(s, 2)), Color(1, 1, 0.85, 0.9))


func _rivet(p: Vector2) -> void:
	draw_circle(p + Vector2(1, 1), 3.5, OUTL)
	draw_circle(p, 3.0, BRASS[1])
	draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(2, 2)), BRASS[3])


## Üst tabela: ampuller (odaya göre sayı ve renk; Gece Salonu'nda neon çerçeve), Büyük Salon'da taçlar,
## ortada top oluğu. "KADER TAHTASI" yazısı tam çözünürlüklü yazı katmanında çizilir (text_items).
func _draw_marquee(W: float, tm: float) -> void:
	var m := Rect2(0, 0, W, 46)
	draw_rect(m, MARQUEE[1])
	draw_rect(Rect2(0, 0, W, 4), MARQUEE[2])
	draw_rect(Rect2(0, 40, W, 6), MARQUEE[0])
	draw_rect(Rect2(0, 44, W, 3), OUTL)
	var reduced := _reduced()
	var bulbs: Array = _th["bulbs"]
	var n: int = int(_th["bulb_n"])
	for i in range(n):
		var x := 10.0 + i * (W - 20.0) / maxf(1.0, n - 1)
		var on := true
		if _tier == 0:
			on = (int(tm * 2.0) + i) % 5 != 0 or reduced
		elif _tier >= 2:
			on = (int(tm * 8.0) - i) % 4 != 0 or reduced   # kayan ışık
		else:
			on = (int(tm * 4.0) + i) % 3 != 0 or reduced
		var bc: Color = bulbs[i % bulbs.size()]
		draw_circle(Vector2(x, 6), 3.0, OUTL)
		draw_circle(Vector2(x, 6), 2.2, bc if on else bc.darkened(0.6))
		if on:
			draw_circle(Vector2(x, 6), 4.5, Color(bc, 0.18 if _tier > 0 else 0.1))
		if _tier >= 2:
			draw_circle(Vector2(x, 40), 2.0, OUTL)
			draw_circle(Vector2(x, 40), 1.4, bc if not on else bc.darkened(0.5))
	if _tier == 3:
		var pulse := 0.7 + 0.3 * sin(tm * 4.0)
		draw_rect(Rect2(3, 3, W - 6, 38), Color(1.0, 0.31, 0.85, pulse), false, 2.0)
		draw_rect(Rect2(7, 7, W - 14, 30), Color(0.25, 0.94, 1.0, pulse * 0.8), false, 1.0)
	if _tier == 4:
		for cx in [W * 0.06, W * 0.94]:
			var b := Vector2(cx, 38)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-14, 0), b + Vector2(-14, -18), b + Vector2(-7, -9), b + Vector2(0, -24), b + Vector2(7, -9), b + Vector2(14, -18), b + Vector2(14, 0)]), OUTL)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-12, -2), b + Vector2(-12, -14), b + Vector2(-6, -7), b + Vector2(0, -20), b + Vector2(6, -7), b + Vector2(12, -14), b + Vector2(12, -2)]), BRASS[0].lerp(Color("ffd23f"), 0.8))
			draw_circle(b + Vector2(0, -8), 2.5, Color("d0203c"))
	# oluk
	var c := Rect2(Geo.CX - 26, 10, 52, 40)
	draw_rect(c.grow(3), OUTL)
	draw_rect(c, BRASS[1])
	draw_rect(Rect2(c.position, Vector2(c.size.x, 4)), BRASS[3])
	draw_rect(Rect2(c.position + Vector2(8, 6), Vector2(c.size.x - 16, c.size.y - 6)), Color("0b0410"))
	draw_rect(Rect2(c.position + Vector2(8, 6), Vector2(c.size.x - 16, 3)), Color("2a1420"))


func _draw_bands(rows: int) -> void:
	var bands := Outcome.bands(int(Game.run["board_level"]))
	var top := Geo.BAND_TOP
	var bh := Geo.BAND_H
	# kova tabanı
	draw_rect(Rect2(10, top - 4, Geo.SIZE.x - 20, bh + 8), OUTL)
	for i in range(bands.size()):
		var b: Dictionary = bands[i]
		var x0 := Geo.u_to_x(float(b["lo"]), rows)
		var x1 := Geo.u_to_x(float(b["hi"]), rows)
		var col: Color = UI.INTERVAL_COLORS[b["type"]]
		var rect := Rect2(Vector2(x0, top), Vector2(x1 - x0, bh))
		draw_rect(rect, col)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), col.lightened(0.4))
		draw_rect(Rect2(rect.position + Vector2(0, bh - 10), Vector2(rect.size.x, 10)), col.darkened(0.3))
		if _band_flash.has(i):
			draw_rect(rect, Color(1, 1, 1, 0.5 * clampf(_band_flash[i] / 0.45, 0.0, 1.0)))
	# ahşap bölmeler
	for i in range(bands.size() + 1):
		var x := Geo.u_to_x(float(bands[mini(i, bands.size() - 1)]["lo"] if i < bands.size() else bands[bands.size() - 1]["hi"]), rows)
		draw_rect(Rect2(x - 2, top - 10, 4, bh + 10), WALNUT[1])
		draw_rect(Rect2(x - 2, top - 10, 1, bh + 10), WALNUT[3])
		draw_rect(Rect2(x - 3, top - 12, 6, 3), BRASS[2])


## Tam çözünürlüklü yazı katmanı için yazılar (tahta koordinatında). u2l: 1 tahta biriminin arayüz pikseli.
## Öğe: {t, p (görsel orta nokta), s (arayüz pikseli), c, a ("c"/"l"), scale}
func text_items(u2l: float) -> Array:
	var out: Array = []
	var W := Geo.SIZE.x
	_apply_theme()
	var sign: Color = _th["sign"]
	# tabela
	out.append({"t": Loc.t("board.sign_left"), "p": Vector2(W * 0.26, 23), "s": 22, "c": sign})
	out.append({"t": Loc.t("board.sign_right"), "p": Vector2(W * 0.74, 23), "s": 22, "c": sign})
	# bantlar: yalnızca net sonuç (ör. "-0,5X"); yüzdeler gösterilmez
	var rows := GameData.rows()
	var bands := Outcome.bands(int(Game.run["board_level"]))
	var intervals: Dictionary = GameData.eco["intervals"]
	for i in range(bands.size()):
		var b: Dictionary = bands[i]
		if String(b["type"]) == "M":
			continue
		var x0 := Geo.u_to_x(float(b["lo"]), rows)
		var x1 := Geo.u_to_x(float(b["hi"]), rows)
		var w_l := (x1 - x0) * u2l
		var net := Fmt.xlabel(float(intervals[b["type"]]["net"]))
		var fsz := 0
		if w_l >= UI.display_font().get_string_size(net, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 8.0:
			fsz = 22
		elif w_l >= UI.display_font().get_string_size(net, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 4.0:
			fsz = 11
		if fsz > 0:
			out.append({"t": net, "p": Vector2((x0 + x1) / 2.0, Geo.BAND_TOP + Geo.BAND_H * 0.5), "s": fsz, "c": Color.WHITE})
	# ★ işareti: dar MAX bandının içinde (lejantta ★ = MAX)
	var mb: Dictionary = bands[3]
	var mx := Geo.u_to_x((float(mb["lo"]) + float(mb["hi"])) / 2.0, rows)
	out.append({"t": "★", "p": Vector2(mx, Geo.BAND_TOP + Geo.BAND_H * 0.5), "s": 22, "c": Color.WHITE})
	# sonuç yazıları
	for p in _popups:
		var k: float = p["t"] / p["life"]
		var rise := 0.0 if _reduced() else 40.0 * k
		var a := 1.0 - k * k
		var pos: Vector2 = p["pos"] - Vector2(0, rise)
		pos.x = clampf(pos.x, 70.0, W - 70.0)
		var col: Color = p["color"]
		col.a = a
		var pop := 1.0
		if bool(p["big"]) and not _reduced():
			pop = 1.0 + 0.35 * maxf(0.0, 1.0 - p["t"] * 6.0)
		var fsz := 33 if bool(p["big"]) else 22
		out.append({"t": p["text"], "p": pos, "s": fsz, "c": col, "scale": pop})
		if String(p.get("sub", "")) != "":
			# yetenek çarpanı: tutarın sağında küçük, nadirlik renginde
			var sc: Color = p["sub_color"]
			sc.a = a
			var mw := UI.display_font().get_string_size(String(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			out.append({"t": p["sub"], "p": pos + Vector2((mw / 2.0 + 4.0) / maxf(u2l, 0.1), 0), "s": 11, "c": sc, "a": "l"})
	return out


## Tahta noktasının görünüm içindeki tam sayı piksel konumu (sprite'lar 1:1 piksel çizilir).
func _px(p: Vector2) -> Vector2:
	return (_offset + p * _scale).floor()


## Sprite'ı merkezine çizer; doku henüz üretilmediyse vektör yedeğe düşer.
func _sprite_at(kind: String, p: Vector2, phase: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = PixelArt.sprite(kind, false, phase)
	if tex != null:
		draw_texture(tex, p - (tex.get_size() / 2.0).floor(), Color(1, 1, 1, alpha))
	elif kind.begins_with("peg:"):
		Icon.draw_peg(self, kind.substr(4), p, 5.0)
	else:
		Icon.draw_ball(self, p, 6.0, kind.substr(5), UI.ball_color(kind.substr(5)))


func _draw_pegs(rows: int) -> void:
	var editing: bool = Game.edit_mode
	# düzenleme ipuçları (tahta uzayında): isabet sıklığı ve imleç halkası
	if editing:
		var heat: Dictionary = {}
		if bool(Game.settings.get("show_heat", true)):
			heat = Game.probabilities()["hits"]
		for r in range(rows):
			for j in range(r + 1):
				var cell := Vector2i(r, j)
				if not PegSystem.is_placeable_cell(cell):
					continue
				var p := Geo.peg_pos(r, j)
				var h: float = float(heat.get(cell, 0.0))
				if not heat.is_empty():
					draw_circle(p, 9.0 + 14.0 * sqrt(h), Color(BRASS[2], 0.12 + 0.35 * h))
				if cell == _hover:
					draw_arc(p, 19.0, 0, TAU, 20, Color.WHITE, 3.0)
	# çiviler: piksel sprite'lar, 1:1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for r in range(rows):
		for j in range(-1, r + 2):
			var cell := Vector2i(r, j)
			var p := _px(Geo.peg_pos(r, j))
			var pid: String = Game.layout_cells.get(cell, "")
			if pid != "":
				if _flash.has(cell):
					draw_circle(p, 7.0 + 6.0 * _flash[cell] / 0.35, Color(UI.peg_color(pid), 0.45))
				draw_circle(p + Vector2(2, 3), 5.0, Color(0, 0, 0, 0.35))
				_sprite_at("peg:" + pid, p, (r * 7 + j) * 0.137)
			else:
				var inside := j >= 0 and j <= r
				var tex := PixelArt.plain_peg("lit" if _flash.has(cell) else ("in" if inside else "out"), String(_th["peg"]))
				draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 3)), Color(0, 0, 0, 0.3))
				draw_texture(tex, p - (tex.get_size() / 2.0).floor())
	if editing and selected_peg != "" and _hover.x >= 0 and PegSystem.is_placeable_cell(_hover) and not Game.layout_cells.has(_hover):
		_sprite_at("peg:" + selected_peg, _px(Geo.peg_pos(_hover.x, _hover.y)), 0.0, 0.7)
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))


## Türlere özgü iz renkleri (ateşli toplar kıvılcım, kuyruklu buz tozu bırakır)
const TRAILS := {
	"volkan": [Color("fff3a0"), Color("ffc23d"), Color("ff7a00"), Color("d64000")],
	"anka": [Color("fff3a0"), Color("ffc93d"), Color("ff7a1f"), Color("e0285e")],
	"kuyruklu": [Color("ffffff"), Color("c8f0ff"), Color("8fe0ff"), Color("a58bff")],
	"miknatis": [Color("6ef2ff"), Color("c08bff")],
	"kara_inci": [Color("d7b8ff"), Color("8a5cff"), Color("5a2cc4")],
	"altin": [Color("fff3b0"), Color("ffcf3d")],
}


static func trail_len(bid: String) -> int:
	return 10 if TRAILS.has(bid) and bid != "altin" else 6


func _draw_balls() -> void:
	var reduced := _reduced()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in Game.flights:
		var pos := _px(f.position_at(f.elapsed))
		var bid: String = f.ball_id
		var phase := float(f.get_instance_id() % 1000) / 1000.0
		if not reduced:
			var pal: Array = TRAILS.get(bid, [UI.ball_color(bid)])
			var n: int = f.trail.size()
			for i in range(n):
				var a := float(i + 1) / float(n + 1)
				var q := _px(f.trail[i])
				var sz := 1.0 + floorf(a * 2.6)
				var col: Color = pal[clampi(int((1.0 - a) * pal.size()), 0, pal.size() - 1)]
				col.a = (0.25 + 0.6 * a) if TRAILS.has(bid) else 0.22 * a
				draw_rect(Rect2(q - Vector2(sz, sz) / 2.0, Vector2(sz, sz)).abs(), col)
		draw_circle(pos + Vector2(2, 4), 5.5, Color(0, 0, 0, 0.3))
		if f.bonus:
			draw_arc(pos, 10.0, 0, TAU, 20, UI.ORANGE, 1.0)
		_sprite_at("ball:" + bid, pos, phase)
		# Özel çivi etkisi: yalnızca topun o ana kadar GERÇEKTEN çarptığı çiviler gösterilir (yol atışta
		# belirlenir ama görsel etki çarpma anında başlar). Halka son çarpılan çivinin renginde; her yeni
		# çarpmada kısa süre büyür, çarpma sayısı arttıkça ikinci halka eklenir.
		var hit_n := 0
		var hit_col := Color.WHITE
		var since := 99.0
		for sh in f.special_hits:
			var ht: float = f.hit_time(int(sh["i"]))
			if f.elapsed >= ht:
				hit_n += 1
				hit_col = UI.peg_color(String(sh["peg"]))
				since = f.elapsed - ht
		if hit_n > 0:
			var pop := 1.0 + 0.8 * maxf(0.0, 1.0 - since / 0.25) if not reduced else 1.0
			draw_arc(pos, 9.0 * pop, 0, TAU, 20, Color(hit_col, 0.35), 3.0)
			draw_arc(pos, 9.0 * pop, 0, TAU, 20, hit_col, 1.0)
			if hit_n >= 2:
				draw_arc(pos, 11.0, 0, TAU, 24, Color(hit_col.lightened(0.3), 0.7), 1.0)
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
