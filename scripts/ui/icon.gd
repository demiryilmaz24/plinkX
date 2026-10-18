extends Control
## Vektör ikonlar (görsel dosyası yok). Tüm ikonlar özgün, basit, canlı renkli çizimlerdir.
## kind örnekleri: ticket, coin, lock, star, star_empty, gear, check, rarity:<r>, ball:<id>, peg:<id>,
## up:<yükseltme>, menu:<ekran>, job, moon, pay, play, stop, robot

const UI := preload("res://scripts/ui/ui_kit.gd")
const OUTLINE := Color("1a0b33")

## Bilet ağacı düğümü -> ikon
const TREE_ICONS := {
	"start_cash": "pay", "free_shots": "x:freeball", "job_pay": "job", "bulk_buy": "x:cart",
	"layouts": "x:blueprint", "stats": "menu:stats", "start_ball": "up:ball_level", "card_size": "card",
	"prestige_bonus": "moon", "auto_ready": "up:auto_unlock", "auto_speed_perm": "up:auto_speed",
	"air_perm": "up:air", "auto_pay": "x:autopay", "start_board": "up:board_level", "start_sockets": "up:sockets",
	"peg_gift": "x:gift", "ball_luck": "rarity:legendary", "ball_slot_cost": "x:tag", "peg_luck": "peg:yildiz",
	"peg_slot_cost": "x:tag2",
}
## Başarım istatistiği -> ikon
const ACH_ICONS := {
	"shots_total": "up:batch", "max_total": "star", "jackpots": "coin", "auto_shots": "up:auto_unlock",
	"rarity_rare": "rarity:rare", "rarity_epic": "rarity:epic", "rarity_legendary": "rarity:legendary",
	"rarities_owned": "menu:collection", "ball_types": "menu:collection", "max_mastery": "star",
	"run_profit_best": "pay", "board_level_best": "up:board_level", "peg_tickets": "peg:bilet",
	"days_closed": "moon", "debt_cleared": "check", "jobs_done": "job", "free_ball_level_best": "up:ball_level",
	"free_board_level_best": "up:board_level", "free_profit_best": "pay", "free_prestiges": "moon",
}

var kind := "ticket"
var tint := Color.WHITE
var _custom_tint := false
## >0 ise piksel sanat modu: ikon bu çözünürlükte rasterleştirilip büyütülür.
var pixel_base := 0
## >0 ise sprite tuvali (efektlerle birlikte) karenin bu katından büyük çizilmez.
var fit := 0.0


## Piksel çözünürlüğü: büyük ikonlarda 1 piksel = 3 ekran pikseli, orta boyda 2.
static func pixel_base_for(size_: float) -> int:
	if size_ < 20.0:
		return 0
	return clampi(int(round(size_ / (3.0 if size_ >= 36.0 else 2.0))), 8, 30)


static func make(kind_: String, size_: float = 18.0, tint_: Color = Color(0, 0, 0, 0)) -> Control:
	var ic: Control = load("res://scripts/ui/icon.gd").new()
	ic.kind = kind_
	ic.custom_minimum_size = Vector2(size_, size_)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.pixel_base = pixel_base_for(size_)
	if tint_.a > 0.0:
		ic.tint = tint_
		ic._custom_tint = true
	return ic


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if pixel_base > 0:
		PixelArt.icon_ready.connect(func(_k): queue_redraw())
	set_process(is_sprite(kind))


func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		set_process(is_sprite(kind))
		queue_redraw()


## Top ve çivi türleri animasyonlu piksel sprite ile çizilir.
static func is_sprite(k: String) -> bool:
	return k.begins_with("ball:") or k.begins_with("peg:")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var t := tint if _custom_tint else Color(0, 0, 0, 0)
	if is_sprite(kind) and draw_sprite(self, kind, Rect2(size / 2.0 - Vector2(s, s) / 2.0, Vector2(s, s)), t, 0.0, fit):
		return
	if pixel_base > 0:
		draw_pixel_icon(self, kind, Rect2(size / 2.0 - Vector2(s, s) / 2.0, Vector2(s, s)), pixel_base, t)
		return
	draw_icon(self, kind, size / 2.0, s, t)


