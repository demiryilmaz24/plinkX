extends Node
## Vektör ikonları piksel sanata çevirir: ikon küçük bir SubViewport'ta (ör. 16x16) bir kez çizilir,
## yarı saydam kenarlar keskinleştirilir, dışına 1 piksel koyu kontur eklenir ve doku önbelleğe alınır.
## Görüntülenirken en-yakın filtreyle büyütülür (keskin, blok pikseller).

signal icon_ready(key)

const Icon := preload("res://scripts/ui/icon.gd")
const SpriteGen := preload("res://scripts/art/sprite_gen.gd")
const OUTLINE := Color("140b2e")

var _cache: Dictionary = {}     # key -> Texture2D
var _pending: Dictionary = {}   # key -> {vp, frames}
# animasyonlu top/çivi sprite'ları: arka planda (WorkerThreadPool) üretilir
var _sprites: Dictionary = {}   # "ball:x@S" -> Array[ImageTexture]
var _tasks: Dictionary = {}     # anahtar -> görev kimliği
var _done: Dictionary = {}      # anahtar -> Array[Image] (iş parçacığından)
var _mutex := Mutex.new()
var _plain: Dictionary = {}     # sıradan çivi dokuları


var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return   # görüntüsüz testlerde doku üretilmez
	_load_bodies()
	# tüm türleri açılışta sıraya koy (menü açıkken biter); önce tahta boyu
	for big in [false, true]:
		for b in GameData.balls:
			_queue_sprite("ball:" + String(b["id"]), big)
		for p in GameData.pegs:
			_queue_sprite("peg:" + String(p["id"]), big)


## Çizilmiş gövde görsellerini (varsa) ana iş parçacığında yükler; sprite üretimi bunları kullanır.
func _load_bodies() -> void:
	for b in GameData.balls:
		var path := "res://assets/art/balls/%s.png" % String(b["id"])
		if ResourceLoader.exists(path):
			SpriteGen.bodies["ball:" + String(b["id"])] = (load(path) as Texture2D).get_image()
	for p in GameData.pegs:
		var path2 := "res://assets/art/pegs/%s.png" % String(p["id"])
		if ResourceLoader.exists(path2):
			SpriteGen.bodies["peg:" + String(p["id"])] = (load(path2) as Texture2D).get_image()


func _exit_tree() -> void:
	for k in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[k])
	_tasks.clear()


static func _sprite_key(kind: String, big: bool) -> String:
	return kind + ("@L" if big else "@S")


## Animasyonlu sprite'ın o anki karesi (phase saniye cinsinden kaydırma). Hazır değilse null.
func sprite(kind: String, big: bool, phase: float = 0.0) -> Texture2D:
	if _headless:
		return null
	var k := _sprite_key(kind, big)
	var arr: Variant = _sprites.get(k)
	if arr == null:
		_queue_sprite(kind, big)
		return null
	var frames: Array = arr
	var f := int(floorf((Time.get_ticks_msec() / 1000.0 + phase) * SpriteGen.FPS)) % frames.size()
	return frames[f]


## Sıradan çivi dokusu ("in", "out", "lit"); stil odaya göre: brass, gold, chrome, pearl
func plain_peg(state: String, style: String = "brass") -> Texture2D:
	var k := state + "@" + style
	if not _plain.has(k):
		_plain[k] = ImageTexture.create_from_image(SpriteGen.plain_peg(state, style))
	return _plain[k]


func _queue_sprite(kind: String, big: bool) -> void:
	var k := _sprite_key(kind, big)
	if _sprites.has(k) or _tasks.has(k):
		return
	_tasks[k] = WorkerThreadPool.add_task(_gen_task.bind(kind, big, k), false, "sprite " + k)


func _gen_task(kind: String, big: bool, k: String) -> void:
	var imgs := SpriteGen.make(kind, big)
	_mutex.lock()
	_done[k] = imgs
	_mutex.unlock()


func _collect_sprites() -> void:
	_mutex.lock()
	var ready := _done.duplicate()
	_done.clear()
	_mutex.unlock()
	for k in ready.keys():
		var texs: Array = []
		for img in ready[k]:
			texs.append(ImageTexture.create_from_image(img))
		_sprites[k] = texs
		if _tasks.has(k):
			WorkerThreadPool.wait_for_task_completion(_tasks[k])
			_tasks.erase(k)
		icon_ready.emit(k)


static func key_of(kind: String, base: int, tint: Color) -> String:
	return "%s@%d@%s" % [kind, base, tint.to_html() if tint.a > 0.0 else "-"]


## Hazırsa dokuyu döndürür; değilse üretimi başlatır ve null döner (hazır olunca icon_ready yayılır).
func get_icon(kind: String, base: int, tint: Color = Color(0, 0, 0, 0)) -> Texture2D:
	if _headless:
		return null
	var k := key_of(kind, base, tint)
	if _cache.has(k):
		return _cache[k]
	if not _pending.has(k):
		_request(kind, base, tint, k)
	return null


func _request(kind: String, base: int, tint: Color, k: String) -> void:
	# kontur için her kenarda 1 piksel pay bırakılır
	var full := base + 2
	var vp := SubViewport.new()
	vp.size = Vector2i(full, full)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var c := Control.new()
	c.size = Vector2(full, full)
	c.draw.connect(_draw_into.bind(c, kind, base, tint))
	vp.add_child(c)
	add_child(vp)
	_pending[k] = {"vp": vp, "frames": 0}


func _draw_into(c: Control, kind: String, base: int, tint: Color) -> void:
	Icon.draw_icon(c, kind, Vector2(base + 2, base + 2) / 2.0, base * 0.96, tint)


func _process(_delta: float) -> void:
	if not _tasks.is_empty():
		_collect_sprites()
	if _pending.is_empty():
		return
	for k in _pending.keys():
		var p: Dictionary = _pending[k]
		p["frames"] = int(p["frames"]) + 1
		if int(p["frames"]) < 3:
			continue
		var vp: SubViewport = p["vp"]
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			_cache[k] = ImageTexture.create_from_image(_pixelize(img))
		vp.queue_free()
		_pending.erase(k)
		icon_ready.emit(k)


## Alfa eşiği + dış kontur
func _pixelize(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var col := img.get_pixel(x, y)
			if col.a < 0.42:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				col.a = 1.0
				img.set_pixel(x, y, col)
	var out := img.duplicate() as Image
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.0:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.0:
					near = true
					break
			if near:
				out.set_pixel(x, y, OUTLINE)
	return out
