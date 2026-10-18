extends Node
## Geliştirici araçları (yalnızca komut satırı argümanlarıyla etkinleşir; normal oyunda hiçbir şey yapmaz).
## Ekran görüntüsü, olasılık doğrulaması, ödeme ölçümü, hata ayıklama oyuncusu ve model tekrar oynatıcısı.

const Fmt := preload("res://scripts/util/fmt.gd")
const RunShop := preload("res://scripts/systems/run_shop.gd")
const BC := preload("res://scripts/systems/ball_collection.gd")
const PS := preload("res://scripts/systems/peg_system.gd")
const DB := preload("res://scripts/systems/debt.gd")
const MT := preload("res://scripts/systems/meta_tree.gd")
const PC := preload("res://scripts/systems/phone_calls.gd")

var ui  # ana arayüz
var skip_menu := false
var skip_story := false
var _debug_seconds := -1.0
var _debug_time := 0.0
var _debug_shot := ""
static var _lang_toggled := false
var _debug_crop := Rect2()
var _debug_demo := false
var _debug_print := false
var _debug_measure := false
var _demo_t := 0.0
var _autoplay := false
var _autoplay_t := 0.0
var _replay: Dictionary = {}
var _replay_idx := 0
var _replay_click := 0.0
var _replay_t := 0.0
var _replay_log_t := 0.0
var _day_start_time := 0.0
var _game_time := 0.0
var _bot_rng := RandomNumberGenerator.new()
var _ui_answer := false     # --answer: çalan telefonu arayüzden açar (ekran görüntüsü için)


func _process(delta: float) -> void:
	_debug_time += delta
	if _debug_seconds > 0.0 and _debug_time >= _debug_seconds:
		_debug_capture()
		return
	if Game.paused:
		return
	_game_time += delta
	if not Game.ringing.is_empty():
		if _ui_answer:
			ui.call("_on_prop", "phone")
		elif _autoplay or not _replay.is_empty():
			_bot_answer()
	if not _replay.is_empty():
		_replay_t += delta
		if _replay_t >= 0.1:
			_replay_step(_replay_t)
			_replay_t = 0.0
	if _autoplay:
		_autoplay_t += delta
		if _autoplay_t >= 0.5:
			_autoplay_t = 0.0
			_autoplay_step()
	if _debug_demo:
		_demo_t += delta
		if _demo_t >= 0.6:
			_demo_t = 0.0
			Game.request_launch(ui.launch.current_batch(), "manual")


## İlk geçiş: menü/hikâye atlama gibi akış bayrakları (arayüz kurulmadan önce).
func parse_flags() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s in ["--skip-menu", "--autoplay", "--demo", "--measure"] or s.begins_with("--replay=") or s.begins_with("--screenshot=") or s.begins_with("--seconds="):
			skip_menu = true
		if s in ["--skip-story", "--autoplay"] or s.begins_with("--replay="):
			skip_story = true
		if s == "--menu":
			skip_menu = false


