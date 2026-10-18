extends RefCounted
## Odaların piksel sanat çizimi (yarım çözünürlüklü sahne koordinatları). Beş oda:
##   0 Arka Oda (tuğla, çıplak ampuller, beton)      1 Ön Salon (çizgili duvar kâğıdı, afişler, renkli ampul dizisi, dama zemin)
##   2 Kırmızı Salon (kadife perdeler, altın korniş, şamdanlar, halı)
##   3 Gece Salonu (neon tüpler, gece şehri pencereleri, parlak zemin)
##   4 Büyük Salon (mermer sütunlar, avizeler, altın süslemeler, kırmızı halı)
## back(): sabit katman (duvar, zemin, sabit süsler) · fx(): hareketli duvar süsleri · table(): masa · decor(): masa süsleri

const Themes := preload("res://scripts/stage/themes.gd")
const OUT := Color("1a0c08")


static func _h(a: int, b: int, s: int = 0) -> float:
	var h := (a * 374761393 + b * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) % 1000) / 999.0


static func floor_y(size: Vector2) -> float:
	return floorf(size.y * 0.80)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var a := i * TAU / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func _sparkle(ci: CanvasItem, p: Vector2, s: int, col: Color) -> void:
	if s <= 0:
		return
	ci.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color.WHITE)
	for k in range(1, s + 1):
		ci.draw_rect(Rect2((p + Vector2(k, 0)).floor(), Vector2(1, 1)), col)
		ci.draw_rect(Rect2((p - Vector2(k, 0)).floor(), Vector2(1, 1)), col)
		ci.draw_rect(Rect2((p + Vector2(0, k)).floor(), Vector2(1, 1)), col)
		ci.draw_rect(Rect2((p - Vector2(0, k)).floor(), Vector2(1, 1)), col)


## Sarkan kablo/zincir (katener yaklaşımı) üzerindeki noktalar
static func _sag(x0: float, x1: float, y: float, sag: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var k := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, k), y + sag * 4.0 * k * (1.0 - k)))
	return pts


# =================================================================== sabit katman

static func back(ci: CanvasItem, size: Vector2, t: Rect2, tier: int) -> void:
	match tier:
		0:
			_back0(ci, size, t)
		1:
			_back1(ci, size, t)
		2:
			_back2(ci, size, t)
		3:
			_back3(ci, size, t)
		_:
			_back4(ci, size, t)


## Arka Oda: kirli tuğla, paslı boru, beton zemin
static func _back0(ci: CanvasItem, size: Vector2, t: Rect2) -> void:
	var wy := floor_y(size)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("1e1218"))
	var pal := [Color("3e2228"), Color("46272c"), Color("4f2c30"), Color("362024")]
	var row := 0
	var y := 0.0
	while y < wy:
		var off := 8.0 if row % 2 == 1 else 0.0
		var x := -off
		var col_i := 0
		while x < size.x:
			var hv := _h(row, col_i, 3)
			var c: Color = pal[int(hv * 3.99)]
			if hv > 0.93:
				c = Color("2a171c")
			ci.draw_rect(Rect2(x + 1, y + 1, 14, 6), c)
			if hv > 0.55:
				ci.draw_rect(Rect2(x + 1, y + 1, 14, 1), c.lightened(0.12))
			x += 16
			col_i += 1
		y += 8
		row += 1
	# paslı boru
	ci.draw_rect(Rect2(0, 9, size.x, 6), Color("2a1a12"))
	ci.draw_rect(Rect2(0, 10, size.x, 4), Color("6a4a32"))
	ci.draw_rect(Rect2(0, 10, size.x, 1), Color("8a6a4a"))
	var bx := 20.0
	while bx < size.x:
		ci.draw_rect(Rect2(bx, 8, 4, 8), Color("3a2a1e"))
		ci.draw_rect(Rect2(bx + 1, 15, 2, 4), Color("2a1a12"))
		bx += 90.0
	# örümcek ağı (köşeler)
	for corner in [Vector2(0, 0), Vector2(size.x, 0)]:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		for k in range(4):
			var a := k * 0.4
			ci.draw_line(corner, corner + Vector2(sx * cos(a) * 26.0, sin(a) * 26.0 + 2.0), Color(0.8, 0.8, 0.85, 0.25), 1.0)
		for r in [8.0, 15.0, 22.0]:
			ci.draw_arc(corner, r, 0.0 if sx > 0 else PI / 2.0, PI / 2.0 if sx > 0 else PI, 6, Color(0.8, 0.8, 0.85, 0.2), 1.0)
	# beton zemin
	ci.draw_rect(Rect2(0, wy, size.x, size.y - wy), Color("2c282e"))
	ci.draw_rect(Rect2(0, wy, size.x, 2), Color("15121a"))
	for i in range(int(size.x / 6.0)):
		var px := float(i) * 6.0
		var hv := _h(i, 7, 1)
		ci.draw_rect(Rect2(px, wy + 4 + hv * (size.y - wy - 8), 2 + hv * 6, 1), Color("3a363c") if hv > 0.5 else Color("221e24"))
	ci.draw_line(Vector2(size.x * 0.2, wy + 6), Vector2(size.x * 0.26, size.y), Color("1a161c"), 1.0)
	ci.draw_line(Vector2(size.x * 0.74, wy + 3), Vector2(size.x * 0.7, size.y), Color("1a161c"), 1.0)


