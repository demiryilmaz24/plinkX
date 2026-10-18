extends RefCounted
## Arayüz yardımcıları: canlı renk paleti, yazı tipleri, tema ve küçük kurucu fonksiyonlar.

# ---------------------------------------------------------------- palet (canlı, doygun)
const BG := Color("1a1240")          # derin çivit
const BG_2 := Color("10265a")        # gece mavisi
const PANEL := Color("2a2f7a")       # zengin mavi kart
const PANEL_2 := Color("353c96")     # açık kart
const PANEL_DARK := Color("1b1f55")
const BORDER := Color("6a78ff")
const TEXT := Color("ffffff")
const MUTED := Color("c3caff")
const DIM := Color("8a92d6")
const GOLD := Color("ffcc33")
const GOLD_DARK := Color("e8941a")
const CORAL := Color("ff5d73")
const MINT := Color("2ee59d")
const SKY := Color("38c6f4")
const PINK := Color("ff4fb4")
const PURPLE := Color("9d5cff")
const ORANGE := Color("ff8a1f")

# eski adlar (diğer betikler kullanır)
const BRASS := GOLD
const GOOD := MINT
const BAD := CORAL
const WARN := ORANGE
const INFO := SKY
const TICKET := Color("ff7a2e")
const TICKET_BG := Color("4a1f5c")
const FELT := Color("10b07a")
const FELT_DARK := Color("0a7f59")

const INTERVAL_COLORS := {
	"M": Color("ffd23f"),
	"W": Color("35e07f"),
	"L": Color("ff6161"),
	"E": Color("d6456b"),
}

const RARITY_COLORS := {
	"common": Color("d7deea"),
	"rare": Color("38c6f4"),
	"epic": Color("b06cff"),
	"legendary": Color("ffb627"),
}

const BALL_COLORS := {
	"demir": Color("b8c4d6"),
	"cam": Color("8fe9ff"),
	"kil": Color("f08a4b"),
	"kaucuk": Color("ff3d5a"),
	"bakir": Color("ff9a3c"),
	"miknatis": Color("4c6bff"),
	"volkan": Color("ff4b1f"),
	"altin": Color("ffd23f"),
	"ikiz": Color("22e0c0"),
	"kuyruklu": Color("c08bff"),
	"anka": Color("ff8a1f"),
	"kara_inci": Color("3a2f66"),
}

const PEG_COLORS := {
	"bakir_civi": Color("ff9a3c"),
	"yay": Color("4dff9a"),
	"kalkan": Color("7fb6ff"),
	"gumus": Color("eef3ff"),
	"ayna": Color("4ff0ff"),
	"huni": Color("c07bff"),
	"altin_civi": Color("ffd23f"),
	"yildiz": Color("ff5fc8"),
	"bilet": Color("ff7a2e"),
	"elmas": Color("a6f6ff"),
}

static var _body_font: Font
static var _display_font: Font


static func ball_color(bid: String) -> Color:
	return BALL_COLORS.get(bid, Color.WHITE)


static func peg_color(pid: String) -> Color:
	return PEG_COLORS.get(pid, GOLD)


static func rarity_color(r: String) -> Color:
	return RARITY_COLORS.get(r, TEXT)


# ---------------------------------------------------------------- yazı tipleri

const PIXEL_FONT_PATH := "res://assets/fonts/PixelifySans-SB.ttf"   # 5 rakamı düzeltilmiş (tools/patch_font.py)
static var _pixel_base: FontFile


## Piksel yazı tipi (Pixelify Sans, OFL).
static func _pixel_file() -> FontFile:
	if _pixel_base == null:
		_pixel_base = load(PIXEL_FONT_PATH)
		# Pixelify Sans 11 piksellik bir ızgarada çizilmiştir (1 tasarım pikseli = em/11). Arayüz tam sayı
		# katlarla ölçeklendiği ve boyutlar fs() ile 11'in katlarına oturtulduğu için kenar yumuşatmasız
		# çizim her boyutta keskin, eşit piksellerden oluşur.
		_pixel_base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_pixel_base.hinting = TextServer.HINTING_NONE
		_pixel_base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_pixel_base.generate_mipmaps = false
	return _pixel_base


## Yazı boyutunu yazı tipinin piksel ızgarasına oturtur: 11 (küçük), 22 (orta), 33, 44 ...
## Ara boyutlar en yakın kata yuvarlanır; böylece her harf pikseli eşit ve keskin olur.
const FONT_GRID := 11


