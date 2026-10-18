extends RefCounted
## Otomatik atıcı. Yalnızca oyun açıkken çalışır; çevrimdışı ilerleme üretmez.
## Bakiye rezervinin altına inmez; ayarlanmışsa rezerve düşünce kendini kapatır.

var timer := 0.0
var status := "locked"   # locked | off | running | waiting_air | reserve | paused_edit


func reset() -> void:
	timer = 0.0
	status = "off"


func tick(game, delta: float) -> void:
	if int(game.run["up"]["auto_unlock"]) == 0:
		status = "locked"
		return
	if not bool(game.run["auto_on"]):
		status = "off"
		timer = 0.0
		return
	if game.edit_mode or game.edit_pending:
		status = "paused_edit"
		return
	var iv: float = game.auto_interval()
	timer += delta
	if timer < iv:
		if status != "reserve" and status != "waiting_air":
			status = "running"
		return
	if game.air_free() <= 0:
		status = "waiting_air"
		timer = iv
		return
	var n: int = game.request_launch(game.auto_batch(), "auto")
	if n <= 0:
		status = "reserve"
		timer = iv
		if bool(game.meta["auto"]["off_on_reserve"]):
			game.run["auto_on"] = false
			game.toast.emit(Loc.t("toast.auto_off_reserve"), "warn")
			game.changed.emit()
		return
	status = "running"
	timer = minf(timer - iv, iv)
