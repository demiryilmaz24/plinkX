extends Node
## Sabit oyun verisi. Tüm fiyatlar, oranlar ve ödüller data/economy.json dosyasından okunur.
## Oyun çalışırken hiçbir değer dinamik olarak üretilmez.

const ECONOMY_PATH := "res://data/economy.json"

var eco: Dictionary = {}
var balls: Array = []
var pegs: Array = []
var tree: Array = []
var achievements: Array = []
var balls_by_id: Dictionary = {}
var pegs_by_id: Dictionary = {}
var tree_by_id: Dictionary = {}
var achievements_by_id: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open(ECONOMY_PATH, FileAccess.READ)
	if f == null:
		push_error("Ekonomi verisi bulunamadı: " + ECONOMY_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("Ekonomi verisi okunamadı")
		return
	eco = parsed
	balls = eco["balls"]
	pegs = eco["pegs"]
	tree = eco["tree"]
	achievements = eco["achievements"]
	for b in balls:
		balls_by_id[b["id"]] = b
	for p in pegs:
		pegs_by_id[p["id"]] = p
	for n in tree:
		tree_by_id[n["id"]] = n
	for a in achievements:
		achievements_by_id[a["id"]] = a


func x_value() -> float:
	return float(eco["x_value"])


func rows() -> int:
	return int(eco["rows"])


func day_count() -> int:
	return eco["days"].size()


## Gün bilgisi (1 tabanlı). Serbest Modda son günün tarifesi kullanılır.
func day_info(day: int) -> Dictionary:
	var days: Array = eco["days"]
	return days[clampi(day, 1, days.size()) - 1]


func total_debt() -> float:
	var s := 0.0
	for d in eco["days"]:
		s += float(d["target"])
	return s


func rarity_index(r: String) -> int:
	return (eco["rarities"] as Array).find(r)


func balls_of_rarity(r: String) -> Array:
	var out: Array = []
	for b in balls:
		if b["rarity"] == r and not b.get("starter", false):
			out.append(b)
	return out


func pegs_of_rarity(r: String) -> Array:
	var out: Array = []
	for p in pegs:
		if p["rarity"] == r:
			out.append(p)
	return out


func starter_ball_id() -> String:
	for b in balls:
		if b.get("starter", false):
			return b["id"]
	return balls[0]["id"]
