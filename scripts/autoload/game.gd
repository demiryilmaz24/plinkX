extends Node
## Oyunun merkezi durumu ve ana döngüsü.
## - meta: kalıcı veriler (koleksiyon, biletler, ağaç, başarımlar, gün/borç ilerlemesi)
## - run:  sefer (gün) verileri; prestijde sıfırlanır
## Alt sistemler ayrı dosyalardadır; bu dosya atış/uçuş/iniş akışını ve sinyalleri yönetir.

const Eco := preload("res://scripts/systems/economy.gd")
const Outcome := preload("res://scripts/systems/outcome_model.gd")
const Flight := preload("res://scripts/board/ball_flight.gd")
const Geo := preload("res://scripts/board/board_geometry.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")
const AutoLauncher := preload("res://scripts/systems/auto_launcher.gd")
const Achievements := preload("res://scripts/systems/achievements.gd")
const SaveSystem := preload("res://scripts/systems/save_system.gd")
const Prestige := preload("res://scripts/systems/prestige.gd")
const Debt := preload("res://scripts/systems/debt.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const PhoneCalls := preload("res://scripts/systems/phone_calls.gd")

signal changed
signal ball_launched(flight)
signal ball_landed(flight, result)
signal peg_hit(flight, cell, peg_id)
signal max_win(flight, result)
signal jackpot(amount)
signal tickets_gained(amount, source)
signal toast(text, kind)
signal day_started(day, free_mode)
signal installment_completed
signal story_finished
signal achievement_unlocked(id)
signal edit_mode_changed(on)
signal layout_changed
signal board_changed(old_win, new_win)
signal job_finished(amount)
signal bonus_ball(flight, kind)   # "split" (İkiz) / "rebirth" (Yeniden doğuş)
signal phone_ring(call)              # telefon çalmaya başladı: {kind: good/threat, who, t, line}
signal phone_missed(call)            # iyi arama açılmadı
signal phone_voicemail(call, result) # Sadık Bey açılmadı: sesli mesaj + ceza zarı sonucu
signal boost_started(secs)           # Ateş Modu başladı
signal boost_ended

const AUTOSAVE_INTERVAL := 15.0

var meta: Dictionary = {}
var run: Dictionary = {}
var settings: Dictionary = {}
var flights: Array = []
var rng := RandomNumberGenerator.new()
var auto := AutoLauncher.new()
var launch_queue: Array = []
var queue_timer := 0.0
var edit_mode := false
var edit_pending := false
var job_left := 0.0
var autosave_timer := 0.0
var ach_timer := 0.0
var last_result: Dictionary = {}
var layout_cells: Dictionary = {}     # Vector2i -> peg_id
var _next_id := 1
var _prob_cache_key := ""
var _prob_cache: Dictionary = {}
var ready_done := false
## Dil değişince arayüz sahnesi yeniden kurulur; oyun içindeysek menüye dönmeden devam edilir.
var resume_after_reload := false
var _quitting := false
## Ana menü veya duraklatma menüsü açıkken oyun akışı durur (atış, uçuş, otomasyon, iş).
var paused := true
## Telefon: Ateş Modu kalan süresi (gerçek saniye), çalan arama, arayüz meşgul mü (pencere açık vb.)
var boost_left := 0.0
var ringing: Dictionary = {}
var ui_busy := false
var has_focus := true   # oyun penceresi odakta mı (başka pencereye geçilince telefon susar ve beklemeye alınır)


func _ready() -> void:
	rng.randomize()
	get_tree().set_auto_accept_quit(false)
	var args := OS.get_cmdline_user_args()
	if args.has("--test-save"):
		SaveSystem.use_test_paths()
		if args.has("--fresh"):
			SaveSystem.delete_save()
	settings = SaveSystem.load_settings()
	# Ana dil İngilizce: oyuncu dili kendisi seçmediyse İngilizce açılır
	if not bool(settings.get("lang_chosen", false)):
		settings["lang"] = "en"
	for a in args:
		if String(a).begins_with("--lang="):
			settings["lang"] = String(a).substr(7)
	Loc.load_language(String(settings["lang"]))
	if not SaveSystem.load_game(self):
		new_game()
	ready_done = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# telefon yalnızca oyuncu masadayken çalar; test oturumlarında odak önemsenmez
		has_focus = SaveSystem.save_path.begins_with("user://test_")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		has_focus = true


## Temiz çıkış: kaydet, sesleri durdur, ses sunucusunun akışları bırakması için iki kare bekle, kapat.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	save_now()
	Sfx.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


# =================================================================== kurulum

func new_game() -> void:
	meta = SaveSystem.default_meta()
	start_run(true)


## Yeni sefer (gün) verisi. Kalıcı ağaç başlangıç bonuslarını uygular.
func make_run() -> Dictionary:
	var price := day_price()
	return {
		"cash": Eco.x() * float(GameData.eco["start_cash"]) * price * pow(2.0, MetaTree.level(self, "start_cash")),
		"ball_level": mini(1 + 3 * MetaTree.level(self, "start_ball"), ball_cap()),
		"board_level": mini(1 + MetaTree.level(self, "start_board"), board_cap()),
		"up": {"air": 0, "batch": 0, "auto_speed": 0, "auto_batch": 0, "polish": 0, "sockets": 0,
			"auto_unlock": 1 if MetaTree.level(self, "auto_ready") > 0 else 0},
		"installment": 0.0,
		"profit": 0.0,
		"ball_spins": 0,
		"peg_spins": 0,
		"pegs": {},
		"layout": {},
		"free_shots": 10 * MetaTree.level(self, "free_shots"),
		"streak": 0,
		"cards_today": 0,
		"jackpots_today": 0,
		"peg_tickets_today": 0,
		"tickets_run": 0,
		"max_today": 0,
		"shots_today": 0,
		"auto_on": MetaTree.level(self, "auto_ready") > 0,
		"batch_choice": 0,
		"phone_good_t": 100.0,
		"phone_threat_t": 280.0,
		"installment_done_announced": false,
	}


## Yeni sefer (gün) başlatır.
func start_run(announce: bool) -> void:
	flights.clear()
	launch_queue.clear()
	edit_mode = false
	edit_pending = false
	job_left = 0.0
	run = make_run()
	for i in range(MetaTree.level(self, "peg_gift")):
		var commons := GameData.pegs_of_rarity("common")
		var pid: String = commons[rng.randi_range(0, commons.size() - 1)]["id"]
		run["pegs"][pid] = int(run["pegs"].get(pid, 0)) + 1
	rebuild_layout_cells()
	auto.reset()
	PhoneCalls.reset_run(self)
	if announce:
		day_started.emit(meta["day"], meta["free_mode"])
	changed.emit()


func rebuild_layout_cells() -> void:
	layout_cells.clear()
	for key in run["layout"].keys():
		var parts: PackedStringArray = String(key).split(",")
		layout_cells[Vector2i(int(parts[0]), int(parts[1]))] = run["layout"][key]
	_prob_cache_key = ""


# =================================================================== sorgular

func x() -> float:
	return Eco.x()


func is_free_mode() -> bool:
	return bool(meta["free_mode"])


func day() -> int:
	return int(meta["day"])


func day_price() -> float:
	if is_free_mode():
		return float(GameData.eco["free_mode"]["price"])
	return float(GameData.day_info(day())["price"])


func ball_cap() -> int:
	if is_free_mode():
		return 1000000
	return int(GameData.day_info(day())["ball_cap"])


func board_cap() -> int:
	if is_free_mode():
		return int(GameData.eco["free_mode"]["board_cap"])
	return int(GameData.day_info(day())["board_cap"])


func target() -> float:
	if is_free_mode():
		return 0.0
	return float(GameData.day_info(day())["target"])


func installment_left() -> float:
	return maxf(0.0, target() - float(run["installment"]))


func installment_done() -> bool:
	return is_free_mode() or float(run["installment"]) >= target() - 0.001


func debt_left() -> float:
	return maxf(0.0, GameData.total_debt() - float(meta["debt_paid"]))


func air_limit() -> int:
	if boost_left > 0.0:
		return int(GameData.eco["phone"]["boost_air_cap"])   # Ateş Modu: hava sınırı yok
	return Eco.air_limit(int(run["up"]["air"]), 2 * MetaTree.level(self, "air_perm"))


func boost_active() -> bool:
	return boost_left > 0.0


## Oyun hızı çarpanı (Ateş Modunda ×2): top uçuşu, fırlatma kuyruğu ve otomatik atıcı bu hızla işler.
func game_speed() -> float:
	return float(GameData.eco["phone"]["boost_speed"]) if boost_left > 0.0 else 1.0


func paid_in_air() -> int:
	var n := 0
	for f in flights:
		if not f.bonus:
			n += 1
	return n + launch_queue.size()


func air_free() -> int:
	return maxi(0, air_limit() - paid_in_air())


func auto_interval() -> float:
	return Eco.auto_interval(int(run["up"]["auto_speed"]), MetaTree.level(self, "auto_speed_perm"))


func auto_batch() -> int:
	return 1 + int(run["up"]["auto_batch"])


func batch_sizes() -> Array:
	var sizes: Array = Eco.upgrade_def("batch")["sizes"]
	return sizes.slice(0, int(run["up"]["batch"]) + 1)


func reserve_amount() -> float:
	var presets: Array = GameData.eco["auto"]["reserve_presets_x"]
	return float(presets[clampi(int(meta["auto"]["reserve_idx"]), 0, presets.size() - 1)]) * x()


func selected_ball() -> String:
	return meta["selected_ball"]


func ball_params() -> Dictionary:
	var bid := selected_ball()
	return Eco.ball_params(bid, int(meta["balls"].get(bid, 0)))


func ball_mult() -> float:
	return Eco.ball_level_mult(int(run["ball_level"]))


func polish_mult() -> float:
	return Eco.polish_mult(int(run["up"]["polish"]))


func sockets() -> int:
	return Eco.sockets(int(run["up"]["sockets"]), MetaTree.level(self, "start_sockets"))


## Güncel düzen ve top için kesin olasılıklar (önbellekli).
func probabilities(board_level: int = -1) -> Dictionary:
	if board_level < 0:
		board_level = int(run["board_level"])
	var p := ball_params()
	var key := "%d|%s|%d|%s" % [board_level, selected_ball(), int(meta["balls"].get(selected_ball(), 0)), str(run["layout"])]
	if key == _prob_cache_key and board_level == int(run["board_level"]):
		return _prob_cache
	var res := Outcome.band_probabilities(board_level, float(p["bias"]), layout_cells)
	if board_level == int(run["board_level"]):
		_prob_cache_key = key
		_prob_cache = res
	return res


func next_shot_cost() -> float:
	if int(run["free_shots"]) > 0:
		return 0.0
	return x()


# =================================================================== ana döngü

func _process(delta: float) -> void:
	if not ready_done or paused:
		return
	meta["stats"]["play_time"] = float(meta["stats"]["play_time"]) + delta
	PhoneCalls.tick(self, delta)
	var gd := delta * game_speed()
	_process_queue(gd)
	auto.tick(self, gd)
	_process_flights(gd)
	if job_left > 0.0:
		job_left -= delta
		if job_left <= 0.0:
			_finish_job()
	if edit_pending and flights.is_empty() and launch_queue.is_empty():
		edit_pending = false
		edit_mode = true
		edit_mode_changed.emit(true)
		changed.emit()
	ach_timer += delta
	if ach_timer >= 0.5:
		ach_timer = 0.0
		Achievements.check_all(self)
		Debt.tick(self)
	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_INTERVAL:
		autosave_timer = 0.0
		save_now()


# =================================================================== atış

## Elle veya otomatik atış isteği. Döner: kuyruğa alınan top sayısı.
func request_launch(count: int, source: String) -> int:
	if edit_mode or edit_pending:
		if source == "manual":
			toast.emit(Loc.t("toast.edit_mode_no_launch"), "warn")
		return 0
	var free := air_free()
	if free <= 0:
		if source == "manual":
			toast.emit(Loc.t("toast.air_full", {"n": air_limit()}), "warn")
		return 0
	var reserve := reserve_amount() if source == "auto" else 0.0
	var paid_affordable := int(floor((float(run["cash"]) - reserve) / x() + 1e-9))
	var affordable := int(run["free_shots"]) + maxi(0, paid_affordable)
	var n := mini(count, mini(free, affordable))
	if n <= 0:
		if source == "manual":
			toast.emit(Loc.t("toast.no_cash", {"cost": Fmt.money(x())}), "warn")
		return 0
	if n < count and source == "manual":
		if affordable < count and affordable <= free:
			toast.emit(Loc.t("toast.partial_cash", {"n": n, "m": count}), "info")
		else:
			toast.emit(Loc.t("toast.partial_air", {"n": n, "m": count}), "info")
	for i in range(n):
		launch_queue.append(source)
	return n


func _process_queue(delta: float) -> void:
	if launch_queue.is_empty():
		queue_timer = 0.0
		return
	queue_timer -= delta
	var stagger: float = float(GameData.eco["auto"]["launch_stagger"])
	while queue_timer <= 0.0 and not launch_queue.is_empty():
		var source: String = launch_queue.pop_front()
		if not _spawn_paid(source):
			var dropped := launch_queue.size() + 1
			launch_queue.clear()
			if source == "manual":
				toast.emit(Loc.t("toast.dropped", {"n": dropped}), "warn")
			break
		queue_timer += stagger


func _spawn_paid(source: String) -> bool:
	var f := Flight.new()
	if int(run["free_shots"]) > 0:
		run["free_shots"] = int(run["free_shots"]) - 1
		f.free = true
		f.cost_paid = 0.0
	else:
		# Otomatik atış, kuyruktayken de rezervin altına inmez (araya satın alma girmiş olabilir).
		var floor_cash := reserve_amount() if source == "auto" else 0.0
		if float(run["cash"]) - x() < floor_cash - 1e-9:
			return false
		run["cash"] = float(run["cash"]) - x()
		f.cost_paid = x()
	_init_flight(f, source == "auto")
	f.from_top = true
	f.start_point = Vector2(Geo.CX + rng.randf_range(-5.0, 5.0), Geo.SPAWN_Y)
	var path := Outcome.roll_path(rng, float(f.params["bias"]), layout_cells)
	_apply_path(f, path)
	# İkiz Bilye: ilk çivide bölünme şansı (bonus toplar zincirleme bölünmez)
	if float(f.params["split_chance"]) > 0.0 and not f.hits.is_empty() and rng.randf() < float(f.params["split_chance"]):
		f.events.push_front({"t": f.hit_time(0), "kind": "split", "i": 0})
		f.events.sort_custom(func(a, b): return a["t"] < b["t"])
	flights.append(f)
	_count_shot(f)
	ball_launched.emit(f)
	return true


func _init_flight(f, is_auto: bool) -> void:
	f.id = _next_id
	_next_id += 1
	f.ball_id = selected_ball()
	f.stars = int(meta["balls"].get(f.ball_id, 0))
	f.params = ball_params()
	f.stake = x()
	f.auto = is_auto
	f.ball_mult = ball_mult()
	f.polish = polish_mult()
	f.setup_timing(float(GameData.eco["fall_time"]), GameData.rows())


func _apply_path(f, path: Dictionary) -> void:
	f.hits = path["hits"]
	f.dirs = path["dirs"]
	f.k = int(path["k"])
	f.u = float(path["u"])
	for i in range(f.hits.size()):
		var cell: Vector2i = f.hits[i]
		var pid: String = layout_cells.get(cell, "")
		if pid == "":
			continue
		var peg: Dictionary = GameData.pegs_by_id[pid]
		if peg.has("mult"):
			f.peg_prod *= float(peg["mult"])
		if peg.has("add"):
			f.peg_add += float(peg["add"])
		if peg.has("max_add"):
			f.peg_max_add += float(peg["max_add"])
		if peg.has("loss_mult"):
			f.peg_loss_mult *= float(peg["loss_mult"])
		var ev := {"t": f.hit_time(i), "kind": "peg", "i": i, "cell": cell, "peg": pid}
		if peg.has("split") and not f.bonus and rng.randf() < float(peg["split"]):
			ev["split"] = true
		if peg.has("ticket_chance") and rng.randf() < float(peg["ticket_chance"]):
			ev["ticket"] = true
		f.events.append(ev)
		f.special_hits.append({"i": i, "cell": cell, "peg": pid})


func _count_shot(f) -> void:
	var st: Dictionary = meta["stats"]
	st["shots_total"] = int(st["shots_total"]) + 1
	run["shots_today"] = int(run["shots_today"]) + 1
	if f.auto:
		st["auto_shots"] = int(st["auto_shots"]) + 1
	var bs: Dictionary = st["ball_shots"]
	bs[f.ball_id] = int(bs.get(f.ball_id, 0)) + 1


## Bonus top (bölünme): ebeveynin i. çivisinden diğer yöne ayrılır.
func _spawn_split(parent, i: int) -> void:
	var cell: Vector2i = parent.hits[i]
	var dir: int = parent.dirs[i]
	var f := Flight.new()
	_init_flight(f, parent.auto)
	f.ball_id = parent.ball_id
	f.stars = parent.stars
	f.params = parent.params
	f.ball_mult = parent.ball_mult
	f.polish = parent.polish
	f.bonus = true
	f.cost_paid = 0.0
	f.from_top = false
	f.start_point = Geo.contact(cell.x, cell.y, 1 - dir)
	var nj := cell.y + (1 - dir)
	var path := Outcome.roll_path(rng, float(f.params["bias"]), layout_cells, cell.x + 1, nj)
	_apply_path(f, path)
	flights.append(f)
	meta["stats"]["bonus_balls"] = int(meta["stats"]["bonus_balls"]) + 1
	bonus_ball.emit(f, "split")


## Bonus top (yeniden doğuş): tepeden ücretsiz yeniden düşer.
func _spawn_rebirth(parent) -> void:
	var f := Flight.new()
	_init_flight(f, parent.auto)
	f.ball_id = parent.ball_id
	f.stars = parent.stars
	f.params = parent.params
	f.ball_mult = parent.ball_mult
	f.polish = parent.polish
	f.bonus = true
	f.cost_paid = 0.0
	f.from_top = true
	f.start_point = Vector2(Geo.CX + rng.randf_range(-5.0, 5.0), Geo.SPAWN_Y)
	var path := Outcome.roll_path(rng, float(f.params["bias"]), layout_cells)
	_apply_path(f, path)
	flights.append(f)
	meta["stats"]["bonus_balls"] = int(meta["stats"]["bonus_balls"]) + 1
	bonus_ball.emit(f, "rebirth")


func _process_flights(delta: float) -> void:
	if flights.is_empty():
		return
	var landed: Array = []
	for f in flights:
		f.elapsed += delta
		while f.next_event < f.events.size() and float(f.events[f.next_event]["t"]) <= f.elapsed:
			_handle_event(f, f.events[f.next_event])
			f.next_event += 1
		if f.elapsed >= f.duration():
			landed.append(f)
	for f in landed:
		flights.erase(f)
		_land(f)


func _handle_event(f, ev: Dictionary) -> void:
	match ev["kind"]:
		"peg":
			peg_hit.emit(f, ev["cell"], ev["peg"])
			if ev.get("split", false):
				_spawn_split(f, int(ev["i"]))
			if ev.get("ticket", false):
				_ticket_peg_award()
		"split":
			_spawn_split(f, int(ev["i"]))


func _ticket_peg_award() -> void:
	var cap: int = int(GameData.pegs_by_id["bilet"]["daily_cap"])
	if int(run["peg_tickets_today"]) >= cap:
		return
	run["peg_tickets_today"] = int(run["peg_tickets_today"]) + 1
	meta["stats"]["peg_tickets"] = int(meta["stats"]["peg_tickets"]) + 1
	add_tickets(1, "peg")
	toast.emit(Loc.t("toast.ticket_peg", {"n": run["peg_tickets_today"], "cap": cap}), "ticket")


func _land(f) -> void:
	var itype := Outcome.type_at(f.u, int(run["board_level"]))
	var res := Eco.resolve(f, itype)
	run["cash"] = float(run["cash"]) + float(res["credit"])
	var change: float = float(res["credit"]) - f.cost_paid
	res["change"] = change
	run["profit"] = float(run["profit"]) + change
	var st: Dictionary = meta["stats"]
	if change > 0.0:
		st["total_won"] = float(st["total_won"]) + change
	if change > float(st["best_win"]):
		st["best_win"] = change
	if bool(res["max"]):
		_on_max(f, res)
	else:
		run["streak"] = 0
	if not bool(res["positive"]) and not f.bonus and float(f.params["rebirth_chance"]) > 0.0:
		if rng.randf() < float(f.params["rebirth_chance"]):
			_spawn_rebirth(f)
	last_result = {"flight": f, "result": res}
	ball_landed.emit(f, res)


func _on_max(f, res: Dictionary) -> void:
	var st: Dictionary = meta["stats"]
	st["max_total"] = int(st["max_total"]) + 1
	run["max_today"] = int(run["max_today"]) + 1
	add_holes(1)
	if not bool(meta["first_max"].get(f.ball_id, false)):
		meta["first_max"][f.ball_id] = true
		var rar: String = GameData.balls_by_id[f.ball_id]["rarity"]
		var bonus: int = int(GameData.eco["tickets"]["first_max_bonus"][rar])
		add_tickets(bonus, "first_max")
		toast.emit(Loc.t("toast.first_max", {"ball": Loc.t("ball." + f.ball_id + ".name"), "n": bonus}), "ticket")
	run["streak"] = int(run["streak"]) + 1
	max_win.emit(f, res)
	var need: int = int(GameData.eco["tickets"]["jackpot_streak"])
	if int(run["streak"]) >= need:
		run["streak"] = 0
		var amount := Eco.jackpot_cash(float(res["net"]))
		run["cash"] = float(run["cash"]) + amount
		run["profit"] = float(run["profit"]) + amount
		st["jackpots"] = int(st["jackpots"]) + 1
		add_holes(int(GameData.eco["tickets"]["jackpot_holes"]))
		if int(run["jackpots_today"]) == 0:
			add_tickets(int(GameData.eco["tickets"]["jackpot_first_daily_tickets"]), "jackpot")
		run["jackpots_today"] = int(run["jackpots_today"]) + 1
		jackpot.emit(amount)


## Şans Kartı: her MAX 1 delik; kart dolunca 1 bilet. Gün içindeki her yeni kart daha büyüktür.
func add_holes(n: int) -> void:
	meta["card_holes"] = int(meta["card_holes"]) + n
	var size := card_size()
	while int(meta["card_holes"]) >= size:
		meta["card_holes"] = int(meta["card_holes"]) - size
		run["cards_today"] = int(run["cards_today"]) + 1
		add_tickets(1, "card")
		toast.emit(Loc.t("toast.card_full"), "ticket")
		size = card_size()


func card_size() -> int:
	return Eco.card_size(int(run["cards_today"]), MetaTree.level(self, "card_size"))


func add_tickets(n: int, source: String) -> void:
	if n <= 0:
		return
	meta["tickets"] = int(meta["tickets"]) + n
	run["tickets_run"] = int(run["tickets_run"]) + n
	meta["stats"]["tickets_earned"] = int(meta["stats"]["tickets_earned"]) + n
	tickets_gained.emit(n, source)


# =================================================================== ücretsiz iş

func job_duration() -> float:
	return float(GameData.eco["free_job"]["duration"])


func job_pay() -> float:
	return float(GameData.eco["free_job"]["pay"]) * x() * (1.0 + float(GameData.eco["tree_effects"]["job_pay"]["per_level"]) * MetaTree.level(self, "job_pay"))


func start_job() -> void:
	if job_left > 0.0:
		return
	job_left = job_duration()
	changed.emit()


func _finish_job() -> void:
	job_left = 0.0
	var pay := job_pay()
	run["cash"] = float(run["cash"]) + pay
	meta["stats"]["jobs_done"] = int(meta["stats"]["jobs_done"]) + 1
	job_finished.emit(pay)
	changed.emit()


# =================================================================== düzenleme modu

func set_edit_mode(on: bool) -> void:
	if on:
		if edit_mode or edit_pending:
			return
		if flights.is_empty() and launch_queue.is_empty():
			edit_mode = true
			edit_mode_changed.emit(true)
		else:
			edit_pending = true
			toast.emit(Loc.t("toast.edit_waiting"), "info")
	else:
		edit_mode = false
		edit_pending = false
		edit_mode_changed.emit(false)
	changed.emit()


func notify_layout_changed() -> void:
	_prob_cache_key = ""
	layout_changed.emit()
	changed.emit()


# =================================================================== kayıt

func save_now() -> void:
	if ready_done:
		SaveSystem.save_game(self)


func has_progress() -> bool:
	return int(meta["stats"]["shots_total"]) > 0 or int(meta["day"]) > 1 or bool(meta["free_mode"])


func wipe_save() -> void:
	SaveSystem.delete_save()
	flights.clear()
	launch_queue.clear()
	new_game()
	save_now()


## Prestij / gün kapanışı sistemi için ince sarmalayıcılar
func prestige_preview() -> Dictionary:
	return Prestige.preview(self)


func prestige_apply() -> void:
	Prestige.apply(self)
