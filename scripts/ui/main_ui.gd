extends Control
## Ana ekran: ana menü, oyun düzeni (merkezde büyük tahta), efektler, pencereler ve duraklatma menüsü.
## Düzen: sol = kasa + resimli yükseltme kartları, orta = tahta + atış çubuğu, sağ = bilet rozeti, menü ikonları,
## slot makineleri ve Günü Kapat. Ayrıntılı ekranlar (koleksiyon, ağaç, başarımlar, istatistik) ikonlardan açılır.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Stage := preload("res://scripts/stage/stage.gd")
const Hud := preload("res://scripts/ui/panels/hud.gd")
const TopRight := preload("res://scripts/ui/panels/top_right.gd")
const UpgradeSidebar := preload("res://scripts/ui/panels/upgrade_sidebar.gd")
const RightPanel := preload("res://scripts/ui/panels/right_panel.gd")
const LaunchBar := preload("res://scripts/ui/panels/launch_bar.gd")
const Toasts := preload("res://scripts/ui/toasts.gd")
const Dialogs := preload("res://scripts/ui/dialogs.gd")
const FxLayer := preload("res://scripts/ui/fx_layer.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const DebugTools := preload("res://scripts/ui/debug_tools.gd")
const SaveSystem := preload("res://scripts/systems/save_system.gd")
const Story := preload("res://scripts/systems/story.gd")
const RunShop := preload("res://scripts/systems/run_shop.gd")
const CaseWindow := preload("res://scripts/ui/widgets/case_window.gd")
const TextLayer := preload("res://scripts/ui/text_layer.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const DayEnd := preload("res://scripts/ui/day_end.gd")
const Themes := preload("res://scripts/stage/themes.gd")
const PhoneCalls := preload("res://scripts/systems/phone_calls.gd")

## Gün içinde açılabilen pencereler. Bilet Ağacı ve istatistikler yalnızca gün sonu ekranındadır.
const SCREENS := {
	"collection": "res://scripts/ui/panels/collection_panel.gd",
	"achievements": "res://scripts/ui/panels/achievements_panel.gd",
}

var root: Control
var board: Control
var launch: Control
var hud: Control
var top_right: Control
var left_side: Control
var right_side: Control
var toasts: Control
var fx: Control
var dialogs: Control
var menu: Control
var debug: Node
var day_end: Control
var transition: Control
var _sheet: Control = null
var _sheet_root: Control = null
var _pause_root: Control = null
var _refresh_t := 0.0
var _ring_t := 0.0
var _call_root: Control = null
var _call_ctx: Dictionary = {}


func _ready() -> void:
	theme = UI.make_theme()
	Sfx.apply_volumes(Game.settings)
	_fit_window()
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	if bool(Game.settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# yazı boyutlarını piksel ızgarasına oturt (sonradan eklenen düğümler dahil)
	get_tree().node_added.connect(_on_node_added)
	debug = DebugTools.new()
	debug.ui = self
	add_child(debug)
	debug.parse_flags()
	_build()
	Game.toast.connect(func(t, k): toasts.show_toast(t, k))
	Game.day_started.connect(_on_day_started)
	Game.story_finished.connect(func(): _show_story_window("finale"))
	Game.installment_completed.connect(_on_installment_done)
	Game.tickets_gained.connect(_on_tickets_gained)
	Game.jackpot.connect(_on_jackpot)
	Game.max_win.connect(_on_max_win)
	Game.achievement_unlocked.connect(func(_id): Sfx.play("ticket", 1.2, -4.0))
	Game.board_changed.connect(func(a, b): toasts.show_toast(Loc.t("toast.board_up", {"a": Fmt.pct(a), "b": Fmt.pct(b)}), "good"))
	Game.job_finished.connect(func(v): toasts.show_toast(Loc.t("toast.job_done", {"v": Fmt.money(v)}), "good"))
	fx.ticket_arrived.connect(func(): top_right.pop())
	menu.language_pressed.connect(_toggle_language)
	Game.phone_ring.connect(_on_phone_ring)
	Game.phone_missed.connect(_on_phone_missed)
	Game.phone_voicemail.connect(_on_phone_voicemail)
	Game.boost_started.connect(_on_boost_started)
	Game.boost_ended.connect(_on_boost_ended)
	if Game.resume_after_reload:
		Game.resume_after_reload = false
		_start_play()
	elif debug.skip_menu:
		_start_play()
	else:
		_show_menu()
	debug.apply_args()
	refresh_all()


# =================================================================== düzen

## Arayüz ölçeği: pencereye sığan en büyük TAM SAYI kat (en az 1280x720 düzen alanı). Kalan alan düzene
## eklenir (kenar boşluğu yok). Tam sayı ölçek sayesinde piksel sanat ve piksel yazı tipi her pencere
## boyutunda keskin kalır; Retina ekranda ölçek genellikle 2'dir.
func _apply_ui_scale() -> void:
	var ws := get_window().size
	var k := maxi(1, int(floor(minf(ws.x / 1280.0, ws.y / 720.0))))
	if not is_equal_approx(get_window().content_scale_factor, float(k)):
		get_window().content_scale_factor = float(k)
	if stage_box:
		call_deferred("_layout_stage")


## Pencereyi ekrana sığan en büyük tam sayı ölçeğe göre boyutlandırır (--resolution / --win ile değiştirilebilir).
func _fit_window() -> void:
	if DisplayServer.get_name() == "headless" or "--resolution" in OS.get_cmdline_args():
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var scr := DisplayServer.screen_get_usable_rect()
	var pick := Vector2i(1280, 720)
	var found := false
	for k in range(4, 0, -1):
		for base in [Vector2i(1440, 810), Vector2i(1376, 774), Vector2i(1280, 720)]:
			var sz: Vector2i = base * k
			if sz.x <= scr.size.x * 0.97 and sz.y <= scr.size.y * 0.95:
				pick = sz
				found = true
				break
		if found:
			break
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--win="):
			var wh := String(a).substr(6).split("x")
			pick = Vector2i(int(wh[0]), int(wh[1]))
	var w := get_window()
	w.min_size = Vector2i(1280, 720)
	w.size = pick
	w.position = scr.position + (scr.size - pick) / 2


const COL_L := 250   # sol sütun (kasa + yükseltme kartları)
const COL_R := 196   # sağ sütun (bilet, çarklar, çiviler, Günü Kapat)
const PIX_SHRINK := 2

var stage_box: SubViewportContainer
var stage: Control
var _fx_box: SubViewportContainer


func _build() -> void:
	# --- piksel sahne: oda, masa, nesneler, Kader Tahtası (yarım çözünürlük, en-yakın büyütme)
	stage_box = _pixel_container(false)
	add_child(stage_box)
	stage = Stage.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_box.get_child(0).add_child(stage)
	stage.prop_clicked.connect(_on_prop)
	board = stage.board
	resized.connect(_layout_stage)
	# tahta ve masa yazıları: tam çözünürlükte (keskin)
	var board_text := TextLayer.new()
	board_text.providers = [_stage_texts, _board_texts]
	add_child(board_text)
	# --- arayüz katmanı (tam çözünürlük): dar yan sütunlar
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var left := UI.vbox(10)
	_anchor_column(left, true)
	root.add_child(left)
	hud = Hud.new()
	hud.pay_warning_needed.connect(_on_pay_warning)
	left.add_child(hud)
	left_side = UpgradeSidebar.new()
	left_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_side)
	var right := UI.vbox(10)
	_anchor_column(right, false)
	root.add_child(right)
	top_right = TopRight.new()
	top_right.open_screen.connect(_open_screen)
	right.add_child(top_right)
	right_side = RightPanel.new()
	right_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_side.close_day_requested.connect(_open_prestige)
	right_side.open_wheel.connect(_open_wheel)
	right_side.select_peg.connect(func(pid): board.selected_peg = pid)
	board.cell_clicked.connect(right_side.on_cell_clicked)
	right.add_child(right_side)
	# atış çubuğu (masanın ön kenarında)
	launch = LaunchBar.new()
	launch.open_collection.connect(func(): _open_screen("collection"))
	launch.anchor_left = 0.0
	launch.anchor_right = 1.0
	launch.anchor_top = 1.0
	launch.anchor_bottom = 1.0
	launch.offset_left = 12 + COL_L + 30
	launch.offset_right = -(12 + COL_R + 30)
	launch.offset_top = -100
	launch.offset_bottom = -8
	root.add_child(launch)
	# --- katmanlar
	# bildirimler: sağ sütunun altında, Günü Kapat düğmesinin hemen üstünde (tahtayı kapatmaz)
	toasts = Toasts.new()
	add_child(toasts)
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.anchor_top = 1.0
	toasts.anchor_bottom = 1.0
	toasts.offset_left = -(10 + COL_R)
	toasts.offset_right = -10
	toasts.offset_top = -(10 + 66 + 8 + 240)
	toasts.offset_bottom = -(10 + 66 + 8)
	_fx_box = _pixel_container(true)
	add_child(_fx_box)
	fx = FxLayer.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.shake_target = stage_box
	_fx_box.get_child(0).add_child(fx)
	var fx_text := TextLayer.new()
	fx_text.providers = [_fx_texts]
	add_child(fx_text)
	menu = MainMenu.new()
	menu.continue_pressed.connect(_on_continue)
	menu.new_game_pressed.connect(_on_new_game)
	menu.settings_pressed.connect(_open_settings)
	menu.quit_pressed.connect(func(): Game.quit_game())
	add_child(menu)
	day_end = DayEnd.new()
	day_end.visible = false
	day_end.back_requested.connect(_day_end_back)
	day_end.close_confirmed.connect(_day_end_confirm)
	day_end.start_requested.connect(_day_end_start)
	add_child(day_end)
	dialogs = Dialogs.new()
	add_child(dialogs)
	transition = Transition.new()
	add_child(transition)
	call_deferred("_layout_stage")


func _board_texts() -> Array:
	var sc: float = float(board.get("_scale"))
	var off: Vector2 = board.get("_offset")
	var base: Vector2 = stage_box.position + (board.position + off) * PIX_SHRINK
	var u2l := sc * PIX_SHRINK
	var out: Array = board.text_items(u2l)
	for it in out:
		it["p"] = base + (it["p"] as Vector2) * u2l
	return out


func _stage_texts() -> Array:
	var out: Array = stage.text_items()
	for it in out:
		it["p"] = stage_box.position + (it["p"] as Vector2) * PIX_SHRINK
	return out


func _fx_texts() -> Array:
	var out: Array = fx.text_items()
	for it in out:
		if it.has("rect"):
			var r: Rect2 = it["rect"]
			it["rect"] = Rect2(r.position * PIX_SHRINK, r.size * PIX_SHRINK)
		else:
			it["p"] = (it["p"] as Vector2) * PIX_SHRINK
	return out


## Yarım çözünürlükte çizip en-yakın filtreyle büyüten kap (gerçek piksel sanat).
func _pixel_container(overlay: bool) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = PIX_SHRINK
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE if overlay else Control.MOUSE_FILTER_STOP
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = overlay
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.gui_embed_subwindows = false
	box.add_child(vp)
	return box


func _anchor_column(c: Control, is_left: bool) -> void:
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	c.offset_top = 10
	c.offset_bottom = -10
	if is_left:
		c.anchor_left = 0.0
		c.anchor_right = 0.0
		c.offset_left = 10
		c.offset_right = 10 + COL_L
	else:
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.offset_left = -10 - COL_R
		c.offset_right = -10


## Masa alanı: iki sütunun arası, altta atış çubuğu payı (sahne koordinatlarında).
## Dolap masanın arka kenarını aşıp ekranın üstüne kadar uzanır; böylece tahta olabildiğince büyük olur.
func _layout_stage() -> void:
	var sz := size
	# piksel kapları çift boyutlu olmalı (yarım çözünürlük tam 2 katla büyüsün)
	for box in [stage_box, _fx_box]:
		box.offset_right = -(sz.x - 2.0 * floorf(sz.x / 2.0))
		box.offset_bottom = -(sz.y - 2.0 * floorf(sz.y / 2.0))
	var x0 := 10.0 + COL_L + 8.0
	var x1 := sz.x - 10.0 - COL_R - 8.0
	var r := Rect2(Vector2(x0, 50), Vector2(x1 - x0, sz.y - 50 - 116))
	var top := 8.0
	if menu and menu.visible:
		# ana menüde masa sağa kayar, sol yarı menüye kalır
		r = Rect2(Vector2(sz.x * 0.47, 80), Vector2(sz.x * 0.515, sz.y - 80 - 70))
		top = 14.0
	var cab := Rect2(Vector2(r.position.x, top), Vector2(r.size.x, r.end.y - 8.0 - top))
	stage.set_layout(Rect2(r.position / PIX_SHRINK, r.size / PIX_SHRINK), Rect2(cab.position / PIX_SHRINK, cab.size / PIX_SHRINK))


func _on_prop(id: String) -> void:
	Sfx.play("tick", 1.0, -6.0)
	match id:
		"jar":
			_open_screen("collection")
		"envelope":
			_open_screen("story")
		"notebook":
			_show_ledger()
		"phone":
			if Game.ringing.is_empty():
				toasts.show_toast(Loc.t("phone.quiet"), "info")
			else:
				_show_call(PhoneCalls.answer(Game))
		"calendar":
			var msg := Loc.t("top.free_mode") if Game.is_free_mode() else Loc.t("top.day_short", {"d": Game.day(), "n": GameData.day_count(), "t": Loc.t("story.day%d.title" % Game.day())})
			toasts.show_toast(msg, "info")


# =================================================================== menü akışı

func _show_menu() -> void:
	_close_sheet()
	if _pause_root:
		dialogs.close(_pause_root)
		_pause_root = null
	Game.paused = true
	Game.save_now()
	menu.set_can_continue(Game.has_progress())
	menu.visible = true
	root.visible = false
	_layout_stage()


func _start_play() -> void:
	menu.visible = false
	root.visible = true
	_layout_stage()
	refresh_all()
	if bool(Game.meta.get("tree_pending", false)):
		# gün kapanmış ama Bilet Ağacı aşaması bitmemişti: oradan devam
		Game.paused = true
		day_end.visible = true
		day_end.show_tree(int(Game.meta["tickets"]))
		return
	Game.paused = false
	call_deferred("_show_day_story")


func _on_continue() -> void:
	_start_play()


func _on_new_game() -> void:
	if Game.has_progress():
		dialogs.confirm(Loc.t("menu.new_title"), Loc.t("menu.new_body"), Loc.t("menu.new_ok"), _do_new_game, true)
	else:
		_do_new_game()


func _do_new_game() -> void:
	Game.wipe_save()
	_start_play()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		if menu.visible or transition.is_playing():
			return
		if _call_root:
			_call_escape()
			get_viewport().set_input_as_handled()
			return
		if day_end.visible and not dialogs.is_open():
			if day_end.phase == "summary":
				_day_end_back()
			get_viewport().set_input_as_handled()
			return
		if _sheet_root:
			_close_sheet()
		elif _pause_root:
			_resume()
		elif dialogs.is_open():
			dialogs.close_top()
		elif right_side.is_editing():
			right_side.call("_close_editor")
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	if _pause_root:
		return
	Game.paused = true
	var v := UI.vbox(12)
	v.add_child(UI.title(Loc.t("pause.title"), 34, UI.GOLD, 8))
	for item in [["pause.resume", UI.GOLD, Color("3a1800"), _resume], ["menu.settings", Color("4656d6"), Color.WHITE, _open_settings],
			["pause.main_menu", UI.PINK, Color.WHITE, _show_menu], ["menu.quit", UI.CORAL, Color.WHITE, func(): Game.quit_game()]]:
		var b := UI.button(Loc.t(item[0]), item[3])
		b.custom_minimum_size = Vector2(360, 58)
		b.add_theme_font_size_override("font_size", 22)
		UI.paint_button(b, item[1], item[2])
		v.add_child(b)
	_pause_root = dialogs.open(v, 420.0)


func _resume() -> void:
	if _pause_root:
		dialogs.close(_pause_root)
		_pause_root = null
	Game.paused = menu.visible


# =================================================================== yenileme

func _process(delta: float) -> void:
	Game.ui_busy = menu.visible or day_end.visible or transition.is_playing() or dialogs.is_open() \
		or _sheet_root != null or _wheel_root != null or right_side.is_editing()
	# zil: telefon çalarken her 1,3 sn'de bir çift çalma
	if not Game.ringing.is_empty() and not Game.paused and not Game.ui_busy and Game.has_focus:
		_ring_t -= delta
		if _ring_t <= 0.0:
			_ring_t = 1.3
			Sfx.play("phone_ring", 1.0, -3.0)
	else:
		_ring_t = 0.0
	_refresh_t += delta
	if _refresh_t >= 0.1:
		_refresh_t = 0.0
		refresh_all()


func refresh_all() -> void:
	hud.refresh()
	top_right.refresh()
	left_side.refresh()
	right_side.refresh()
	launch.refresh()
	if _sheet and is_instance_valid(_sheet) and _sheet.has_method("refresh"):
		_sheet.refresh()
		_sheet_tickets.text = str(int(Game.meta["tickets"]))
	fx.ticket_target = top_right.ticket_center() / PIX_SHRINK


# =================================================================== olaylar

func _board_point(p: Vector2) -> Vector2:
	return board.get_global_transform() * (board.get("_offset") + p * float(board.get("_scale")))


func _on_tickets_gained(n: int, src: String) -> void:
	if src == "prestige":
		top_right.pop()
		return
	Sfx.play("ticket", 1.0, -6.0)
	var from: Vector2 = board.get_global_rect().get_center() + Vector2(0, board.size.y * 0.35)
	if src == "achievement":
		from = toasts.get_global_rect().get_center() / PIX_SHRINK
	fx.ticket_fly(from, n)


func _on_installment_done() -> void:
	Sfx.play("pay", 1.2, 0.0)
	if not Game.is_free_mode():
		toasts.show_toast(Loc.t("toast.installment_done"), "good")
		fx.burst((right_side.get_global_rect().get_center() + Vector2(0, right_side.size.y * 0.4)) / PIX_SHRINK, 40, ["coin", "confetti", "spark"], 260.0)


func _on_jackpot(amount: float) -> void:
	Sfx.play("jackpot", 1.0, 0.0)
	var tickets := int(GameData.eco["tickets"]["jackpot_first_daily_tickets"]) if int(Game.run["jackpots_today"]) == 1 else 0
	fx.jackpot(amount, tickets)


func _on_max_win(f, _res) -> void:
	fx.max_win(_board_point(f.landing_point()))


# =================================================================== ekranlar (pencereler)

func _open_screen(id: String) -> void:
	match id:
		"story":
			_show_story_window("free" if Game.is_free_mode() else str(Game.day()))
			return
		"settings":
			_open_pause()
			return
	if not SCREENS.has(id):
		return
	if _sheet_root == null:
		_build_sheet()
	_switch_sheet(id)
	Sfx.play("buy", 1.0, -8.0)


var _sheet_tabs: Dictionary = {}
var _sheet_body: Control
var _sheet_tickets: Label
const SHEET_ORDER := ["collection", "achievements"]


## Sekmeli büyük pencere: üstte sekmeler + bilet sayacı + kapat; içerik sekmeye göre değişir.
func _build_sheet() -> void:
	var v := UI.vbox(12)
	var head := UI.hbox(8)
	v.add_child(head)
	_sheet_tabs.clear()
	for tid in SHEET_ORDER:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 54)
		b.text = Loc.t("top.btn." + tid)
		b.add_theme_font_size_override("font_size", 20)
		var ic := Icon.make("menu:" + tid, 30)
		ic.position = Vector2(12, 9)
		b.add_child(ic)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_switch_sheet.bind(tid))
		head.add_child(b)
		_sheet_tabs[tid] = b
	head.add_child(UI.spacer())
	var tk := PanelContainer.new()
	tk.add_theme_stylebox_override("panel", UI.style(Color("5a1f6e"), UI.ORANGE, 0, 1, 10))
	var th := UI.hbox(8)
	th.add_child(Icon.make("ticket", 36))
	_sheet_tickets = UI.title("", 26, UI.ORANGE, 6)
	th.add_child(_sheet_tickets)
	tk.add_child(th)
	head.add_child(tk)
	var x := UI.button("✕", _close_sheet, 54)
	x.custom_minimum_size.y = 54
	x.add_theme_font_size_override("font_size", 24)
	UI.paint_button(x, UI.CORAL)
	head.add_child(x)
	_sheet_body = Control.new()
	_sheet_body.custom_minimum_size = Vector2(1000, 560)
	v.add_child(_sheet_body)
	_sheet_root = dialogs.open(v, 1060.0, Color("4f6aa8"))