static func fs(size: int) -> int:
	if size <= 0:
		return size
	if size <= 16:
		return FONT_GRID
	return int(round(float(size) / FONT_GRID)) * FONT_GRID


## Kontur kalınlığı: tasarım pikselinin katı (11 → 2, 22 → 4, 33 → 6).
static func outline_for(size: int) -> int:
	return 2 * maxi(1, fs(size) / FONT_GRID)


## Düğüm (ve sonradan eklenecek alt düğümleri) üzerindeki yazı boyutu geçersiz kılmalarını ızgaraya oturtur.
static func snap_fonts(c: Node) -> void:
	if c is Control:
		var ctl := c as Control
		for item in ["font_size", "normal_font_size", "bold_font_size"]:
			if ctl.has_theme_font_size_override(item):
				var v := ctl.get_theme_font_size(item)
				if v != fs(v):
					ctl.add_theme_font_size_override(item, fs(v))
		if ctl.has_theme_constant_override("outline_size") and ctl.has_theme_font_size_override("font_size"):
			var o := ctl.get_theme_constant("outline_size")
			if o > 0:
				var want := outline_for(ctl.get_theme_font_size("font_size"))
				if o != want:
					ctl.add_theme_constant_override("outline_size", want)


## Gövde metni: okunaklı, orta kalınlık.
static func body_font() -> Font:
	if _body_font == null:
		var f := FontVariation.new()
		f.base_font = _pixel_file()
		f.variation_opentype = {"wght": 500}
		_body_font = f
	return _body_font


## Başlık/sayı/düğme: kalın.
static func display_font() -> Font:
	if _display_font == null:
		var f := FontVariation.new()
		f.base_font = _pixel_file()
		f.variation_opentype = {"wght": 700}
		_display_font = f
	return _display_font


# ---------------------------------------------------------------- piksel çerçeveler

const PIX := 3                       # bir mantıksal pikselin ekran pikseli
const OUTLINE_C := Color("140b2e")
static var _frame_cache: Dictionary = {}