## Ön Salon: turkuaz çizgili duvar kâğıdı, korniş, afişler, ahşap lambri, dama zemin
static func _back1(ci: CanvasItem, size: Vector2, t: Rect2) -> void:
	var wy := floor_y(size)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("1b5260"))
	var x := 0.0
	var i := 0
	while x < size.x:
		if i % 2 == 0:
			ci.draw_rect(Rect2(x, 0, 12, wy), Color("226a78"))
			var yy := 14.0 + (i % 4) * 5.0
			while yy < wy - 40:
				_diamond(ci, Vector2(x + 6, yy), 2.0, Color("e0b450"))
				yy += 22.0
		else:
			ci.draw_rect(Rect2(x + 5, 0, 1, wy), Color("d8c89c"))
		x += 12
		i += 1
	# korniş
	ci.draw_rect(Rect2(0, 0, size.x, 6), Color("efe0b8"))
	ci.draw_rect(Rect2(0, 6, size.x, 1), Color("a08860"))
	ci.draw_rect(Rect2(0, 7, size.x, 2), Color(0, 0, 0, 0.2))
	# afişler (masanın iki yanındaki duvarda)
	for side in [0, 1]:
		var room_w := t.position.x if side == 0 else size.x - t.end.x
		if room_w < 60:
			continue
		var cx := room_w / 2.0 if side == 0 else t.end.x + room_w / 2.0
		for k in range(2):
			var pr := Rect2(Vector2(cx - 18, 30 + k * 70), Vector2(36, 50))
			if pr.end.y > wy - 40:
				break
			ci.draw_rect(pr.grow(2), OUT)
			ci.draw_rect(pr.grow(1), Color("c8902a"))
			var bg := Color("ff5fa8") if (k + side) % 2 == 0 else Color("41c8e8")
			ci.draw_rect(pr, bg)
			ci.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 10)), bg.darkened(0.25))
			ci.draw_circle(pr.get_center() + Vector2(0, 4), 10.0, OUT)
			ci.draw_circle(pr.get_center() + Vector2(0, 4), 9.0, Color("ffd23f"))
			ci.draw_circle(pr.get_center() + Vector2(-3, 1), 3.0, Color("fff6c0"))
			_star(ci, pr.position + Vector2(pr.size.x / 2.0, 5), 3.5, Color.WHITE)
	# lambri
	var ly := wy - 34
	ci.draw_rect(Rect2(0, ly, size.x, 34), Color("6a3a1e"))
	ci.draw_rect(Rect2(0, ly, size.x, 3), Color("9a5e2c"))
	ci.draw_rect(Rect2(0, ly + 3, size.x, 1), OUT)
	var px := 6.0
	while px < size.x:
		ci.draw_rect(Rect2(px, ly + 8, 30, 20), Color("5a3018"))
		ci.draw_rect(Rect2(px, ly + 8, 30, 1), Color("3a1e0e"))
		ci.draw_rect(Rect2(px, ly + 27, 30, 1), Color("8a5228"))
		px += 38.0
	# dama zemin
	ci.draw_rect(Rect2(0, wy, size.x, size.y - wy), Color("cdbfa4"))
	var ty := wy
	var r := 0
	while ty < size.y:
		var tx := 0.0 if r % 2 == 0 else 12.0
		while tx < size.x:
			ci.draw_rect(Rect2(tx, ty, 12, 8), Color("3d3550"))
			tx += 24.0
		ty += 8.0
		r += 1
	ci.draw_rect(Rect2(0, wy, size.x, 2), Color("3a1e0e"))


## Kırmızı Salon: kadife duvar, altın korniş, yan perdeler, maun lambri, halı
static func _back2(ci: CanvasItem, size: Vector2, t: Rect2) -> void:
	var wy := floor_y(size)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("520a1a"))
	var yy := 18.0
	var row := 0
	while yy < wy:
		var xx := 8.0 if row % 2 == 0 else 0.0
		while xx < size.x:
			_diamond(ci, Vector2(xx, yy), 5.0, Color("6c1426"))
			_diamond(ci, Vector2(xx, yy), 2.0, Color("c89030"))
			ci.draw_rect(Rect2(xx - 1, yy - 9, 2, 2), Color("7e1a2e"))
			xx += 16.0
		yy += 16.0
		row += 1
	# altın korniş + dişler
	ci.draw_rect(Rect2(0, 0, size.x, 7), Color("c08a12"))
	ci.draw_rect(Rect2(0, 0, size.x, 2), Color("ffe080"))
	ci.draw_rect(Rect2(0, 7, size.x, 2), Color("7a4a08"))
	var dx := 0.0
	while dx < size.x:
		ci.draw_rect(Rect2(dx, 9, 3, 3), Color("c08a12"))
		dx += 6.0
	# perde üst saçağı (fistolar)
	var sx := 0.0
	while sx < size.x:
		_ellipse(ci, Vector2(sx + 12, 12), 13.0, 7.0, Color("6a0618"))
		_ellipse(ci, Vector2(sx + 12, 11), 12.0, 6.0, Color("9a1028"))
		ci.draw_rect(Rect2(sx + 4, 17, 16, 1), Color("f2c434"))
		for k in range(4):
			ci.draw_rect(Rect2(sx + 5 + k * 4, 18, 1, 3), Color("f2c434"))
		sx += 24.0
	# yan perdeler
	for side in [0, 1]:
		var x0 := 0.0 if side == 0 else size.x - 40.0
		for k in range(8):
			var c: Color = [Color("6a0618"), Color("8a0c22"), Color("a8142c"), Color("8a0c22")][k % 4]
			ci.draw_rect(Rect2(x0 + k * 5, 10, 5, wy - 10), c)
		var tie_y := wy * 0.55
		ci.draw_rect(Rect2(x0, tie_y, 40, 5), Color("c08a12"))
		ci.draw_rect(Rect2(x0, tie_y, 40, 1), Color("ffe080"))
		ci.draw_circle(Vector2(x0 + (34.0 if side == 0 else 6.0), tie_y + 8), 3.0, Color("f2c434"))
	# lambri
	var ly := wy - 30
	ci.draw_rect(Rect2(0, ly, size.x, 30), Color("3a0c08"))
	ci.draw_rect(Rect2(0, ly, size.x, 2), Color("f2c434"))
	ci.draw_rect(Rect2(0, ly + 2, size.x, 1), OUT)
	# halı
	ci.draw_rect(Rect2(0, wy, size.x, size.y - wy), Color("7a0c1c"))
	ci.draw_rect(Rect2(0, wy, size.x, 2), OUT)
	ci.draw_rect(Rect2(0, wy + 5, size.x, 2), Color("d4a030"))
	ci.draw_rect(Rect2(0, wy + 9, size.x, 1), Color("d4a030"))
	var cx := 6.0
	while cx < size.x:
		_diamond(ci, Vector2(cx, wy + 20), 3.0, Color("a01c30"))
		ci.draw_rect(Rect2(cx - 1, wy + 19, 2, 2), Color("d4a030"))
		cx += 14.0