func _switch_sheet(id: String) -> void:
	for tid in _sheet_tabs.keys():
		var on: bool = tid == id
		UI.paint_button(_sheet_tabs[tid], UI.GOLD if on else Color("3a4a7a"), Color("3a1800") if on else UI.TEXT)
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBox = _sheet_tabs[tid].get_theme_stylebox(st).duplicate()
			sb.content_margin_left = 52
			_sheet_tabs[tid].add_theme_stylebox_override(st, sb)
	for c in _sheet_body.get_children():
		c.queue_free()
	_sheet = load(SCREENS[id]).new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet_body.add_child(_sheet)
	_sheet.refresh()


func _close_sheet() -> void:
	if _sheet_root:
		dialogs.close(_sheet_root)
	_sheet_root = null
	_sheet = null
	_sheet_tabs.clear()


# =================================================================== çark (kasa açma) penceresi

var _wheel_root: Control
var _wheel_win: Control


func _open_wheel(kind: String) -> void:
	_close_wheel()
	_wheel_win = CaseWindow.new()
	_wheel_win.setup(kind)
	_wheel_win.request_close.connect(_close_wheel)
	_wheel_win.request_edit.connect(_wheel_to_editor)
	_wheel_root = dialogs.open(_wheel_win, 960.0, UI.GOLD)
	_wheel_root.tree_exited.connect(_on_wheel_gone)