## Animasyonlu top/çivi sprite'ını kareye ortalayıp tam sayı ölçekle çizer (piksel bozulmadan).
## Gövde karenin ~%80'ine sığar; alev/dalga gibi efektler kareden taşabilir. Hazır değilse false.
static func draw_sprite(ci: CanvasItem, k: String, rect: Rect2, t: Color = Color(0, 0, 0, 0), phase: float = 0.0, fit_: float = 0.0) -> bool:
	var is_ball := k.begins_with("ball:")
	var target := rect.size.x * 0.8
	var big := target >= 30.0
	var body := (24.0 if is_ball else 22.0) if big else (14.0 if is_ball else 12.0)
	var sc := maxi(1, int(floorf(target / body + 0.2)))
	var tex: Texture2D = PixelArt.sprite(k, big, phase)
	if tex == null:
		return false
	if fit_ > 0.0:
		sc = mini(sc, maxi(1, int(floorf(rect.size.x * fit_ / tex.get_size().x))))
	var sz := tex.get_size() * sc
	ci.draw_texture_rect(tex, Rect2((rect.get_center() - sz / 2.0).round(), sz), false, t if t.a > 0.0 else Color.WHITE)
	return true


## Piksel sanat dokusunu verilen kareye çizer; doku henüz hazır değilse hiçbir şey çizmez (bir kare sonra gelir).
static func draw_pixel_icon(ci: CanvasItem, k: String, rect: Rect2, base: int, t: Color = Color(0, 0, 0, 0)) -> bool:
	if is_sprite(k) and draw_sprite(ci, k, rect, t):
		return true
	var tex: Texture2D = PixelArt.get_icon(k, base, t)
	if tex == null:
		return false
	# tam sayı büyütme: her doku pikseli eşit sayıda ekran pikseline düşer (keskin)
	var sc := maxi(1, int(round(rect.size.x / float(base))))
	var ds := float((base + 2) * sc)
	ci.draw_texture_rect(tex, Rect2((rect.get_center() - Vector2(ds, ds) / 2.0).round(), Vector2(ds, ds)), false)
	return true


static func _rot(pts: PackedVector2Array, c: Vector2, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c).rotated(a))
	return out


static func _star(c: Vector2, r_out: float, r_in: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n * 2):
		var a := -PI / 2.0 + i * PI / n
		var rr := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func _rrect(c: Vector2, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(w / 2 - r, -h / 2 + r), Vector2(w / 2 - r, h / 2 - r), Vector2(-w / 2 + r, h / 2 - r), Vector2(-w / 2 + r, -h / 2 + r)]
	var starts := [-PI / 2, 0.0, PI / 2, PI]
	for i in range(4):
		for k in range(5):
			var a: float = starts[i] + k * (PI / 2) / 4.0
			pts.append(c + corners[i] + Vector2(cos(a), sin(a)) * r)
	return pts


## Hilal: dış daireden iç (kaydırılmış) daireyi çıkaran çokgen; kesişim noktaları analitik hesaplanır.
static func _crescent(c: Vector2, big_r: float) -> PackedVector2Array:
	var off := Vector2(big_r * 0.45, -big_r * 0.3)
	var small_r := big_r * 0.8
	var ci := c + off
	var d := off.length()
	var u := off / d
	var a := (big_r * big_r - small_r * small_r + d * d) / (2.0 * d)
	var h := sqrt(maxf(big_r * big_r - a * a, 0.0))
	var perp := Vector2(-u.y, u.x)
	var p1 := c + u * a + perp * h
	var p2 := c + u * a - perp * h
	var back := (-u).angle()
	var pts := PackedVector2Array()
	pts.append_array(_arc_through(c, big_r, (p1 - c).angle(), (p2 - c).angle(), back))
	pts.append_array(_arc_through(ci, small_r, (p2 - ci).angle(), (p1 - ci).angle(), back))
	return pts


## from açısından to açısına, via açısından geçen yay üzerindeki noktalar.
static func _arc_through(center: Vector2, rad: float, from: float, to: float, via: float) -> PackedVector2Array:
	var span := wrapf(to - from, 0.0, TAU)
	var ccw := wrapf(via - from, 0.0, TAU) < span
	var total := span if ccw else -(TAU - span)
	var pts := PackedVector2Array()
	for k in range(17):
		var ang := from + total * k / 16.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	return pts


