extends HFlowContainer
## Topun yetenekleri: her yetenek için renkli küçük çip (ör. "★MAX ×1,50", "İkiz top %25") ve
## nadirlik renginde "Güç +%35" çipi. Ayrıntılı açıklama çipin araç ipucundadır.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Fmt := preload("res://scripts/util/fmt.gd")
const BallCollection := preload("res://scripts/systems/ball_collection.gd")

## yetenek -> renk (aralık renkleriyle uyumlu)
var font_size := 11

const COLORS := {
	"trait.pos_mult": Color("4fe0a0"), "trait.w_mult": Color("35e07f"), "trait.max_mult": Color("ffd23f"),
	"trait.loss_mult": Color("ff8a8a"), "trait.bias": Color("7fd6ff"), "trait.split_chance": Color("4fe8cc"),
	"trait.rebirth_chance": Color("ffa52e"),
}


static func value_text(key: String, val: float) -> String:
	if key == "trait.bias" or key.ends_with("chance"):
		return Fmt.pct(val, 0)
	return Fmt.mult(val)


func show_ball(bid: String, stars: int, with_power: bool = true, centered: bool = true) -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	alignment = FlowContainer.ALIGNMENT_CENTER if centered else FlowContainer.ALIGNMENT_BEGIN
	var rar: String = GameData.balls_by_id[bid]["rarity"]
	if with_power:
		var pw := BallCollection.power(Game, bid, stars)
		var t := Loc.t("trait.power", {"v": Fmt.pct(pw, 0)}) if absf(pw) > 0.005 else Loc.t("trait.power_base")
		add_child(_chip(t, UI.rarity_color(rar).lightened(0.2), Color("1d1a45"), true))
	for line in BallCollection.trait_lines(bid, stars):
		var key: String = line[0]
		var val: float = line[1]
		var col: Color = COLORS.get(key, UI.TEXT)
		var chip := _chip(Loc.t(key.replace("trait.", "trait.short."), {"v": value_text(key, val)}), col, Color("15183a"), false)
		chip.tooltip_text = Loc.t(key, {"v": value_text(key, val)})
		add_child(chip)


func _chip(text_: String, col: Color, bg: Color, strong: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(bg, col.darkened(0.25) if not strong else col, 0, 1, 4 if font_size <= 11 else 6))
	var l := UI.title(text_, font_size, col, UI.outline_for(font_size))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p