func _on_wheel_gone() -> void:
	_wheel_root = null
	_wheel_win = null


func _close_wheel() -> void:
	if _wheel_root and is_instance_valid(_wheel_root):
		dialogs.close(_wheel_root)
	_wheel_root = null
	_wheel_win = null


func _wheel_to_editor() -> void:
	_close_wheel()
	right_side.call("_open_editor")


# =================================================================== hikâye

func _on_day_started(_d, _f) -> void:
	# gün sonu akışında hikâye, "Yeni Günü Başlat"tan sonra gösterilir
	if not day_end.visible and not transition.is_playing():
		call_deferred("_show_day_story")


func _show_day_story() -> void:
	if debug.skip_story or menu.visible:
		return
	var key := "free" if Game.is_free_mode() else str(Game.day())
	if Game.meta["story_seen"].has(key):
		return
	Game.meta["story_seen"][key] = true
	_show_story_window(key)


func _show_story_window(key: String) -> void:
	var entry := Story.entry(key)
	var row := UI.hbox(18)
	# sol: karakter portresi (gerçek piksel, tam 2 katla) ve ad levhası
	var pc := UI.vbox(6)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("1a1440"), UI.GOLD, 0, 2, 6))
	var tex: Texture2D = load(String(entry["portrait"]))
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = tex.get_size() * 2.0 if tex else Vector2(198, 198)
	frame.add_child(tr)
	pc.add_child(frame)
	var nm := UI.title(String(entry["name"]), 22, UI.GOLD, 4)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(nm)
	row.add_child(pc)
	var v := UI.vbox(12)
	v.custom_minimum_size.x = 540
	row.add_child(v)
	v.add_child(UI.title(entry["kicker"], 15, UI.PINK, 4))
	v.add_child(UI.title(entry["title"], 34, UI.GOLD, 8))
	var body := UI.wrap_label(entry["body"], 17, UI.TEXT)
	body.custom_minimum_size.x = 520
	v.add_child(body)
	if entry.has("note"):
		var note := PanelContainer.new()
		var ns := UI.style(Color("fff4d6"), Color("e8941a"), 6, 0, 16)
		note.add_theme_stylebox_override("panel", ns)
		var nl := UI.wrap_label(entry["note"], 17, Color("3a2410"))
		nl.custom_minimum_size.x = 480
		note.add_child(nl)
		v.add_child(note)
	if entry.has("info"):
		v.add_child(UI.wrap_label(entry["info"], 14, UI.MUTED))
	var h := UI.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_END
	var holder: Array = [null]
	var b := UI.button(Loc.t("story.continue"), func(): dialogs.close(holder[0]), 220)
	b.custom_minimum_size.y = 54
	b.add_theme_font_size_override("font_size", 20)
	UI.paint_button(b, UI.GOLD, Color("3a1800"))
	h.add_child(b)
	v.add_child(h)
	holder[0] = dialogs.open(row, 820.0)
	Sfx.play("day", 1.0, -4.0)