## İkinci geçiş: durum değiştiren argümanlar (oyun başladıktan sonra).
func apply_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--screenshot="):
			_debug_shot = s.substr(13)
			if _debug_seconds < 0.0:
				_debug_seconds = 3.0
		elif s.begins_with("--crop="):
			var c := s.substr(7).split(",")
			_debug_crop = Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		elif s.begins_with("--seconds="):
			_debug_seconds = float(s.substr(10))
		elif s == "--demo":
			_debug_demo = true
		elif s.begins_with("--cash="):
			Game.run["cash"] = float(s.substr(7))
		elif s.begins_with("--buy="):
			for part in s.substr(6).split(","):
				var kv := part.split(":")
				for i in range(int(kv[1])):
					RunShop.buy(Game, kv[0])
		elif s.begins_with("--spin="):
			for part in s.substr(7).split(","):
				var kv := part.split(":")
				for i in range(int(kv[1])):
					if kv[0] == "ball":
						BC.spin(Game)
					else:
						PS.spin(Game)
		elif s.begins_with("--give-pegs="):
			for part in s.substr(12).split(","):
				var kv := part.split(":")
				Game.run["pegs"][kv[0]] = int(kv[1])
		elif s.begins_with("--place="):
			Game.edit_mode = true
			for part in s.substr(8).split(","):
				var kv := part.split(":")
				PS.place(Game, Vector2i(int(kv[0]), int(kv[1])), kv[2])
			Game.edit_mode = false
		elif s == "--pay-all":
			DB.pay(Game, float(Game.run["cash"]))
		elif s == "--new-day-fx":
			ui.call_deferred("_debug_tree_phase")
			ui.call_deferred("_day_end_start")
		elif s.begins_with("--wheel-call="):
			# --wheel-call=SN:yöntem → SN saniye sonra açık çark penceresinde yöntemi çağırır (ör. 5:_on_open)
			var kv := s.substr(13).split(":")
			ui.get_tree().create_timer(float(kv[0])).timeout.connect(_wheel_call.bind(kv[1]))
		elif s.begins_with("--ui-sell="):
			ui.get_tree().create_timer(float(s.substr(10))).timeout.connect(func():
				if ui.get("_wheel_win"):
					ui.get("_wheel_win").call("_on_sell"))
		elif s == "--toggle-lang" and not _lang_toggled:
			_lang_toggled = true
			ui.get_tree().create_timer(0.8).timeout.connect(func(): ui.call("_toggle_language"))
		elif s == "--tree-phase":
			ui.call_deferred("_debug_tree_phase")
		elif s == "--open-prestige":
			ui.call_deferred("_open_prestige")
		elif s == "--do-prestige":
			Game.prestige_apply()
		elif s.begins_with("--day="):
			var d := int(s.substr(6))
			Game.meta["day"] = d
			var paid := 0.0
			for i in range(1, d):
				paid += float(GameData.day_info(i)["target"])
			Game.meta["debt_paid"] = paid
			Game.start_run(false)
		elif s.begins_with("--tickets="):
			Game.meta["tickets"] = int(s.substr(10))
		elif s.begins_with("--phone="):
			# telefonu yarım saniye içinde çaldırır: good | threat
			Game.run["phone_good_t" if s.substr(8) == "good" else "phone_threat_t"] = 0.5
			if s.substr(8) != "good":
				Game.run["phone_good_t"] = 999.0
		elif s == "--answer":
			_ui_answer = true
		elif s.begins_with("--call-act="):
			# açık arama penceresinde düğmeye basar: pay | hang | boost (zamanlayıcı oyun duraklasa da işler)
			ui.get_tree().create_timer(2.0).timeout.connect(_call_act.bind(s.substr(11)))
		elif s == "--boost":
			PC.start_boost(Game)
		elif s == "--autoplay":
			_autoplay = true
		elif s.begins_with("--replay="):
			var f := FileAccess.open(s.substr(9), FileAccess.READ)
			_replay = JSON.parse_string(f.get_as_text())
		elif s.begins_with("--timescale="):
			Engine.time_scale = float(s.substr(12))
		elif s == "--measure":
			_debug_measure = true
		elif s == "--print":
			_debug_print = true
		elif s == "--open-settings":
			ui.call_deferred("_open_settings")
		elif s.begins_with("--open="):
			ui.call_deferred("_open_screen", s.substr(7))
		elif s.begins_with("--wheel="):
			ui.call_deferred("_open_wheel", s.substr(8))
		elif s.begins_with("--ui-spin="):
			for kind in s.substr(10).split("+"):
				ui.call_deferred("_debug_spin", kind)
		elif s == "--pause":
			ui.call_deferred("_open_pause")
		elif s == "--job":
			Game.start_job()
		elif s == "--jackpot-fx":
			Game.run["jackpots_today"] = 1
			Game.jackpot.emit(12345.0)
		elif s == "--edit":
			ui.call_deferred("_debug_edit")
		elif s.begins_with("--give-balls="):
			# tüm top türlerini verilen ustalık yıldızıyla koleksiyona ekler (kopya/satış testleri için)
			for b in GameData.eco["balls"]:
				Game.meta["balls"][String(b["id"])] = int(s.substr(13))
		elif s.begins_with("--select-ball="):
			Game.meta["balls"][s.substr(14)] = 0
			Game.meta["selected_ball"] = s.substr(14)
		elif s == "--verify-probs":
			_verify_probs()
		elif s.begins_with("--sprite-sheet="):
			_sprite_sheet(s.substr(15))


