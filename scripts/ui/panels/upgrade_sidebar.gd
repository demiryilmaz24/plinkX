extends VBoxContainer
## Sol kenar: iki sekme (Yükseltme / Otomasyon) ve resimli, az metinli kartlar.
## Kart açıklamaları araç ipucundadır. Karta tıklamak satın alır (Toplu Alım açıksa Shift+tık = Maks).

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Card := preload("res://scripts/ui/widgets/upgrade_card.gd")
const RunShop := preload("res://scripts/systems/run_shop.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")

const TABS := {
	"upgrades": ["ball_level", "board_level", "batch", "air", "polish", "sockets"],
	"auto": ["auto_unlock", "auto_speed", "auto_batch"],
}

var _accents := {
	"ball_level": UI.GOLD, "board_level": UI.MINT, "batch": UI.PINK, "air": UI.SKY, "polish": UI.PURPLE,
	"sockets": UI.ORANGE, "auto_unlock": UI.SKY, "auto_speed": UI.GOLD, "auto_batch": UI.PINK,
}
var _tab := "upgrades"
var _tab_buttons: Dictionary = {}
var _job: Button
var _lists: Dictionary = {}
var _cards: Dictionary = {}
var _auto_box: PanelContainer
var _auto_btn: Button
var _auto_status: Label
var _auto_info: Label
var _reserve: OptionButton
var _off_on_reserve: CheckBox


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var tabs := UI.hbox(6)
	add_child(tabs)
	for t in ["upgrades", "auto"]:
		var b := UI.button(Loc.t("side.tab." + t), _set_tab.bind(t))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 11)
		tabs.add_child(b)
		_tab_buttons[t] = b
	_job = Card.new()
	_job.setup("job", Loc.t("card.job"), UI.MINT)
	_job.pressed.connect(_on_job)
	add_child(_job)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var holder := UI.vbox(6)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for t in TABS.keys():
		var list := UI.vbox(6)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(list)
		_lists[t] = list
		if t == "auto":
			list.add_child(_build_auto_box())
		for key in TABS[t]:
			var c := Card.new()
			c.setup("up:" + key, Loc.t("card." + key), _accents[key])
			c.pressed.connect(_on_card.bind(key))
			list.add_child(c)
			_cards[key] = c
	_set_tab("upgrades")


func _build_auto_box() -> PanelContainer:
	_auto_box = UI.panel(Color("23296e"), UI.BORDER, 10, 2)
	var v := UI.vbox(6)
	_auto_box.add_child(v)
	_auto_btn = UI.button("", _on_auto_toggle)
	_auto_btn.custom_minimum_size.y = 40
	_auto_btn.add_theme_font_size_override("font_size", 22)
	v.add_child(_auto_btn)
	_auto_status = UI.title("", 11, UI.MINT, 2)
	v.add_child(_auto_status)
	_auto_info = UI.label("", 11, UI.MUTED)
	v.add_child(_auto_info)
	var rh := UI.hbox(6)
	rh.add_child(Icon.make("peg:kalkan", 20))
	rh.add_child(UI.label(Loc.t("side.reserve"), 11, UI.MUTED))
	_reserve = OptionButton.new()
	_reserve.focus_mode = Control.FOCUS_NONE
	_reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reserve.tooltip_text = Loc.t("left.reserve_tip")
	for xv in GameData.eco["auto"]["reserve_presets_x"]:
		_reserve.add_item(Fmt.money(float(xv) * GameData.x_value()))
	_reserve.item_selected.connect(func(i): Game.meta["auto"]["reserve_idx"] = i)
	rh.add_child(_reserve)
	v.add_child(rh)
	_off_on_reserve = CheckBox.new()
	_off_on_reserve.text = Loc.t("side.off_on_reserve")
	_off_on_reserve.focus_mode = Control.FOCUS_NONE
	_off_on_reserve.tooltip_text = Loc.t("left.off_on_reserve")
	_off_on_reserve.toggled.connect(func(on): Game.meta["auto"]["off_on_reserve"] = on)
	v.add_child(_off_on_reserve)
	return _auto_box


func _set_tab(t: String) -> void:
	_tab = t
	for k in _lists.keys():
		_lists[k].visible = k == t
	for k in _tab_buttons.keys():
		UI.paint_button(_tab_buttons[k], UI.GOLD if k == t else Color("3a43a8"), Color("2a1200") if k == t else UI.TEXT)
	refresh()


func show_tab(t: String) -> void:
	_set_tab(t)


func _on_job() -> void:
	if Game.job_left > 0.0:
		return
	Game.start_job()
	Sfx.play("job", 1.0, -6.0)