## Gece Salonu: koyu tuğla, gece şehri pencereleri (üst şerit ve yanlar), parlak koyu zemin
static func _back3(ci: CanvasItem, size: Vector2, t: Rect2) -> void:
	var wy := floor_y(size)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("0e0b26"))
	var row := 0
	var y := 0.0
	while y < wy:
		var off := 8.0 if row % 2 == 1 else 0.0
		var x := -off
		while x < size.x:
			ci.draw_rect(Rect2(x + 1, y + 1, 14, 6), Color("141034") if _h(row, int(x), 9) > 0.4 else Color("110d2e"))
			x += 16
		y += 8
		row += 1
	# üst şeritte geniş pencere + iki yanda büyük pencere
	var wins: Array = []
	if t.position.y > 12:
		wins.append(Rect2(4, 3, size.x - 8, t.position.y - 6))
	for side in [0, 1]:
		var room_w := t.position.x if side == 0 else size.x - t.end.x
		if room_w >= 70:
			var x0 := 10.0 if side == 0 else t.end.x + 10.0
			wins.append(Rect2(x0, 40, room_w - 20, wy - 100))
	for w in wins:
		_night_window(ci, w)
	# parlak zemin
	ci.draw_rect(Rect2(0, wy, size.x, size.y - wy), Color("0a0818"))
	ci.draw_rect(Rect2(0, wy, size.x, 2), Color("2a2460"))
	var gx := 0.0
	while gx < size.x:
		ci.draw_rect(Rect2(gx, wy + 2, 1, size.y - wy), Color("141232"))
		gx += 32.0


static func _night_window(ci: CanvasItem, w: Rect2) -> void:
	ci.draw_rect(w.grow(2), Color("24204a"))
	ci.draw_rect(w.grow(1), Color("05040e"))
	var bands := [Color("0a0a30"), Color("110e42"), Color("1a1458"), Color("261a6c")]
	for i in range(4):
		var bh := w.size.y / 4.0
		ci.draw_rect(Rect2(w.position.x, w.position.y + i * bh, w.size.x, ceilf(bh)), bands[i])
	for i in range(int(w.size.x * w.size.y / 90.0)):
		var p := w.position + Vector2(_h(i, 1, 4) * w.size.x, _h(i, 2, 4) * w.size.y * 0.6)
		ci.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color(1, 1, 1, 0.5 + 0.5 * _h(i, 3, 4)))
	if w.size.y > 30:
		ci.draw_circle(w.position + Vector2(w.size.x * 0.8, 10), 6.0, Color("fff3c0"))
		ci.draw_circle(w.position + Vector2(w.size.x * 0.8 + 3, 8), 5.0, Color("1a1458"))
	# şehir silueti
	var x := w.position.x
	var i2 := 0
	while x < w.end.x:
		var bw := 8.0 + _h(i2, 5, 2) * 14.0
		var bh := w.size.y * (0.25 + _h(i2, 6, 2) * 0.55)
		var br := Rect2(x, w.end.y - bh, minf(bw, w.end.x - x), bh)
		ci.draw_rect(br, Color("070616"))
		var wx := br.position.x + 2
		while wx < br.end.x - 2:
			var wyy := br.position.y + 3
			while wyy < br.end.y - 2:
				var hv := _h(int(wx), int(wyy), 8)
				if hv > 0.62:
					ci.draw_rect(Rect2(wx, wyy, 1, 1), Color("ffd86a") if hv > 0.8 else Color("6ef0ff"))
				wyy += 3
			wx += 3
		x += bw + 1
		i2 += 1
	# pencere kayıtları
	ci.draw_rect(Rect2(w.position.x, w.get_center().y, w.size.x, 1), Color("24204a"))


## Büyük Salon: mor-altın kafesli duvar, mermer sütunlar, altın korniş ve kurdeleler, mermer zemin + kırmızı halı
static func _back4(ci: CanvasItem, size: Vector2, t: Rect2) -> void:
	var wy := floor_y(size)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("2c1054"))
	var step := 20.0
	var yy := 0.0
	while yy < wy:
		var xx := 0.0
		while xx < size.x:
			ci.draw_line(Vector2(xx, yy), Vector2(xx + step, yy + step), Color("3e1a70"), 1.0)
			ci.draw_line(Vector2(xx + step, yy), Vector2(xx, yy + step), Color("3e1a70"), 1.0)
			ci.draw_rect(Rect2(xx - 1, yy - 1, 2, 2), Color("e0b040"))
			xx += step
		yy += step
	# mermer sütunlar
	var cols: Array = []
	var cx := 18.0
	while cx < size.x:
		cols.append(cx)
		cx += 112.0
	for c in cols:
		var x0: float = c - 11.0
		ci.draw_rect(Rect2(x0 - 1, 8, 24, wy - 8), Color("1a0e02"))
		ci.draw_rect(Rect2(x0, 8, 22, wy - 8), Color("ece6da"))
		ci.draw_rect(Rect2(x0, 8, 4, wy - 8), Color("fbf8f0"))
		ci.draw_rect(Rect2(x0 + 17, 8, 5, wy - 8), Color("cfc6b4"))
		for k in range(3):
			ci.draw_rect(Rect2(x0 + 7 + k * 4, 18, 1, wy - 30), Color("ddd4c2"))
		for v in range(4):
			var vy := 40.0 + v * 60.0
			if vy < wy - 30:
				ci.draw_line(Vector2(x0 + 3, vy), Vector2(x0 + 14, vy + 12), Color("bdb4a2"), 1.0)
		ci.draw_rect(Rect2(x0 - 4, 8, 30, 7), Color("c08a14"))
		ci.draw_rect(Rect2(x0 - 4, 8, 30, 2), Color("ffe27a"))
		ci.draw_rect(Rect2(x0 - 4, wy - 9, 30, 9), Color("c08a14"))
		ci.draw_rect(Rect2(x0 - 4, wy - 9, 30, 2), Color("ffe27a"))
	# korniş
	ci.draw_rect(Rect2(0, 0, size.x, 8), Color("c08a14"))
	ci.draw_rect(Rect2(0, 0, size.x, 2), Color("fff0a0"))
	ci.draw_rect(Rect2(0, 8, size.x, 2), Color("6a4006"))
	var dx := 0.0
	while dx < size.x:
		_diamond(ci, Vector2(dx + 4, 4), 2.0, Color("fff0a0"))
		dx += 10.0
	# altın kurdeleler (sütunlar arası)
	for k in range(cols.size() - 1):
		var pts := _sag(float(cols[k]) + 11.0, float(cols[k + 1]) - 11.0, 14.0, 12.0, 12)
		for i in range(pts.size() - 1):
			ci.draw_line(pts[i], pts[i + 1], Color("8a5a0c"), 3.0)
			ci.draw_line(pts[i], pts[i + 1], Color("f2c434"), 1.0)
		ci.draw_circle(pts[6] + Vector2(0, 2), 2.5, Color("d0203c"))
	# mermer lambri
	var ly := wy - 30
	ci.draw_rect(Rect2(0, ly, size.x, 30), Color("e6dfd0"))
	ci.draw_rect(Rect2(0, ly, size.x, 2), Color("f2c434"))
	ci.draw_rect(Rect2(0, ly + 2, size.x, 1), Color("8a5a0c"))
	# mermer dama zemin + kırmızı halı
	ci.draw_rect(Rect2(0, wy, size.x, size.y - wy), Color("f0ebe0"))
	var ty := wy
	var r := 0
	while ty < size.y:
		var tx := 0.0 if r % 2 == 0 else 16.0
		while tx < size.x:
			ci.draw_rect(Rect2(tx, ty, 16, 10), Color("d4cab6"))
			tx += 32.0
		ty += 10.0
		r += 1
	var gy := wy
	while gy < size.y:
		ci.draw_rect(Rect2(0, gy, size.x, 1), Color("e0b040"))
		gy += 10.0
	var rx0 := t.position.x - 10.0
	ci.draw_rect(Rect2(rx0, wy, t.size.x + 20.0, size.y - wy), Color("a8102c"))
	ci.draw_rect(Rect2(rx0, wy, 3, size.y - wy), Color("f2c434"))
	ci.draw_rect(Rect2(rx0 + t.size.x + 17.0, wy, 3, size.y - wy), Color("f2c434"))
	ci.draw_rect(Rect2(0, wy, size.x, 2), Color("8a5a0c"))


