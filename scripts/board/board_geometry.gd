extends RefCounted
## Tahta geometrisi (tahta uzayı: 640 x 636, 8 sıra, 9 kova). Görünüm bu uzayı ekrana ölçekler.
## Hem animasyon (top konumu) hem çizim aynı fonksiyonları kullanır; böylece topun görsel
## olarak indiği nokta ile ekonomik sonucun belirlendiği u konumu birebir aynıdır.

const SIZE := Vector2(640, 636)
const CX := 320.0
const SX := 64.0          # yatay çivi aralığı (= 1 kova genişliği)
const SY := 60.0          # sıra aralığı
const TOP_Y := 104.0      # ilk çivi sırası
const PEG_R := 8.0
const BALL_R := 12.0
const SPAWN_Y := 30.0
const BAND_TOP := 566.0   # aralık bantlarının üst kenarı
const BAND_H := 64.0
const LAND_Y := 582.0     # topun indiği yükseklik


static func peg_pos(r: int, j: int) -> Vector2:
	return Vector2(CX + (j - r / 2.0) * SX, TOP_Y + r * SY)


## Topun (r, j) çivisine değdiği nokta; dir: 1 sağa, 0 sola sekecek.
static func contact(r: int, j: int, dir: int) -> Vector2:
	var p := peg_pos(r, j)
	var side := 3.5 if dir == 1 else -3.5
	return Vector2(p.x - side, p.y - (PEG_R + BALL_R) + 1.0)


## Alt eksendeki u konumunun x koordinatı (u ∈ [0, rows+1]).
static func u_to_x(u: float, rows: int) -> float:
	return CX + (u - (rows + 1) / 2.0) * SX


static func x_to_u(x: float, rows: int) -> float:
	return (x - CX) / SX + (rows + 1) / 2.0


static func board_left(rows: int) -> float:
	return u_to_x(0.0, rows)


static func board_right(rows: int) -> float:
	return u_to_x(rows + 1.0, rows)


## Ekran noktasına en yakın yerleştirilebilir çivi hücresi (yoksa (-1,-1)).
static func cell_at(p: Vector2, rows: int) -> Vector2i:
	var r := int(roundf((p.y - TOP_Y) / SY))
	if r < 0 or r >= rows:
		return Vector2i(-1, -1)
	var j := int(roundf((p.x - CX) / SX + r / 2.0))
	if j < 0 or j > r:
		return Vector2i(-1, -1)
	if peg_pos(r, j).distance_to(p) > SX * 0.45:
		return Vector2i(-1, -1)
	return Vector2i(r, j)
