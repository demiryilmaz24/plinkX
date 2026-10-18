extends VBoxContainer
## Tahtanın altındaki atış çubuğu: seçili top, AT düğmesi, toplu atış seçimi, OTO anahtarı, hava sayacı
## ve tek satırlık son atış özeti.

signal open_collection

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const TraitChips := preload("res://scripts/ui/widgets/trait_chips.gd")
const BallCollection := preload("res://scripts/systems/ball_collection.gd")

var _ball_btn: Button
var _ball_icon: Control
var _ball_lv: Label
var _launch: Button
var _batch_box: HBoxContainer
var _batch_buttons: Array = []
var _batch_sig := ""
var _auto_btn: Button
var _auto_icon: Control
var _air: Label
var _last: RichTextLabel


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var row := UI.hbox(8)
	add_child(row)
	# seçili top
	_ball_btn = Button.new()
	_ball_btn.focus_mode = Control.FOCUS_NONE
	_ball_btn.custom_minimum_size = Vector2(132, 64)
	_ball_btn.tooltip_text = Loc.t("launch.ball_tip")
	UI.paint_button(_ball_btn, Color("3f49b8"))
	_ball_btn.pressed.connect(func(): open_collection.emit())
	var bh := UI.hbox(6)
	bh.position = Vector2(8, 6)
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_btn.add_child(bh)
	_ball_icon = Icon.make("ball:demir", 44)
	bh.add_child(_ball_icon)
	_ball_lv = UI.title("", 15, UI.TEXT, 4)
	_ball_lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bh.add_child(_ball_lv)
	row.add_child(_ball_btn)
	# AT
	_launch = UI.button("", _on_launch)
	_launch.custom_minimum_size = Vector2(0, 64)
	_launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launch.add_theme_font_size_override("font_size", 26)
	_launch.tooltip_text = Loc.t("launch.key_tip")
	UI.paint_button(_launch, UI.GOLD, Color("3a1800"))
	row.add_child(_launch)
	_batch_box = UI.hbox(4)
	row.add_child(_batch_box)
	# OTO
	_auto_btn = Button.new()
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.custom_minimum_size = Vector2(64, 64)
	_auto_btn.pressed.connect(_toggle_auto)
	_auto_icon = Icon.make("up:auto_unlock", 40)
	_auto_icon.position = Vector2(12, 6)
	_auto_btn.add_child(_auto_icon)
	row.add_child(_auto_btn)
	# hava
	var air_box := UI.vbox(0)
	air_box.alignment = BoxContainer.ALIGNMENT_CENTER
	air_box.tooltip_text = Loc.t("launch.air_tip")
	air_box.mouse_filter = Control.MOUSE_FILTER_PASS
	air_box.add_child(Icon.make("up:air", 26))
	_air = UI.title("", 14, UI.TEXT, 3)
	_air.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	air_box.add_child(_air)
	row.add_child(air_box)
	# son atış
	_last = RichTextLabel.new()
	_last.bbcode_enabled = true
	_last.fit_content = true
	_last.scroll_active = false
	_last.custom_minimum_size.y = 20
	_last.add_theme_font_size_override("normal_font_size", 13)
	_last.add_theme_font_size_override("bold_font_size", 14)
	_last.add_theme_color_override("default_color", UI.MUTED)
	add_child(_last)
	Game.ball_landed.connect(func(_f, _r): _update_last())
	_update_last()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_SPACE and not Game.paused:
		_on_launch()
		get_viewport().set_input_as_handled()


func current_batch() -> int:
	var sizes := Game.batch_sizes()
	var idx := clampi(int(Game.run["batch_choice"]), 0, sizes.size() - 1)
	return int(sizes[idx])


func _on_launch() -> void:
	var n := Game.request_launch(current_batch(), "manual")
	if n > 0:
		Sfx.play("tick", 0.8, -10.0)
	else:
		Sfx.play("error", 1.0, -10.0)


func _toggle_auto() -> void:
	if int(Game.run["up"]["auto_unlock"]) == 0:
		Game.toast.emit(Loc.t("left.auto_locked"), "info")
		return
	Game.run["auto_on"] = not bool(Game.run["auto_on"])
	Sfx.play("buy", 1.2 if Game.run["auto_on"] else 0.9, -8.0)