# =================================================================== hareketli duvar süsleri

static func fx(ci: CanvasItem, size: Vector2, t: Rect2, cab: Rect2, tier: int, time: float, reduced: bool) -> void:
	var tm := 0.0 if reduced else time
	match tier:
		0:
			# çıplak ampuller ve toz zerreleri
			for bx in [t.position.x + (cab.position.x - t.position.x) * 0.5, cab.end.x + (t.end.x - cab.end.x) * 0.5]:
				var fl := 0.85 + 0.15 * sin(tm * 9.0 + bx) * sin(tm * 3.3)
				ci.draw_line(Vector2(bx, 0), Vector2(bx, 14), Color("140c08"), 1.0)
				ci.draw_rect(Rect2(bx - 2, 13, 4, 3), Color("4a4a4a"))
				ci.draw_circle(Vector2(bx, 19), 26.0 * fl, Color(1.0, 0.8, 0.4, 0.05))
				ci.draw_circle(Vector2(bx, 19), 12.0 * fl, Color(1.0, 0.85, 0.5, 0.10))
				ci.draw_circle(Vector2(bx, 19), 4.0, Color("ffe9a0"))
				ci.draw_rect(Rect2(bx - 1, 17, 2, 2), Color.WHITE)
			for i in range(14):
				var p := Vector2(fposmod(_h(i, 1) * size.x + tm * 3.0 * (0.5 + _h(i, 2)), size.x),
					fposmod(_h(i, 3) * size.y * 0.7 - tm * 2.0 * _h(i, 4), size.y * 0.7))
				ci.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color(1, 0.9, 0.7, 0.35))
		1:
			# renkli ampul dizisi
			var pts := _sag(0.0, size.x, 10.0, 7.0, int(size.x / 14.0))
			for i in range(pts.size() - 1):
				ci.draw_line(pts[i], pts[i + 1], Color("1a1a1a"), 1.0)
			var cols := [Color("ff5fa8"), Color("ffd23f"), Color("6ee0ff"), Color("6dff9a")]
			for i in range(pts.size()):
				var on := (int(tm * 3.0) + i) % 4 != 0
				var c: Color = cols[i % 4]
				var p := pts[i] + Vector2(0, 3)
				if on:
					ci.draw_circle(p, 5.0, Color(c, 0.18))
				ci.draw_rect(Rect2(p - Vector2(1, 2), Vector2(3, 4)), c if on else c.darkened(0.55))
		2:
			# duvar şamdanları (titreyen alev)
			var xs: Array = [48.0, size.x - 48.0]
			if t.position.x > 90:
				xs.append(t.position.x * 0.5)
				xs.append(t.end.x + (size.x - t.end.x) * 0.5)
			for sx in xs:
				var y := 44.0
				ci.draw_rect(Rect2(sx - 5, y + 8, 10, 3), Color("c08a12"))
				ci.draw_rect(Rect2(sx - 1, y + 11, 2, 8), Color("8a5a0c"))
				ci.draw_rect(Rect2(sx - 2, y, 4, 8), Color("fff4e0"))
				var fl := 1.0 + 0.25 * sin(tm * 11.0 + sx)
				ci.draw_circle(Vector2(sx, y - 3), 14.0 * fl, Color(1.0, 0.7, 0.3, 0.07))
				ci.draw_rect(Rect2(sx - 1, y - 5 - fl, 3, 4 + fl), Color("ffcf3d"))
				ci.draw_rect(Rect2(sx, y - 3, 1, 2), Color("fff8d0"))
		3:
			# neon tüpler, yanıp sönen pencereler, zemin yansımaları
			var top_y := maxf(2.0, t.position.y - 3.0)
			var flick := 1.0 if (int(tm * 13.0) % 37) != 0 else 0.35
			var pink := Color(1.0, 0.31, 0.85, 1.0)
			var cyan := Color(0.25, 0.94, 1.0, 1.0)
			ci.draw_rect(Rect2(0, top_y - 3, size.x, 7), Color(pink, 0.12 * flick))
			ci.draw_rect(Rect2(0, top_y, size.x, 1), Color(pink, flick))
			var wy := floor_y(size)
			ci.draw_rect(Rect2(0, wy - 34, size.x, 5), Color(cyan, 0.12))
			ci.draw_rect(Rect2(0, wy - 32, size.x, 1), cyan)
			for i in range(30):
				var on := sin(tm * (0.5 + _h(i, 9)) * 3.0 + i) > 0.3
				var p := Vector2(_h(i, 10) * size.x, _h(i, 11) * maxf(4.0, t.position.y - 6.0) + 4.0)
				ci.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color("ffd86a") if on else Color("1a1458"))
			for i in range(int(size.x / 40.0)):
				var rx := float(i) * 40.0 + 10.0 + sin(tm * 1.5 + i) * 3.0
				var c := pink if i % 2 == 0 else cyan
				ci.draw_rect(Rect2(rx, wy + 4, 2, size.y - wy - 6), Color(c, 0.10))
			# yan duvarlarda neon ★ (menüde görünür)
			if t.position.x > 90:
				_neon_star(ci, Vector2(t.position.x * 0.5, floor_y(size) - 60), 14.0, pink, flick)
		_:
			# avizeler, parıltılar, süzülen altın tozu
			for ax in [t.position.x + (cab.position.x - t.position.x) * 0.5, cab.end.x + (t.end.x - cab.end.x) * 0.5]:
				_chandelier(ci, Vector2(ax, 2), tm)
			for i in range(20):
				var k := fposmod(tm * 0.6 + _h(i, 1), 1.0)
				var s := 1 if k < 0.1 else (2 if k < 0.2 else (1 if k < 0.3 else 0))
				_sparkle(ci, Vector2(_h(i, 2) * size.x, _h(i, 3) * floor_y(size) * 0.9), s, Color("ffe27a"))
			for i in range(18):
				var p := Vector2(fposmod(_h(i, 5) * size.x + sin(tm + i) * 4.0, size.x), fposmod(_h(i, 6) * size.y + tm * 10.0 * (0.5 + _h(i, 7)), size.y))
				ci.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color(1.0, 0.85, 0.3, 0.6))


