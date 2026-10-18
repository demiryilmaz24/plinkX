extends PanelContainer
## Sol üst kasa kartı: nakit, günlük taksit çubuğu, Öde düğmesi ve küçük kalan borç satırı.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Debt := preload("res://scripts/systems/debt.gd")
const MetaTree := preload("res://scripts/systems/meta_tree.gd")

## İlk ÖDE'de tek seferlik uyarı gösterilsin diye ana arayüz dinler.
signal pay_warning_needed

var _cash: Label
var _bar: ProgressBar
var _bar_text: Label
var _pay: Button
var _debt: Label
var _autopay: CheckBox
var _shown_cash := 0.0


func _ready() -> void:
	var s := UI.style(Color("2b2f86"), UI.GOLD, 16, 3, 8)
	add_theme_stylebox_override("panel", s)
	var v := UI.vbox(6)
	add_child(v)
	var top := UI.hbox(8)
	top.add_child(Icon.make("coin", 33))
	_cash = UI.title("0$", 33, UI.GOLD, 6)
	_cash.tooltip_text = Loc.t("hud.cash_tip")
	_cash.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(_cash)
	v.add_child(top)
	var row := UI.hbox(6)
	v.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 26)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.tooltip_text = Loc.t("hud.bar_tip")
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(holder)
	_bar = UI.progress(26, UI.GOLD)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_bar)
	_bar_text = UI.title("", 11, UI.TEXT, 2)
	_bar_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_bar_text)
	_pay = UI.button(Loc.t("hud.pay"), _on_pay, 66)
	_pay.add_theme_font_size_override("font_size", 22)
	_pay.tooltip_text = Loc.t("left.pay_all_tip")
	UI.paint_button(_pay, UI.MINT, Color("06301f"))
	row.add_child(_pay)
	var bottom := UI.hbox(6)
	_debt = UI.label("", 11, UI.MUTED)
	_debt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_debt)
	_autopay = CheckBox.new()
	_autopay.text = Loc.t("hud.autopay")
	_autopay.tooltip_text = Loc.t("left.autopay_tip")
	_autopay.focus_mode = Control.FOCUS_NONE
	_autopay.add_theme_font_size_override("font_size", 11)
	_autopay.toggled.connect(func(on): Game.meta["auto"]["auto_pay_on"] = on)
	bottom.add_child(_autopay)
	v.add_child(bottom)


func _on_pay() -> void:
	if not bool(Game.settings.get("pay_warned", false)):
		pay_warning_needed.emit()
		return
	do_pay()


func do_pay() -> void:
	var amount := maxf(0.0, float(Game.run["cash"]) - Game.reserve_amount())
	if Debt.pay(Game, amount) > 0.0:
		Sfx.play("pay")
	else:
		Sfx.play("error", 1.0, -8.0)


func _process(delta: float) -> void:
	# nakit sayacı yumuşak sayar (görsel)
	var target: float = float(Game.run.get("cash", 0.0))
	if absf(target - _shown_cash) < 0.01 or bool(Game.settings.get("reduced_motion", false)):
		_shown_cash = target
	else:
		_shown_cash = lerpf(_shown_cash, target, minf(1.0, delta * 12.0))
	_cash.text = Fmt.money(_shown_cash)


func refresh() -> void:
	var free := Game.is_free_mode()
	var done := Game.installment_done()
	if free:
		_bar.value = 1.0
		_bar_text.text = Loc.t("left.free_mode_bar")
	else:
		var tgt := Game.target()
		_bar.value = clampf(float(Game.run["installment"]) / tgt, 0.0, 1.0)
		_bar_text.text = "%s / %s" % [Fmt.money(float(Game.run["installment"])), Fmt.money(tgt)]
	_bar.add_theme_stylebox_override("fill", UI.style(UI.MINT if done else UI.GOLD, UI.MINT if done else UI.GOLD, 8, 0, 0))
	_pay.visible = not free
	_pay.disabled = done or float(Game.run["cash"]) <= Game.reserve_amount()
	_debt.text = Loc.t("hud.debt", {"v": Fmt.money(Game.debt_left())}) if not free else Loc.t("top.free_mode")
	_autopay.visible = not free and MetaTree.level(Game, "auto_pay") > 0
	_autopay.set_pressed_no_signal(bool(Game.meta["auto"].get("auto_pay_on", false)))