## Hata ayıklama oyuncusu: basit açgözlü kararlarla oynar (ekonomiyi oyun kodu üzerinde doğrulamak için).
func _autoplay_step() -> void:
	ui.dialogs.close_top()
	if int(Game.run["up"]["auto_unlock"]) == 0:
		RunShop.buy(Game, "auto_unlock")
	Game.run["auto_on"] = true
	for i in range(8):
		var best_key := ""
		var best_cost := INF
		for key in ["ball_level", "board_level", "air", "auto_speed", "auto_batch", "polish", "batch", "sockets"]:
			var inf := RunShop.info(Game, key)
			if inf["block"] == "" and float(inf["cost"]) < best_cost:
				best_cost = float(inf["cost"])
				best_key = key
		if best_key == "" or float(Game.run["cash"]) - best_cost < 30.0 * Game.x():
			break
		RunShop.buy(Game, best_key)
	if Game.auto.status != "running":
		Game.request_launch(ui.launch.current_batch(), "manual")
	var cash: float = float(Game.run["cash"])
	if BC.spin_cost(Game) < cash * 0.08 and cash - BC.spin_cost(Game) > 30.0 * Game.x():
		_bot_ball_spin()
	if PS.spin_cost(Game) < cash * 0.05 and cash - PS.spin_cost(Game) > 30.0 * Game.x():
		PS.spin(Game)
	# en nadir/güçlü topu seç
	var order := ["kara_inci", "anka", "kuyruklu", "ikiz", "altin", "miknatis", "bakir", "cam", "kaucuk", "kil", "volkan", "demir"]
	for b in order:
		if BC.owned(Game, b):
			if Game.selected_ball() != b:
				BC.select(Game, b)
			break
	# çivileri yerleştir (toplar inmişken)
	var free_sockets: int = Game.sockets() - PS.placed_count(Game)
	if free_sockets > 0 and Game.flights.is_empty() and Game.launch_queue.is_empty():
		Game.set_edit_mode(true)
		if Game.edit_mode:
			var hits: Dictionary = Game.probabilities()["hits"]
			var cells: Array = hits.keys().filter(func(c): return PS.is_placeable_cell(c))
			cells.sort_custom(func(a, b): return float(hits[a]) > float(hits[b]))
			for pid in Game.run["pegs"].keys():
				for c in cells:
					if PS.place(Game, c, pid) == "":
						pass
			Game.set_edit_mode(false)
	var caps_done := int(Game.run["ball_level"]) >= Game.ball_cap() and int(Game.run["board_level"]) >= Game.board_cap()
	if caps_done:
		DB.pay(Game, float(Game.run["cash"]) - 30.0 * Game.x())
	if Game.installment_done() and not Game.is_free_mode():
		print("OTO: gün %d bitti, oyun süresi %.1f dk, bilet %d, top_sv %d, tahta_sv %d, atış %d" % [Game.day(), (_game_time - _day_start_time) / 60.0, int(Game.meta["tickets"]), int(Game.run["ball_level"]), int(Game.run["board_level"]), int(Game.run["shots_today"])])
		_day_start_time = _game_time
		Game.prestige_apply()
		# basit ağaç alımı
		for node in ["auto_ready", "start_ball", "start_cash", "start_board", "air_perm", "card_size", "auto_speed_perm", "ball_luck", "start_sockets", "free_shots", "prestige_bonus"]:
			while MT.buy(Game, node):
				pass


