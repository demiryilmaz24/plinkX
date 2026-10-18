extends VBoxContainer
## Sağ kenar: iki küçük çark düğmesi (Top Çarkı / Çivi Çarkı → kasa açma penceresi), bugünkü çivi
## envanteri (Diz düğmesiyle) ve büyük Günü Kapat düğmesi.
## Çivi düzenlerken içerik, ikon ızgaralı çivi düzenleyicisine dönüşür (tahta görünür kalır).

signal close_day_requested
signal open_wheel(kind)
signal select_peg(pid)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const WheelButton := preload("res://scripts/ui/widgets/wheel_button.gd")
const PegSystem := preload("res://scripts/systems/peg_system.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")
const Eco := preload("res://scripts/systems/economy.gd")

var _main: VBoxContainer
var _editor: VBoxContainer
var _wheels: Array = []
var _inv_grid: GridContainer
var _inv_sockets: Label
var _inv_sig := ""
var _close_btn: Button
var _close_sub: Label
var _ticket_pill: Label
# düzenleyici
var _ed_sockets: Label
var _ed_wait: Label
var _ed_grid: GridContainer
var _ed_sig := ""
var _ed_buttons: Dictionary = {}
var _ed_tpl: HBoxContainer
var _selected := ""


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_main = UI.vbox(10)
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_main)
	for k in ["ball", "peg"]:
		var w := WheelButton.new()
		w.setup(k)
		w.pressed.connect(_on_wheel.bind(k))
		_main.add_child(w)
		_wheels.append(w)
	_main.add_child(_build_inventory())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(sp)
	_close_btn = _big_button("moon", Loc.t("right.close_day"), UI.MINT, 66)
	_close_sub = _close_btn.get_meta("sub")
	_ticket_pill = UI.title("", 11, UI.ORANGE, 2)
	_ticket_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_close_btn.get_meta("subrow") as HBoxContainer).add_child(_ticket_pill)
	_close_btn.pressed.connect(func(): close_day_requested.emit())
	_main.add_child(_close_btn)
	_build_editor()
	Game.edit_mode_changed.connect(func(_on): refresh())
	Game.day_started.connect(func(_d, _f): _select(""))


func _on_wheel(k: String) -> void:
	Sfx.play("buy", 1.0, -8.0)
	open_wheel.emit(k)


## Bugünkü çivi envanteri: sahip olunan çiviler (canlı sprite + adet), yuva sayısı ve DİZ düğmesi.
func _build_inventory() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color("1c6f78"), Color("5fe0d0"), 12, 3, 8))
	var v := UI.vbox(6)
	p.add_child(v)
	var head := UI.hbox(6)
	head.add_child(Icon.make("menu:pegs", 22))
	head.add_child(UI.title(Loc.t("right.inventory"), 11, UI.TEXT, 2))
	head.add_child(UI.spacer())
	_inv_sockets = UI.title("", 22, UI.GOLD, 4)
	_inv_sockets.tooltip_text = Loc.t("right.sockets_tip")
	_inv_sockets.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_inv_sockets)
	v.add_child(head)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 3
	_inv_grid.add_theme_constant_override("h_separation", 4)
	_inv_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_inv_grid)
	var b := UI.button(Loc.t("right.place"), _open_editor)
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 22)
	UI.paint_button(b, UI.GOLD, Color("3a1800"))
	var ic := Icon.make("menu:pegs", 24)
	ic.position = Vector2(8, 6)
	b.add_child(ic)
	v.add_child(b)
	return p


func _refresh_inventory() -> void:
	_inv_sockets.text = "%d/%d" % [PegSystem.placed_count(Game), Game.sockets()]
	var sig := str(Game.run["pegs"]) + str(Game.run["layout"])
	if sig == _inv_sig:
		return
	_inv_sig = sig
	UI.clear(_inv_grid)
	var count := 0
	for pd in GameData.pegs:
		var pid: String = pd["id"]
		var have := PegSystem.owned(Game, pid)
		if have <= 0:
			continue
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", UI.style(Color("124e57"), UI.rarity_color(pd["rarity"]), 0, 1, 2))
		cell.custom_minimum_size = Vector2(50, 56)
		count += 1
		cell.tooltip_text = "%s (%s)\n%s" % [Loc.t("peg." + pid + ".name"), Loc.t("rarity." + String(pd["rarity"])), Loc.t("peg." + pid + ".desc", PegSystem.desc_args(pid))]
		var cc := Control.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cc)
		var ic := Icon.make("peg:" + pid, 40)
		ic.position = Vector2(2, -2)
		cc.add_child(ic)
		var cnt := UI.title("%d/%d" % [PegSystem.placed_count(Game, pid), have], 11, UI.TEXT, 2)
		cnt.position = Vector2(0, 34)
		cnt.size = Vector2(44, 14)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(cnt)
		_inv_grid.add_child(cell)
	# boş yuvalar (yazı yerine soluk kareler): envanter boşken bile alanın ne olduğu görünür
	while count < 3 or count % 3 != 0:
		var e := PanelContainer.new()
		e.add_theme_stylebox_override("panel", UI.style(Color("124e57"), Color("2a7d86"), 0, 1, 2))
		e.custom_minimum_size = Vector2(50, 56)
		e.modulate = Color(1, 1, 1, 0.5)
		_inv_grid.add_child(e)
		count += 1