static func _neon_star(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float) -> void:
	var pts := PackedVector2Array()
	for i in range(11):
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_polyline(pts, Color(col, 0.25 * a), 4.0)
	ci.draw_polyline(pts, Color(col, a), 1.0)


static func _chandelier(ci: CanvasItem, top: Vector2, tm: float) -> void:
	ci.draw_line(top, top + Vector2(0, 8), Color("8a5a0c"), 1.0)
	var c := top + Vector2(0, 12)
	ci.draw_circle(c, 30.0, Color(1.0, 0.92, 0.6, 0.05))
	ci.draw_rect(Rect2(c.x - 14, c.y, 28, 3), Color("c08a14"))
	ci.draw_rect(Rect2(c.x - 14, c.y, 28, 1), Color("ffe27a"))
	ci.draw_rect(Rect2(c.x - 2, c.y - 4, 4, 4), Color("c08a14"))
	for k in range(5):
		var x := c.x - 12 + k * 6
		ci.draw_rect(Rect2(x, c.y - 4, 2, 4), Color("fff8e8"))
		var fl := 1 if sin(tm * 9.0 + k * 1.7) > 0 else 0
		ci.draw_rect(Rect2(x, c.y - 6 - fl, 2, 2 + fl), Color("ffcf3d"))
		for d in range(3):
			var on := sin(tm * 2.0 + k + d * 1.3) > 0.6
			ci.draw_rect(Rect2(x + (d % 2), c.y + 4 + d * 3, 1, 2), Color.WHITE if on else Color("a8e8ff"))


# =================================================================== masa