func _wheel_call(method: String) -> void:
	var w = ui.get("_wheel_win")
	if w and is_instance_valid(w):
		w.call(method)


func _call_act(act: String) -> void:
	ui.call({"pay": "_call_pay", "hang": "_call_hang_up", "boost": "_call_boost"}[act])


## Botların Top Çarkı: modeldeki akılcı kural — kullanılmayan topun kopyası satılır, kullanılan topunki
## ustalık yıldızı olarak kalır; yıldızları dolu kopya otomatik satılır.
func _bot_ball_spin() -> void:
	var r := BC.spin(Game)
	if BC.is_duplicate(r) and int(r["star"]) > 0 and String(r["ball"]) != Game.selected_ball():
		BC.sell(Game, r, Game.selected_ball())
	BC.settle(Game, r)


## Botlar telefonu modeldeki gibi açar: iyi aramaların açılma oranı modelle aynı (Ateş Modu hemen başlar);
## Sadık Bey kasa boşken nakde el koyar, kısmen ödenmişken bot "Kapat" der (ceza zarı o anki taksit oranıyla).
func _bot_answer() -> void:
	if bool(Game.ringing.get("bot_seen", false)):
		return
	Game.ringing["bot_seen"] = true
	var good := String(Game.ringing["kind"]) == "good"
	if good and _bot_rng.randf() >= float(_replay.get("phone_answer_rate", 0.85)):
		return  # açılmaz, çalıp susar
	var c := PC.answer(Game)
	if good:
		PC.start_boost(Game)
		print("  telefon: %s → Ateş Modu (g%d t=%.1fdk)" % [c["who"], Game.day(), (_game_time - _day_start_time) / 60.0])
	elif PC.threat_mode(Game) == "collect":
		print("  telefon: Sadık Bey → kasa boş, el konan %s" % Fmt.money(PC.collect(Game)))
	elif PC.threat_mode(Game) == "warn":
		var r := PC.roll_fine(Game)
		print("  telefon: Sadık Bey → ceza %s (ihtimal %.0f%%)" % [Fmt.money(float(r["amount"])), float(r["chance"]) * 100.0])


