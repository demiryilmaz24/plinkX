extends Control
## Canlı, desenli arka plan: dikey renk geçişi, çapraz şeritler ve yavaşça süzülen soluk bilyeler/yıldızlar.

const UI := preload("res://scripts/ui/ui_kit.gd")

var _t := 0.0
var _motes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := [UI.PINK, UI.SKY, UI.GOLD, UI.MINT, UI.PURPLE]
	for i in range(26):
		_motes.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(4.0, 14.0),
			"c": cols[i % cols.size()], "s": rng.randf_range(0.004, 0.012), "star": i % 3 == 0})


func _process(delta: float) -> void:
	if bool(Game.settings.get("reduced_motion", false)):
		return
	_t += delta
	for m in _motes:
		m["p"].y -= m["s"] * delta
		if m["p"].y < -0.05:
			m["p"].y = 1.05
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([UI.BG, UI.BG, UI.BG_2, UI.BG_2]))
	# çapraz şeritler
	var step := 46.0
	var x := -h
	var stripe := Color(1, 1, 1, 0.025)
	while x < w:
		draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 18, h), Vector2(x + 18 + h, 0), Vector2(x + h, 0)]), stripe)
		x += step
	# soluk bilyeler ve yıldızlar
	for m in _motes:
		var pos := Vector2(m["p"].x * w, m["p"].y * h)
		var col: Color = m["c"]
		if m["star"]:
			var pts := PackedVector2Array()
			for i in range(8):
				var a := -PI / 2.0 + i * PI / 4.0 + _t * 0.3
				pts.append(pos + Vector2(cos(a), sin(a)) * (m["r"] if i % 2 == 0 else m["r"] * 0.4))
			draw_colored_polygon(pts, Color(col, 0.10))
		else:
			draw_circle(pos, m["r"], Color(col, 0.08))
			draw_circle(pos + Vector2(-m["r"] * 0.3, -m["r"] * 0.3), m["r"] * 0.3, Color(1, 1, 1, 0.06))