static func table(ci: CanvasItem, size: Vector2, t: Rect2, tier: int, grain: Array, time: float) -> void:
	var th := Themes.table(tier)
	var top: Array = th["top"]
	var edge: Array = th["edge"]
	var leg: Array = th["leg"]
	# zemin gölgesi (Gece Salonu: pembe alt ışık)
	if tier == 3:
		_ellipse(ci, Vector2(t.get_center().x, t.end.y + 30), t.size.x * 0.6, 22.0, Color(1.0, 0.3, 0.85, 0.16))
	else:
		ci.draw_rect(Rect2(t.position + Vector2(6, 8), t.size + Vector2(0, 20)), Color(0, 0, 0, 0.45))
	# ayaklar
	var front_y := t.end.y
	var leg_w := 22
	for lx in [t.position.x + 18, t.end.x - 18 - leg_w]:
		var lr := Rect2(lx, front_y + 10, leg_w, size.y - front_y)
		ci.draw_rect(lr.grow(1), OUT)
		ci.draw_rect(lr, leg[1])
		ci.draw_rect(Rect2(lx + 2, front_y + 10, 4, lr.size.y), leg[2])
		ci.draw_rect(Rect2(lx + leg_w - 5, front_y + 10, 5, lr.size.y), leg[0])
		if tier >= 2:
			# oyma / bilezik
			for k in range(3):
				ci.draw_rect(Rect2(lx - 2, front_y + 18 + k * 14, leg_w + 4, 3), leg[2] if tier != 3 else Color("3ff0ff"))
	# ön kenar
	var er := Rect2(t.position.x, front_y, t.size.x, 12)
	ci.draw_rect(er.grow(1), OUT)
	ci.draw_rect(er, edge[1])
	ci.draw_rect(Rect2(er.position, Vector2(er.size.x, 2)), edge[2])
	ci.draw_rect(Rect2(er.position + Vector2(0, er.size.y - 3), Vector2(er.size.x, 3)), edge[0])
	# üst yüzey
	ci.draw_rect(t.grow(1), OUT)
	ci.draw_rect(t, top[1])
	match tier:
		0:
			var y := t.position.y + 22.0
			while y < t.end.y - 4:
				ci.draw_rect(Rect2(t.position.x, int(y), t.size.x, 1), top[0])
				ci.draw_rect(Rect2(t.position.x, int(y) + 1, t.size.x, 1), top[2])
				y += 22.0
			for g in grain:
				ci.draw_rect(g[0], g[1])
		1, 2:
			for g in grain:
				ci.draw_rect(g[0], g[1])
			var inl: Array = th["inlay"]
			var ir := t.grow(-10)
			ci.draw_rect(ir.grow(1), OUT)
			ci.draw_rect(ir, inl[1])
			ci.draw_rect(Rect2(ir.position, Vector2(ir.size.x, 2)), inl[0])
			if tier == 1:
				# keçe dikişi
				var sx := ir.position.x + 3
				while sx < ir.end.x - 3:
					ci.draw_rect(Rect2(sx, ir.position.y + 4, 2, 1), inl[2])
					ci.draw_rect(Rect2(sx, ir.end.y - 5, 2, 1), inl[2])
					sx += 5
			else:
				# kadife desen + altın şerit + köşe başlıkları
				var yy := ir.position.y + 8
				var row := 0
				while yy < ir.end.y - 4:
					var xx := ir.position.x + (8.0 if row % 2 == 0 else 16.0)
					while xx < ir.end.x - 4:
						_diamond(ci, Vector2(xx, yy), 2.0, inl[2])
						xx += 16.0
					yy += 10.0
					row += 1
				ci.draw_rect(Rect2(ir.position.x, ir.position.y, ir.size.x, ir.size.y), Color("f2c434"), false, 1.0)
				for c in [t.position, Vector2(t.end.x - 12, t.position.y), Vector2(t.position.x, t.end.y - 12), t.end - Vector2(12, 12)]:
					ci.draw_rect(Rect2(c, Vector2(12, 12)), Color("c08a12"))
					ci.draw_rect(Rect2(c + Vector2(2, 2), Vector2(8, 8)), Color("f2c434"))
					ci.draw_rect(Rect2(c + Vector2(4, 4), Vector2(4, 4)), Color("d0203c"))
				# ön kenardan sarkan altın saçak
				var fx := t.position.x
				while fx < t.end.x:
					ci.draw_rect(Rect2(fx, front_y + 12, 2, 4 + int(fx) % 3), Color("f2c434"))
					fx += 4
		3:
			# siyah lake: parlak çizgiler, iç neon çerçeve ve nabız atan neon kenar
			var ir3 := t.grow(-8)
			var pa := 0.7 + 0.3 * sin(time * 3.1 + 1.0)
			ci.draw_rect(ir3.grow(2), Color(1.0, 0.31, 0.85, 0.14 * pa), false, 4.0)
			ci.draw_rect(ir3, Color(1.0, 0.31, 0.85, pa), false, 1.0)
			for i in range(10):
				var gp := t.position + Vector2(_h(i, 1, 12) * t.size.x, _h(i, 2, 12) * t.size.y)
				if sin(time * 2.0 + i * 1.3) > 0.7:
					ci.draw_rect(Rect2(gp.floor(), Vector2(2, 1)), Color(0.6, 0.95, 1.0, 0.8))
			for k in range(6):
				var gx := t.position.x + 20 + k * (t.size.x - 40) / 5.0
				ci.draw_line(Vector2(gx, t.position.y + 4), Vector2(gx - 18, t.end.y - 4), Color(1, 1, 1, 0.04), 3.0)
			var pulse := 0.6 + 0.4 * sin(time * 2.4)
			ci.draw_rect(Rect2(t.position.x, t.position.y, t.size.x, 2), Color(0.25, 0.94, 1.0, pulse))
			ci.draw_rect(Rect2(t.position.x, front_y + 4, t.size.x, 2), Color(0.25, 0.94, 1.0, pulse))
			ci.draw_rect(Rect2(t.position.x, front_y + 2, t.size.x, 6), Color(0.25, 0.94, 1.0, 0.12 * pulse))
		_:
			# mermer damarları + altın kakma
			for i in range(14):
				var p0 := t.position + Vector2(_h(i, 1, 6) * t.size.x, _h(i, 2, 6) * t.size.y)
				var p1 := p0 + Vector2(20 + _h(i, 3, 6) * 40, 6 + _h(i, 4, 6) * 14)
				var p2 := p1 + Vector2(10 + _h(i, 5, 6) * 30, -4 + _h(i, 6, 6) * 10)
				ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color("bdb6a6"), 1.0)
			var ir := t.grow(-6)
			ci.draw_rect(ir, Color("e0b030"), false, 2.0)
			ci.draw_rect(ir.grow(-3), Color("f2c434"), false, 1.0)
			for c in [ir.position, Vector2(ir.end.x, ir.position.y), Vector2(ir.position.x, ir.end.y), ir.end]:
				_diamond(ci, c, 4.0, OUT)
				_diamond(ci, c, 3.0, Color("d0203c"))
				ci.draw_rect(Rect2(c - Vector2(1, 2), Vector2(1, 1)), Color("ffb0b8"))
	# kenar pahı
	ci.draw_rect(Rect2(t.position, Vector2(t.size.x, 3)), top[3])
	ci.draw_rect(Rect2(t.position, Vector2(3, t.size.y)), top[2])
	ci.draw_rect(Rect2(Vector2(t.end.x - 3, t.position.y), Vector2(3, t.size.y)), top[0])
	ci.draw_rect(Rect2(Vector2(t.position.x, t.end.y - 3), Vector2(t.size.x, 3)), top[0])
	if tier == 0:
		for c in [t.position + Vector2(6, 6), Vector2(t.end.x - 8, t.position.y + 6), Vector2(t.position.x + 6, t.end.y - 8), t.end - Vector2(8, 8)]:
			ci.draw_rect(Rect2(c, Vector2(2, 2)), Color("e3b341"))
			ci.draw_rect(Rect2(c + Vector2(1, 1), Vector2(1, 1)), Color("fff1a8"))


## Tavandan masaya düşen ışık (bantlı halkalar). Gece Salonu: pembe + turkuaz iki havuz.
static func lamp(ci: CanvasItem, t: Rect2, tier: int, time: float) -> void:
	var th := Themes.table(tier)
	var col: Color = th["light"]
	var flick := 1.0 + 0.04 * sin(time * 7.0) * sin(time * 3.1)
	if tier == 3:
		for side in [-1.0, 1.0]:
			var c := Vector2(t.get_center().x + side * t.size.x * 0.28, t.position.y + t.size.y * 0.45)
			var cc := Color(1.0, 0.35, 0.85, 0.03) if side < 0 else Color(0.3, 0.9, 1.0, 0.03)
			for i in range(4):
				_ellipse(ci, c, t.size.x * (0.32 - i * 0.06) * flick, t.size.y * (0.5 - i * 0.09), cc)
		return
	var c2 := Vector2(t.get_center().x, t.position.y + t.size.y * 0.35)
	for i in range(4):
		_ellipse(ci, c2, t.size.x * (0.62 - i * 0.12) * flick, t.size.y * (0.55 - i * 0.1), col)