# =================================================================== prestij

## Günü Kapat: gece geçişi -> gün sonu özeti. Oyun bu sırada duraklar (hiçbir şey ilerlemez).
func _open_prestige() -> void:
	var pv := Game.prestige_preview()
	if not bool(pv["can"]):
		toasts.show_toast(Loc.t("left.close_locked", {"v": Fmt.money(Game.installment_left())}), "warn")
		return
	if transition.is_playing() or day_end.visible:
		return
	_close_sheet()
	_close_wheel()
	_close_call()
	if right_side.is_editing():
		right_side.call("_close_editor")
	Game.paused = true
	PhoneCalls.cancel(Game)
	var title := Loc.t("transition.night_free") if bool(pv["free_mode"]) else Loc.t("transition.night", {"d": int(pv["day"])})
	transition.play("night", title, Loc.t("transition.night_sub"), _show_day_end)


func _show_day_end() -> void:
	day_end.visible = true
	day_end.show_summary()


func _day_end_back() -> void:
	day_end.visible = false
	Game.paused = menu.visible
	Sfx.play("buy", 1.1, -8.0)


## Günü bitir: prestij uygulanır (biletler eklenir), ardından Bilet Ağacı aşaması açılır.
func _day_end_confirm() -> void:
	var before := int(Game.meta["tickets"])
	Game.prestige_apply()
	Game.meta["tree_pending"] = true
	Game.save_now()
	Sfx.play("jackpot", 1.3, -6.0)
	day_end.show_tree(before)
	refresh_all()