func _rebuild_batch() -> void:
	var sizes := Game.batch_sizes()
	var sig := str(sizes)
	if sig == _batch_sig:
		return
	_batch_sig = sig
	UI.clear(_batch_box)
	_batch_buttons.clear()
	for i in range(sizes.size()):
		var b := UI.button("×%d" % int(sizes[i]), _select_batch.bind(i), 50)
		b.custom_minimum_size.y = 64
		b.add_theme_font_size_override("font_size", 17)
		b.tooltip_text = Loc.t("launch.batch_tip", {"n": int(sizes[i])})
		_batch_box.add_child(b)
		_batch_buttons.append(b)


func _select_batch(i: int) -> void:
	Game.run["batch_choice"] = i
	Sfx.play("tick", 1.2, -10.0)
	refresh()


func refresh() -> void:
	_rebuild_batch()
	var bid := Game.selected_ball()
	_ball_icon.set_kind("ball:" + bid)
	_ball_lv.text = "%s\n%s" % [Loc.t("side.lvl_short", {"l": int(Game.run["ball_level"])}), Fmt.mult(Game.ball_mult())]
	var parts: Array = []
	for line in BallCollection.trait_lines(bid, BallCollection.stars(Game, bid)):
		parts.append(Loc.t(String(line[0]).replace("trait.", "trait.short."), {"v": TraitChips.value_text(line[0], line[1])}))
	var tip := "%s\n%s\n%s" % [Loc.t("ball." + bid + ".name"), " • ".join(parts), Loc.t("launch.ball_tip")]
	if _ball_btn.tooltip_text != tip:
		_ball_btn.tooltip_text = tip
	var idx := clampi(int(Game.run["batch_choice"]), 0, _batch_buttons.size() - 1)
	for i in range(_batch_buttons.size()):
		UI.paint_button(_batch_buttons[i], UI.PINK if i == idx else Color("3f49b8"))
	var n := current_batch()
	if Game.edit_mode or Game.edit_pending:
		_launch.text = Loc.t("launch.edit_short")
		_launch.disabled = true
	else:
		_launch.disabled = false
		var fs := int(Game.run["free_shots"])
		var paid := maxi(0, n - fs)
		_launch.text = Loc.t("launch.button_short", {"n": n, "c": Fmt.money(paid * Game.x())})
	var unlocked := int(Game.run["up"]["auto_unlock"]) > 0
	var on := bool(Game.run["auto_on"]) and unlocked
	UI.paint_button(_auto_btn, UI.MINT if on else (Color("3f49b8") if unlocked else Color("2b3170")))
	_auto_icon.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)
	_auto_btn.tooltip_text = (Loc.t("launch.auto_tip_on") if on else Loc.t("launch.auto_tip_off")) if unlocked else Loc.t("left.auto_locked")
	# Ateş Modu'nda hava sınırı kalkar
	if Game.boost_active():
		_air.text = "%d/∞" % Game.paid_in_air()
		_air.add_theme_color_override("font_color", UI.ORANGE)
	else:
		_air.text = "%d/%d" % [Game.paid_in_air(), Game.air_limit()]
		_air.add_theme_color_override("font_color", UI.TEXT)


func _update_last() -> void:
	var lr: Dictionary = Game.last_result
	if lr.is_empty():
		_last.text = ""
		return
	var f = lr["flight"]
	var res: Dictionary = lr["result"]
	var itype: String = res["type"]
	var col: Color = UI.INTERVAL_COLORS[itype]
	var parts: Array = res["parts"]
	var txt := ""
	for p in parts:
		var key: String = p[0]
		var val: float = float(p[1])
		if key == "base":
			txt += Fmt.xlabel(val)
		elif absf(val - 1.0) > 0.0001:
			txt += " × %s %s" % [Fmt.dec(val, 2), Loc.t("part." + key)]
	var change: float = float(res["change"])
	var ccol := UI.MINT if change > 0 else (UI.CORAL if change < 0 else UI.MUTED)
	var s := "[center][color=#%s]%s[/color]  %s = [color=#%s][b]%s[/b][/color]" % [col.to_html(false), Loc.t("interval." + itype), txt, ccol.to_html(false), Fmt.money_signed(change)]
	if f.bonus:
		s += "  [color=#%s](%s)[/color]" % [UI.TICKET.to_html(false), Loc.t("launch.bonus_ball")]
	elif f.free:
		s += "  [color=#%s](%s)[/color]" % [UI.TICKET.to_html(false), Loc.t("launch.free_ball")]
	_last.text = s + "[/center]"