## Model tekrar oynatıcısı: Python modelindeki normal oyuncunun kararlarını sırasıyla uygular.
## Amaç, modelin öngördüğü gün sürelerini gerçek oyun kodu üzerinde doğrulamaktır.
func _replay_step(dt: float) -> void:
	ui.dialogs.close_top()
	var days: Array = _replay["days"]
	var di := Game.day() - 1
	if Game.is_free_mode() or di >= days.size():
		return
	var actions: Array = days[di]["actions"]
	# elle tıklama (modelle aynı sıklık, en büyük toplu atış)
	# Ateş Modu'nda model oyuncunun daha sık tıkladığını varsayar
	_replay_click += dt * (float(_replay.get("boost_click_mult", 2.0)) if Game.boost_active() else 1.0)
	var every := 1.0 / float(_replay["click_rate"])
	if _replay_click >= every:
		_replay_click -= every
		var sizes := Game.batch_sizes()
		Game.request_launch(int(sizes[sizes.size() - 1]), "manual")
	if int(Game.run["up"]["auto_unlock"]) > 0:
		Game.run["auto_on"] = true
	# Gerçek oyuncu gibi: havadaki toplar dönene kadar atışa yetecek tampon bırak (model geliri soyut sayar).
	var buffer: float = Game.air_limit() * Game.x()
	if float(Game.run["cash"]) < Game.x() and Game.flights.is_empty() and Game.job_left <= 0.0:
		Game.start_job()
	var guard := 0
	while _replay_idx < actions.size() and guard < 50:
		guard += 1
		var act: Dictionary = actions[_replay_idx]
		var a: String = act["a"]
		var spendable: float = float(Game.run["cash"]) - buffer
		if a == "buy":
			# hedef: bu yükseltmeyi modeldeki mutlak seviyeye getir
			var key: String = act["k"]
			if RunShop.level(Game, key) >= int(act["lv"]):
				_replay_idx += 1
				continue
			var inf := RunShop.info(Game, key)
			if inf["block"] != "":
				_replay_idx += 1
				continue
			if spendable >= float(inf["cost"]):
				RunShop.buy(Game, key)
				continue
			break
		elif a == "ball_slot":
			if int(Game.run["ball_spins"]) >= int(act["n"]):
				_replay_idx += 1
				continue
			if spendable >= BC.spin_cost(Game):
				_bot_ball_spin()
				continue
			break
		elif a == "peg_slot":
			if int(Game.run["peg_spins"]) >= int(act["n"]):
				_replay_idx += 1
				continue
			if spendable >= PS.spin_cost(Game):
				PS.spin(Game)
				continue
			break
		else:
			DB.pay(Game, spendable)
			_replay_idx += 1
	if _replay_idx >= actions.size():
		DB.pay(Game, float(Game.run["cash"]) - buffer)
	_bot_pick_ball_and_pegs()
	_replay_log_t += dt
	if _replay_log_t >= 120.0:
		_replay_log_t = 0.0
		print("  durum g%d t=%.1fdk nakit=%s taksit=%s/%s top=%d tahta=%d hava=%d/%d oto=%s(%s) top_türü=%s çivi=%d" % [Game.day(), (_game_time - _day_start_time) / 60.0, Fmt.money(float(Game.run["cash"])), Fmt.money(float(Game.run["installment"])), Fmt.money(Game.target()), int(Game.run["ball_level"]), int(Game.run["board_level"]), Game.paid_in_air(), Game.air_limit(), str(Game.run["auto_on"]), Game.auto.status, Game.selected_ball(), PS.placed_count(Game)])
	if Game.installment_done():
		print("TEKRAR: gün %d bitti, oyun %.2f dk, model %.2f dk, atış %d, top_sv %d, tahta_sv %d, bilet %d" % [Game.day(), (_game_time - _day_start_time) / 60.0, float(days[di]["model_minutes"]), int(Game.run["shots_today"]), int(Game.run["ball_level"]), int(Game.run["board_level"]), int(Game.meta["tickets"])])
		_day_start_time = _game_time
		_replay_idx = 0
		Game.prestige_apply()
		_bot_buy_tree(_replay["tree_priority"])


func _bot_pick_ball_and_pegs() -> void:
	# yaklaşık getiri sırası (economy_model.py balls); model her an en yüksek getirili topu seçer
	var order := ["kara_inci", "kuyruklu", "anka", "ikiz", "volkan", "miknatis", "altin", "cam", "kaucuk", "kil", "bakir", "demir"]
	# modelin varsayımı: oyuncu yeni topu ilk ★MAX bonusu için dener
	for b in Game.meta["balls"].keys():
		if not bool(Game.meta["first_max"].get(b, false)):
			order.push_front(b)
			break
	for b in order:
		if BC.owned(Game, b):
			if Game.selected_ball() != b:
				BC.select(Game, b)
			break
	var free_sockets: int = Game.sockets() - PS.placed_count(Game)
	var unplaced := 0
	for pid in Game.run["pegs"].keys():
		unplaced += PS.owned(Game, pid) - PS.placed_count(Game, pid)
	# gerçek oyuncu gibi: düzenleme modunu iste, toplar inince yerleştir ve çık
	if free_sockets > 0 and unplaced > 0 and not Game.edit_mode and not Game.edit_pending:
		Game.set_edit_mode(true)
	if Game.edit_mode:
		var hits: Dictionary = Game.probabilities()["hits"]
		var cells: Array = hits.keys().filter(func(c): return PS.is_placeable_cell(c))
		cells.sort_custom(func(a, b): return float(hits[a]) > float(hits[b]))
		for pid in ["elmas", "altin_civi", "bilet", "gumus", "yildiz", "huni", "ayna", "bakir_civi", "yay", "kalkan"]:
			for c in cells:
				if PS.owned(Game, pid) - PS.placed_count(Game, pid) <= 0 or PS.placed_count(Game) >= Game.sockets():
					break
				PS.place(Game, c, pid)
		Game.set_edit_mode(false)


