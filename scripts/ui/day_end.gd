extends Control
## Gün sonu ekranı (tam ekran, gece teması). İki aşama:
##  1) Özet: bugünün sayıları (ikonlu karolar), kazanılacak biletler, sıfırlanan/kalan, yarın.
##     İstatistikler düğmesi tüm istatistikleri gösterir. "Masaya Dön" günü sürdürür, "GÜNÜ BİTİR" kapatır.
##  2) Bilet Ağacı: gün kapandıktan sonra açılır; oyuncu biletlerini harcar ve "YENİ GÜNÜ BAŞLAT"a basar.
##     Ağaç yalnızca burada erişilebilir; gün içinde açılmaz.

signal back_requested
signal close_confirmed
signal start_requested

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const TreePanel := preload("res://scripts/ui/panels/tree_panel.gd")
const StatsPanel := preload("res://scripts/ui/panels/stats_panel.gd")

var phase := ""
var _body: VBoxContainer
var _stars: Array = []
var _tree: Control
var _stats: Control
var _summary: Control
var _ticket_label: Label
var _shown_tickets := 0.0
var _stats_btn: Button
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(120):
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf() * TAU])
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	_body = UI.vbox(12)
	_body.custom_minimum_size = Vector2(1000, 0)
	cc.add_child(_body)


func _process(delta: float) -> void:
	_t += delta
	if _ticket_label:
		var target := float(Game.meta["tickets"])
		if absf(_shown_tickets - target) > 0.5:
			_shown_tickets = move_toward(_shown_tickets, target, maxf(1.0, absf(target - _shown_tickets) * 3.0) * delta)
		else:
			_shown_tickets = target
		_ticket_label.text = str(int(round(_shown_tickets)))
	if _tree and is_instance_valid(_tree) and int(_t * 10.0) % 3 == 0:
		_tree.refresh()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120c30"))
	# ufukta mor bant
	for i in range(6):
		draw_rect(Rect2(0, size.y - (i + 1) * 18.0, size.x, 18.0), Color(0.23, 0.16, 0.48, 0.10 + i * 0.0))
	for s in _stars:
		var p := Vector2((s[0] as Vector2).x * size.x, (s[0] as Vector2).y * size.y).floor()
		var on := sin(_t * 2.0 + float(s[1])) > -0.2
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 0.95, 0.85, 0.8 if on else 0.3))


# =================================================================== aşama 1: özet

