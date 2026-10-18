extends RefCounted
## Top ve özel çivi türleri için yordamsal, animasyonlu piksel sprite'lar (görsel dosyası yok).
## Her tür FRAMES karelik kesintisiz bir döngüdür. Kareler Image olarak üretilir; autoload'lara
## dokunmadığı için iş parçacığında güvenle çalışır. Işık sol üstten gelir; gölgeleme 4-5 tonlu
## rampa + 2x2 Bayer titreşimiyle yapılır, gövdenin dışına 1 piksel kontur eklenir.
##
## Tasarımlar (özet):
##  demir: dönen dikiş çizgili çelik bilye      cam: içinde dönen turuncu kedi gözü şeridi, yarı saydam
##  kil: mat, parmak izi çukurları, dökülen toz  kauçuk: yuvarlanan sarı/turkuaz şeritler
##  bakır: dönen pas (patina) lekeleri, parıltı  mıknatıs: K/G yarıları, dışa yayılan alan dalgaları
##  volkan: lav çatlaklı bazalt, etrafında alev  altın: süzülen parlama ve yıldızcıklar
##  ikiz: dönen ikili desen + yörüngede iki uydu  kuyruklu: buz çekirdek, ışıltılı kuyruk ve hale
##  anka: tüy desenli gövde, çırpan ateş kanatlar kara inci: yanardöner parlaklık, mor aura

const FRAMES := 12
const FPS := 12.0
const OUTLINE := Color("140b2e")
const CLEAR := Color(0, 0, 0, 0)
const LDIR := Vector3(-0.47, -0.59, 0.66)
const HDIR := Vector3(-0.258, -0.324, 0.910)
const BAYER := [0.0, 0.5, 0.75, 0.25]

## Gövde yarıçapları (piksel). Küçük: tahta (yarım çözünürlük, 1:1). Büyük: arayüz.
const BALL_SMALL := 7.0
const BALL_BIG := 12.0
const PEG_SMALL := 6.0
const PEG_BIG := 11.0
const PLAIN_PEG := 4.0

const RAMPS := {
	"demir": [Color("1f2533"), Color("3a4459"), Color("5f6b85"), Color("8f9cb6"), Color("c8d2e4")],
	"cam": [Color("0d3352"), Color("1f6f9e"), Color("49aee0"), Color("8fe0ff"), Color("d8fbff")],
	"cam_rib": [Color("7a2410"), Color("c4501c"), Color("ff8a3d"), Color("ffc27a")],
	"kil": [Color("4d1f0f"), Color("7d3517"), Color("a9502a"), Color("cc7444"), Color("e39a66")],
	"kaucuk": [Color("6b0d2a"), Color("a8173f"), Color("e02c55"), Color("ff5d7e"), Color("ffa3b8")],
	"kaucuk_y": [Color("8a5a00"), Color("d19a00"), Color("ffd21f"), Color("fff08a")],
	"kaucuk_t": [Color("0b4a5c"), Color("138099"), Color("20b8d4"), Color("7ae8f5")],
	"bakir": [Color("3d180a"), Color("7a3816"), Color("b5612a"), Color("e08f50"), Color("ffc890")],
	"patina": [Color("1f5c4a"), Color("2f8a6c"), Color("4fb592"), Color("8fe0c0")],
	"mik_r": [Color("5c0a14"), Color("9e1525"), Color("dd2a3a"), Color("ff6670"), Color("ffb3b8")],
	"mik_b": [Color("0e1a5c"), Color("1d36a8"), Color("3f63ec"), Color("7d9bff"), Color("c2d0ff")],
	"basalt": [Color("0e0606"), Color("1d0d0b"), Color("301612"), Color("47221a"), Color("5e3226")],
	"lava": [Color("8a1a00"), Color("d64000"), Color("ff7a00"), Color("ffc23d"), Color("fff3a0")],
	"altin": [Color("5a3600"), Color("9c6400"), Color("d99a14"), Color("ffcf3d"), Color("fff3b0")],
	"ikiz_a": [Color("06403a"), Color("0b7a6a"), Color("16b89c"), Color("4fe8cc"), Color("b5fff0")],
	"ikiz_b": [Color("4a0b40"), Color("861a76"), Color("c42ead"), Color("f05fd8"), Color("ffb0f0")],
	"kuyruklu": [Color("21155c"), Color("3d2aa0"), Color("6a52e0"), Color("a58bff"), Color("e6dcff")],
	"anka": [Color("6b1500"), Color("b33a00"), Color("ff6a00"), Color("ffa52e"), Color("ffe27a")],
	"kanat": [Color("8a0f3a"), Color("e0285e"), Color("ff7a1f"), Color("ffc93d"), Color("fff3a0")],
	"inci": [Color("07040d"), Color("140c24"), Color("23153c"), Color("38235e"), Color("5a3f8a")],
	"gumus": [Color("2c3346"), Color("56607a"), Color("8e9ab4"), Color("cfd8ea"), Color("ffffff")],
	"elmas": [Color("1a5f80"), Color("3fb0d6"), Color("8ff0ff"), Color("d8fdff"), Color("ffffff")],
	"yildiz": [Color("7a1452"), Color("c42a8a"), Color("ff5fc8"), Color("ffa8e6"), Color("fff0fa")],
	"yay": [Color("0b5a2c"), Color("169c4c"), Color("2fd673"), Color("8bffb8")],
	"huni": [Color("2a0f52"), Color("4f1f8f"), Color("7f3fd0"), Color("b07bff"), Color("dcc2ff")],
	"kalkan": [Color("12306b"), Color("1f55b0"), Color("3f86f0"), Color("8fc0ff")],
	"ayna": [Color("3a8fa8"), Color("6fd0e6"), Color("b5f3ff"), Color("e8fdff")],
	"bilet": [Color("8a2a00"), Color("d4561c"), Color("ff7a2e"), Color("ffb347"), Color("ffe0a0")],
	"brass": [Color("5a3a0c"), Color("8f5f17"), Color("c9902a"), Color("f0c04a"), Color("fff0a0")],
	"pin": [Color("3a2c18"), Color("6e5832"), Color("a88a52"), Color("d8c08a"), Color("f6ead0")],
	"pin_gold": [Color("5a3600"), Color("9c6400"), Color("d99a14"), Color("ffcf3d"), Color("fff3b0")],
	"pin_chrome": [Color("1a2440"), Color("3e5078"), Color("7a94c0"), Color("bcd6f4"), Color("f0fbff")],
	"pin_pearl": [Color("8a7a94"), Color("bcaec4"), Color("e2d8e8"), Color("f6eef8"), Color("ffffff")],
}