static func _poly_outlined(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, line, true)


## Herhangi bir CanvasItem üzerine ikon çizer (tahta ve efekt katmanı da kullanır).
static func draw_icon(ci: CanvasItem, k: String, c: Vector2, s: float, override: Color = Color(0, 0, 0, 0)) -> void:
	var r := s * 0.45
	var lw := maxf(1.2, s * 0.06)
	if k.begins_with("rarity:"):
		_draw_rarity(ci, k.substr(7), c, r, override)
		return
	if k.begins_with("ball:"):
		var bid := k.substr(5)
		draw_ball(ci, c, r, bid, UI.ball_color(bid) if override.a == 0.0 else override)
		return
	if k.begins_with("peg:"):
		draw_peg(ci, k.substr(4), c, r)
		return
	if k.begins_with("tree:"):
		var mapped: String = TREE_ICONS.get(k.substr(5), "ticket")
		draw_icon(ci, mapped, c, s, override)
		return
	if k.begins_with("ach:"):
		draw_icon(ci, ACH_ICONS.get(k.substr(4), "star"), c, s, override)
		return
	if k.begins_with("up:") or k.begins_with("menu:") or k.begins_with("x:"):
		_draw_feature(ci, k, c, r, lw)
		return
	match k:
		"ticket":
			draw_ticket(ci, c, s, override)
		"coin":
			var cc: Color = override if override.a > 0.0 else UI.GOLD
			ci.draw_circle(c + Vector2(0, r * 0.08), r, cc.darkened(0.35))
			ci.draw_circle(c, r, cc)
			ci.draw_circle(c, r * 0.72, cc.lightened(0.18))
			ci.draw_arc(c, r * 0.72, 0, TAU, 24, cc.darkened(0.2), lw)
			ci.draw_line(c + Vector2(-r * 0.25, -r * 0.35), c + Vector2(r * 0.25, r * 0.35), cc.darkened(0.3), lw * 1.3)
			ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.14, Color(1, 1, 1, 0.8))
		"lock":
			var lc: Color = override if override.a > 0.0 else UI.MUTED
			ci.draw_arc(c + Vector2(0, -r * 0.15), r * 0.45, PI, TAU, 14, lc, r * 0.24)
			ci.draw_colored_polygon(_rrect(c + Vector2(0, r * 0.3), r * 1.5, r * 1.05, r * 0.2), lc)
			ci.draw_circle(c + Vector2(0, r * 0.28), r * 0.14, OUTLINE)
		"star", "star_empty":
			var sc: Color = override if override.a > 0.0 else UI.GOLD
			if k == "star":
				_poly_outlined(ci, _star(c, r, r * 0.45, 5), sc, lw)
			else:
				var pts := _star(c, r, r * 0.45, 5)
				pts.append(pts[0])
				ci.draw_polyline(pts, Color(sc, 0.55), lw, true)
		"check":
			var gc: Color = override if override.a > 0.0 else UI.MINT
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.7, 0), c + Vector2(-r * 0.15, r * 0.55), c + Vector2(r * 0.75, -r * 0.6)]), gc, r * 0.32, true)
		"gear":
			var gc2: Color = override if override.a > 0.0 else Color("dfe4ff")
			for i in range(8):
				var a := i * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r, gc2, r * 0.34)
			ci.draw_circle(c, r * 0.66, gc2)
			ci.draw_circle(c, r * 0.28, UI.PANEL_DARK)
		"card":
			var kc: Color = override if override.a > 0.0 else UI.TICKET
			ci.draw_colored_polygon(_rrect(c, r * 1.6, r * 2.0, r * 0.25), kc)
			for i in range(3):
				ci.draw_circle(c + Vector2(-r * 0.4 + i * r * 0.4, -r * 0.3), r * 0.14, OUTLINE)
				ci.draw_circle(c + Vector2(-r * 0.4 + i * r * 0.4, r * 0.3), r * 0.14, Color(OUTLINE, 0.4))
		"moon":
			var mc: Color = override if override.a > 0.0 else UI.GOLD
			_poly_outlined(ci, _crescent(c, r), mc, lw)
			ci.draw_colored_polygon(_star(c + Vector2(r * 0.5, -r * 0.35), r * 0.3, r * 0.12, 4), Color.WHITE)
		"pay":
			var pc: Color = override if override.a > 0.0 else UI.GOLD
			for i in range(3):
				var cc2 := c + Vector2(0, r * 0.45 - i * r * 0.38)
				ci.draw_colored_polygon(_rrect(cc2, r * 1.6, r * 0.42, r * 0.2), pc.darkened(0.1 * i))
				ci.draw_line(cc2 + Vector2(-r * 0.6, 0), cc2 + Vector2(r * 0.6, 0), pc.darkened(0.35), lw * 0.7)
		"play":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.7), c + Vector2(r * 0.75, 0), c + Vector2(-r * 0.5, r * 0.7)]), override if override.a > 0.0 else UI.MINT, lw)
		"stop":
			_poly_outlined(ci, _rrect(c, r * 1.3, r * 1.3, r * 0.2), override if override.a > 0.0 else UI.CORAL, lw)
		"job":
			# sünger + köpük + parıltı
			_poly_outlined(ci, _rrect(c + Vector2(-r * 0.1, r * 0.2), r * 1.5, r * 1.0, r * 0.3), Color("ffe14d"), lw)
			for p in [Vector2(-0.45, 0.1), Vector2(0.1, 0.35), Vector2(0.3, 0.05), Vector2(-0.2, 0.45)]:
				ci.draw_circle(c + p * r, r * 0.09, Color("e0b400"))
			ci.draw_circle(c + Vector2(r * 0.55, -r * 0.55), r * 0.3, Color("b8f3ff"))
			ci.draw_circle(c + Vector2(r * 0.2, -r * 0.75), r * 0.18, Color("b8f3ff"))
			ci.draw_colored_polygon(_star(c + Vector2(-r * 0.6, -r * 0.6), r * 0.32, r * 0.1, 4), Color.WHITE)