func show_summary() -> void:
	phase = "summary"
	UI.clear(_body)
	_tree = null
	_ticket_label = null
	var pv := Game.prestige_preview()
	var free := bool(pv["free_mode"])
	# başlık
	var head := UI.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(Icon.make("moon", 44))
	head.add_child(UI.title(Loc.t("dayend.title_free") if free else Loc.t("dayend.title", {"d": int(pv["day"])}), 44, UI.GOLD, 8))
	_body.add_child(head)
	if not free:
		var sub := UI.title(Loc.t("dayend.sub", {"v": Fmt.money(float(pv["debt_left"]))}), 11, Color("cfc6ff"), 2)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(sub)
	_summary = UI.vbox(12)
	_body.add_child(_summary)
	var row := UI.hbox(12)
	_summary.add_child(row)
	# bugün: ikonlu sayı karoları
	var today := _section(Loc.t("dayend.today"), UI.SKY)
	today.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(today)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	today.get_child(0).add_child(grid)
	var r: Dictionary = Game.run
	grid.add_child(_tile("up:batch", Fmt.num(int(r["shots_today"])), Loc.t("dayend.s_shots"), UI.SKY))
	grid.add_child(_tile("star", Fmt.num(int(r["max_today"])), Loc.t("dayend.s_max"), UI.GOLD))
	grid.add_child(_tile("coin", Fmt.num(int(r["jackpots_today"])), Loc.t("dayend.s_jackpots"), UI.ORANGE))
	grid.add_child(_tile("card", Fmt.num(int(r["cards_today"])), Loc.t("dayend.s_cards"), UI.PINK))
	grid.add_child(_tile("pay", Fmt.money(float(r["profit"])), Loc.t("dayend.s_profit"), UI.MINT))
	grid.add_child(_tile("check", Fmt.money(float(r["installment"])), Loc.t("dayend.s_paid"), UI.MINT))
	# biletler
	var tk := _section(Loc.t("dayend.tickets"), UI.ORANGE, Color("4a1a5e"))
	tk.custom_minimum_size.x = 330
	row.add_child(tk)
	var tv := tk.get_child(0) as VBoxContainer
	var big := UI.hbox(10)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_child(Icon.make("ticket", 66))
	var pt: Dictionary = pv["prestige"]
	big.add_child(UI.title("+%d" % int(pt["total"]), 44, UI.ORANGE, 8))
	tv.add_child(big)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_child(_chip(Loc.t("dayend.t_base", {"n": int(pt["base"])}), Color("f4d9ff")))
	chips.add_child(_chip(Loc.t("dayend.t_perf", {"n": int(pt["perf"])}), Color("f4d9ff")))
	if float(pt["bonus_pct"]) > 0.0:
		chips.add_child(_chip(Loc.t("dayend.t_bonus", {"n": int(round(float(pt["bonus_pct"]) * 100.0))}), UI.GOLD))
	chips.add_child(_chip(Loc.t("dayend.t_run", {"n": int(pv["tickets_run"])}), UI.MINT))
	tv.add_child(chips)
	tk.tooltip_text = Loc.t("prestige.tickets_formula", {
		"b": int(pt["base"]), "p": int(pt["perf"]), "k": Fmt.money(float(pv["profit"])),
		"x": int(round(float(pt["bonus_pct"]) * 100.0)),
		"kk": Fmt.dec(float(GameData.eco["tickets"]["prestige_perf_k"]), 0),
		"cap": int(GameData.eco["tickets"]["prestige_perf_cap"])})
	# sıfırlanan / kalan (ikon çipleri)
	var rs: Dictionary = pv["reset"]
	var kp: Dictionary = pv["keep"]
	var rr := UI.hbox(12)
	_summary.add_child(rr)
	var reset := _section(Loc.t("dayend.reset"), UI.CORAL)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.tooltip_text = Loc.t("prestige.reset_slots")
	rr.add_child(reset)
	var rh := UI.hbox(6)
	reset.get_child(0).add_child(rh)
	rh.add_child(_icon_chip("coin", Fmt.money(float(rs["cash"])), Loc.t("prestige.reset_cash", {"v": Fmt.money(float(rs["cash"]))})))
	rh.add_child(_icon_chip("up:ball_level", Loc.t("common.lv", {"n": int(rs["ball_level"])}), Loc.t("prestige.reset_levels", {"b": int(rs["ball_level"]), "t": int(rs["board_level"])})))
	rh.add_child(_icon_chip("up:board_level", Loc.t("common.lv", {"n": int(rs["board_level"])}), Loc.t("prestige.reset_levels", {"b": int(rs["ball_level"]), "t": int(rs["board_level"])})))
	rh.add_child(_icon_chip("up:air", str(int(rs["upgrades"])), Loc.t("prestige.reset_upgrades", {"n": int(rs["upgrades"])})))
	rh.add_child(_icon_chip("menu:pegs", str(int(rs["pegs"])), Loc.t("prestige.reset_pegs", {"n": int(rs["pegs"]), "p": int(rs["placed"])})))
	var keep := _section(Loc.t("dayend.keep"), UI.MINT)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(keep)
	var kh := UI.hbox(6)
	keep.get_child(0).add_child(kh)
	kh.add_child(_icon_chip("menu:collection", str(int(kp["balls"])), Loc.t("prestige.keep_balls", {"n": int(kp["balls"])})))
	kh.add_child(_icon_chip("ticket", str(int(kp["tickets"])), Loc.t("prestige.keep_tickets", {"n": int(kp["tickets"])})))
	kh.add_child(_icon_chip("menu:tree", str(int(kp["tree"])), Loc.t("prestige.keep_tree", {"n": int(kp["tree"])})))
	kh.add_child(_icon_chip("menu:achievements", str(int(kp["achievements"])), Loc.t("prestige.keep_ach", {"n": int(kp["achievements"])})))
	# yarın
	var nx: Dictionary = pv["next"]
	if not nx.is_empty():
		var tm := _section(Loc.t("dayend.tomorrow", {"d": int(nx["day"])}), UI.SKY)
		_summary.add_child(tm)
		var th := UI.hbox(6)
		tm.get_child(0).add_child(th)
		th.add_child(_icon_chip("pay", Fmt.money(float(nx["target"])), Loc.t("prestige.next_target", {"v": Fmt.money(float(nx["target"]))})))
		var caps_tip := Loc.t("prestige.next_caps", {"a": int(nx["ball_cap_now"]), "b": int(nx["ball_cap"]), "c": int(nx["board_cap_now"]), "d": int(nx["board_cap"])})
		th.add_child(_icon_chip("up:ball_level", "≤ %d" % int(nx["ball_cap"]), caps_tip))
		th.add_child(_icon_chip("up:board_level", "≤ %d" % int(nx["board_cap"]), caps_tip))
		for u in nx["unlocks"]:
			var us: String = u
			if us.begins_with("batch:"):
				th.add_child(_icon_chip("up:batch", "×" + us.substr(6), Loc.t("prestige.unlock_batch", {"n": us.substr(6)})))
			else:
				th.add_child(_icon_chip("up:" + us, Loc.t("dayend.new"), Loc.t("shop." + us + ".name")))
	elif bool(pv["final_day"]):
		var fl := UI.title(Loc.t("dayend.final"), 22, UI.MINT, 4)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_summary.add_child(fl)
	# tüm istatistikler (gizli; düğmeyle açılır)
	_stats = StatsPanel.new()
	_stats.custom_minimum_size = Vector2(0, 380)
	_stats.visible = false
	_body.add_child(_stats)
	# düğmeler
	var bh := UI.hbox(10)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats_btn = UI.button(Loc.t("dayend.stats"), _toggle_stats, 200)
	_stats_btn.custom_minimum_size.y = 52
	_stats_btn.add_theme_font_size_override("font_size", 22)
	var si := Icon.make("menu:stats", 30)
	si.position = Vector2(10, 9)
	_stats_btn.add_child(si)
	bh.add_child(_stats_btn)
	var back := UI.button(Loc.t("dayend.back"), func(): back_requested.emit(), 220)
	back.custom_minimum_size.y = 52
	back.add_theme_font_size_override("font_size", 22)
	UI.paint_button(back, Color("4656d6"))
	bh.add_child(back)
	var ok := UI.button(Loc.t("dayend.confirm_free") if free else Loc.t("dayend.confirm"), func(): close_confirmed.emit(), 300)
	ok.custom_minimum_size.y = 52
	ok.add_theme_font_size_override("font_size", 22)
	UI.paint_button(ok, UI.MINT, Color("06301f"))
	bh.add_child(ok)
	_body.add_child(bh)


