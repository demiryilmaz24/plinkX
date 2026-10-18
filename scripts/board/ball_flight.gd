extends RefCounted
## Havadaki tek bir topun kaydı. Yol atış anında belirlenir; animasyon bu yolu izler ve
## topun indiği u konumu ekonomik sonucu belirler.

const Geo := preload("res://scripts/board/board_geometry.gd")

const DROP_T := 0.30
const FINAL_T := 0.42

var id := 0
var ball_id := ""
var stars := 0
var params: Dictionary = {}
var stake := 0.0          # X (atış anındaki masa bahsi)
var cost_paid := 0.0
var free := false         # ikram atış
var bonus := false        # bölünme / yeniden doğuş topu
var auto := false
var ball_mult := 1.0      # atış anındaki top seviyesi çarpanı
var polish := 1.0         # atış anındaki cila çarpanı
var color := Color.WHITE

# Yol
var from_top := true
var start_point := Vector2.ZERO
var hits: Array = []      # Vector2i
var dirs: Array = []      # 0 sol / 1 sağ
var k := 0
var u := 0.0
var row_t := 0.21
var rows := 8

# Çivi etkileri (yol boyunca birikir)
var peg_prod := 1.0
var peg_add := 0.0
var peg_max_add := 0.0
var peg_loss_mult := 1.0
var special_hits: Array = []   # [{i, cell, peg_id}]

# Zamanlama ve olaylar
var elapsed := 0.0
var events: Array = []         # [{t, kind, ...}] zamana göre sıralı
var next_event := 0
var landed := false
var trail: Array = []


func setup_timing(fall_time: float, rows_: int) -> void:
	rows = rows_
	row_t = (fall_time - DROP_T - FINAL_T) / float(rows)


func hit_time(i: int) -> float:
	if from_top:
		return DROP_T + i * row_t
	return (i + 1) * row_t


func duration() -> float:
	if hits.is_empty():
		return FINAL_T
	return hit_time(hits.size() - 1) + FINAL_T


func landing_point() -> Vector2:
	return Vector2(Geo.u_to_x(u, rows), Geo.LAND_Y)


func _contact_i(i: int) -> Vector2:
	var c: Vector2i = hits[i]
	return Geo.contact(c.x, c.y, dirs[i])


## Topun t anındaki konumu (tahta uzayı).
func position_at(t: float) -> Vector2:
	if hits.is_empty():
		var tau := clampf(t / FINAL_T, 0.0, 1.0)
		var e := landing_point()
		return Vector2(lerpf(start_point.x, e.x, tau), lerpf(start_point.y, e.y, tau * tau))
	if from_top and t < DROP_T:
		var tau := clampf(t / DROP_T, 0.0, 1.0)
		var c0 := _contact_i(0)
		return Vector2(lerpf(start_point.x, c0.x, tau), lerpf(start_point.y, c0.y, tau * tau))
	if not from_top and t < row_t:
		var tau := clampf(t / row_t, 0.0, 1.0)
		var c0 := _contact_i(0)
		return _arc(start_point, c0, tau)
	var last := hits.size() - 1
	for i in range(last):
		var t0 := hit_time(i)
		if t < t0 + row_t:
			return _arc(_contact_i(i), _contact_i(i + 1), clampf((t - t0) / row_t, 0.0, 1.0))
	var tl := hit_time(last)
	var tau2 := clampf((t - tl) / FINAL_T, 0.0, 1.0)
	var a := _contact_i(last)
	var b := landing_point()
	var xs := lerpf(a.x, b.x, 1.0 - pow(1.0 - tau2, 2.0))
	return Vector2(xs, lerpf(a.y, b.y, tau2 * tau2) - 18.0 * 4.0 * tau2 * (1.0 - tau2))


## Çividen sekme: top çivinin tepesinden yana doğru zıplar (belirgin yay), sonra bir alt sıradaki
## çiviye iner. Yön, yolun o çividen aldığı sağ/sol kararıdır (gösterilen olasılıklarla aynı).
func _arc(a: Vector2, b: Vector2, tau: float) -> Vector2:
	var x := lerpf(a.x, b.x, 1.0 - pow(1.0 - tau, 1.6))
	var y := lerpf(a.y, b.y, tau * tau) - 22.0 * 4.0 * tau * (1.0 - tau)
	return Vector2(x, y)