# =================================================================== masa süsleri

## left/right: süs için boş alanlar (takvim ile defter, zarf ile kavanoz arası)
static func decor(ci: CanvasItem, left: Rect2, right: Rect2, tier: int, time: float, ball_cols: Array) -> void:
	# sağ boşluk telefonun altında kalır; sığmıyorsa sağ süs çizilmez
	if right.size.y < 44:
		right = Rect2(Vector2(-9999, -9999), Vector2.ZERO)
	match tier:
		0:
			_paper_ball(ci, left.get_center() + Vector2(-6, 6))
			for k in range(3):
				var c: Color = ball_cols[k % ball_cols.size()]
				var p := right.get_center() + Vector2(-10 + k * 9, 8 - (k % 2) * 5)
				ci.draw_circle(p + Vector2(1, 2), 4.0, Color(0, 0, 0, 0.3))
				ci.draw_circle(p, 4.0, c.darkened(0.45))
				ci.draw_circle(p - Vector2(0.5, 0.5), 3.0, c)
				ci.draw_rect(Rect2(p - Vector2(2, 2), Vector2(1, 1)), Color(1, 1, 1, 0.8))
		1:
			_plant(ci, left.get_center() + Vector2(0, 16))
			_radio(ci, right.get_center() + Vector2(0, 14), time)
		2:
			_candelabra(ci, left.get_center() + Vector2(0, 20), time)
			_roses(ci, right.get_center() + Vector2(0, 20))
		3:
			_lava_lamp(ci, left.get_center() + Vector2(0, 22), time)
			_neon_dice(ci, right.get_center() + Vector2(0, 10), time)
		_:
			_trophy(ci, left.get_center() + Vector2(0, 22), time)
			_coins(ci, right.get_center() + Vector2(0, 16), time)


static func _paper_ball(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c + Vector2(2, 3), 8.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, 8.0, OUT)
	ci.draw_circle(c, 7.0, Color("e8e2d0"))
	for k in range(5):
		var a := k * 1.3
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 6.0, Color("b8b0a0"), 1.0)
	ci.draw_rect(Rect2(c - Vector2(3, 4), Vector2(2, 1)), Color.WHITE)


static func _plant(ci: CanvasItem, base: Vector2) -> void:
	ci.draw_rect(Rect2(base + Vector2(-12, -2), Vector2(24, 6)), Color(0, 0, 0, 0.3))
	var pot := Rect2(base + Vector2(-9, -14), Vector2(18, 14))
	ci.draw_rect(pot.grow(1), OUT)
	ci.draw_rect(pot, Color("c4562a"))
	ci.draw_rect(Rect2(pot.position, Vector2(pot.size.x, 3)), Color("e07a42"))
	ci.draw_rect(Rect2(pot.position + Vector2(-1, 0), Vector2(pot.size.x + 2, 2)), Color("8a3418"))
	# kaktüs
	var g := [Color("1a5a2a"), Color("2a8a3e"), Color("4cbf5a")]
	ci.draw_rect(Rect2(base + Vector2(-4, -36), Vector2(8, 22)), OUT)
	ci.draw_rect(Rect2(base + Vector2(-3, -35), Vector2(6, 21)), g[1])
	ci.draw_rect(Rect2(base + Vector2(-3, -35), Vector2(2, 21)), g[2])
	ci.draw_rect(Rect2(base + Vector2(3, -28), Vector2(6, 4)), g[1])
	ci.draw_rect(Rect2(base + Vector2(7, -33), Vector2(3, 8)), g[1])
	ci.draw_rect(Rect2(base + Vector2(-9, -24), Vector2(6, 4)), g[1])
	ci.draw_rect(Rect2(base + Vector2(-10, -29), Vector2(3, 8)), g[1])
	ci.draw_rect(Rect2(base + Vector2(-1, -39), Vector2(3, 3)), Color("ff5fa8"))


static func _radio(ci: CanvasItem, base: Vector2, tm: float) -> void:
	var r := Rect2(base + Vector2(-16, -20), Vector2(32, 20))
	ci.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(r.grow(1), OUT)
	ci.draw_rect(r, Color("7a4a26"))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("a86a3a"))
	ci.draw_rect(Rect2(r.position + Vector2(3, 4), Vector2(14, 12)), Color("d8c89c"))
	for k in range(3):
		ci.draw_rect(Rect2(r.position + Vector2(4, 6 + k * 3), Vector2(12, 1)), Color("8a7a5a"))
	ci.draw_circle(r.position + Vector2(24, 9), 3.0, Color("ffd23f"))
	ci.draw_circle(r.position + Vector2(24, 15), 2.0, Color("3a2a1e"))
	ci.draw_line(r.position + Vector2(26, 0), r.position + Vector2(32, -10), Color("c8c8d0"), 1.0)
	# notalar
	for k in range(2):
		var u := fposmod(tm * 0.5 + k * 0.5, 1.0)
		var p := r.position + Vector2(10 + k * 8 + sin(tm * 2.0 + k) * 3.0, -4 - u * 18)
		var c := Color(1, 1, 1, 1.0 - u)
		ci.draw_rect(Rect2(p.floor(), Vector2(2, 2)), c)
		ci.draw_rect(Rect2((p + Vector2(1, -5)).floor(), Vector2(1, 5)), c)


static func _candelabra(ci: CanvasItem, base: Vector2, tm: float) -> void:
	ci.draw_rect(Rect2(base + Vector2(-10, -2), Vector2(20, 4)), Color(0, 0, 0, 0.3))
	var gold := [Color("8a5a0c"), Color("c08a14"), Color("f2c434")]
	ci.draw_rect(Rect2(base + Vector2(-7, -4), Vector2(14, 4)), gold[1])
	ci.draw_rect(Rect2(base + Vector2(-1, -22), Vector2(2, 18)), gold[1])
	ci.draw_rect(Rect2(base + Vector2(-12, -22), Vector2(24, 2)), gold[1])
	for x in [-11.0, 0.0, 11.0]:
		var cx: float = base.x + x
		var cy: float = base.y - (30.0 if x == 0.0 else 26.0)
		ci.draw_rect(Rect2(cx - 2, cy, 4, 8), Color("fff4e0"))
		var fl := 1.0 + 0.4 * sin(tm * 12.0 + x)
		ci.draw_circle(Vector2(cx, cy - 4), 10.0, Color(1.0, 0.7, 0.3, 0.07))
		ci.draw_rect(Rect2(cx - 1, cy - 4 - fl, 2, 3 + fl), Color("ffcf3d"))