func _toggle_stats() -> void:
	var on := not _stats.visible
	_stats.visible = on
	_summary.visible = not on
	_stats_btn.text = Loc.t("dayend.summary") if on else Loc.t("dayend.stats")
	if on:
		_stats.set("_last_ms", -100000)
		_stats.refresh()
	Sfx.play("tick", 1.0, -8.0)


func _section(title_text: String, color: Color, bg: Color = Color("221a52")) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(bg, color, 0, 2, 10))
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(title_text, 11, color, 2))
	return p


## Sayı karosu: ikon, büyük sayı, küçük etiket
func _tile(icon_kind: String, value: String, label: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color("2d2468"), color.darkened(0.3), 0, 1, 6))
	p.custom_minimum_size = Vector2(186, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(8)
	p.add_child(h)
	h.add_child(Icon.make(icon_kind, 33))
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UI.title(value, 22, color.lightened(0.2), 4))
	v.add_child(UI.label(label, 11, UI.MUTED))
	return p


func _chip(text_: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color("2a1240"), color.darkened(0.4), 0, 1, 4))
	p.add_child(UI.title(text_, 11, color, 2))
	return p


## İkon + kısa değer; ayrıntı araç ipucunda.
func _icon_chip(icon_kind: String, value: String, tip: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color("2d2468"), Color("4f4aa8"), 0, 1, 4))
	p.tooltip_text = tip
	var h := UI.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(Icon.make(icon_kind, 24))
	var l := UI.title(value, 22, UI.TEXT, 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return p


# =================================================================== aşama 2: Bilet Ağacı

func show_tree(prev_tickets: int) -> void:
	phase = "tree"
	UI.clear(_body)
	_stats = null
	_summary = null
	var head := UI.hbox(12)
	head.add_child(Icon.make("menu:tree", 44))
	var tv := UI.vbox(0)
	tv.add_child(UI.title(Loc.t("dayend.tree_title"), 33, UI.GOLD, 6))
	tv.add_child(UI.label(Loc.t("dayend.tree_hint"), 11, Color("cfc6ff")))
	head.add_child(tv)
	head.add_child(UI.spacer())
	var tk := PanelContainer.new()
	tk.add_theme_stylebox_override("panel", UI.style(Color("5a1f6e"), UI.ORANGE, 0, 1, 8))
	var th := UI.hbox(8)
	th.add_child(Icon.make("ticket", 44))
	_ticket_label = UI.title(str(prev_tickets), 33, UI.ORANGE, 6)
	_shown_tickets = float(prev_tickets)
	th.add_child(_ticket_label)
	tk.add_child(th)
	head.add_child(tk)
	_body.add_child(head)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(1000, 440)
	_body.add_child(frame)
	_tree = TreePanel.new()
	_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_tree)
	_tree.refresh()
	var bh := UI.hbox(10)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UI.button(Loc.t("dayend.start_free") if Game.is_free_mode() else Loc.t("dayend.start", {"d": Game.day()}), func(): start_requested.emit(), 380)
	go.custom_minimum_size.y = 58
	go.add_theme_font_size_override("font_size", 22)
	UI.paint_button(go, UI.GOLD, Color("3a1800"))
	var pi := Icon.make("play", 33, Color("3a1800"))
	pi.position = Vector2(14, 10)
	go.add_child(pi)
	bh.add_child(go)
	_body.add_child(bh)
