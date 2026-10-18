extends RefCounted
## Masadaki telefon: iyi karakterlerin "Ateş Modu" hediyesi ve Sadık Bey'in tehdit/ceza aramaları.
## Kurallar (sabit veriler: economy.json → phone):
##  - Zamanlayıcılar yalnızca oyuncu masadayken sayar (oyun duraklatılmamış, pencere/düzenleme yok, Ateş Modu yok,
##    oyun penceresi odakta). Çalan telefon da o sırada bekler; oyuncu dönünce çalmaya devam eder.
##    Oyun kapalıyken hiçbir şey ilerlemez.
##  - İyi arama (Nevin Abla veya gece bekçisi): açılırsa 15 sn Ateş Modu → oyun hızı ×2, hava sınırı kalkar.
##    Olasılıklar ve ödemeler değişmez; yalnızca atış hızı artar. Açılmayan arama kaçar.
##  - Tehdit (Sadık Bey): yalnızca bugünkü taksit tamamlanmamışken arar. Tavrı o anki duruma göredir (threat_mode):
##    "collect": bugün taksite hiç ödeme yapılmamış → "kasa hâlâ boş" der, cebe collect_leave_x × X bırakıp kalan
##               nakde el koyar ve bugünkü taksite yatırır (para kaybolmaz ama yükseltmelere gidemez → gün uzar).
##    "warn":    bir kısmı ödenmiş → ceza riski. Ceza ihtimali = fine_chance_max × (1 − bugün ödenen / taksit);
##               ceza = kasadaki nakdin fine_rate kadarı. "Şimdi Öde" rezervin üstündeki nakdi taksite yatırır ve
##               Sadık Bey memnun kalır (ceza yok); "Kapat" ceza zarını atar.
##    Açılmayan arama sesli mesaj bırakır; tahsilat ya da ceza zarı yine uygulanır.

const Debt := preload("res://scripts/systems/debt.gd")


static func cfg() -> Dictionary:
	return GameData.eco["phone"]


static func _rand(game, r: Array) -> float:
	return game.rng.randf_range(float(r[0]), float(r[1]))


## Yeni gün: ilk arama zamanları, Ateş Modu ve çalan arama sıfırlanır.
static func reset_run(game) -> void:
	game.run["phone_good_t"] = _rand(game, cfg()["good_first"])
	game.run["phone_threat_t"] = _rand(game, cfg()["threat_first"])
	cancel(game)


## Gün kapanırken: çalan arama susar, Ateş Modu söner.
static func cancel(game) -> void:
	game.ringing = {}
	if game.boost_left > 0.0:
		game.boost_left = 0.0
		game.boost_ended.emit()


static func boost_active(game) -> bool:
	return game.boost_left > 0.0


## Her kare, gerçek zamanla (oyun duraklatılmamışken çağrılır).
static func tick(game, delta: float) -> void:
	if game.boost_left > 0.0:
		game.boost_left -= delta
		if game.boost_left <= 0.0:
			game.boost_left = 0.0
			game.boost_ended.emit()
		return
	if game.ui_busy or game.edit_mode or game.edit_pending or not game.has_focus:
		return
	if not game.ringing.is_empty():
		game.ringing["t"] = float(game.ringing["t"]) - delta
		if float(game.ringing["t"]) <= 0.0:
			_missed(game)
		return
	game.run["phone_good_t"] = float(game.run["phone_good_t"]) - delta
	var threat_on: bool = not game.is_free_mode() and not game.installment_done()
	if threat_on:
		game.run["phone_threat_t"] = float(game.run["phone_threat_t"]) - delta
	if float(game.run["phone_good_t"]) <= 0.0:
		game.run["phone_good_t"] = _rand(game, cfg()["good_every"])
		_ring(game, "good")
	elif threat_on and float(game.run["phone_threat_t"]) <= 0.0:
		game.run["phone_threat_t"] = _rand(game, cfg()["threat_every"])
		_ring(game, "threat")


static func _ring(game, kind: String) -> void:
	var who := "sadik"
	if kind == "good":
		who = "guard" if game.rng.randf() < 0.35 else "nevin"
	game.ringing = {"kind": kind, "who": who, "t": float(cfg()["ring_secs"]), "line": game.rng.randi_range(1, 3)}
	game.phone_ring.emit(game.ringing)