static func _roses(ci: CanvasItem, base: Vector2) -> void:
	ci.draw_rect(Rect2(base + Vector2(-9, -2), Vector2(18, 4)), Color(0, 0, 0, 0.3))
	var vase := PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0), base + Vector2(8, -10), base + Vector2(4, -18), base + Vector2(-4, -18), base + Vector2(-8, -10)])
	ci.draw_colored_polygon(vase, Color("3a8ad6"))
	ci.draw_rect(Rect2(base + Vector2(-5, -16), Vector2(2, 12)), Color("8ac8ff"))
	for s in [Vector2(-6, -30), Vector2(0, -34), Vector2(6, -29), Vector2(-2, -26)]:
		ci.draw_line(base + Vector2(0, -18), base + s, Color("2a7a3a"), 1.0)
		ci.draw_circle(base + s, 4.0, Color("8a0c22"))
		ci.draw_circle(base + s, 3.0, Color("e0284a"))
		ci.draw_rect(Rect2(base + s - Vector2(1, 1), Vector2(1, 1)), Color("ff8aa0"))


static func _lava_lamp(ci: CanvasItem, base: Vector2, tm: float) -> void:
	ci.draw_circle(base + Vector2(0, -14), 22.0, Color(1.0, 0.3, 0.85, 0.08))
	var glass := PackedVector2Array([base + Vector2(-5, -6), base + Vector2(5, -6), base + Vector2(8, -30), base + Vector2(4, -38), base + Vector2(-4, -38), base + Vector2(-8, -30)])
	ci.draw_colored_polygon(glass, Color("3a0c5a"))
	for k in range(3):
		var u := fposmod(tm * (0.12 + k * 0.05) + k * 0.33, 1.0)
		var y := -10.0 - absf(sin(u * PI)) * 24.0
		ci.draw_circle(base + Vector2(sin(u * 6.0 + k) * 2.0, y), 3.0 + k, Color("ff4fd8"))
	ci.draw_rect(Rect2(base + Vector2(-7, -6), Vector2(14, 6)), Color("9aacc8"))
	ci.draw_rect(Rect2(base + Vector2(-4, -42), Vector2(8, 4)), Color("9aacc8"))


static func _neon_dice(ci: CanvasItem, base: Vector2, tm: float) -> void:
	var a := 0.7 + 0.3 * sin(tm * 3.0)
	for k in range(2):
		var r := Rect2(base + Vector2(-16 + k * 18, -12 - k * 4), Vector2(14, 14))
		var c := Color(0.25, 0.94, 1.0, a) if k == 0 else Color(1.0, 0.31, 0.85, a)
		ci.draw_rect(r.grow(2), Color(c, 0.15))
		ci.draw_rect(r, Color("0a0a20"))
		ci.draw_rect(r, c, false, 1.0)
		for p in ([Vector2(4, 4), Vector2(10, 10)] if k == 0 else [Vector2(3, 3), Vector2(7, 7), Vector2(11, 11)]):
			ci.draw_rect(Rect2(r.position + p - Vector2(1, 1), Vector2(2, 2)), c)


static func _trophy(ci: CanvasItem, base: Vector2, tm: float) -> void:
	var g := [Color("8a5a0c"), Color("c08a14"), Color("f2c434"), Color("fff0a0")]
	ci.draw_rect(Rect2(base + Vector2(-11, -2), Vector2(22, 4)), Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(base + Vector2(-9, -6), Vector2(18, 6)), Color("3a1e0e"))
	ci.draw_rect(Rect2(base + Vector2(-2, -14), Vector2(4, 8)), g[1])
	var cup := PackedVector2Array([base + Vector2(-10, -34), base + Vector2(10, -34), base + Vector2(7, -20), base + Vector2(2, -15), base + Vector2(-2, -15), base + Vector2(-7, -20)])
	ci.draw_colored_polygon(cup, g[2])
	ci.draw_rect(Rect2(base + Vector2(-7, -32), Vector2(3, 10)), g[3])
	ci.draw_arc(base + Vector2(-11, -27), 4.0, PI * 0.5, PI * 1.5, 6, g[1], 2.0)
	ci.draw_arc(base + Vector2(11, -27), 4.0, -PI * 0.5, PI * 0.5, 6, g[1], 2.0)
	_star(ci, base + Vector2(0, -26), 4.0, Color.WHITE)
	var k := fposmod(tm * 0.7, 1.0)
	_sparkle(ci, base + Vector2(8, -36), 1 if k < 0.15 else (2 if k < 0.3 else 0), Color("fff0a0"))


static func _coins(ci: CanvasItem, base: Vector2, tm: float) -> void:
	ci.draw_rect(Rect2(base + Vector2(-16, -1), Vector2(32, 4)), Color(0, 0, 0, 0.3))
	for st in [[-9.0, 6], [3.0, 4], [12.0, 2]]:
		for i in range(int(st[1])):
			var c := base + Vector2(float(st[0]), -2 - i * 3)
			_ellipse(ci, c, 6.0, 2.5, Color("6a4006"))
			_ellipse(ci, c - Vector2(0, 1), 6.0, 2.5, Color("f2c434"))
			ci.draw_rect(Rect2(c - Vector2(3, 2), Vector2(2, 1)), Color("fff0a0"))
	_diamond(ci, base + Vector2(-4, -26), 5.0, OUT)
	_diamond(ci, base + Vector2(-4, -26), 4.0, Color("d0203c"))
	ci.draw_rect(Rect2(base + Vector2(-6, -28), Vector2(2, 2)), Color("ffb0b8"))
	var k := fposmod(tm * 0.8 + 0.4, 1.0)
	_sparkle(ci, base + Vector2(10, -16), 1 if k < 0.15 else (2 if k < 0.3 else 0), Color("fff0a0"))