## Yeni günü başlat: gün doğumu geçişi -> masa ve günün hikâyesi.
func _day_end_start() -> void:
	if transition.is_playing():
		return
	Game.meta["tree_pending"] = false
	Game.save_now()
	var title := "∞" if Game.is_free_mode() else str(Game.day())
	var sub := Loc.t("top.free_mode") if Game.is_free_mode() else Loc.t("story.day%d.title" % Game.day())
	# yeni odaya geçiliyorsa geçişte duyur
	var now_tier := Themes.current()
	var prev_tier := Themes.tier_for(Game.day() - 1, false) if not Game.is_free_mode() else 4
	if now_tier != prev_tier:
		transition.badge = Loc.t("room.new", {"r": Loc.t("room.%d" % now_tier)})
	transition.play("day", title, sub, _day_end_hide, _day_end_done)


func _day_end_hide() -> void:
	day_end.visible = false
	refresh_all()


func _day_end_done() -> void:
	Game.paused = menu.visible
	_show_day_story()


## Yeni eklenen düğümlerin yazı boyutları bir kare sonra piksel ızgarasına oturtulur. Düğüm o arada silinmiş
## olabilir (ör. kapanışta oluşturulan bildirim), bu yüzden zayıf referansla ertelenir.
func _on_node_added(n: Node) -> void:
	_snap_later.call_deferred(weakref(n))


func _snap_later(w: WeakRef) -> void:
	var n = w.get_ref()
	if n != null:
		UI.snap_fonts(n)


# =================================================================== telefon

func _on_phone_ring(_c: Dictionary) -> void:
	_ring_t = 0.0