## Bilet rozeti: eğik, delikli, yıldızlı turuncu-pembe bilet (oyunun kalıcı para birimi).
static func draw_ticket(ci: CanvasItem, c: Vector2, s: float, override: Color = Color(0, 0, 0, 0)) -> void:
	var w := s * 0.92
	var h := s * 0.6
	var a := -0.22
	var body: Color = override if override.a > 0.0 else Color("ff7a2e")
	var top := Color("ffb347")
	var lw := maxf(1.3, s * 0.07)
	var shape := _rot(_rrect(c, w, h, h * 0.18), c, a)
	ci.draw_colored_polygon(_rot(_rrect(c + Vector2(0, s * 0.05), w, h, h * 0.18), c, a), Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(shape, body)
	ci.draw_colored_polygon(_rot(_rrect(c + Vector2(0, -h * 0.22), w * 0.92, h * 0.38, h * 0.14), c, a), top)
	# kenar çentikleri
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(side * w / 2.0, 0).rotated(a), h * 0.17, Color("ff4fb4"))
	# delikli çizgi
	for i in range(4):
		var p := c + Vector2(w * 0.22, -h * 0.3 + i * h * 0.2).rotated(a)
		ci.draw_circle(p, maxf(0.8, h * 0.045), Color(OUTLINE, 0.7))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ci.draw_polyline(closed, OUTLINE, lw, true)
	# yıldız
	var sc := c + Vector2(-w * 0.12, 0).rotated(a)
	ci.draw_colored_polygon(_rot(_star(sc, h * 0.36, h * 0.15, 5), sc, a), Color.WHITE)


static func _draw_rarity(ci: CanvasItem, rar: String, c: Vector2, r: float, override: Color) -> void:
	var col: Color = UI.rarity_color(rar) if override.a == 0.0 else override
	var lw := maxf(1.0, r * 0.14)
	match rar:
		"common":
			ci.draw_circle(c, r * 0.72, OUTLINE)
			ci.draw_circle(c, r * 0.58, col)
		"rare":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col, lw)
		"epic":
			_poly_outlined(ci, _star(c, r, r * 0.45, 5), col, lw)
		"legendary":
			_poly_outlined(ci, PackedVector2Array([
				c + Vector2(-r, r * 0.6), c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.5, r * 0.05),
				c + Vector2(0, -r * 0.75), c + Vector2(r * 0.5, r * 0.05), c + Vector2(r, -r * 0.4), c + Vector2(r, r * 0.6)]), col, lw)