## Telefonu açar: çalan aramayı döndürür (çalmıyorsa boş sözlük).
static func answer(game) -> Dictionary:
	var c: Dictionary = game.ringing
	game.ringing = {}
	if not c.is_empty():
		game.meta["stats"]["calls"] = int(game.meta["stats"].get("calls", 0)) + 1
	return c


static func _missed(game) -> void:
	var c: Dictionary = game.ringing
	game.ringing = {}
	if String(c["kind"]) == "threat":
		var mode := threat_mode(game)
		if mode == "collect":
			game.phone_voicemail.emit(c, {"mode": mode, "paid": collect(game)})
		elif mode == "warn":
			var r := roll_fine(game)
			r["mode"] = mode
			game.phone_voicemail.emit(c, r)
	else:
		game.phone_missed.emit(c)


## Ateş Modu: oyun hızı ×boost_speed, hava sınırı boost_air_cap (fiilen sınırsız).
static func start_boost(game) -> void:
	game.boost_left = float(cfg()["boost_secs"])
	game.meta["stats"]["boosts"] = int(game.meta["stats"].get("boosts", 0)) + 1
	game.boost_started.emit(game.boost_left)


## Sadık Bey'in o anki tavrı: "paid" (taksit tamam), "collect" (bugün hiç ödeme yok), "warn" (ceza riski).
static func threat_mode(game) -> String:
	if game.is_free_mode() or game.installment_done():
		return "paid"
	if float(game.run["installment"]) <= 0.0:
		return "collect"
	return "warn"


## Kasa boş cezası: cebe collect_leave_x × X bırakır, kalan nakde el koyup bugünkü taksite yatırır.
## Döner: yatırılan tutar.
static func collect(game) -> float:
	var leave: float = float(cfg()["collect_leave_x"]) * game.x()
	var paid := Debt.pay(game, maxf(0.0, float(game.run["cash"]) - leave))
	if paid > 0.0:
		game.meta["stats"]["collected"] = float(game.meta["stats"].get("collected", 0.0)) + paid
	return paid


static func fine_chance(game) -> float:
	if game.is_free_mode() or game.installment_done():
		return 0.0
	var ratio := clampf(float(game.run["installment"]) / maxf(1.0, game.target()), 0.0, 1.0)
	return float(cfg()["fine_chance_max"]) * (1.0 - ratio)


static func fine_amount(game) -> float:
	return floorf(float(game.run["cash"]) * float(cfg()["fine_rate"]))


## Ceza zarı. Döner: {fined, amount, chance}
static func roll_fine(game) -> Dictionary:
	var p := fine_chance(game)
	var amount := fine_amount(game)
	var hit: bool = amount >= 1.0 and game.rng.randf() < p
	if hit:
		game.run["cash"] = float(game.run["cash"]) - amount
		game.run["profit"] = float(game.run["profit"]) - amount
		game.meta["stats"]["fines_paid"] = float(game.meta["stats"].get("fines_paid", 0.0)) + amount
		game.changed.emit()
	return {"fined": hit, "amount": amount if hit else 0.0, "chance": p}


## "Şimdi Öde" düğmesinin yatıracağı tutar (rezervin üstündeki nakit, bugünkü kalan taksitle sınırlı).
static func pay_now_amount(game) -> float:
	return minf(maxf(0.0, float(game.run["cash"]) - game.reserve_amount()), game.installment_left())


## Telefonda "Şimdi Öde": rezervin üstündeki nakdi bugünkü taksite yatırır. Sadık Bey memnun kalır ve ceza
## kesmez; yalnızca yatırılan, kesilecek cezadan bile azsa (rezerv çok yüksek tutulmuşsa) zar yine atılır.
## Döner: {paid, satisfied, fine (zar atıldıysa roll_fine sonucu, yoksa boş)}
static func pay_now(game) -> Dictionary:
	var fine_before := fine_amount(game)
	var paid := Debt.pay(game, pay_now_amount(game))
	var ok: bool = paid > 0.0 and (paid >= fine_before or fine_before <= game.x() or game.installment_done())
	var out := {"paid": paid, "satisfied": ok, "fine": {}}
	if not ok:
		out["fine"] = roll_fine(game)
	return out