func _on_phone_missed(c: Dictionary) -> void:
	toasts.show_toast(Loc.t("phone.missed", {"name": Loc.t("char." + String(c["who"]))}), "warn")


func _on_phone_voicemail(_c: Dictionary, res: Dictionary) -> void:
	if String(res.get("mode", "warn")) == "collect":
		var paid := float(res["paid"])
		if paid > 0.0:
			toasts.show_toast(Loc.t("phone.voicemail_collect", {"v": Fmt.money(paid)}), "bad")
			_fine_fx(paid)
		return
	if bool(res["fined"]):
		toasts.show_toast(Loc.t("phone.voicemail_fined", {"v": Fmt.money(float(res["amount"]))}), "bad")
		_fine_fx(float(res["amount"]))
	else:
		toasts.show_toast(Loc.t("phone.voicemail_spared"), "warn")


func _on_boost_started(_secs: float) -> void:
	fx.start_boost()
	Sfx.play("boost", 1.0, -2.0)
	Sfx.set_music_pitch(1.18)


func _on_boost_ended() -> void:
	fx.stop_boost()
	Sfx.set_music_pitch(1.0)
	if not day_end.visible and not transition.is_playing():
		toasts.show_toast(Loc.t("phone.boost_over"), "info")


## Ceza kesildiğinde: hüzünlü ses, sarsıntı ve HUD'dan aşağı saçılan paralar.
func _fine_fx(_amount: float) -> void:
	Sfx.play("fine", 1.0, -2.0)
	fx.shake(0.3)
	fx.burst(hud.get_global_rect().get_center() / PIX_SHRINK, 26, ["coin"], 220.0, PI / 2.0, 2.2)


## Arama penceresi: solda arayanın portresi, sağda konuşma ve seçenekler. Açıkken oyun duraklar.
func _show_call(c: Dictionary) -> void:
	if c.is_empty():
		return
	_call_ctx = c.duplicate()
	Game.paused = true
	var who: String = c["who"]
	var good: bool = String(c["kind"]) == "good"
	var row := UI.hbox(18)
	var pc := UI.vbox(6)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("1a1440"), UI.GOLD if good else UI.CORAL, 0, 2, 6))
	var tex: Texture2D = load("res://assets/art/portrait_%s.png" % who)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = tex.get_size() * 2.0 if tex else Vector2(198, 198)
	frame.add_child(tr)
	pc.add_child(frame)
	var nm := UI.title(Loc.t("char." + who), 22, UI.GOLD if good else UI.CORAL, 4)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(nm)
	row.add_child(pc)
	var v := UI.vbox(12)
	v.custom_minimum_size.x = 470
	row.add_child(v)
	v.add_child(UI.title(Loc.t("phone.kicker"), 11, UI.PINK, 2))
	# Sadık Bey'in tavrı o anki duruma göre: taksit tamam / bugün hiç ödeme yok / kısmen ödenmiş
	var mode := "" if good else PhoneCalls.threat_mode(Game)
	_call_ctx["mode"] = mode
	var line_key := "phone.%s.%d" % [who, int(c["line"])]
	if mode == "paid":
		line_key = "phone.sadik_paid.%d" % (1 + int(c["line"]) % 2)
	elif mode == "collect":
		line_key = "phone.sadik_empty.%d" % int(c["line"])
	var line := UI.wrap_label(Loc.t(line_key), 22, UI.TEXT)
	line.custom_minimum_size.x = 460
	v.add_child(line)
	var info := UI.vbox(6)
	v.add_child(info)
	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons)
	_call_ctx["info"] = info
	_call_ctx["buttons"] = buttons
	if good:
		var bi := UI.title(Loc.t("phone.boost_info", {"x": Fmt.dec(float(GameData.eco["phone"]["boost_speed"]), 0)}) + "  •  " + Loc.t("phone.boost_secs", {"s": int(GameData.eco["phone"]["boost_secs"])}), 22, UI.ORANGE, 4)
		bi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(bi)
		var go := UI.button(Loc.t("phone.boost_btn"), _call_boost, 260)
		go.custom_minimum_size.y = 56
		UI.paint_button(go, UI.ORANGE, Color("3a1200"))
		buttons.add_child(go)
	elif mode == "paid":
		_call_add_ok(buttons)
	elif mode == "collect":
		_call_collect(info)
		_call_add_ok(buttons)
	else:
		_call_show_risk(info)
		var amt := PhoneCalls.pay_now_amount(Game)
		var pay := UI.button(Loc.t("phone.pay_now", {"v": Fmt.money(amt)}), _call_pay, 240)
		pay.custom_minimum_size.y = 56
		UI.paint_button(pay, UI.MINT, Color("06301f"))
		pay.disabled = amt <= 0.0
		buttons.add_child(pay)
		var hang := UI.button(Loc.t("phone.hang_up"), _call_hang_up, 180)
		hang.custom_minimum_size.y = 56
		UI.paint_button(hang, UI.CORAL)
		buttons.add_child(hang)
	_call_root = dialogs.open(row, 800.0, UI.GOLD if good else UI.CORAL)
	Sfx.play("tick", 0.8, -4.0)