## Yükseltme ve menü ikonları
static func _draw_feature(ci: CanvasItem, k: String, c: Vector2, r: float, lw: float) -> void:
	match k:
		"up:ball_level":
			draw_ball(ci, c + Vector2(-r * 0.15, r * 0.15), r * 0.72, "altin", UI.GOLD)
			_poly_outlined(ci, PackedVector2Array([c + Vector2(r * 0.55, -r * 0.95), c + Vector2(r * 1.0, -r * 0.35), c + Vector2(r * 0.72, -r * 0.35), c + Vector2(r * 0.72, r * 0.2), c + Vector2(r * 0.38, r * 0.2), c + Vector2(r * 0.38, -r * 0.35), c + Vector2(r * 0.1, -r * 0.35)]), UI.MINT, lw)
		"up:board_level":
			_poly_outlined(ci, _rrect(c, r * 1.9, r * 1.9, r * 0.35), UI.FELT, lw)
			for row in range(3):
				for j in range(row + 1):
					var p := c + Vector2((j - row / 2.0) * r * 0.5, -r * 0.45 + row * r * 0.42)
					ci.draw_circle(p, r * 0.11, UI.GOLD)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.55), Vector2(r * 0.4, r * 0.2)), UI.CORAL)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.55), Vector2(r * 0.6, r * 0.2)), UI.MINT)
			ci.draw_rect(Rect2(c + Vector2(r * 0.3, r * 0.55), Vector2(r * 0.4, r * 0.2)), UI.CORAL)
		"up:batch":
			draw_ball(ci, c + Vector2(-r * 0.45, r * 0.35), r * 0.48, "demir", UI.SKY)
			draw_ball(ci, c + Vector2(r * 0.45, r * 0.35), r * 0.48, "demir", UI.PINK)
			draw_ball(ci, c + Vector2(0, -r * 0.35), r * 0.48, "demir", UI.GOLD)
		"up:air":
			_poly_outlined(ci, _rot(_rrect(c + Vector2(-r * 0.1, r * 0.25), r * 0.7, r * 1.4, r * 0.2), c + Vector2(-r * 0.1, r * 0.25), 0.5), Color("8fa2ff"), lw)
			draw_ball(ci, c + Vector2(r * 0.45, -r * 0.55), r * 0.36, "demir", UI.SKY)
			for i in range(3):
				ci.draw_line(c + Vector2(-r * 0.7 + i * r * 0.25, r * 0.95), c + Vector2(-r * 0.55 + i * r * 0.25, r * 0.7), UI.ORANGE, lw)
		"up:polish":
			_poly_outlined(ci, _star(c + Vector2(-r * 0.15, r * 0.1), r * 0.85, r * 0.28, 4), Color("fff2a8"), lw)
			ci.draw_colored_polygon(_star(c + Vector2(r * 0.6, -r * 0.6), r * 0.35, r * 0.12, 4), UI.PINK)
			ci.draw_colored_polygon(_star(c + Vector2(r * 0.65, r * 0.6), r * 0.22, r * 0.08, 4), UI.SKY)
		"up:sockets":
			draw_peg(ci, "huni", c + Vector2(-r * 0.2, r * 0.15), r * 0.62)
			ci.draw_circle(c + Vector2(r * 0.55, -r * 0.55), r * 0.38, UI.MINT)
			ci.draw_rect(Rect2(c + Vector2(r * 0.55 - r * 0.22, -r * 0.55 - r * 0.06), Vector2(r * 0.44, r * 0.12)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(r * 0.55 - r * 0.06, -r * 0.55 - r * 0.22), Vector2(r * 0.12, r * 0.44)), OUTLINE)
		"up:auto_unlock":
			draw_robot(ci, c, r)
		"up:auto_speed":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.6, r * 0.15), c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.25, r), c + Vector2(r * 0.65, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)]), UI.GOLD, lw)
		"up:auto_batch":
			_poly_outlined(ci, _rrect(c, r * 0.95, r * 1.9, r * 0.3), Color("8fa2ff"), lw)
			for i in range(3):
				draw_ball(ci, c + Vector2(0, -r * 0.55 + i * r * 0.55), r * 0.3, "demir", [UI.PINK, UI.GOLD, UI.MINT][i])
		"menu:collection":
			draw_ball(ci, c + Vector2(-r * 0.4, r * 0.3), r * 0.5, "kaucuk", UI.ball_color("kaucuk"))
			draw_ball(ci, c + Vector2(r * 0.45, r * 0.3), r * 0.5, "cam", UI.ball_color("cam"))
			draw_ball(ci, c + Vector2(0, -r * 0.4), r * 0.5, "altin", UI.ball_color("altin"))
		"menu:pegs":
			draw_peg(ci, "yildiz", c + Vector2(r * 0.4, -r * 0.4), r * 0.5)
			draw_peg(ci, "huni", c + Vector2(-r * 0.4, -r * 0.2), r * 0.45)
			draw_peg(ci, "gumus", c + Vector2(0, r * 0.5), r * 0.45)
		"menu:tree":
			var pts := [c + Vector2(0, -r * 0.65), c + Vector2(-r * 0.65, r * 0.55), c + Vector2(r * 0.65, r * 0.55)]
			ci.draw_line(pts[0], pts[1], Color("ffd1a8"), lw * 1.4)
			ci.draw_line(pts[0], pts[2], Color("ffd1a8"), lw * 1.4)
			for p in pts:
				ci.draw_circle(p, r * 0.36, OUTLINE)
				ci.draw_circle(p, r * 0.28, UI.TICKET)
			ci.draw_colored_polygon(_star(pts[0], r * 0.2, r * 0.08, 5), Color.WHITE)
		"menu:achievements":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.5, r * 0.1), c + Vector2(0, r * 0.35), c + Vector2(-r * 0.5, r * 0.1)]), UI.GOLD, lw)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.3), Vector2(r * 0.24, r * 0.4)), UI.GOLD_DARK)
			ci.draw_colored_polygon(_rrect(c + Vector2(0, r * 0.8), r * 1.0, r * 0.3, r * 0.1), UI.GOLD_DARK)
			ci.draw_colored_polygon(_star(c + Vector2(0, -r * 0.35), r * 0.25, r * 0.1, 5), Color.WHITE)
		"menu:stats":
			var cols := [UI.SKY, UI.MINT, UI.PINK]
			var hs := [0.6, 1.1, 1.6]
			for i in range(3):
				var x := c.x - r * 0.75 + i * r * 0.55
				ci.draw_colored_polygon(_rrect(Vector2(x + r * 0.2, c.y + r * 0.8 - r * hs[i] / 2.0), r * 0.4, r * hs[i], r * 0.08), cols[i])
		"menu:story":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.65), c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.75), c + Vector2(-r * 0.9, r * 0.55)]), Color("fff4d6"), lw)
			_poly_outlined(ci, PackedVector2Array([c + Vector2(r * 0.9, -r * 0.65), c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.75), c + Vector2(r * 0.9, r * 0.55)]), Color("ffe7b0"), lw)
			for i in range(3):
				ci.draw_line(c + Vector2(-r * 0.7, -r * 0.3 + i * r * 0.28), c + Vector2(-r * 0.2, -r * 0.2 + i * r * 0.28), Color(OUTLINE, 0.4), lw * 0.6)
		"menu:settings":
			draw_icon(ci, "gear", c, r / 0.45)
		"x:freeball":
			draw_ball(ci, c + Vector2(-r * 0.15, r * 0.1), r * 0.75, "cam", UI.SKY)
			ci.draw_colored_polygon(_star(c + Vector2(r * 0.55, -r * 0.55), r * 0.4, r * 0.15, 4), UI.GOLD)
		"x:cart":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.3), c + Vector2(r * 0.9, -r * 0.3), c + Vector2(r * 0.65, r * 0.6), c + Vector2(-r * 0.65, r * 0.6)]), Color("c8743a"), lw)
			for i in range(3):
				draw_icon(ci, "coin", c + Vector2(-r * 0.45 + i * r * 0.45, -r * 0.55), r * 0.9)
		"x:blueprint":
			_poly_outlined(ci, _rrect(c, r * 1.8, r * 1.8, r * 0.15), Color("2f6fd6"), lw)
			for i in range(3):
				ci.draw_line(c + Vector2(-r * 0.7, -r * 0.45 + i * r * 0.45), c + Vector2(r * 0.7, -r * 0.45 + i * r * 0.45), Color(1, 1, 1, 0.5), lw * 0.6)
			draw_peg(ci, "huni", c + Vector2(-r * 0.3, 0), r * 0.32)
			draw_peg(ci, "gumus", c + Vector2(r * 0.35, r * 0.4), r * 0.3)
		"x:autopay":
			draw_icon(ci, "coin", c + Vector2(-r * 0.2, r * 0.15), r * 1.5)
			draw_icon(ci, "gear", c + Vector2(r * 0.55, -r * 0.55), r * 0.95, Color("dfe4ff"))
		"x:gift":
			_poly_outlined(ci, _rrect(c + Vector2(0, r * 0.25), r * 1.6, r * 1.2, r * 0.12), UI.PINK, lw)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.35), Vector2(r * 0.24, r * 1.2)), UI.GOLD)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.05), Vector2(r * 1.6, r * 0.22)), UI.GOLD)
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.5), r * 0.22, UI.GOLD)
			ci.draw_circle(c + Vector2(r * 0.25, -r * 0.5), r * 0.22, UI.GOLD)
		"x:globe":
			ci.draw_circle(c, r * 0.95, OUTLINE)
			ci.draw_circle(c, r * 0.82, Color("41c8e8"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.55), c + Vector2(r * 0.05, -r * 0.6), c + Vector2(r * 0.1, -r * 0.1), c + Vector2(-r * 0.3, r * 0.1), c + Vector2(-r * 0.6, -r * 0.15)]), UI.MINT)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.25, r * 0.05), c + Vector2(r * 0.65, r * 0.1), c + Vector2(r * 0.5, r * 0.6), c + Vector2(r * 0.15, r * 0.5)]), UI.MINT)
			ci.draw_arc(c, r * 0.82, 0, TAU, 24, Color(1, 1, 1, 0.5), lw * 0.6)
			ci.draw_line(c + Vector2(-r * 0.82, 0), c + Vector2(r * 0.82, 0), Color(1, 1, 1, 0.35), lw * 0.5)
		"x:tag", "x:tag2":
			var tc := UI.GOLD if k == "x:tag" else UI.SKY
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.2), c + Vector2(-r * 0.2, -r * 0.9), c + Vector2(r * 0.9, -r * 0.9), c + Vector2(r * 0.9, r * 0.2), c + Vector2(r * 0.2, r * 0.9)]), tc, lw)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.5), r * 0.16, OUTLINE)
			ci.draw_line(c + Vector2(-r * 0.35, r * 0.05), c + Vector2(r * 0.2, -r * 0.5), OUTLINE, lw)