## İkonlu, alt yazılı büyük düğme
func _big_button(icon_kind: String, text_: String, color: Color, h: int = 62) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	UI.paint_button(b, color)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 4)
	b.add_child(m)
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	row.add_child(Icon.make(icon_kind, 36))
	var v := UI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var t := UI.title(text_, 22, UI.TEXT, 4)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var subrow := UI.hbox(6)
	subrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(subrow)
	var sub := UI.title("", 11, Color(1, 1, 1, 0.85), 2)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subrow.add_child(sub)
	b.set_meta("subrow", subrow)
	b.set_meta("sub", sub)
	b.set_meta("row", row)
	return b


# ------------------------------------------------------------------ çivi düzenleyici

func _build_editor() -> void:
	_editor = UI.vbox(8)
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.visible = false
	add_child(_editor)
	var p := UI.panel(Color("1c6f78"), UI.GOLD, 8, 3)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.add_child(p)
	var v := UI.vbox(6)
	p.add_child(v)
	var head := UI.hbox(6)
	head.add_child(Icon.make("menu:pegs", 24))
	head.add_child(UI.title(Loc.t("pegs.title"), 11, UI.TEXT, 2))
	head.add_child(UI.spacer())
	var info := UI.title("?", 22, UI.GOLD, 4)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.tooltip_text = ""
	info.set_meta("rules", true)
	head.add_child(info)
	v.add_child(head)
	_ed_sockets = UI.title("", 22, UI.GOLD, 4)
	v.add_child(_ed_sockets)
	_ed_wait = UI.title(Loc.t("pegs.waiting"), 11, UI.ORANGE, 2)
	_ed_wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ed_wait)
	# öğretici yazı yalnızca burada (ana panelde yer kaplamaz)
	v.add_child(UI.wrap_label(Loc.t("right.peg_hint"), 11, Color("dff9ff")))
	_ed_grid = GridContainer.new()
	_ed_grid.columns = 3
	_ed_grid.add_theme_constant_override("h_separation", 6)
	_ed_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_ed_grid)
	v.add_child(UI.spacer())
	var empty := UI.wrap_label(Loc.t("pegs.empty"), 11, UI.MUTED)
	empty.set_meta("empty", true)
	v.add_child(empty)
	_ed_tpl = UI.hbox(6)
	var save_b := UI.button(Loc.t("pegs.save_tpl"), func(): PegSystem.save_template(Game))
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_b.add_theme_font_size_override("font_size", 11)
	_ed_tpl.add_child(save_b)
	var apply_b := UI.button(Loc.t("pegs.apply_tpl"), _apply_template)
	apply_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_b.add_theme_font_size_override("font_size", 11)
	_ed_tpl.add_child(apply_b)
	v.add_child(_ed_tpl)
	var clear_b := UI.button(Loc.t("pegs.clear"), func(): PegSystem.clear_layout(Game))
	UI.paint_button(clear_b, UI.CORAL)
	clear_b.add_theme_font_size_override("font_size", 11)
	v.add_child(clear_b)
	var done := UI.button(Loc.t("right.done"), _close_editor)
	done.custom_minimum_size.y = 50
	done.add_theme_font_size_override("font_size", 22)
	UI.paint_button(done, UI.GOLD, Color("3a1800"))
	_editor.add_child(done)
	info.tooltip_text = Loc.t("pegs.rules", {"row": PegSystem.min_row() + 1, "s": "N"})
	_rules_label = info


var _rules_label: Label


func _open_editor() -> void:
	Game.set_edit_mode(true)
	_main.visible = false
	_editor.visible = true
	Sfx.play("buy", 0.9, -8.0)
	refresh()


func _close_editor() -> void:
	Game.set_edit_mode(false)
	_select("")
	_main.visible = true
	_editor.visible = false
	Sfx.play("buy", 1.1, -8.0)
	refresh()


func is_editing() -> bool:
	return _editor.visible