const KIL_DENTS := [Vector3(0.3, 0.2, 0.93), Vector3(-0.42, 0.35, 0.84), Vector3(0.12, -0.5, 0.86), Vector3(0.58, -0.22, 0.78)]
const BAKIR_SPOTS := [Vector3(0.3, 0.1, 0.95), Vector3(-0.5, 0.4, 0.77), Vector3(0.6, -0.5, 0.62),
	Vector3(-0.2, -0.6, 0.77), Vector3(-0.8, -0.1, -0.59), Vector3(0.7, 0.4, -0.59), Vector3(0.0, 0.8, -0.6)]
const COMET_CRATERS := [Vector3(0.35, 0.25, 0.9), Vector3(-0.3, 0.45, 0.84), Vector3(0.5, -0.35, 0.79)]
const VOLKAN_CELLS := [Vector3(0.0, 0.0, 1.0), Vector3(0.7, 0.1, 0.7), Vector3(-0.7, 0.2, 0.68),
	Vector3(0.1, 0.75, 0.65), Vector3(-0.15, -0.76, 0.63), Vector3(0.58, -0.6, 0.55),
	Vector3(-0.6, -0.5, 0.62), Vector3(0.55, 0.63, 0.55), Vector3(-0.58, 0.65, 0.49)]


## Çizilmiş gövde görselleri (assets/art/balls|pegs/<id>.png, tools/slice_sheet.py ile üretilir). Ana iş parçacığında
## (PixelArt._ready) bir kez doldurulur; iş parçacıkları yalnızca okur. Varsa gövde bu görselden gelir, hareketli
## efektler (alev, dalga, parıltı...) yordamsal olarak üstüne/arkasına eklenir.
static var bodies: Dictionary = {}   # "ball:id" / "peg:id" -> Image

## Gövde görseli zaten içerdiği için yordamsal olarak tekrar çizilmeyecek efektler
const BODY_HAS_FX := {"ball:ikiz": "orbit", "ball:anka": "wings", "ball:kuyruklu": "tail"}


## Gövde görselini hedef çapa (2r) uygun tam boyuta getirir: büyükse alan ortalamasıyla küçültür, kenarı
## keskinleştirir ve koyu konturu yeniden çizer.
static func _fit_body(src: Image, r: float, ref_size: float) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var k := (2.0 * r) / ref_size
	if absf(k - 1.0) > 0.05:
		var nw := maxi(4, int(round(img.get_width() * k)))
		var nh := maxi(4, int(round(img.get_height() * k)))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		for y in range(nh):
			for x in range(nw):
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					img.set_pixel(x, y, CLEAR)
				else:
					c.a = 1.0
					img.set_pixel(x, y, c)
		# küçültmede yumuşayan dış kenarı koyulaştır (boyutu büyütmeden kontur)
		var src2 := img.duplicate() as Image
		for y in range(nh):
			for x in range(nw):
				var c2 := src2.get_pixel(x, y)
				if c2.a < 0.5:
					continue
				var edge := x == 0 or y == 0 or x == nw - 1 or y == nh - 1
				if not edge:
					edge = src2.get_pixel(x - 1, y).a < 0.5 or src2.get_pixel(x + 1, y).a < 0.5 \
						or src2.get_pixel(x, y - 1).a < 0.5 or src2.get_pixel(x, y + 1).a < 0.5
				if edge:
					img.set_pixel(x, y, c2.darkened(0.6))
	return img


## Gövdeye çapraz bir parlama şeridi (döngünün ilk yarısında bir kez geçer)
static func _sweep(body: Image, t: float, strength: float) -> void:
	if t >= 0.5:
		return
	var w := body.get_width()
	var h := body.get_height()
	var pos := -0.3 + (t / 0.5) * 1.6
	for y in range(h):
		for x in range(w):
			var c := body.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var u := (float(x) / w + float(y) / h) * 0.5
			var d := absf(u - pos)
			if d < 0.06:
				body.set_pixel(x, y, c.lightened(strength * (1.0 - d / 0.06)))


## kind: "ball:<id>" veya "peg:<id>"; big: arayüz boyu. Döner: FRAMES adet Image.
static func make(kind: String, big: bool) -> Array:
	if kind.begins_with("ball:"):
		return ball(kind.substr(5), BALL_BIG if big else BALL_SMALL)
	if kind.begins_with("peg:"):
		return peg(kind.substr(4), PEG_BIG if big else PEG_SMALL)
	return []


static func canvas_size(r: float, margin: float) -> int:
	return int(2.0 * ceilf(r + margin))