## Özgün "atıcı robot" (otomatik atıcı simgesi).
static func draw_robot(ci: CanvasItem, c: Vector2, r: float) -> void:
	var lw := maxf(1.2, r * 0.13)
	ci.draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, -r * 0.95), OUTLINE, lw)
	ci.draw_circle(c + Vector2(0, -r * 0.98), r * 0.16, UI.CORAL)
	_poly_outlined(ci, _rrect(c + Vector2(0, r * 0.05), r * 1.7, r * 1.3, r * 0.35), Color("9fb0ff"), lw)
	ci.draw_colored_polygon(_rrect(c + Vector2(0, r * 0.0), r * 1.25, r * 0.6, r * 0.25), Color("1b1f55"))
	ci.draw_circle(c + Vector2(-r * 0.3, 0), r * 0.15, UI.MINT)
	ci.draw_circle(c + Vector2(r * 0.3, 0), r * 0.15, UI.MINT)
	ci.draw_line(c + Vector2(-r * 0.3, r * 0.45), c + Vector2(r * 0.3, r * 0.45), OUTLINE, lw)


static func draw_ball(ci: CanvasItem, c: Vector2, r: float, bid: String, col: Color) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.1), r * 1.04, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, r, col.darkened(0.4))
	ci.draw_circle(c + Vector2(-r * 0.07, -r * 0.07), r * 0.86, col)
	match bid:
		"miknatis":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.2), Vector2(r * 1.6, r * 0.4)), Color("ff4b5c"))
		"volkan":
			ci.draw_circle(c + Vector2(r * 0.2, r * 0.25), r * 0.32, Color("ffd34d"))
		"ikiz":
			ci.draw_circle(c + Vector2(r * 0.35, 0), r * 0.42, col.lightened(0.4))
		"kuyruklu":
			ci.draw_colored_polygon(_star(c, r * 0.55, r * 0.25, 5), Color.WHITE)
		"anka":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.4, r * 0.4), c + Vector2(-r * 0.4, r * 0.4)]), Color("ffe08a"))
		"kara_inci":
			ci.draw_arc(c, r * 0.6, -PI * 0.9, -PI * 0.3, 10, Color("d4b8ff"), r * 0.18)
		"cam":
			ci.draw_arc(c, r * 0.55, PI * 0.1, PI * 0.7, 8, Color(1, 1, 1, 0.85), r * 0.15)
		"altin":
			ci.draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.38, Color("fff1b8"))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.38), r * 0.24, Color(1, 1, 1, 0.7))