## 12x12 mantıksal ızgarada piksel çerçeve dokusu: basamaklı köşe, koyu kontur, isteğe bağlı renkli iç halka,
## üstte açık şerit, altta koyu kalınlık (3B). pressed: kalınlık yok, üst gölgeli.
static func pixel_frame(fill: Color, ring: Color = Color(0, 0, 0, 0), raised: bool = true, pressed: bool = false, pad: int = 8) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s|%d" % [fill.to_html(), ring.to_html(), raised, pressed, pad]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var n := 12
	var img := Image.create(n * PIX, n * PIX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var light := fill.lightened(0.22)
	var dark := fill.darkened(0.38)
	for y in range(n):
		for x in range(n):
			var edge := x == 0 or y == 0 or x == n - 1 or y == n - 1
			var corner := (x == 0 or x == n - 1) and (y == 0 or y == n - 1)
			var c := fill
			if corner:
				continue
			if edge:
				c = OUTLINE_C
			elif (x == 1 or x == n - 2) and (y == 1 or y == n - 2):
				c = OUTLINE_C
			elif ring.a > 0.0 and (x == 1 or y == 1 or x == n - 2 or y == n - 2):
				c = ring
			elif raised and not pressed and y >= n - 3:
				c = dark
			elif raised and not pressed and y == (2 if ring.a > 0.0 else 1):
				c = light
			elif pressed and y == (2 if ring.a > 0.0 else 1):
				c = dark
			img.fill_rect(Rect2i(x * PIX, y * PIX, PIX, PIX), c)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := 4 * PIX
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7 + (PIX if pressed else 0)
	sb.content_margin_bottom = pad * 0.7 + (PIX * 2 if raised and not pressed else 0)
	_frame_cache[key] = sb
	return sb


# ---------------------------------------------------------------- kutular

static func _box(bg: Color, border: Color, radius: int = 10, bw: int = 0, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.75
	s.content_margin_bottom = pad * 0.75
	return s


## Tok, "basılabilir" piksel düğme (üstte açık şerit, altta koyu kalınlık).
static func chunky(bg: Color, pressed: bool = false, radius: int = 12, pad: int = 10) -> StyleBox:
	return pixel_frame(bg, Color(0, 0, 0, 0), true, pressed, pad)


## Piksel panel çerçevesi. bw>0 ise border renginde iç halka çizilir.
static func style(bg: Color, border: Color, radius: int = 10, bw: int = 1, pad: int = 8) -> StyleBox:
	return pixel_frame(bg, border if bw > 0 else Color(0, 0, 0, 0), false, false, pad)


## Bir düğmeyi renkli tok düğmeye çevirir.
static func paint_button(b: Button, color: Color, font_color: Color = Color.WHITE) -> void:
	b.add_theme_stylebox_override("normal", chunky(color))
	b.add_theme_stylebox_override("hover", chunky(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", chunky(color.darkened(0.08), true))
	b.add_theme_stylebox_override("disabled", chunky(Color(color.darkened(0.45), 0.85)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_hover_color", font_color)
	b.add_theme_color_override("font_pressed_color", font_color)
	b.add_theme_color_override("font_disabled_color", Color(font_color, 0.45))


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = FONT_GRID
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", style(PANEL, BORDER, 0, 0, 12))
	t.set_stylebox("panel", "Panel", style(PANEL, BORDER, 0, 0, 12))
	# Düğmeler: tok, yuvarlak
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", FONT_GRID * 2)
	t.set_stylebox("normal", "Button", chunky(Color("4656d6")))
	t.set_stylebox("hover", "Button", chunky(Color("5a6cf0")))
	t.set_stylebox("pressed", "Button", chunky(Color("3a47b8"), true))
	t.set_stylebox("disabled", "Button", chunky(Color("2b3170")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("8a92d6"))
	# İlerleme çubuğu
	t.set_stylebox("background", "ProgressBar", _box(Color("12164a"), BORDER, 8, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, GOLD, 8, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	# İpucu
	t.set_stylebox("panel", "TooltipPanel", style(Color("141850"), GOLD, 0, 1, 12))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_GRID)
	# Seçim kutuları
	t.set_stylebox("normal", "OptionButton", chunky(Color("4656d6"), false, 10, 8))
	t.set_stylebox("hover", "OptionButton", chunky(Color("5a6cf0"), false, 10, 8))
	t.set_stylebox("pressed", "OptionButton", chunky(Color("3a47b8"), true, 10, 8))
	t.set_stylebox("panel", "PopupMenu", style(Color("1b1f55"), GOLD, 0, 1, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	for cb in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", cb, TEXT)
		t.set_color("font_hover_color", cb, GOLD)
		t.set_color("font_pressed_color", cb, TEXT)
		t.set_stylebox("normal", cb, StyleBoxEmpty.new())
		t.set_stylebox("hover", cb, StyleBoxEmpty.new())
		t.set_stylebox("pressed", cb, StyleBoxEmpty.new())
		t.set_stylebox("hover_pressed", cb, StyleBoxEmpty.new())
		t.set_stylebox("focus", cb, StyleBoxEmpty.new())
	t.set_stylebox("slider", "HSlider", _box(Color("12164a"), BORDER, 6, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD, GOLD, 6, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("ffe07a"), GOLD, 6, 0, 3))
	# Kaydırma çubuğu: ince ve sade
	var grab := _box(Color(1, 1, 1, 0.25), Color.TRANSPARENT, 6, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(Color(1, 1, 1, 0.4), Color.TRANSPARENT, 6, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(GOLD, Color.TRANSPARENT, 6, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", _box(Color(0, 0, 0, 0.15), Color.TRANSPARENT, 6, 0, 0))
	return t


# ---------------------------------------------------------------- kurucular

static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Kalın, dış çizgili büyük yazı (sayılar ve başlıklar).
static func title(text: String, size: int = 22, color: Color = TEXT, outline: int = 6) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", display_font())
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.18, 0.85))
	return l


static func wrap_label(text: String, size: int = 14, color: Color = MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	return b


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func panel(bg: Color = PANEL, border: Color = BORDER, pad: int = 10, bw: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border, 0, bw, pad + PIX))
	return p


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func section_title(text: String) -> Label:
	var l := title(text, 15, GOLD, 4)
	l.uppercase = true
	return l


static func progress(min_h: int = 14, fill: Color = GOLD) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size.y = min_h
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 1.0
	p.add_theme_stylebox_override("fill", _box(fill, fill, 8, 0, 0))
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
