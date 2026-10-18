extends RefCounted
## Tek seferlik başarımlar. Tamamlanınca bilet ödülü verir; aynı kayıtta tekrar alınamaz.


static func stat_value(game, stat: String) -> float:
	var st: Dictionary = game.meta["stats"]
	match stat:
		"rarity_rare", "rarity_epic", "rarity_legendary":
			var want := stat.substr(7)
			var n := 0
			for bid in game.meta["balls"].keys():
				if GameData.balls_by_id[bid]["rarity"] == want:
					n += 1
			return n
		"rarities_owned":
			var seen := {}
			for bid in game.meta["balls"].keys():
				seen[GameData.balls_by_id[bid]["rarity"]] = true
			return seen.size()
		"ball_types":
			return game.meta["balls"].size()
		"max_mastery":
			var m := 0
			for v in game.meta["balls"].values():
				m = maxi(m, int(v))
			return m
		"run_profit_best":
			return maxf(float(st["run_profit_best"]), float(game.run["profit"]))
		"free_profit_best":
			var cur := float(game.run["profit"]) if game.is_free_mode() else 0.0
			return maxf(float(st["free_profit_best"]), cur)
	return float(st.get(stat, 0))


static func check_all(game) -> void:
	for a in GameData.achievements:
		var id: String = a["id"]
		if game.meta["achievements"].has(id):
			continue
		if stat_value(game, a["stat"]) >= float(a["value"]):
			unlock(game, a)


static func unlock(game, a: Dictionary) -> void:
	var id: String = a["id"]
	game.meta["achievements"][id] = true
	game.add_tickets(int(a["tickets"]), "achievement")
	game.achievement_unlocked.emit(id)
	game.toast.emit(Loc.t("toast.achievement", {"name": Loc.t("ach." + id + ".name"), "n": int(a["tickets"])}), "ticket")
	game.changed.emit()
