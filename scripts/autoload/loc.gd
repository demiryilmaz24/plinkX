extends Node
## Basit yerelleştirme: data/lang/<dil>.json içindeki anahtar -> metin tablosu.
## Yeni dil eklemek için aynı anahtarlarla yeni bir JSON dosyası eklemek yeterlidir.

signal language_changed

const DEFAULT_LANG := "en"   # ana dil İngilizce; eksik anahtarlar İngilizceden tamamlanır

var lang := DEFAULT_LANG
var _texts: Dictionary = {}
var _fallback: Dictionary = {}


func _ready() -> void:
	_fallback = _read(DEFAULT_LANG)
	load_language(DEFAULT_LANG)


func _read(code: String) -> Dictionary:
	var path := "res://data/lang/%s.json" % code
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Dil dosyası bulunamadı: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Dil dosyası okunamadı: " + path)
	return {}


func load_language(code: String) -> void:
	var d := _read(code)
	if d.is_empty():
		return
	_texts = d
	lang = code
	language_changed.emit()


func available_languages() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/lang")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	return out


## Anahtarın metnini döndürür; {ad} biçimindeki yer tutucular args ile doldurulur.
func t(key: String, args: Dictionary = {}) -> String:
	var s: String = _texts.get(key, _fallback.get(key, key))
	if not args.is_empty():
		s = s.format(args)
	return s


func has(key: String) -> bool:
	return _texts.has(key) or _fallback.has(key)