# =================================================================== ortak yardımcılar

static func _lum(nx: float, ny: float, nz: float) -> float:
	var d := nx * LDIR.x + ny * LDIR.y + nz * LDIR.z
	return clampf((d + 0.45) / 1.45, 0.0, 1.0)


static func _spec(nx: float, ny: float, nz: float) -> float:
	return pow(maxf(0.0, nx * HDIR.x + ny * HDIR.y + nz * HDIR.z), 28.0)


static func _ramp(ramp: Array, v: float, x: int, y: int) -> Color:
	var n := ramp.size()
	var b: float = BAYER[(x & 1) + 2 * (y & 1)]
	var i := clampi(int(floorf(v * n + (b - 0.375) * 0.85)), 0, n - 1)
	return ramp[i]


static func _with_spec(col: Color, sp: float) -> Color:
	if sp > 0.6:
		return Color(1, 1, 1, 1)
	if sp > 0.3:
		var c := col.lightened(0.5)
		c.a = maxf(col.a, 0.9)
		return c
	return col


static func _near(x: float, y: float, z: float, pts: Array, cos_min: float) -> bool:
	for p in pts:
		var v: Vector3 = p
		if x * v.x + y * v.y + z * v.z > cos_min:
			return true
	return false


static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if col.a <= 0.01 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if col.a >= 0.999:
		img.set_pixel(x, y, col)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _outline(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.05:
				continue
			if (x > 0 and src.get_pixel(x - 1, y).a > 0.3) or (x < w - 1 and src.get_pixel(x + 1, y).a > 0.3) \
					or (y > 0 and src.get_pixel(x, y - 1).a > 0.3) or (y < h - 1 and src.get_pixel(x, y + 1).a > 0.3):
				img.set_pixel(x, y, col)


## Dört kollu parıltı; boy 0 ise çizilmez.
static func _sparkle(img: Image, p: Vector2, sz: int, col: Color) -> void:
	if sz <= 0:
		return
	var x := int(p.x)
	var y := int(p.y)
	_put(img, x, y, Color.WHITE)
	for k in range(1, sz + 1):
		var c := col if k == sz else Color.WHITE.lerp(col, 0.4)
		_put(img, x + k, y, c)
		_put(img, x - k, y, c)
		_put(img, x, y + k, c)
		_put(img, x, y - k, c)


## Döngü içinde kısa yanıp sönen parıltının boyu (0, 1, 2, 1, 0 ...).
static func _twinkle(t: float, phase: float, scale: int) -> int:
	var k := fposmod(t + phase, 1.0)
	if k < 0.09:
		return scale
	if k < 0.18:
		return scale * 2
	if k < 0.27:
		return scale
	return 0


static func _ring(img: Image, c: Vector2, rad: float, col: Color, dashed: int = 0) -> void:
	var s := img.get_width()
	for y in range(s):
		for x in range(s):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d := sqrt(dx * dx + dy * dy)
			if absf(d - rad) >= 0.55:
				continue
			if dashed > 0 and int(floorf((atan2(dy, dx) + PI) / TAU * dashed * 2.0)) % 2 == 1:
				continue
			_put(img, x, y, col)


static func _hash(ix: int, iy: int, sd: int) -> float:
	var h := (ix * 374761393 + iy * 668265263 + sd * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h % 1024) / 1023.0


## Dikeyde py hücrede tekrar eden değer gürültüsü (alevlerin kesintisiz döngüsü için).
static func _vnoise(x: float, y: float, cell: float, py: int, sd: int) -> float:
	var gx := x / cell
	var gy := y / cell
	var ix := int(floorf(gx))
	var iy := int(floorf(gy))
	var fx := gx - ix
	var fy := gy - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(ix, posmod(iy, py), sd)
	var b := _hash(ix + 1, posmod(iy, py), sd)
	var c := _hash(ix, posmod(iy + 1, py), sd)
	var d := _hash(ix + 1, posmod(iy + 1, py), sd)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Küçük gölgeli küre (ikiz uyduları vb.)
static func _mini_ball(img: Image, c: Vector2, rad: float, ramp: Array) -> void:
	var s := img.get_width()
	var tmp := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(int(c.y - rad - 1), int(c.y + rad + 2)):
		for x in range(int(c.x - rad - 1), int(c.x + rad + 2)):
			if x < 0 or y < 0 or x >= s or y >= s:
				continue
			var nx := (x + 0.5 - c.x) / rad
			var ny := (y + 0.5 - c.y) / rad
			if nx * nx + ny * ny > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			tmp.set_pixel(x, y, _with_spec(_ramp(ramp, _lum(nx, ny, nz), x, y), _spec(nx, ny, nz)))
	_outline(tmp, OUTLINE)
	img.blend_rect(tmp, Rect2i(0, 0, s, s), Vector2i.ZERO)


## Gövdenin çevresinde yükselen alev (arka katman) ve gövdenin üst kenarını yalayan diller (ön katman).
static func _flames(back: Image, front: Image, c: Vector2, r: float, m: float, t: float, pal: Array, sd: int) -> void:
	var s := back.get_width()
	var cell := maxf(1.6, r * 0.42)
	var py := 4
	var scroll := t * cell * py
	for y in range(s):
		for x in range(s):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var dist := sqrt(dx * dx + dy * dy)
			if dist < r - 2.0 or dist > r + m:
				continue
			var up := -dy / maxf(dist, 0.001)
			var reach := m * (0.22 + 0.85 * maxf(0.0, up * 0.7 + 0.3))
			var heat := 1.0 - (dist - r + 1.0) / reach
			heat *= 0.45 + 0.85 * _vnoise(x, y + scroll, cell, py, sd)
			if dist < r and up < 0.25:
				continue
			if heat < 0.18:
				continue
			var b: float = BAYER[(x & 1) + 2 * (y & 1)]
			var idx := clampi(int(floorf(heat * pal.size() * 1.15 + (b - 0.375) * 0.8)), 0, pal.size() - 1)
			var col: Color = pal[idx]
			if dist < r:
				_put(front, x, y, Color(col, 0.9))
			else:
				_put(back, x, y, col)


static func _embers(img: Image, c: Vector2, r: float, m: float, t: float, n: int, hot: Color, cool: Color) -> void:
	var big := r > 8.0
	for k in range(n):
		var u := fposmod(t + float(k) / n, 1.0)
		var px := c.x + sin(k * 2.3) * r * 0.55 + sin(u * TAU + k) * (1.5 if big else 1.0)
		var py := c.y - r * 0.6 - u * (m + r * 0.6)
		var col := hot.lerp(cool, u)
		col.a = 1.0 - u * 0.8
		_put(img, int(px), int(py), col)
		if big:
			_put(img, int(px) + 1, int(py), col)
			_put(img, int(px), int(py) + 1, col)


# =================================================================== toplar

## Efekt payı (gövde yarıçapına oran): alevli/kuyruklu toplar daha geniş tuval ister.
const BALL_MARGIN := {"volkan": 1.5, "anka": 1.25, "kuyruklu": 1.5, "miknatis": 1.05, "kara_inci": 1.0, "ikiz": 1.0}


static func ball(bid: String, r: float) -> Array:
	var m := ceilf(r * float(BALL_MARGIN.get(bid, 0.6)))
	var s := canvas_size(r, m)
	var out: Array = []
	for f in range(FRAMES):
		out.append(_ball_frame(bid, r, m, s, float(f) / FRAMES))
	return out


static func _ball_frame(bid: String, r: float, m: float, s: int, t: float) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var body := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var front := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	var art: Image = bodies.get("ball:" + bid)
	if art != null:
		var fit := _fit_body(art, r, 24.0)
		_sweep(fit, t, 0.35 if bid in ["demir", "altin", "bakir", "miknatis", "kara_inci", "cam"] else 0.18)
		_ball_fx(bid, img, front, c, r, m, t)
		img.blend_rect(fit, Rect2i(Vector2i.ZERO, fit.get_size()), Vector2i((c - fit.get_size() / 2.0).floor()))
		img.blend_rect(front, Rect2i(0, 0, s, s), Vector2i.ZERO)
		return img
	var r2 := r * r
	for y in range(s):
		for x in range(s):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			if dx * dx + dy * dy > r2:
				continue
			var nx := dx / r
			var ny := dy / r
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			body.set_pixel(x, y, _ball_px(bid, nx, ny, nz, t, x, y, r))
	var ramp: Array = RAMPS.get(_ramp_of(bid), RAMPS["demir"])
	_outline(body, (ramp[0] as Color).darkened(0.55))
	_ball_fx(bid, img, front, c, r, m, t)
	img.blend_rect(body, Rect2i(0, 0, s, s), Vector2i.ZERO)
	img.blend_rect(front, Rect2i(0, 0, s, s), Vector2i.ZERO)
	return img


static func _ramp_of(bid: String) -> String:
	match bid:
		"miknatis":
			return "mik_b"
		"volkan":
			return "basalt"
		"ikiz":
			return "ikiz_b"
		"kara_inci":
			return "inci"
	return bid


static func _ball_px(bid: String, nx: float, ny: float, nz: float, t: float, x: int, y: int, r: float) -> Color:
	var v := _lum(nx, ny, nz)
	var sp := _spec(nx, ny, nz)
	var col := Color()
	match bid:
		"demir":
			var a := t * PI
			var ax := Vector3(cos(a), 0.35, sin(a)).normalized()
			var seam := absf(nx * ax.x + ny * ax.y + nz * ax.z) < 0.09
			col = _ramp(RAMPS["demir"], v - (0.25 if seam else 0.0), x, y)
		"cam":
			var d := sqrt(nx * nx + ny * ny)
			var ang := atan2(ny, nx)
			if d < 0.8 and absf(sin(ang - t * PI - d * 2.4)) < 0.4 * (1.0 - d) + 0.06:
				col = _ramp(RAMPS["cam_rib"], v, x, y)
			else:
				col = _ramp(RAMPS["cam"], v, x, y)
				col.a = 0.92 if d > 0.82 else 0.55
		"kil":
			col = _ramp(RAMPS["kil"], v, x, y)
			if _near(nx, ny, nz, KIL_DENTS, 0.975):
				col = col.darkened(0.22)
			if absf(ny - nx * 0.7 + 0.15) < 0.07 and nx > -0.1 and nx < 0.6:
				col = RAMPS["kil"][0]
			sp *= 0.35
		"kaucuk":
			var a := t * TAU
			var by := ny * cos(a) - nz * sin(a)
			if absf(by) < 0.2:
				col = _ramp(RAMPS["kaucuk_y"], v, x, y)
			elif absf(nx) < 0.15:
				col = _ramp(RAMPS["kaucuk_t"], v, x, y)
			else:
				col = _ramp(RAMPS["kaucuk"], v, x, y)
		"bakir":
			var a := t * TAU
			var bx := nx * cos(a) + nz * sin(a)
			var bz := -nx * sin(a) + nz * cos(a)
			col = _ramp(RAMPS["bakir"], v, x, y)
			if _near(bx, ny, bz, BAKIR_SPOTS, 0.955):
				col = _ramp(RAMPS["patina"], v, x, y)
		"miknatis":
			if absf(nx) < 0.13:
				col = _ramp(RAMPS["demir"], v + 0.1, x, y)
			elif nx < 0.0:
				col = _ramp(RAMPS["mik_r"], v, x, y)
			else:
				col = _ramp(RAMPS["mik_b"], v, x, y)
		"volkan":
			var d1 := 9.0
			var d2 := 9.0
			for p in VOLKAN_CELLS:
				var pv: Vector3 = p
				var dd := 1.0 - (nx * pv.x + ny * pv.y + nz * pv.z)
				if dd < d1:
					d2 = d1
					d1 = dd
				elif dd < d2:
					d2 = dd
			var edge := d2 - d1
			var glow := 0.55 + 0.45 * sin(t * TAU * 2.0 + nx * 3.0)
			var thin := 0.055 if r < 8.0 else 0.035
			if edge < thin:
				col = _ramp(RAMPS["lava"], 0.3 + glow * 0.55 + v * 0.25, x, y)
			elif edge < thin * 2.2:
				col = _ramp(RAMPS["basalt"], v + 0.3, x, y).lerp(Color("a3300c"), 0.45 * glow)
			else:
				col = _ramp(RAMPS["basalt"], v, x, y)
			sp *= 0.5
		"altin":
			col = _ramp(RAMPS["altin"], v, x, y)
			if t < 0.5:
				var g := -1.5 + t / 0.5 * 3.0
				if absf((nx + ny) * 0.71 - g) < 0.17:
					col = Color("fff8d6")
		"ikiz":
			var a := t * TAU
			var u := nx * cos(a) + ny * sin(a)
			var w := -nx * sin(a) + ny * cos(a)
			var yin := u < 0.0
			if Vector2(u, w - 0.5).length() < 0.5:
				yin = true
			elif Vector2(u, w + 0.5).length() < 0.5:
				yin = false
			if Vector2(u, w - 0.5).length() < 0.17:
				yin = false
			elif Vector2(u, w + 0.5).length() < 0.17:
				yin = true
			col = _ramp(RAMPS["ikiz_a"] if yin else RAMPS["ikiz_b"], v, x, y)
		"kuyruklu":
			col = _ramp(RAMPS["kuyruklu"], v, x, y)
			if _near(nx, ny, nz, COMET_CRATERS, 0.97):
				col = _ramp(RAMPS["kuyruklu"], v - 0.3, x, y)
		"anka":
			var f := fposmod(ny * 2.4 + absf(nx) * 1.8 - t, 1.0)
			col = _ramp(RAMPS["anka"], v - (0.24 if absf(f - 0.5) < 0.12 else 0.0), x, y)
		"kara_inci":
			col = _ramp(RAMPS["inci"], v, x, y)
			if v > 0.5:
				var hue := fposmod(t + nx * 0.4 - ny * 0.3, 1.0)
				col = col.lerp(Color.from_hsv(hue, 0.55, 1.0), clampf((v - 0.5) * 1.5, 0.0, 0.65))
		_:
			col = _ramp(RAMPS["demir"], v, x, y)
	return _with_spec(col, sp)


static func _ball_fx(bid: String, back: Image, front: Image, c: Vector2, r: float, m: float, t: float) -> void:
	var sc := 1 if r < 8.0 else 2
	var has_art := bodies.has("ball:" + bid)
	if has_art and bid == "ikiz":
		# uydular çizimde var; yalnızca küçük bir parıltı
		_sparkle(front, c + Vector2(r * 0.6, -r * 0.7), _twinkle(t, 0.3, sc), Color("b5fff0"))
		return
	if has_art and bid == "anka":
		_embers(back, c, r, m, t, 4, Color("fff3a0"), Color("ff3d6e"))
		return
	if has_art and bid == "kuyruklu":
		var dir := Vector2(0.55, -1.0).normalized()
		var perp := Vector2(-dir.y, dir.x)
		for k in range(10):
			var u := fposmod(t + fposmod(k * 0.618, 1.0), 1.0)
			var off := (fposmod(k * 0.37, 1.0) - 0.5) * r * 1.2
			var q := c + dir * (r * 0.9 + u * (r + m)) + perp * off * (0.5 + u * 0.5)
			var col := Color.WHITE.lerp(Color("8fe0ff"), u)
			col.a = 1.0 - u * 0.8
			_put(front, int(q.x), int(q.y), col)
		return
	match bid:
		"cam":
			_sparkle(front, c + Vector2(-r * 0.55, -r * 0.62), _twinkle(t, 0.3, sc), Color("bdf6ff"))
		"kil":
			for k in range(2):
				var u := fposmod(t + k * 0.5, 1.0)
				var col := Color("c98a5a")
				col.a = 1.0 - u
				_put(back, int(c.x + (k * 2 - 1) * r * 0.45), int(c.y + r + 1.0 + u * m * 0.8), col)
		"bakir":
			_sparkle(front, c + Vector2(r * 0.7, -r * 0.7), _twinkle(t, 0.55, sc), Color("ffd9a0"))
		"miknatis":
			for k in range(3):
				var u := fposmod(t + k / 3.0, 1.0)
				var col := Color("6ef2ff") if k % 2 == 0 else Color("c08bff")
				col.a = (1.0 - u) * (0.8 if r < 8.0 else 0.95)
				_ring(back, c, r + 1.5 + u * (m - 1.8), col, 6 if r < 8.0 else 10)
		"volkan":
			_flames(back, front, c, r, m, t, RAMPS["lava"], 7)
			_embers(back, c, r, m, t, 3, Color("fff3a0"), Color("ff3d00"))
		"altin":
			_sparkle(front, c + Vector2(r * 0.8, -r * 0.85), _twinkle(t, 0.0, sc), Color("ffe680"))
			_sparkle(front, c + Vector2(-r * 1.0, r * 0.45), _twinkle(t, 0.5, sc), Color("ffe680"))
		"ikiz":
			var a := t * TAU
			for k in range(2):
				var aa := a + k * PI
				var orb := Vector2(cos(aa) * (r + m * 0.5), sin(aa) * (r + m * 0.5) * 0.42)
				_mini_ball(front if sin(aa) > 0.0 else back, c + orb, maxf(1.6, r * 0.32), RAMPS["ikiz_a"] if k == 0 else RAMPS["ikiz_b"])
		"kuyruklu":
			var dir := Vector2(0.55, -1.0).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var s := back.get_width()
			var tail_len := r + m * 1.3
			for y in range(s):
				for x in range(s):
					var p := Vector2(x + 0.5, y + 0.5) - c
					var along := p.dot(dir)
					if along < r * 0.3 or along > tail_len:
						continue
					var k := along / tail_len
					if absf(p.dot(perp)) > r * 0.85 * (1.0 - k * 0.8):
						continue
					var b: float = BAYER[(x & 1) + 2 * (y & 1)]
					if b > 1.05 - k:
						continue
					_put(back, x, y, Color(0.6, 0.88, 1.0, 0.8 * (1.0 - k) + 0.1))
			for k in range(12):
				var u := fposmod(t + fposmod(k * 0.618, 1.0), 1.0)
				var off := (fposmod(k * 0.37, 1.0) - 0.5) * r * 1.3
				var q := c + dir * (r * 0.8 + u * tail_len * 0.95) + perp * off * (0.5 + u * 0.5)
				var col := Color.WHITE.lerp(Color("8fe0ff"), u).lerp(Color("a58bff"), u * u)
				col.a = 1.0 - u * 0.7
				_put(back, int(q.x), int(q.y), col)
				if sc > 1 or u < 0.35:
					_put(back, int(q.x) + 1, int(q.y), col)
					_put(back, int(q.x), int(q.y) + 1, col)
			_ring(back, c, r + 1.5, Color(0.6, 0.9, 1.0, 0.3 + 0.15 * sin(t * TAU)))
		"anka":
			var s := back.get_width()
			var flap := sin(t * TAU)
			var pal: Array = RAMPS["kanat"]
			for y in range(s):
				for x in range(s):
					var dx := x + 0.5 - c.x
					var dy := y + 0.5 - c.y
					var adx := absf(dx)
					if adx < r * 0.6 or adx > r + m:
						continue
					var span := (adx - r * 0.6) / (m + r * 0.4)
					var top := -r * 0.15 - span * r * (0.55 + 0.6 * flap)
					var bottom := top + r * (1.0 - 0.65 * span) - fposmod(adx, maxf(2.0, r * 0.3)) * 0.7
					if dy < top or dy > bottom:
						continue
					if adx < r and dx * dx + dy * dy < r * r:
						continue
					var heat := 1.0 - span * 0.9 - (dy - top) / maxf(bottom - top, 0.5) * 0.25
					var b: float = BAYER[(x & 1) + 2 * (y & 1)]
					var idx := clampi(int(floorf(heat * pal.size() + (b - 0.375) * 0.8)), 0, pal.size() - 1)
					_put(back, x, y, pal[idx])
			_outline(back, Color("4a0614"))
			_embers(back, c, r, m, t, 3, Color("fff3a0"), Color("ff3d6e"))
		"kara_inci":
			var s := back.get_width()
			for y in range(s):
				for x in range(s):
					var dx := x + 0.5 - c.x
					var dy := y + 0.5 - c.y
					var dist := sqrt(dx * dx + dy * dy)
					if dist < r + 1.0 or dist > r + m * 0.9:
						continue
					var k := (dist - r) / (m * 0.9)
					var pulse := 0.55 + 0.45 * sin(t * TAU - dist * (0.9 if r < 8.0 else 0.45))
					var a := (1.0 - k) * pulse
					var b: float = BAYER[(x & 1) + 2 * (y & 1)]
					if a > b * 0.9 + 0.12:
						_put(back, x, y, Color(0.45, 0.2, 1.0, 0.6))
			var oa := t * TAU
			var op := c + Vector2(cos(oa) * (r + m * 0.45), sin(oa) * (r + m * 0.45) * 0.5)
			_sparkle(front if sin(oa) > 0.0 else back, op, sc, Color("d7b8ff"))


# =================================================================== çiviler

static func peg(pid: String, r: float) -> Array:
	var m := ceilf(r * 0.7)
	var s := canvas_size(r, m)
	var out: Array = []
	for f in range(FRAMES):
		out.append(_peg_frame(pid, r, m, s, float(f) / FRAMES))
	return out


## Sıradan pirinç çivi (tek kare): state "in" (oyun alanı), "out" (kenar), "lit" (vuruş anı)
static func plain_peg(state: String, style: String = "brass") -> Image:
	var r := PLAIN_PEG
	var s := canvas_size(r, 1.0)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	for y in range(s):
		for x in range(s):
			var nx := (x + 0.5 - c.x) / r
			var ny := (y + 0.5 - c.y) / r
			if nx * nx + ny * ny > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var v := _lum(nx, ny, nz) - 0.08
			if state == "out":
				v -= 0.25
			var ramp_key := "pin" if style == "brass" else "pin_" + style
			var col := _ramp(RAMPS.get(ramp_key, RAMPS["pin"]), v, x, y)
			if state == "lit":
				col = Color.WHITE.lerp(col, 0.25)
			img.set_pixel(x, y, _with_spec(col, _spec(nx, ny, nz)))
	_outline(img, Color("120806"))
	return img


static func _peg_frame(pid: String, r: float, m: float, s: int, t: float) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var body := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var front := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	var art: Image = bodies.get("peg:" + pid)
	if art != null:
		var fit := _fit_body(art, r, maxf(22.0, float(maxi(art.get_width(), art.get_height())) - 2.0))
		_sweep(fit, t, 0.3 if pid in ["elmas", "ayna", "kalkan"] else 0.15)
		var oc := c
		if pid == "yay":
			oc.y -= roundf(absf(sin(t * TAU)) * (2.0 if r > 8.0 else 1.0))
		elif pid == "bilet" and fposmod(t, 0.5) >= 0.25:
			oc.y -= 1.0
		_peg_fx(pid, img, front, c, r, m, t)
		img.blend_rect(fit, Rect2i(Vector2i.ZERO, fit.get_size()), Vector2i((oc - fit.get_size() / 2.0).floor()))
		img.blend_rect(front, Rect2i(0, 0, s, s), Vector2i.ZERO)
		return img
	if pid == "bilet" and fposmod(t, 0.5) >= 0.25:
		c.y -= 1.0
	for y in range(s):
		for x in range(s):
			var col := _peg_px(pid, (x + 0.5 - c.x) / r, (y + 0.5 - c.y) / r, t, x, y)
			if col.a > 0.0:
				body.set_pixel(x, y, col)
	_outline(body, OUTLINE)
	_peg_fx(pid, img, front, c, r, m, t)
	img.blend_rect(body, Rect2i(0, 0, s, s), Vector2i.ZERO)
	img.blend_rect(front, Rect2i(0, 0, s, s), Vector2i.ZERO)
	return img


static func _peg_px(pid: String, nx: float, ny: float, t: float, x: int, y: int) -> Color:
	var d := sqrt(nx * nx + ny * ny)
	match pid:
		"bakir_civi", "gumus", "altin_civi":
			if d > 1.0:
				return CLEAR
			var nz := maxf(sqrt(maxf(0.0, 1.0 - d * d)), 0.45)
			var ramp: Array = RAMPS["bakir" if pid == "bakir_civi" else ("gumus" if pid == "gumus" else "altin")]
			var v := _lum(nx * 0.8, ny * 0.8, nz)
			var col := _ramp(ramp, v, x, y)
			var sym := false
			if pid == "altin_civi":
				sym = (absf(nx - ny) < 0.26 or absf(nx + ny) < 0.26) and d < 0.66
			else:
				sym = (absf(nx) < 0.2 and absf(ny) < 0.62) or (absf(ny) < 0.2 and absf(nx) < 0.62)
			if sym:
				col = ramp[0]
			elif pid != "bakir_civi" and t < 0.45:
				var g := -1.5 + t / 0.45 * 3.0
				if absf((nx + ny) * 0.71 - g) < 0.2:
					col = Color.WHITE
			return _with_spec(col, _spec(nx * 0.8, ny * 0.8, nz))
		"elmas":
			var inside := false
			var crown := ny < -0.2
			if ny >= -0.82 and ny < -0.2:
				inside = absf(nx) <= 0.55 + (ny + 0.82) / 0.62 * 0.45
			elif ny >= -0.2 and ny <= 1.05:
				inside = absf(nx) <= 1.0 - (ny + 0.2) / 1.25
			if not inside:
				return CLEAR
			var fi := clampi(int(floorf((nx + 1.0) * 2.0)), 0, 3)
			var crown_v := [0.7, 0.95, 0.62, 0.4]
			var pav_v := [0.5, 0.72, 0.38, 0.18]
			var v: float = crown_v[fi] if crown else pav_v[fi]
			if absf(ny + 0.2) < 0.09:
				v = 0.85
			var col := _ramp(RAMPS["elmas"], v, x, y)
			var g := -1.6 + fposmod(t * 1.0, 1.0) * 3.2
			if absf(nx * 0.8 + ny * 0.6 - g) < 0.16:
				col = Color.from_hsv(fposmod(t * 2.0 + nx * 0.5, 1.0), 0.35, 1.0)
			return col
		"yildiz":
			var a := -t * TAU / 5.0
			var u := nx * cos(a) - ny * sin(a)
			var w := nx * sin(a) + ny * cos(a)
			var ang := atan2(w, u) + PI / 2.0
			var seg := fposmod(ang + TAU / 10.0, TAU / 5.0) - TAU / 10.0
			var rb := lerpf(1.08, 0.46, absf(seg) / (TAU / 10.0))
			if d > rb:
				return CLEAR
			var v := (0.78 if seg < 0.0 else 0.42) + (0.18 if d < 0.3 else 0.0)
			return _ramp(RAMPS["yildiz"], v, x, y)
		"yay":
			var bounce := absf(sin(t * TAU))
			var sc := 1.0 - 0.13 * bounce
			var dd := d / sc
			if dd > 1.0:
				return CLEAR
			var zx := nx / sc
			var zy := ny / sc
			if dd > 0.62:
				var nz := sqrt(maxf(0.0, 1.0 - dd * dd)) * 0.6 + 0.4
				return _ramp(RAMPS["yay"], _lum(zx, zy, nz), x, y)
			if absf(zx) < 0.52:
				var tri := absf(fposmod(zx * 3.0 + 0.25, 1.0) - 0.5) * 2.0 - 0.5
				if absf(zy - tri * 0.75 * (1.0 - 0.5 * bounce)) < 0.17:
					return Color("ffe14d")
			return Color("0d3b26")
		"huni":
			if d > 1.0:
				return CLEAR
			if d < 0.24:
				return Color("1a0830")
			var ang := atan2(ny, nx)
			var arm := sin(2.0 * ang - d * 7.0 + t * TAU)
			return _ramp(RAMPS["huni"], 0.3 + 0.32 * arm + 0.25 * (1.0 - d) - 0.12 * ny, x, y)
		"kalkan":
			var half := 0.0
			if ny < -0.85 or ny > 1.0:
				return CLEAR
			if ny <= 0.15:
				half = 0.9
			else:
				var k := (ny - 0.15) / 0.85
				half = 0.9 * sqrt(maxf(0.0, 1.0 - k * k))
			if absf(nx) > half:
				return CLEAR
			var v := 0.62 - nx * 0.35 - ny * 0.2
			if absf(nx) < 0.17:
				return _ramp(RAMPS["gumus"], v + 0.15, x, y)
			return _ramp(RAMPS["kalkan"], v, x, y)
		"ayna":
			if d > 1.0:
				return CLEAR
			if d > 0.7:
				var nz := sqrt(maxf(0.0, 1.0 - d * d)) * 0.7 + 0.3
				return _ramp(RAMPS["altin"], _lum(nx, ny, nz), x, y)
			var g := -1.4 + t * 2.8
			if absf((nx - ny) * 0.7 - g) < 0.14:
				return Color.WHITE
			return _ramp(RAMPS["ayna"], 0.72 - ny * 0.3 - nx * 0.15, x, y)
		"bilet":
			var a := sin(t * TAU) * 0.12
			var u := nx * cos(a) + ny * sin(a)
			var w := -nx * sin(a) + ny * cos(a)
			if absf(u) > 1.02 or absf(w) > 0.64:
				return CLEAR
			if (absf(u) - 1.02) * (absf(u) - 1.02) + w * w < 0.07:
				return CLEAR
			if absf(u - 0.42) < 0.08 and fposmod(w * 4.0, 1.0) < 0.5:
				return Color("8a2a00")
			if Vector2(u + 0.3, w).length() < 0.24 and (absf(u + 0.3) < 0.08 or absf(w) < 0.08):
				return Color.WHITE
			return _ramp(RAMPS["bilet"], 0.75 - w * 0.5, x, y)
	if d > 1.0:
		return CLEAR
	return _ramp(RAMPS["brass"], 0.6 - ny * 0.3, x, y)


static func _peg_fx(pid: String, back: Image, front: Image, c: Vector2, r: float, m: float, t: float) -> void:
	var sc := 1 if r < 8.0 else 2
	match pid:
		"gumus":
			_sparkle(front, c + Vector2(r * 0.75, -r * 0.75), _twinkle(t, 0.6, sc), Color("e8f0ff"))
		"altin_civi":
			_sparkle(front, c + Vector2(r * 0.8, -r * 0.8), _twinkle(t, 0.6, sc), Color("ffe680"))
			_sparkle(front, c + Vector2(-r * 0.9, r * 0.6), _twinkle(t, 0.15, sc), Color("ffe680"))
		"elmas":
			_sparkle(front, c + Vector2(r * 0.85, -r * 0.7), _twinkle(t, 0.0, sc), Color("c8f8ff"))
			_sparkle(front, c + Vector2(-r * 0.9, -r * 0.4), _twinkle(t, 0.5, sc), Color("ffc8f0"))
		"ayna":
			_sparkle(front, c + Vector2(-r * 0.3, -r * 0.35), _twinkle(t, 0.45, sc), Color("e8fdff"))
		"bilet":
			_sparkle(front, c + Vector2(r * 0.95, -r * 0.7), _twinkle(t, 0.2, sc), Color("ffe0a0"))
		"yildiz":
			var s := back.get_width()
			var pulse := 0.5 + 0.5 * sin(t * TAU)
			for y in range(s):
				for x in range(s):
					var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
					if dist < r * 0.9 or dist > r + m:
						continue
					var k := (dist - r * 0.9) / (m + r * 0.1)
					var b: float = BAYER[(x & 1) + 2 * (y & 1)]
					if (1.0 - k) * (0.4 + 0.6 * pulse) > b * 0.8 + 0.25:
						_put(back, x, y, Color(1.0, 0.5, 0.9, 0.8))
		"huni":
			for k in range(4):
				var u := fposmod(t + k * 0.25, 1.0)
				var ang := k * PI / 2.0 + u * PI * 1.2
				var rad := r + m * 0.9 - u * (m * 0.9 + r * 0.6)
				var col := Color("dcc2ff")
				col.a = 0.4 + 0.6 * u
				var p := c + Vector2(cos(ang), sin(ang)) * rad
				_put(front if rad < r else back, int(p.x), int(p.y), col)
		"kalkan":
			var a := 0.55 + 0.4 * sin(t * TAU)
			_ring(back, c + Vector2(0, r * 0.05), r + 1.5, Color(0.6, 0.9, 1.0, a), 6 if r < 8.0 else 9)
			if r >= 8.0:
				_ring(back, c + Vector2(0, r * 0.05), r + 3.0, Color(0.6, 0.9, 1.0, a * 0.4), 9)