## Modeldeki Meta.buy_tree ile aynı kural: öncelik sırasındaki ilk alınabilir düğüm için biriktir.
func _bot_buy_tree(priority: Array) -> void:
	while true:
		var progressed := false
		for node in priority:
			var nid: String = node
			if MT.level(Game, nid) >= MT.max_level(nid) or not MT.prereq_ok(Game, nid):
				continue
			if int(Game.meta["tickets"]) >= MT.next_cost(Game, nid):
				MT.buy(Game, nid)
				progressed = true
			break
		if not progressed:
			return


## Olasılık doğrulaması: her tahta seviyesinde DP ile hesaplanan olasılık, gerçek yol üretimiyle
## (animasyonun kullandığı aynı fonksiyon) Monte Carlo olarak karşılaştırılır.
func _verify_probs() -> void:
	var Outcome := preload("res://scripts/systems/outcome_model.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var n := 200000
	var prev_win := 0.0
	for lv in range(1, Outcome.max_board_level() + 1):
		var pr := Outcome.band_probabilities(lv, 0.5, {})
		var cnt := {"M": 0, "W": 0, "L": 0, "E": 0}
		for i in range(n):
			var path := Outcome.roll_path(rng, 0.5, {})
			cnt[Outcome.type_at(float(path["u"]), lv)] += 1
		var mc_win := float(cnt["M"] + cnt["W"]) / n
		print("Tahta Sv.%2d  DP kazanma %.4f  MC %.4f  | MAX DP %.4f MC %.4f | artış: %s" % [lv, pr["win"], mc_win, pr["types"]["M"], float(cnt["M"]) / n, "EVET" if float(pr["win"]) > prev_win else "HAYIR"])
		prev_win = float(pr["win"])
	# Görsel iniş doğrulaması: oyunun kendi top uçuşu (BallFlight) üretilir, animasyonun son karesindeki
	# x konumundan bant türü okunur ve tahtada yazan olasılıklarla karşılaştırılır (çekimli top + huni çivisi).
	var Flight := preload("res://scripts/board/ball_flight.gd")
	var Geo := preload("res://scripts/board/board_geometry.gd")
	var layout := {Vector2i(3, 1): "huni", Vector2i(5, 3): "yay"}
	for case in [[3, 0.5, {}], [3, 0.56, {}], [5, 0.5, layout]]:
		var lv: int = case[0]
		var bias: float = case[1]
		var lay: Dictionary = case[2]
		var pr2 := Outcome.band_probabilities(lv, bias, lay)
		var cnt2 := {"M": 0, "W": 0, "L": 0, "E": 0}
		var m := 60000
		for i in range(m):
			var f = Flight.new()
			f.setup_timing(float(GameData.eco["fall_time"]), GameData.rows())
			f.start_point = Vector2(Geo.CX, Geo.SPAWN_Y)
			var path := Outcome.roll_path(rng, bias, lay)
			f.hits = path["hits"]
			f.dirs = path["dirs"]
			f.u = float(path["u"])
			var end_x: float = f.position_at(f.duration()).x
			cnt2[Outcome.type_at(Geo.x_to_u(end_x, GameData.rows()), lv)] += 1
		print("GÖRSEL Sv.%d çekim %.2f çivi %d | tahtada yazan M %.3f W %.3f L %.3f E %.3f | animasyon M %.3f W %.3f L %.3f E %.3f" % [
			lv, bias, lay.size(), pr2["types"]["M"], pr2["types"]["W"], pr2["types"]["L"], pr2["types"]["E"],
			float(cnt2["M"]) / m, float(cnt2["W"]) / m, float(cnt2["L"]) / m, float(cnt2["E"]) / m])
	Game.quit_game()


func _debug_capture() -> void:
	_debug_seconds = -1.0
	if _debug_shot != "":
		# pencere arka planda kalmışsa son kare eski olabilir: yakalamadan önce bir kare çizdir
		RenderingServer.force_draw(false)
		var img: Image = ui.get_viewport().get_texture().get_image()
		img.save_png(_debug_shot)
		if _debug_crop.size.x > 0:
			# yakın plan: bölgeyi kes ve en-yakın filtreyle 2 kat büyüt
			var sc: float = float(img.get_width()) / float(ui.get_viewport_rect().size.x)
			var reg := img.get_region(Rect2i(Vector2i(_debug_crop.position * sc), Vector2i(_debug_crop.size * sc)))
			reg.resize(reg.get_width() * 2, reg.get_height() * 2, Image.INTERPOLATE_NEAREST)
			reg.save_png(_debug_shot.get_basename() + "_zoom.png")
		print("ekran görüntüsü: ", _debug_shot, " pencere=", ui.get_window().size, " düzen=", ui.get_viewport_rect().size)
	if _debug_measure:
		print("ÖLÇÜM atış=%d kâr=%.2f atış_başı_net_X=%.4f MAX_oranı=%.4f" % [int(Game.run["shots_today"]), float(Game.run["profit"]),
			float(Game.run["profit"]) / maxf(1.0, float(Game.run["shots_today"])) / Game.x(),
			float(Game.run["max_today"]) / maxf(1.0, float(Game.run["shots_today"]))])
	if _debug_print:
		print("DURUM gün=%d nakit=%.2f bilet=%d top_sv=%d tahta_sv=%d havada=%d atış=%d fps=%d" % [
			Game.day(), float(Game.run["cash"]), int(Game.meta["tickets"]), int(Game.run["ball_level"]),
			int(Game.run["board_level"]), Game.flights.size(), int(Game.meta["stats"]["shots_total"]), Engine.get_frames_per_second()])
	Game.save_now()
	Game.quit_game()


## Tüm top/çivi sprite'larının karelerini PNG sayfalarında toplar (tasarım incelemesi için):
## <yol>_1.png, _2.png ... (sayfa başına 6 tür; solda tahta boyu ×4, sağda arayüz boyu ×2).
func _sprite_sheet(path: String) -> void:
	var SG := preload("res://scripts/art/sprite_gen.gd")
	var kinds: Array = []
	for b in GameData.balls:
		kinds.append("ball:" + String(b["id"]))
	for p in GameData.pegs:
		kinds.append("peg:" + String(p["id"]))
	var page := 0
	while page * 6 < kinds.size():
		var rows: Array = []
		var w := 0
		var h := 0
		for i in range(page * 6, mini(kinds.size(), page * 6 + 6)):
			var small: Array = SG.make(kinds[i], false)
			var big: Array = SG.make(kinds[i], true)
			var ss: int = (small[0] as Image).get_width()
			var bs: int = (big[0] as Image).get_width()
			var rh := maxi(ss * 4, bs * 2) + 6
			w = maxi(w, (ss * 4 + 4) * 4 + (bs * 2 + 4) * 4)
			h += rh
			rows.append({"small": small, "big": big, "h": rh})
		var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("13925f"))
		var y := 0
		for row in rows:
			var x := 0
			for f in range(4):
				var im: Image = (row["small"][f * 3] as Image).duplicate()
				im.resize(im.get_width() * 4, im.get_height() * 4, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
				x += im.get_width() + 4
			for f in range(4):
				var im2: Image = (row["big"][f * 3] as Image).duplicate()
				im2.resize(im2.get_width() * 2, im2.get_height() * 2, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(im2, Rect2i(Vector2i.ZERO, im2.get_size()), Vector2i(x, y))
				x += im2.get_width() + 4
			y += int(row["h"])
		page += 1
		sheet.save_png(path.get_basename() + "_%d.png" % page)
	print("sprite sayfası: ", path)
