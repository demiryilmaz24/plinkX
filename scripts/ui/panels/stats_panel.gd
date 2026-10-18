extends ScrollContainer
## İstatistikler. Temel satırlar her zaman görünür; ayrıntılı sayfa bilet ağacındaki "Defter" ile açılır.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")

const BASIC := ["play_time", "shots_total", "max_total", "jackpots", "best_win", "days_closed"]
const DETAILED := ["auto_shots", "bonus_balls", "total_won", "run_profit_best", "tickets_earned",
	"tickets_spent", "ball_spins", "peg_spins", "jobs_done", "peg_tickets", "ball_level_best",
	"board_level_best", "cash_spent_shop", "calls", "boosts", "fines_paid", "collected"]
const MONEY := ["best_win", "total_won", "run_profit_best", "cash_spent_shop", "fines_paid", "collected"]

var _box: VBoxContainer
var _last_ms := -100000


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = UI.vbox(4)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_box)


func _row(name_: String, value: String, col: Color = UI.TEXT) -> void:
	var h := UI.hbox(8)
	var l := UI.label(name_, 14, UI.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.label(value, 14, col))
	_box.add_child(h)


func _fmt(key: String) -> String:
	var v: float = float(Game.meta["stats"].get(key, 0))
	if key == "play_time":
		return Fmt.duration(v)
	if key in MONEY:
		return Fmt.money(v)
	return Fmt.num(v)


func refresh() -> void:
	if Time.get_ticks_msec() - _last_ms < 1000:
		return
	_last_ms = Time.get_ticks_msec()
	UI.clear(_box)
	_box.add_child(UI.label(Loc.t("stats.header"), 16, UI.BRASS))
	for k in BASIC:
		_row(Loc.t("stats." + k), _fmt(k))
	# bugün
	_box.add_child(UI.section_title(Loc.t("stats.today")))
	_row(Loc.t("stats.today_shots"), Fmt.num(int(Game.run["shots_today"])))
	_row(Loc.t("stats.today_max"), Fmt.num(int(Game.run["max_today"])))
	_row(Loc.t("stats.today_jackpots"), Fmt.num(int(Game.run["jackpots_today"])))
	_row(Loc.t("stats.today_cards"), Fmt.num(int(Game.run["cards_today"])))
	if MetaTree.level(Game, "stats") == 0:
		_box.add_child(UI.wrap_label(Loc.t("stats.locked"), 13, UI.WARN))
		return
	_box.add_child(UI.section_title(Loc.t("tab.stats")))
	for k in DETAILED:
		_row(Loc.t("stats." + k), _fmt(k))
	# en çok kullanılan top
	var bs: Dictionary = Game.meta["stats"]["ball_shots"]
	var best := ""
	var best_n := -1
	for bid in bs.keys():
		if int(bs[bid]) > best_n:
			best_n = int(bs[bid])
			best = bid
	if best != "":
		_row(Loc.t("stats.most_used"), "%s (%s)" % [Loc.t("ball." + best + ".name"), Fmt.num(best_n)], UI.BRASS)
	_box.add_child(UI.section_title(Loc.t("stats.balls_title")))
	for bid in bs.keys():
		_row(Loc.t("ball." + bid + ".name"), Fmt.num(int(bs[bid])))