## Özel çivi simgeleri: her simge etkisini anlatır (+ kazanç, oklar, kalkan, bölünme, ×, yıldız, bilet, elmas).
static func draw_peg(ci: CanvasItem, pid: String, c: Vector2, r: float) -> void:
	var col := UI.peg_color(pid)
	var dark := OUTLINE
	var lw := maxf(1.0, r * 0.16)
	match pid:
		"bakir_civi", "gumus":
			ci.draw_circle(c, r + lw * 0.5, dark)
			ci.draw_circle(c, r, col)
			var t := r * (0.24 if pid == "bakir_civi" else 0.3)
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, t / 2.0), Vector2(r * 1.2, t)), dark)
			ci.draw_rect(Rect2(c - Vector2(t / 2.0, r * 0.6), Vector2(t, r * 1.2)), dark)
		"yay":
			ci.draw_circle(c, r + lw * 0.5, dark)
			ci.draw_circle(c, r, col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.4), c + Vector2(-r * 0.25, 0), c + Vector2(-r * 0.75, r * 0.4)]), dark, r * 0.24)
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.75, -r * 0.4), c + Vector2(r * 0.25, 0), c + Vector2(r * 0.75, r * 0.4)]), dark, r * 0.24)
		"huni":
			ci.draw_circle(c, r + lw * 0.5, dark)
			ci.draw_circle(c, r, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(r * 0.7, -r * 0.5), c + Vector2(0, r * 0.6)]), dark)
		"kalkan":
			_poly_outlined(ci, PackedVector2Array([c + Vector2(-r, -r * 0.8), c + Vector2(r, -r * 0.8), c + Vector2(r * 0.85, r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.85, r * 0.2)]), col, lw)
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), dark, r * 0.2)
		"ayna":
			ci.draw_circle(c, r + lw * 0.5, dark)
			ci.draw_circle(c, r, col)
			ci.draw_circle(c + Vector2(-r * 0.35, 0), r * 0.3, dark)
			ci.draw_circle(c + Vector2(r * 0.35, 0), r * 0.3, dark)
		"altin_civi", "elmas":
			if pid == "elmas":
				_poly_outlined(ci, PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r, 0), c + Vector2(0, r * 1.1), c + Vector2(-r, 0)]), col, lw)
			else:
				ci.draw_circle(c, r + lw * 0.5, dark)
				ci.draw_circle(c, r, col)
			ci.draw_line(c + Vector2(-r * 0.42, -r * 0.42), c + Vector2(r * 0.42, r * 0.42), dark, r * 0.24)
			ci.draw_line(c + Vector2(r * 0.42, -r * 0.42), c + Vector2(-r * 0.42, r * 0.42), dark, r * 0.24)
		"yildiz":
			_poly_outlined(ci, _star(c, r * 1.15, r * 0.5, 5), col, lw)
		"bilet":
			draw_ticket(ci, c, r * 2.2)
		_:
			ci.draw_circle(c, r, col)
