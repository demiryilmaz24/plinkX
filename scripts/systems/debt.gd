extends RefCounted
## Günlük taksit ve toplam borç.
## - Bir günde ödenebilecek miktar o günün kalan taksitiyle sınırlıdır (fazla ödeme yapılamaz).
## - Taksit dolunca gösterge dolu kalır; sonraki kazançlar yalnızca sefer bakiyesini etkiler.
## - Ödenen borç kalıcıdır (prestijde korunur).

const MetaTree := preload("res://scripts/systems/meta_tree.gd")


## amount kadar (bakiye ve kalan taksitle sınırlı) öder. Döner: ödenen miktar.
static func pay(game, amount: float) -> float:
	if game.is_free_mode():
		return 0.0
	var left: float = game.installment_left()
	var paid := minf(minf(amount, float(game.run["cash"])), left)
	if paid <= 0.0:
		return 0.0
	game.run["cash"] = float(game.run["cash"]) - paid
	game.run["installment"] = float(game.run["installment"]) + paid
	game.meta["debt_paid"] = float(game.meta["debt_paid"]) + paid
	if game.installment_left() <= 0.001:
		# kayan nokta artığını temizle: gösterge tam hedefte kalsın
		var extra: float = float(game.run["installment"]) - game.target()
		game.run["installment"] = game.target()
		game.meta["debt_paid"] = float(game.meta["debt_paid"]) - extra
		if not bool(game.run["installment_done_announced"]):
			game.run["installment_done_announced"] = true
			game.installment_completed.emit()
			if game.day() >= GameData.day_count() and game.debt_left() <= 0.5:
				game.meta["debt_paid"] = GameData.total_debt()
				game.meta["story_done"] = true
				game.meta["stats"]["debt_cleared"] = 1
				game.story_finished.emit()
		game.save_now()
	game.changed.emit()
	return paid


## Bilet ağacı "Taksit Otomatiği": açıkken rezervin üstündeki nakit taksite aktarılır.
static func tick(game) -> void:
	if game.is_free_mode() or MetaTree.level(game, "auto_pay") == 0:
		return
	if not bool(game.meta["auto"].get("auto_pay_on", false)):
		return
	if game.installment_left() <= 0.0:
		return
	var spare: float = float(game.run["cash"]) - game.reserve_amount()
	if spare > 0.0:
		pay(game, spare)