func _on_card(key: String) -> void:
	var bought := 0
	if Input.is_key_pressed(KEY_SHIFT) and MetaTree.level(Game, "bulk_buy") > 0:
		bought = RunShop.buy_many(Game, key, 0)
	else:
		bought = 1 if RunShop.buy(Game, key) else 0
	if bought > 0:
		_cards[key].flash()
		Sfx.play("buy", 1.0 + minf(0.3, bought * 0.02), -6.0)
	else:
		Sfx.play("error", 1.0, -10.0)
	refresh()


func _on_auto_toggle() -> void:
	Game.run["auto_on"] = not bool(Game.run["auto_on"])
	Sfx.play("buy", 1.2 if Game.run["auto_on"] else 0.9, -8.0)
	refresh()


func _tip(key: String, inf: Dictionary) -> String:
	var lines: Array = [Loc.t("shop." + key + ".name"), Loc.t("shop." + key + ".desc")]
	if inf["block"] == "shop.maxed":
		lines.append(Loc.t("shop.effect_now", {"v": inf["now"]}))
	else:
		lines.append(Loc.t("side.tip_effect", {"a": inf["now"], "b": inf["next"]}))
	var block: String = inf["block"]
	if block != "":
		var args: Dictionary = inf["block_args"]
		if block == "shop.day_cap" and int(args.get("next", -1)) > int(args.get("cap", 0)):
			lines.append(Loc.t("shop.day_cap_next", args))
		elif block == "shop.day_cap":
			lines.append(Loc.t("shop.day_cap", args))
		else:
			lines.append(Loc.t(block, args))
	if MetaTree.level(Game, "bulk_buy") > 0:
		lines.append(Loc.t("side.tip_bulk"))
	return "\n".join(lines)


func refresh() -> void:
	var cash: float = float(Game.run["cash"])
	# Ek iş
	var working := Game.job_left > 0.0
	_job.set_state("+" + Fmt.money(Game.job_pay()), true, Loc.t("side.job_time", {"s": int(Game.job_duration())}),
		(1.0 - Game.job_left / Game.job_duration()) if working else 0.0, "", Loc.t("left.job_desc", {"s": int(Game.job_duration()), "v": Fmt.money(Game.job_pay())}))
	_job.disabled = working
	# Kartlar
	for key in TABS[_tab]:
		var inf := RunShop.info(Game, key)
		var lv: int = inf["level"]
		var block: String = inf["block"]
		var lvl_txt := ""
		var ratio := -1.0
		match key:
			"batch":
				lvl_txt = "×%d" % Game.batch_sizes()[Game.batch_sizes().size() - 1]
			"auto_unlock":
				lvl_txt = Loc.t("common.on") if lv > 0 else ""
			"ball_level":
				lvl_txt = Loc.t("side.lvl", {"l": lv, "c": "∞" if Game.is_free_mode() else str(inf["cap"])})
				ratio = float(lv) / maxf(1.0, float(inf["cap"])) if not Game.is_free_mode() else -1.0
			_:
				lvl_txt = Loc.t("side.lvl", {"l": lv, "c": inf["cap"]})
				ratio = float(lv) / maxf(1.0, float(inf["cap"]))
		var locked_txt := ""
		match block:
			"shop.unlock_day":
				locked_txt = Loc.t("side.unlock_day", {"d": inf["block_args"]["day"]})
			"shop.need_auto":
				locked_txt = Loc.t("side.need_auto")
			"shop.maxed":
				locked_txt = Loc.t("side.maxed")
			"shop.day_cap":
				locked_txt = Loc.t("side.day_cap")
		var c: float = inf["cost"]
		_cards[key].set_state(Fmt.money(c), cash >= c, lvl_txt, ratio, locked_txt, _tip(key, inf))
	# Otomasyon kutusu
	if _tab == "auto":
		var unlocked := int(Game.run["up"]["auto_unlock"]) > 0
		_auto_box.visible = unlocked
		if unlocked:
			var on := bool(Game.run["auto_on"])
			_auto_btn.text = Loc.t("left.auto_stop") if on else Loc.t("left.auto_start")
			UI.paint_button(_auto_btn, UI.CORAL if on else UI.MINT, Color.WHITE if on else Color("06301f"))
			var stt: String = Game.auto.status
			_auto_status.text = "● " + Loc.t("auto.short." + stt)
			var col := UI.MUTED
			match stt:
				"running":
					col = UI.MINT
				"reserve", "waiting_air", "paused_edit":
					col = UI.ORANGE
			_auto_status.add_theme_color_override("font_color", col)
			_auto_info.text = Loc.t("left.auto_info", {"s": Fmt.dec(Game.auto_interval(), 2), "n": Game.auto_batch()})
			if _reserve.selected != int(Game.meta["auto"]["reserve_idx"]):
				_reserve.select(int(Game.meta["auto"]["reserve_idx"]))
			_off_on_reserve.set_pressed_no_signal(bool(Game.meta["auto"]["off_on_reserve"]))
