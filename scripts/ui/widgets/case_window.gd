extends VBoxContainer
## Kasa açma penceresi (Top Çarkı / Çivi Çarkı). AÇ'a basınca sonuç o anda sabit verilerle belirlenir
## (BallCollection.spin / PegSystem.spin); ardından olası öğeler yatay bir şeritte hızla akar, yavaşlar ve
## sonucun üstünde durur. Şerit yalnızca gösterimdir: diğer kartlar aynı oranlarla rastgele seçilir.
## Şeride tıklamak animasyonu atlar. Pencere dönerken kapanırsa sonuç bildirim olarak gösterilir.

signal request_close
signal request_edit

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const BallCollection := preload("res://scripts/systems/ball_collection.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")
const TraitChips := preload("res://scripts/ui/widgets/trait_chips.gd")

const STRIP := 58
const WIN_AT := 50


class CaseReel extends Control:
	signal stopped
	const UIK := preload("res://scripts/ui/ui_kit.gd")
	const IconK := preload("res://scripts/ui/icon.gd")
	const CARD := Vector2(128, 156)
	const GAP := 10.0
	const PAD := 12.0
	const SILHOUETTE := Color("15183a")
	const OUT := Color("0b0618")

	var items: Array = []        # [{kind, rarity, known}]
	var offset := 0.0
	var spinning := false
	var win := -1
	var reveal_t := -1.0
	var _from := 0.0
	var _to := 0.0
	var _t := 0.0
	var _dur := 3.4
	var _last_idx := -1
	var _tick_cd := 0.0
	var _sparks: Array = []      # [pos, vel, life, color]
	var _font: Font
	var _center_i := -1
	## Kazanan kartın üstüne basılan damga ("SENDE VAR", "SATILDI"); boşsa çizilmez.
	var stamp := ""
	var stamp_col := Color.WHITE
	var _stamp_t := -1.0

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_font = UIK.display_font()
		resized.connect(_on_resized)

	func _on_resized() -> void:
		if not spinning and win < 0 and _center_i >= 0:
			offset = center_offset(_center_i)

	func step() -> float:
		return CARD.x + GAP

	func center_offset(i: int) -> float:
		return PAD + i * step() + CARD.x / 2.0 - size.x / 2.0

	## delay: damganın kartın açılmasından ne kadar sonra basılacağı (sn)
	func set_stamp(text: String, col: Color, delay: float = 0.0) -> void:
		stamp = text
		stamp_col = col
		_stamp_t = -delay
		if delay <= 0.0:
			Sfx.play("peg", 0.6, -4.0)

	func show_items(list: Array, center_i: int) -> void:
		items = list
		win = -1
		reveal_t = -1.0
		stamp = ""
		_center_i = center_i
		offset = center_offset(center_i)
		queue_redraw()

	func spin(list: Array, win_i: int, duration: float) -> void:
		items = list
		win = win_i
		_from = center_offset(3)
		_to = center_offset(win_i) + randf_range(-0.42, 0.42) * CARD.x
		offset = _from
		_t = 0.0
		_dur = duration
		_last_idx = -1
		reveal_t = -1.0
		stamp = ""
		_sparks.clear()
		spinning = true

	func skip() -> void:
		if spinning:
			_t = _dur

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			skip()
			accept_event()

	func _process(delta: float) -> void:
		if spinning:
			_t += delta
			var p := clampf(_t / _dur, 0.0, 1.0)
			offset = lerpf(_from, _to, 1.0 - pow(1.0 - p, 4.0))
			var idx := int(floorf((offset + size.x / 2.0 - PAD + GAP / 2.0) / step()))
			_tick_cd -= delta
			if idx != _last_idx:
				_last_idx = idx
				if _tick_cd <= 0.0:
					_tick_cd = 0.045
					Sfx.play("tick", randf_range(1.0, 1.25), -12.0)
			if p >= 1.0:
				spinning = false
				reveal_t = 0.0
				_burst()
				stopped.emit()
		if stamp != "":
			if _stamp_t < 0.0 and _stamp_t + delta >= 0.0:
				Sfx.play("peg", 0.6, -4.0)
			_stamp_t += delta
		if reveal_t >= 0.0:
			reveal_t += delta
			var keep: Array = []
			for s in _sparks:
				s[2] -= delta
				if s[2] > 0.0:
					s[1] += Vector2(0, 420) * delta
					s[0] += s[1] * delta
					keep.append(s)
			_sparks = keep
		queue_redraw()

	func _burst() -> void:
		if win < 0 or win >= items.size():
			return
		var rc := UIK.rarity_color(items[win]["rarity"])
		var n: int = [14, 22, 34, 50][maxi(0, GameData.rarity_index(items[win]["rarity"]))]
		var c := Vector2(size.x / 2.0, size.y / 2.0 - 10)
		for i in range(n):
			var a := randf() * TAU
			var sp := randf_range(140, 420)
			var col: Color = [rc, rc.lightened(0.4), Color.WHITE, UIK.GOLD][i % 4]
			_sparks.append([c, Vector2(cos(a), sin(a) - 0.6) * sp, randf_range(0.5, 1.1), col])

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("140c2c"))
		# iç gölge bantları
		for k in range(4):
			draw_rect(Rect2(0, k * 4, size.x, 4), Color(0, 0, 0, 0.25 - k * 0.06))
			draw_rect(Rect2(0, size.y - (k + 1) * 4, size.x, 4), Color(0, 0, 0, 0.25 - k * 0.06))
		# kazanan kartın arkasında dönen ışınlar
		if reveal_t >= 0.0 and win >= 0:
			var rc := UIK.rarity_color(items[win]["rarity"])
			var wc := Vector2(PAD + win * step() + CARD.x / 2.0 - offset, size.y / 2.0)
			for i in range(10):
				var a := reveal_t * 0.8 + i * TAU / 10.0
				var pts := PackedVector2Array([wc, wc + Vector2(cos(a - 0.12), sin(a - 0.12)) * 360.0, wc + Vector2(cos(a + 0.12), sin(a + 0.12)) * 360.0])
				draw_colored_polygon(pts, Color(rc, 0.16 * clampf(reveal_t * 3.0, 0.0, 1.0)))
		var first := maxi(0, int(floorf((offset - PAD) / step())) - 1)
		var last := mini(items.size() - 1, first + int(size.x / step()) + 3)
		for i in range(first, last + 1):
			_draw_card(i, PAD + i * step() - offset)
		# kenar karartmaları
		var fw := 150.0
		var dark := Color(0.05, 0.02, 0.12, 0.92)
		var clear := Color(0.05, 0.02, 0.12, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(fw, 0), Vector2(fw, size.y), Vector2(0, size.y)]),
			PackedColorArray([dark, clear, clear, dark]))
		draw_polygon(PackedVector2Array([Vector2(size.x - fw, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - fw, size.y)]),
			PackedColorArray([clear, dark, dark, clear]))
		# orta işaretçi
		var mx := floorf(size.x / 2.0)
		draw_rect(Rect2(mx - 3, 0, 6, size.y), OUT)
		draw_rect(Rect2(mx - 1, 0, 2, size.y), UIK.GOLD)
		for sgn in [1.0, -1.0]:
			var y0 := 0.0 if sgn > 0 else size.y
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 14, y0), Vector2(mx + 14, y0), Vector2(mx, y0 + sgn * 18)]), OUT)
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 10, y0), Vector2(mx + 10, y0), Vector2(mx, y0 + sgn * 13)]), UIK.GOLD)
		for s in _sparks:
			var sz := 4.0 if s[2] > 0.4 else 2.0
			draw_rect(Rect2((s[0] as Vector2) - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(s[3], clampf(s[2] * 2.0, 0.0, 1.0)))
		# damga en üstte: orta işaretçinin de üzerine basılır
		if stamp != "" and _stamp_t >= 0.0 and win >= 0 and reveal_t >= 0.0:
			_draw_stamp(Rect2(Vector2(PAD + win * step() - offset, (size.y - CARD.y) / 2.0), CARD))

	func _draw_card(i: int, x: float) -> void:
		var it: Dictionary = items[i]
		var rc := UIK.rarity_color(it["rarity"])
		var r := Rect2(Vector2(x, (size.y - CARD.y) / 2.0), CARD)
		var is_win := i == win and reveal_t >= 0.0
		if is_win:
			var pop := 1.0 + 0.06 * maxf(0.0, 1.0 - reveal_t * 3.0)
			r = r.grow_individual(CARD.x * (pop - 1.0), CARD.y * (pop - 1.0), CARD.x * (pop - 1.0), CARD.y * (pop - 1.0))
		draw_rect(r.grow(3), OUT)
		draw_rect(r, Color("2a2350"))
		# alttan yükselen nadirlik ışığı (bantlı)
		for k in range(5):
			draw_rect(Rect2(r.position.x, r.end.y - 14 - (k + 1) * 14, r.size.x, 14), Color(rc, 0.05 * (5 - k)))
		draw_rect(Rect2(r.position.x, r.end.y - 14, r.size.x, 14), Color(rc, 0.3))
		draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), rc)
		draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 2), rc.lightened(0.45))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(1, 1, 1, 0.06))
		var ic := r.position + Vector2(r.size.x / 2.0, r.size.y * 0.44)
		for k in range(3):
			draw_circle(ic, 44.0 - k * 12.0, Color(rc, 0.07 + 0.05 * k))
		var known: bool = it["known"] or (is_win and reveal_t >= 0.0)
		IconK.draw_sprite(self, it["kind"], Rect2(ic - Vector2(40, 40), Vector2(80, 80)), Color(0, 0, 0, 0) if known else SILHOUETTE, i * 0.37)
		if not known:
			var w := _font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
			draw_string_outline(_font, ic + Vector2(-w / 2.0, 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, OUT)
			draw_string(_font, ic + Vector2(-w / 2.0, 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
		if is_win:
			var pulse := 0.6 + 0.4 * sin(reveal_t * 8.0)
			draw_rect(r.grow(2), Color(rc.lightened(0.3), pulse), false, 4.0)
			draw_rect(r.grow(6), Color(rc, pulse * 0.5), false, 2.0)

	## Kartın alt yarısına basılan şerit damga; basılırken büyükten küçülerek oturur.
	func _draw_stamp(r: Rect2) -> void:
		var k := clampf(_stamp_t / 0.16, 0.0, 1.0)
		var sc := lerpf(1.7, 1.0, 1.0 - pow(1.0 - k, 3.0))
		var fsz := 22
		var tw := _font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var band := Vector2(roundf(maxf(tw + 20.0, r.size.x - 12.0)), 30.0)
		var c := Vector2(roundf(r.get_center().x), roundf(r.position.y + r.size.y * 0.68))
		draw_set_transform(c, 0.0, Vector2(sc, sc))
		var br := Rect2(-band / 2.0, band)
		draw_rect(br.grow(3), OUT)
		draw_rect(br, stamp_col)
		draw_rect(Rect2(br.position, Vector2(br.size.x, 3)), stamp_col.lightened(0.35))
		draw_rect(Rect2(br.position + Vector2(0, br.size.y - 3), Vector2(br.size.x, 3)), stamp_col.darkened(0.3))
		var base_y := (_font.get_ascent(fsz) - _font.get_descent(fsz)) / 2.0
		draw_string(_font, Vector2(roundf(-tw / 2.0), roundf(base_y)), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("1a0c08"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## SAT düğmesine dikkat çeken işaretçi: düğmenin çevresinde nabız gibi atan çerçeve ve sağında ona doğru zıplayan ok
## (üstteki yetenek çiplerinin üzerine binmesin diye yanda). top_level olduğu için yerleşimi bozmaz; her kare düğmeyi izler.
class SellPointer extends Control:
	const OUT := Color("0b0618")
	const PAD := 12.0       # çerçeve payı
	const ARROW := 56.0     # sağdaki ok alanı
	var target: Control
	var color := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _process(delta: float) -> void:
		if not visible or target == null or not is_instance_valid(target):
			return
		_t += delta
		global_position = (target.global_position - Vector2(PAD, PAD)).round()
		size = target.size + Vector2(PAD * 2.0 + ARROW, PAD * 2.0)
		queue_redraw()

	func _draw() -> void:
		if target == null or not target.is_visible_in_tree():
			return
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		var br := Rect2(Vector2(PAD, PAD) - Vector2(4, 4), target.size + Vector2(8, 8))
		draw_rect(br, Color(color, 0.45 + 0.55 * pulse), false, 3.0)
		draw_rect(br.grow(5), Color(color, 0.12 + 0.3 * pulse), false, 2.0)
		# sola bakan, düğmeye doğru zıplayan ok (piksel: gövde + üçgen uç, koyu konturlu)
		var bob := roundf(absf(sin(_t * 5.0)) * 8.0)
		var cy := roundf(PAD + target.size.y / 2.0)
		var tip := Vector2(PAD + target.size.x + 12.0 + bob, cy)
		var head := PackedVector2Array([tip, tip + Vector2(12, -12), tip + Vector2(12, 12)])
		var head_o := PackedVector2Array([tip + Vector2(-4, 0), tip + Vector2(14, -17), tip + Vector2(14, 17)])
		draw_rect(Rect2(tip.x + 9, cy - 7, 19, 14), OUT)
		draw_colored_polygon(head_o, OUT)
		draw_rect(Rect2(tip.x + 11, cy - 4, 14, 8), color)
		draw_colored_polygon(head, color)


var kind := "ball"
var _reel: CaseReel
var _open_btn: Button
var _use_btn: Button
var _sell_btn: Button
var _sell_ptr: SellPointer
var _prev_ball := ""
var _res_title: Label
var _res_sub: Label
var _res_chips: Control
var _cash: Label
var _odds: Array = []
var _pending: Dictionary = {}
var _last: Dictionary = {}
var _refresh_t := 0.0


func setup(kind_: String) -> void:
	kind = kind_
	add_theme_constant_override("separation", 12)
	# başlık
	var head := UI.hbox(10)
	head.add_child(Icon.make("menu:collection" if kind == "ball" else "menu:pegs", 44))
	head.add_child(UI.title(Loc.t("wheel.%s_title" % kind), 32, UI.GOLD, 8))
	var info := UI.title("?", 22, UI.SKY, 5)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.tooltip_text = _pool_tip()
	head.add_child(info)
	head.add_child(UI.spacer())
	var cash_box := PanelContainer.new()
	cash_box.add_theme_stylebox_override("panel", UI.style(Color("2b2f86"), UI.GOLD, 0, 1, 8))
	var ch := UI.hbox(6)
	ch.add_child(Icon.make("coin", 26))
	_cash = UI.title("", 22, UI.GOLD, 5)
	ch.add_child(_cash)
	cash_box.add_child(ch)
	head.add_child(cash_box)
	var x := UI.button("✕", func(): request_close.emit(), 50)
	x.custom_minimum_size.y = 50
	x.add_theme_font_size_override("font_size", 22)
	UI.paint_button(x, UI.CORAL)
	head.add_child(x)
	add_child(head)
	# şerit
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("0b0618"), UI.GOLD_DARK, 0, 1, 4))
	_reel = CaseReel.new()
	_reel.custom_minimum_size = Vector2(900, 196)
	_reel.stopped.connect(_on_stopped)
	frame.add_child(_reel)
	add_child(frame)
	# nadirlik oranları
	var oh := UI.hbox(10)
	oh.alignment = BoxContainer.ALIGNMENT_CENTER
	for r in GameData.eco["rarities"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.style(Color("1d1a45"), UI.rarity_color(r), 0, 1, 6))
		var h := UI.hbox(6)
		h.add_child(Icon.make("rarity:" + r, 20))
		var l := UI.title("", 16, UI.rarity_color(r).lightened(0.3), 4)
		h.add_child(l)
		chip.add_child(h)
		oh.add_child(chip)
		_odds.append(l)
	add_child(oh)
	# sonuç
	_res_title = UI.title("", 28, UI.TEXT, 7)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_title.custom_minimum_size.y = 36
	add_child(_res_title)
	_res_sub = UI.title(Loc.t("wheel.hint"), 11, UI.MUTED, 2)
	_res_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_res_sub)
	_res_chips = TraitChips.new()
	_res_chips.font_size = 22
	_res_chips.visible = false
	add_child(_res_chips)
	# düğmeler
	var bh := UI.hbox(12)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	_open_btn = UI.button("", _on_open, 360)
	_open_btn.custom_minimum_size.y = 64
	_open_btn.add_theme_font_size_override("font_size", 26)
	UI.paint_button(_open_btn, UI.GOLD, Color("3a1800"))
	bh.add_child(_open_btn)
	_use_btn = UI.button("", _on_use, 200)
	_use_btn.custom_minimum_size.y = 64
	_use_btn.add_theme_font_size_override("font_size", 22)
	UI.paint_button(_use_btn, UI.MINT if kind == "ball" else Color("2f9c8f"))
	_use_btn.visible = false
	bh.add_child(_use_btn)
	# satış: ödülü istemiyorsan nadirliğe göre fiyatla nakde çevir
	_sell_btn = UI.button("", _on_sell, 200)
	_sell_btn.custom_minimum_size.y = 64
	_sell_btn.add_theme_font_size_override("font_size", 22)
	_sell_btn.visible = false
	var ci := Icon.make("coin", 30)
	ci.position = Vector2(12, 14)
	_sell_btn.add_child(ci)
	var ratios: Array = GameData.eco["%s_slot" % kind]["sell"]
	var rars: Array = GameData.eco["rarities"]
	var parts: Array = []
	for i in range(rars.size()):
		parts.append("%s %s" % [Loc.t("rarity." + String(rars[i])), Fmt.mult(float(ratios[i]))])
	_sell_btn.tooltip_text = Loc.t("wheel.sell_tip", {"list": " • ".join(parts)})
	bh.add_child(_sell_btn)
	add_child(bh)
	_sell_ptr = SellPointer.new()
	_sell_ptr.target = _sell_btn
	add_child(_sell_ptr)
	_reel.show_items(_make_strip(12, -1, "", ""), 5)
	refresh()


func _odds_now() -> Array:
	return BallCollection.odds(Game) if kind == "ball" else PegSystem.odds(Game)


func _cost() -> float:
	return BallCollection.spin_cost(Game) if kind == "ball" else PegSystem.spin_cost(Game)


## Gösterim şeridi: kazanan dışındaki kartlar güncel oranlarla rastgele (sonucu etkilemez).
func _make_strip(n: int, win_i: int, win_id: String, win_rar: String, win_known: bool = true) -> Array:
	var odds := _odds_now()
	var rars: Array = GameData.eco["rarities"]
	var out: Array = []
	for i in range(n):
		if i == win_i:
			out.append({"kind": _prefix() + win_id, "rarity": win_rar, "known": win_known})
			continue
		var x := randf()
		var rar: String = rars[rars.size() - 1]
		for k in range(odds.size()):
			x -= float(odds[k])
			if x < 0.0:
				rar = rars[k]
				break
		var pool: Array = GameData.balls_of_rarity(rar) if kind == "ball" else GameData.pegs_of_rarity(rar)
		var id: String = pool[randi() % pool.size()]["id"]
		out.append({"kind": _prefix() + id, "rarity": rar, "known": true})
	return out


func _prefix() -> String:
	return "ball:" if kind == "ball" else "peg:"


func _on_open() -> void:
	if _reel.spinning:
		return
	_settle_last()
	var res: Dictionary = BallCollection.spin(Game) if kind == "ball" else PegSystem.spin(Game)
	if not bool(res["ok"]):
		Sfx.play("error", 1.0, -8.0)
		return
	_pending = res
	_prev_ball = Game.selected_ball()
	var id: String = res["ball"] if kind == "ball" else res["peg"]
	var known := true
	var dur := 0.7 if bool(Game.settings.get("reduced_motion", false)) else 3.4
	_reel.spin(_make_strip(STRIP, WIN_AT, id, String(res["rarity"]), known), WIN_AT, dur)
	_res_title.text = ""
	_res_chips.visible = false
	_res_sub.text = Loc.t("wheel.skip")
	_res_sub.add_theme_color_override("font_color", UI.MUTED)
	_use_btn.visible = false
	_sell_btn.visible = false
	_sell_ptr.visible = false
	Sfx.play("buy", 0.9, -6.0)
	refresh()


func _result_lines(res: Dictionary) -> Array:
	var rar: String = res["rarity"]
	if kind == "ball":
		var bid: String = res["ball"]
		var nm := Loc.t("ball." + bid + ".name")
		if bool(res["new"]):
			return [Loc.t("wheel.new") + "  " + nm, Loc.t("rarity." + rar)]
		# zaten sahip olunan top: açıkça söyle ve satışa yönlendir
		var m := int(GameData.eco["ball_slot"]["max_mastery"])
		if bool(res["maxed"]):
			return [Loc.t("wheel.owned", {"name": nm}), Loc.t("wheel.owned_full", {"m": m})]
		return [Loc.t("wheel.owned", {"name": nm}), Loc.t("wheel.owned_star", {"n": int(res["star"]), "m": m})]
	var pid: String = res["peg"]
	var pn := Loc.t("peg." + pid + ".name")
	if float(res["dup_refund"]) > 0.0:
		return [pn, Loc.t("wheel.refund", {"v": Fmt.money(float(res["dup_refund"]))})]
	return [pn + "  ×%d" % int(res["count"]), Loc.t("peg." + pid + ".desc", PegSystem.desc_args(pid))]


func _on_stopped() -> void:
	if _pending.is_empty():
		return
	var res := _pending
	_pending = {}
	_last = res
	var rar: String = res["rarity"]
	var lines := _result_lines(res)
	var dup := kind == "ball" and BallCollection.is_duplicate(res)
	_res_title.text = lines[0]
	_res_title.add_theme_color_override("font_color", UI.ORANGE if dup else UI.rarity_color(rar).lightened(0.25))
	_res_sub.text = lines[1]
	_res_sub.add_theme_color_override("font_color", UI.TEXT)
	Sfx.play("slot_" + rar, 1.0, -3.0)
	if kind == "ball":
		_res_chips.show_ball(String(res["ball"]), BallCollection.stars(Game, String(res["ball"])))
		_res_chips.visible = true
		_use_btn.text = Loc.t("wheel.use")
		# kopyada dikkat satışta: Kullan düğmesi gizlenir (top koleksiyondan her an seçilebilir)
		_use_btn.visible = not dup and Game.selected_ball() != String(res["ball"])
		if dup:
			_reel.set_stamp(Loc.t("wheel.owned_stamp"), UI.ORANGE, 0.35)
	else:
		_use_btn.text = Loc.t("wheel.place")
		_use_btn.visible = float(res["dup_refund"]) <= 0.0
	_show_sell(res)
	_sell_ptr.color = UI.GOLD
	_sell_ptr.visible = dup and _sell_btn.visible
	refresh()


func _sell_price(res: Dictionary) -> float:
	return BallCollection.sell_price(res) if kind == "ball" else PegSystem.sell_price(res)


## Satış düğmesi: rengi ödülün nadirliği, üstünde fiyat
func _show_sell(res: Dictionary) -> void:
	var price := _sell_price(res)
	_sell_btn.visible = price > 0.0
	if price <= 0.0:
		return
	var rc := UI.rarity_color(String(res["rarity"]))
	UI.paint_button(_sell_btn, rc.darkened(0.15), Color("1a0c08") if rc.get_luminance() > 0.55 else Color.WHITE)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = _sell_btn.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = 48
		_sell_btn.add_theme_stylebox_override(st, sb)
	_sell_btn.text = Loc.t("wheel.sell", {"v": Fmt.money(price)})


func _on_sell() -> void:
	if _last.is_empty() or _reel.spinning:
		return
	var got := BallCollection.sell(Game, _last, _prev_ball) if kind == "ball" else PegSystem.sell(Game, _last)
	if got <= 0.0:
		Sfx.play("error", 1.0, -8.0)
		return
	Sfx.play("pay", 1.1, -4.0)
	_res_title.text = Loc.t("wheel.sold", {"v": Fmt.money(got)})
	_res_title.add_theme_color_override("font_color", UI.GOLD)
	_res_sub.text = ""
	_res_chips.visible = false
	_use_btn.visible = false
	_sell_btn.visible = false
	_sell_ptr.visible = false
	_reel.set_stamp(Loc.t("wheel.sold_stamp"), UI.GOLD)
	refresh()


func _on_use() -> void:
	if _last.is_empty():
		return
	if kind == "ball":
		BallCollection.select(Game, String(_last["ball"]))
		Sfx.play("buy", 1.1, -6.0)
		_use_btn.visible = false
	else:
		request_edit.emit()


## Yıldızları dolu kopya satılmadan bırakıldıysa (yeni açılış / pencere kapanışı) otomatik satılır.
func _settle_last() -> void:
	if kind != "ball" or _last.is_empty():
		return
	var got := BallCollection.settle(Game, _last)
	if got > 0.0:
		Game.toast.emit(Loc.t("wheel.auto_sold", {"name": Loc.t("ball." + String(_last["ball"]) + ".name"), "v": Fmt.money(got)}), "good")


func _exit_tree() -> void:
	_settle_last()
	# dönerken kapatıldıysa sonucu kaybetme: bildirim olarak göster
	if not _pending.is_empty():
		var res := _pending
		_pending = {}
		var msg := ""
		if kind == "ball" and BallCollection.is_duplicate(res):
			var nm := Loc.t("ball." + String(res["ball"]) + ".name")
			var got := BallCollection.settle(Game, res)
			if got > 0.0:
				msg = Loc.t("wheel.auto_sold", {"name": nm, "v": Fmt.money(got)})
			else:
				msg = Loc.t("wheel.owned_kept", {"name": nm, "n": int(res["star"]), "m": int(GameData.eco["ball_slot"]["max_mastery"])})
		else:
			var lines := _result_lines(res)
			msg = "%s — %s" % [lines[0], lines[1]]
		Game.toast.emit(msg, "good")
		Sfx.play("slot_" + String(res["rarity"]), 1.0, -6.0)


func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= 0.2:
		_refresh_t = 0.0
		refresh()


func refresh() -> void:
	var c := _cost()
	_cash.text = Fmt.money(float(Game.run["cash"]))
	_open_btn.text = Loc.t("wheel.again" if not _last.is_empty() else "wheel.open", {"v": Fmt.money(c)})
	_open_btn.disabled = _reel.spinning or float(Game.run["cash"]) < c
	var odds := _odds_now()
	var rars: Array = GameData.eco["rarities"]
	for i in range(odds.size()):
		_odds[i].text = "%s %s" % [Loc.t("rarity." + String(rars[i])), Fmt.pct(float(odds[i]), 0)]


func _pool_tip() -> String:
	var lines: Array = [Loc.t("slots.%s_desc" % kind, {"m": int(GameData.eco["ball_slot"]["max_mastery"]), "p": int(round(float(GameData.eco["peg_slot"]["dup_refund"]) * 100.0))})]
	lines.append(Loc.t("slots.spins", {"n": int(Game.run["%s_spins" % kind]), "g": Fmt.dec(float(GameData.eco["%s_slot" % kind]["cost_growth"]), 2)}))
	for r in GameData.eco["rarities"]:
		var items: Array = GameData.balls_of_rarity(r) if kind == "ball" else GameData.pegs_of_rarity(r)
		var parts: Array = []
		for it in items:
			var id: String = it["id"]
			if kind == "ball":
				parts.append(Loc.t("ball." + id + ".name"))
			else:
				parts.append(Loc.t("peg." + id + ".name"))
		lines.append("%s: %s" % [Loc.t("rarity." + r), ", ".join(parts)])
	return "\n".join(lines)
