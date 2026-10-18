extends RefCounted
## Sonuç aralıkları ve olasılık hesabı.
##
## Top yolu ayrık Galton adımlarıdır: r. sıradaki j. çiviye çarpan top r+1. sırada j veya j+1
## konumuna geçer. Son sıradan sonra k kovasına (0..rows) iner ve kova içinde düzgün dağılımlı
## bir noktaya düşer: u = k + U(0,1). Alt eksen u ∈ [0, rows+1] aralık bantlarına bölünür.
## Aynı hesap hem animasyondaki gerçek sonucu hem de arayüzde gösterilen olasılıkları üretir;
## bu yüzden gösterilen olasılık ile gerçek sonuç birbirinden ayrılamaz.

const TYPES := ["M", "W", "L", "E"]


static func rows() -> int:
	return GameData.rows()


static func center() -> float:
	return (rows() + 1) / 2.0


static func max_board_level() -> int:
	return (GameData.eco["board_levels"] as Array).size()


## Merkezden dışa sınırlar: [[tür, iç, dış], ...] (kova biriminde, merkeze uzaklık)
static func bounds(board_level: int) -> Array:
	var bl: Array = GameData.eco["board_levels"]
	var lv: Array = bl[clampi(board_level, 1, bl.size()) - 1]
	var half := center()
	return [
		["M", 0.0, float(lv[0])],
		["W", float(lv[0]), float(lv[1])],
		["L", float(lv[1]), float(lv[2])],
		["E", float(lv[2]), half],
	]


## Soldan sağa 7 bant: [{type, lo, hi}] (u ekseninde)
static func bands(board_level: int) -> Array:
	var c := center()
	var b := bounds(board_level)
	var out: Array = []
	for i in range(3, 0, -1):
		out.append({"type": b[i][0], "lo": c - b[i][2], "hi": c - b[i][1]})
	out.append({"type": "M", "lo": c - b[0][2], "hi": c + b[0][2]})
	for i in range(1, 4):
		out.append({"type": b[i][0], "lo": c + b[i][1], "hi": c + b[i][2]})
	return out


## u konumunun düştüğü aralık türü.
static func type_at(u: float, board_level: int) -> String:
	var d := absf(u - center())
	for e in bounds(board_level):
		if d <= e[2]:
			return e[0]
	return "E"


## Merkeze yönelme olasılığı b iken (r, j) çivisinde sağa gitme olasılığı.
static func toward_center_q(r: int, j: int, b: float) -> float:
	var off := j - r / 2.0
	if off < -0.001:
		return b
	if off > 0.001:
		return 1.0 - b
	return 0.5


static func peg_bias_at(layout: Dictionary, cell: Vector2i, ball_bias: float) -> float:
	var pid: String = layout.get(cell, "")
	if pid != "":
		var peg: Dictionary = GameData.pegs_by_id[pid]
		if peg.has("bias"):
			return maxf(ball_bias, float(peg["bias"]))
	return ball_bias


## Kesin dağılım: final[k] = k kovasına inme olasılığı, hits[(r,j)] = o çiviye çarpma olasılığı.
static func distribution(ball_bias: float, layout: Dictionary) -> Dictionary:
	var R := rows()
	var P: Array = [1.0]
	var hits := {}
	for r in range(R):
		var n: Array = []
		n.resize(r + 2)
		n.fill(0.0)
		for j in range(P.size()):
			var p: float = P[j]
			var cell := Vector2i(r, j)
			hits[cell] = p
			var q := toward_center_q(r, j, peg_bias_at(layout, cell, ball_bias))
			n[j] += p * (1.0 - q)
			n[j + 1] += p * q
		P = n
	return {"final": P, "hits": hits}


static func _overlap(k: int, lo: float, hi: float) -> float:
	return maxf(0.0, minf(hi, k + 1.0) - maxf(lo, float(k)))


## 7 bandın her birinin olasılığı (soldan sağa) ve tür toplamları.
static func band_probabilities(board_level: int, ball_bias: float, layout: Dictionary) -> Dictionary:
	var dist := distribution(ball_bias, layout)
	var fin: Array = dist["final"]
	var bl := bands(board_level)
	var per_band: Array = []
	var per_type := {"M": 0.0, "W": 0.0, "L": 0.0, "E": 0.0}
	for band in bl:
		var p := 0.0
		for k in range(fin.size()):
			p += float(fin[k]) * _overlap(k, band["lo"], band["hi"])
		per_band.append(p)
		per_type[band["type"]] += p
	return {"bands": per_band, "types": per_type, "win": per_type["M"] + per_type["W"], "hits": dist["hits"]}


## Rastgele yol üretimi (animasyonun izleyeceği gerçek yol).
## start_r sırasında start_j konumundan başlar. Döner: hits (Vector2i dizisi), k, u.
static func roll_path(rng: RandomNumberGenerator, ball_bias: float, layout: Dictionary, start_r: int = 0, start_j: int = 0) -> Dictionary:
	var R := rows()
	var j := start_j
	var hits: Array = []
	var dirs: Array = []
	for r in range(start_r, R):
		var cell := Vector2i(r, j)
		hits.append(cell)
		var q := toward_center_q(r, j, peg_bias_at(layout, cell, ball_bias))
		if rng.randf() < q:
			dirs.append(1)
			j += 1
		else:
			dirs.append(0)
	var u := j + rng.randf()
	return {"hits": hits, "dirs": dirs, "k": j, "u": u}
