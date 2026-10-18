extends RefCounted
## Kayıt sistemi (JSON, sürümlü).
## - Oyun kapalıyken hiçbir şey ilerlemez: kayıtta zaman damgası yalnızca bilgi amaçlıdır,
##   yüklemede çevrimdışı kazanç hesaplanmaz.
## - Kayıt anında havadaki ücretli topların ücreti bakiyeye iade edilmiş olarak yazılır;
##   böylece kapanış/çökme anında ne kazanç ne kayıp oluşur.

const SAVE_PATH := "user://son_bilye_save.json"
const SETTINGS_PATH := "user://son_bilye_settings.json"
const VERSION := 2

## Geliştirme sırasında gerçek kaydı korumak için komut satırından ayrı yol seçilebilir (--test-save).
static var save_path := SAVE_PATH
static var settings_path := SETTINGS_PATH


static func use_test_paths() -> void:
	save_path = "user://test_save.json"
	settings_path = "user://test_settings.json"


static func default_stats() -> Dictionary:
	return {
		"shots_total": 0, "auto_shots": 0, "max_total": 0, "jackpots": 0, "bonus_balls": 0,
		"total_won": 0.0, "best_win": 0.0, "run_profit_best": 0.0, "ball_level_best": 1,
		"board_level_best": 1, "peg_tickets": 0, "days_closed": 0, "debt_cleared": 0,
		"jobs_done": 0, "free_ball_level_best": 0, "free_board_level_best": 0,
		"free_profit_best": 0.0, "free_prestiges": 0, "tickets_earned": 0, "tickets_spent": 0,
		"ball_spins": 0, "peg_spins": 0, "cash_spent_shop": 0.0, "play_time": 0.0,
		"calls": 0, "boosts": 0, "fines_paid": 0.0, "collected": 0.0,
		"ball_shots": {},
	}


static func default_meta() -> Dictionary:
	var starter := GameData.starter_ball_id()
	return {
		"tickets": 0,
		"tree": {},
		"balls": {starter: 0},
		"first_max": {},
		"selected_ball": starter,
		"achievements": {},
		"day": 1,
		"debt_paid": 0.0,
		"free_mode": false,
		"story_done": false,
		"card_holes": 0,
		"peg_template": {},
		"auto": {"reserve_idx": int(GameData.eco["auto"]["default_reserve_index"]), "off_on_reserve": false, "auto_pay_on": false},
		"story_seen": {},
		"tree_pending": false,
		"stats": default_stats(),
	}


static func default_settings() -> Dictionary:
	return {"master": 0.8, "sfx": 0.8, "music": 0.45, "reduced_motion": false, "fullscreen": false,
		"lang": "en", "lang_chosen": false, "show_heat": true, "pay_warned": false}


## Eksik anahtarları varsayılanlarla tamamlar (eski kayıtlar yeni sürümde açılabilsin).
static func _merge(defaults: Dictionary, data: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for k in data.keys():
		if out.has(k) and out[k] is Dictionary and data[k] is Dictionary and not (out[k] as Dictionary).is_empty():
			out[k] = _merge(out[k], data[k])
		else:
			out[k] = data[k]
	return out


static func _write_json(path: String, data: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Kayıt yazılamadı: " + tmp)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists(path.get_file()):
		dir.rename(path.get_file(), path.get_file() + ".bak")
	dir.rename(tmp.get_file(), path.get_file())


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func save_game(game) -> void:
	var run_copy: Dictionary = game.run.duplicate(true)
	var refund := 0.0
	for f in game.flights:
		refund += float(f.cost_paid)
	run_copy["cash"] = float(run_copy["cash"]) + refund
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"meta": game.meta,
		"run": run_copy,
	}
	_write_json(save_path, data)


## Sürüm göçleri: eski kayıt biçimlerini güncel biçime taşır.
static func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < 2:
		# v2: tahta 12 sıradan 8 sıraya indi; eski çivi yerleşimleri ve şablonlar geçersiz.
		# Çiviler envanterde kalır, yalnızca tahtadan toplanır.
		if data.get("run") is Dictionary:
			data["run"]["layout"] = {}
		if data.get("meta") is Dictionary:
			data["meta"]["peg_template"] = {}
	data["version"] = VERSION
	return data


static func load_game(game) -> bool:
	var parsed: Variant = _read_json(save_path)
	if not parsed is Dictionary:
		parsed = _read_json(save_path + ".bak")
	if not parsed is Dictionary:
		return false
	var data := _migrate(parsed)
	if not data.has("meta") or not data.has("run"):
		return false
	game.meta = _merge(default_meta(), data["meta"])
	game.meta["stats"] = _merge(default_stats(), game.meta["stats"])
	game.run = _merge(game.make_run(), data["run"])
	game.rebuild_layout_cells()
	return true


static func delete_save() -> void:
	var dir := DirAccess.open("user://")
	for p in [save_path, save_path + ".bak"]:
		if dir.file_exists(p.get_file()):
			dir.remove(p.get_file())


static func load_settings() -> Dictionary:
	var parsed: Variant = _read_json(settings_path)
	if parsed is Dictionary:
		return _merge(default_settings(), parsed)
	return default_settings()


static func save_settings(settings: Dictionary) -> void:
	_write_json(settings_path, settings)