func _call_show_risk(info: VBoxContainer) -> void:
	UI.clear(info)
	var p := PhoneCalls.fine_chance(Game)
	var amount := PhoneCalls.fine_amount(Game)
	var l := UI.title(Loc.t("phone.risk", {"p": Fmt.pct(p, 0), "r": Fmt.pct(float(GameData.eco["phone"]["fine_rate"]), 0), "v": Fmt.money(amount)}), 22, UI.WARN, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	info.add_child(l)
	var hint := UI.wrap_label(Loc.t("phone.risk_hint", {"v": Fmt.money(PhoneCalls.pay_now_amount(Game))}), 11, UI.MUTED)
	hint.custom_minimum_size.x = 460
	info.add_child(hint)


## Arama penceresine sonuç satırı ekler (büyük yazı sarılır).
func _call_info(info: VBoxContainer, text: String, col: Color) -> void:
	var l := UI.title(text, 22, col, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	info.add_child(l)


## Kasa boş cezası: pencere açılınca Sadık Bey nakde el koyup taksite yatırır; ne olduğu açıkça yazılır.
func _call_collect(info: VBoxContainer) -> void:
	_call_ctx["resolved"] = true
	var paid := PhoneCalls.collect(Game)
	if paid > 0.0:
		var ratio := clampf(float(Game.run["installment"]) / maxf(1.0, Game.target()), 0.0, 1.0)
		var leave := float(GameData.eco["phone"]["collect_leave_x"]) * Game.x()
		_call_info(info, Loc.t("phone.collected", {"v": Fmt.money(paid), "p": Fmt.pct(ratio, 0), "l": Fmt.money(minf(leave, float(Game.run["cash"])))}), UI.CORAL)
		var hint := UI.wrap_label(Loc.t("phone.collect_hint"), 11, UI.MUTED)
		hint.custom_minimum_size.x = 460
		info.add_child(hint)
		_fine_fx(paid)
	else:
		_call_info(info, Loc.t("phone.collect_nothing"), UI.WARN)
	refresh_all()


## Ceza zarının sonucu (kesildi / bu seferlik bağışlandı)
func _call_fine_line(info: VBoxContainer, res: Dictionary) -> void:
	if bool(res.get("fined", false)):
		_call_info(info, Loc.t("phone.fined", {"v": Fmt.money(float(res["amount"]))}), UI.BAD)
		_fine_fx(float(res["amount"]))
	else:
		_call_info(info, Loc.t("phone.spared_paid" if Game.installment_done() else "phone.spared"), UI.GOOD)


func _call_add_ok(buttons: HBoxContainer) -> void:
	UI.clear(buttons)
	var ok := UI.button(Loc.t("phone.ok"), _close_call, 180)
	ok.custom_minimum_size.y = 56
	UI.paint_button(ok, UI.GOLD, Color("3a1800"))
	buttons.add_child(ok)


func _call_boost() -> void:
	_close_call()
	PhoneCalls.start_boost(Game)


## Şimdi Öde: nakit bugünkü taksite gider ve ne kadar yatırıldığı yazılır; Sadık Bey memnun kalır, ceza kesmez.
func _call_pay() -> void:
	if _call_ctx.is_empty() or bool(_call_ctx.get("resolved", false)):
		return
	_call_ctx["resolved"] = true
	var r := PhoneCalls.pay_now(Game)
	var paid := float(r["paid"])
	if paid > 0.0:
		Sfx.play("pay", 1.1, -4.0)
	var info: VBoxContainer = _call_ctx["info"]
	UI.clear(info)
	var ratio := clampf(float(Game.run["installment"]) / maxf(1.0, Game.target()), 0.0, 1.0)
	if Game.installment_done():
		_call_info(info, Loc.t("phone.paid_full", {"v": Fmt.money(paid)}), UI.GOOD)
	elif bool(r["satisfied"]):
		_call_info(info, Loc.t("phone.paid_ok", {"v": Fmt.money(paid), "p": Fmt.pct(ratio, 0)}), UI.GOOD)
	else:
		_call_info(info, Loc.t("phone.paid_little", {"v": Fmt.money(paid)}), UI.WARN)
		_call_fine_line(info, r["fine"])
	_call_add_ok(_call_ctx["buttons"])
	refresh_all()


func _call_hang_up() -> void:
	_call_resolve()


## Sadık Bey araması sonucu: ceza zarı atılır, sonuç pencerede gösterilir.
func _call_resolve() -> void:
	if _call_ctx.is_empty() or bool(_call_ctx.get("resolved", false)):
		return
	_call_ctx["resolved"] = true
	var res := PhoneCalls.roll_fine(Game)
	var info: VBoxContainer = _call_ctx["info"]
	UI.clear(info)
	_call_fine_line(info, res)
	_call_add_ok(_call_ctx["buttons"])
	refresh_all()


## Esc: iyi aramada hediyeyi reddeder; Sadık Bey ceza riskiyle aradıysa telefonu kapatır (zar atılır).
func _call_escape() -> void:
	if _call_ctx.is_empty():
		return
	if String(_call_ctx.get("mode", "")) == "warn" and not bool(_call_ctx.get("resolved", false)):
		_call_resolve()
		return
	_close_call()


func _close_call() -> void:
	if _call_root and is_instance_valid(_call_root):
		dialogs.close(_call_root)
	_call_root = null
	_call_ctx = {}
	Game.paused = menu.visible or day_end.visible


## Ana menüdeki dil düğmesi: diller arasında sırayla geçer.
func _toggle_language() -> void:
	var langs := Loc.available_languages()
	langs.sort()
	var i := langs.find(Loc.lang)
	_on_language(String(langs[(i + 1) % langs.size()]))


## İlk ÖDE: paranın neredeyse tamamının taksite gideceğini bir kez söyler.
func _on_pay_warning() -> void:
	dialogs.confirm(Loc.t("hud.pay_warn_title"), Loc.t("hud.pay_warn_body"), Loc.t("hud.pay_warn_ok"), _pay_warned)


func _pay_warned() -> void:
	Game.settings["pay_warned"] = true
	SaveSystem.save_settings(Game.settings)
	hud.do_pay()


## Borç Defteri (masadaki defter): günlerin taksitleri, ödenenler işaretli.
func _show_ledger() -> void:
	var v := UI.vbox(6)
	var th := UI.hbox(10)
	th.add_child(Icon.make("pay", 33))
	th.add_child(UI.title(Loc.t("ledger.title"), 33, Color("5a2a12"), 0))
	v.add_child(th)
	var cur := Game.day()
	for d in range(1, GameData.day_count() + 1):
		var info := GameData.day_info(d)
		var h := UI.hbox(8)
		var done := d < cur or Game.is_free_mode()
		var now := d == cur and not Game.is_free_mode()
		var col := Color("3a6a2a") if done else (Color("b0361f") if now else Color("6a5040"))
		var l := UI.title(Loc.t("ledger.day", {"d": d}), 22, col, 0)
		l.custom_minimum_size.x = 110
		h.add_child(l)
		var amt := UI.title(Fmt.money(float(info["target"])), 22, col, 0)
		amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(amt)
		if done:
			h.add_child(Icon.make("check", 22))
		elif now:
			h.add_child(UI.title("%d%%" % int(clampf(float(Game.run["installment"]) / maxf(1.0, Game.target()), 0.0, 1.0) * 100.0), 22, col, 0))
		v.add_child(h)
	v.add_child(UI.title(Loc.t("ledger.left", {"v": Fmt.money(Game.debt_left())}), 22, Color("5a2a12"), 0))
	var holder: Array = [null]
	var b := UI.button(Loc.t("common.close"), func(): dialogs.close(holder[0]), 160)
	b.custom_minimum_size.y = 44
	b.add_theme_font_size_override("font_size", 22)
	UI.paint_button(b, Color("2f5fa8"))
	var bh := UI.hbox(0)
	bh.alignment = BoxContainer.ALIGNMENT_END
	bh.add_child(b)
	v.add_child(bh)
	holder[0] = dialogs.open(v, 420.0, Color("e8941a"))
	(holder[0] as Control).get_child(1).get_child(0).add_theme_stylebox_override("panel", UI.style(Color("f4ead0"), Color("e8941a"), 0, 3, 18))


# =================================================================== ayarlar

func _open_settings() -> void:
	var s: Dictionary = Game.settings
	var v := UI.vbox(12)
	var th := UI.hbox(10)
	th.add_child(Icon.make("gear", 40))
	th.add_child(UI.title(Loc.t("settings.title"), 30, UI.GOLD, 7))
	v.add_child(th)
	for key in ["master", "sfx", "music"]:
		var h := UI.hbox(10)
		var l := UI.title(Loc.t("settings." + key), 16, UI.TEXT, 3)
		l.custom_minimum_size.x = 170
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(s[key])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size.x = 260
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(_on_volume.bind(key))
		h.add_child(sl)
		v.add_child(h)
	for key in ["reduced_motion", "show_heat", "fullscreen"]:
		var cb := CheckBox.new()
		cb.text = Loc.t("settings." + key)
		cb.button_pressed = bool(s[key])
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_on_toggle_setting.bind(key))
		v.add_child(cb)
	var lh := UI.hbox(10)
	lh.add_child(UI.title(Loc.t("settings.language"), 16, UI.TEXT, 3))
	var lang := OptionButton.new()
	lang.focus_mode = Control.FOCUS_NONE
	var langs := Loc.available_languages()
	for i in range(langs.size()):
		lang.add_item(Loc.t("lang." + str(langs[i])))
		if langs[i] == Loc.lang:
			lang.select(i)
	lang.item_selected.connect(func(i): _on_language(langs[i]))
	lh.add_child(lang)
	v.add_child(lh)
	v.add_child(UI.wrap_label(Loc.t("settings.offline_note"), 13, UI.MUTED))
	var h2 := UI.hbox(10)
	var wipe := UI.button(Loc.t("settings.wipe"), _ask_wipe, 190)
	UI.paint_button(wipe, Color("6a2440"), UI.CORAL)
	h2.add_child(wipe)
	h2.add_child(UI.spacer())
	var holder: Array = [null]
	var close := UI.button(Loc.t("common.close"), _close_settings.bind(holder), 160)
	UI.paint_button(close, UI.GOLD, Color("3a1800"))
	h2.add_child(close)
	v.add_child(h2)
	holder[0] = dialogs.open(v, 560.0)


func _close_settings(holder: Array) -> void:
	SaveSystem.save_settings(Game.settings)
	dialogs.close(holder[0])


func _on_volume(value: float, key: String) -> void:
	Game.settings[key] = value
	Sfx.apply_volumes(Game.settings)


func _on_toggle_setting(on: bool, key: String) -> void:
	Game.settings[key] = on
	if key == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	SaveSystem.save_settings(Game.settings)


## Dil değişimi: ayar kaydedilir ve arayüz sahnesi yeni dille yeniden kurulur (oyun durumu korunur).
func _on_language(code: String) -> void:
	if code == Loc.lang:
		return
	Game.settings["lang"] = code
	Game.settings["lang_chosen"] = true
	SaveSystem.save_settings(Game.settings)
	Loc.load_language(code)
	Game.save_now()
	Game.resume_after_reload = not menu.visible and not day_end.visible
	get_tree().call_deferred("reload_current_scene")


func _ask_wipe() -> void:
	dialogs.confirm(Loc.t("settings.wipe_title"), Loc.t("settings.wipe_body"), Loc.t("settings.wipe_ok"), _do_wipe, true)


func _do_wipe() -> void:
	dialogs.close_top()
	Game.wipe_save()
	_show_menu()


# =================================================================== hata ayıklama yardımcıları

func _debug_spin(kind: String) -> void:
	_open_wheel(kind)
	if _wheel_win:
		_wheel_win.call("_on_open")


func _debug_tree_phase() -> void:
	Game.paused = true
	day_end.visible = true
	_day_end_confirm()


func _debug_edit() -> void:
	right_side.call("_open_editor")