func _apply_template() -> void:
	if not Game.edit_mode:
		return
	var n := PegSystem.restore_saved_layout(Game)
	Game.rebuild_layout_cells()
	Game.notify_layout_changed()
	Game.toast.emit(Loc.t("toast.template_applied", {"n": n}), "info")


func _select(pid: String) -> void:
	_selected = pid
	select_peg.emit(pid)
	_ed_sig = ""


## Tahtaya tıklama (ana arayüz bağlar)
func on_cell_clicked(cell: Vector2i, button_index: int) -> void:
	if not Game.edit_mode:
		if Game.layout_cells.has(cell) or PegSystem.is_placeable_cell(cell):
			Game.toast.emit(Loc.t("pegs.need_edit"), "info")
		return
	if button_index == MOUSE_BUTTON_RIGHT or Game.layout_cells.has(cell):
		if PegSystem.remove(Game, cell):
			Sfx.play("tick", 0.7, -6.0)
		_ed_sig = ""
		return
	if _selected == "":
		Game.toast.emit(Loc.t("right.pick_peg"), "info")
		return
	var why := PegSystem.place(Game, cell, _selected)
	if why != "":
		Game.toast.emit(Loc.t(why), "warn")
		Sfx.play("error", 1.0, -10.0)
	else:
		Sfx.play("tick", 1.3, -4.0)
		if PegSystem.placed_count(Game, _selected) >= PegSystem.owned(Game, _selected):
			_select("")
	_ed_sig = ""


func _rebuild_grid() -> void:
	var sig := str(Game.run["pegs"]) + str(Game.run["layout"]) + _selected
	if sig == _ed_sig:
		return
	_ed_sig = sig
	UI.clear(_ed_grid)
	_ed_buttons.clear()
	var any := false
	for p in GameData.pegs:
		var pid: String = p["id"]
		var have := PegSystem.owned(Game, pid)
		if have <= 0:
			continue
		any = true
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 62)
		var sel := pid == _selected
		UI.paint_button(b, UI.GOLD if sel else Color("2b8f9a"))
		var ic := Icon.make("peg:" + pid, 40)
		ic.position = Vector2(6, 0)
		b.add_child(ic)
		var cnt := UI.title("%d/%d" % [PegSystem.placed_count(Game, pid), have], 11, UI.TEXT, 2)
		cnt.position = Vector2(0, 38)
		cnt.size = Vector2(52, 14)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cnt)
		var rar: String = p["rarity"]
		b.tooltip_text = "%s (%s)\n%s" % [Loc.t("peg." + pid + ".name"), Loc.t("rarity." + rar), Loc.t("peg." + pid + ".desc", PegSystem.desc_args(pid))]
		b.pressed.connect(_on_peg_button.bind(pid))
		_ed_grid.add_child(b)
	for c in _editor.get_child(0).get_child(0).get_children():
		if c.has_meta("empty"):
			c.visible = not any


func _on_peg_button(pid: String) -> void:
	_select("" if _selected == pid else pid)
	Sfx.play("tick", 1.1, -8.0)


func refresh() -> void:
	if _editor.visible:
		_rebuild_grid()
		_ed_sockets.text = Loc.t("pegs.sockets", {"n": PegSystem.placed_count(Game), "m": Game.sockets()})
		_ed_wait.visible = Game.edit_pending
		_ed_tpl.visible = MetaTree.level(Game, "layouts") > 0
		_rules_label.tooltip_text = Loc.t("pegs.rules", {"row": PegSystem.min_row() + 1, "s": Game.sockets()})
		if not Game.edit_mode and not Game.edit_pending:
			_main.visible = true
			_editor.visible = false
		return
	for w in _wheels:
		w.refresh()
	_refresh_inventory()
	var free := Game.is_free_mode()
	var done := Game.installment_done()
	_close_btn.disabled = not done
	var pt := Eco.prestige_tickets(Game.day(), float(Game.run["profit"]), Game.target(), free, MetaTree.level(Game, "prestige_bonus"))
	_ticket_pill.text = "+%d" % int(pt["total"])
	var title_l: Label = (_close_btn.get_meta("row") as HBoxContainer).get_child(1).get_child(0)
	title_l.text = Loc.t("right.prestige_free") if free else Loc.t("right.close_day")
	if done:
		_close_sub.text = Loc.t("right.close_ready")
	else:
		_close_sub.text = Loc.t("right.close_locked", {"p": int(round(clampf(float(Game.run["installment"]) / maxf(1.0, Game.target()), 0.0, 1.0) * 100.0))})
	_close_btn.tooltip_text = Loc.t("left.close_ready") if done else Loc.t("left.close_locked", {"v": Fmt.money(Game.installment_left())})
