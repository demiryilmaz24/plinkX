extends RefCounted
## Dile göre sayı biçimlendirme.
##  Türkçe:   binlik ".", ondalık ",", para "12.345$", yüzde "%45,8", büyük sayılar Mn/Mr/Tn/Kt/Kn
##  İngilizce: binlik ",", ondalık ".", para "$12,345", yüzde "45.8%", büyük sayılar M/B/T/Qa/Qi
## Daha büyükleri bilimsel gösterim.

const SUFFIX_TR := ["", "", " Mn", " Mr", " Tn", " Kt", " Kn"]
const SUFFIX_EN := ["", "", "M", "B", "T", "Qa", "Qi"]


static func _tr() -> bool:
	return Loc.lang == "tr"


static func group_int(n: int) -> String:
	var sep := "." if _tr() else ","
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if neg else "") + out


static func dec(x: float, digits: int) -> String:
	var s: String
	if digits <= 0:
		s = "%d" % int(roundf(x))
	elif digits == 1:
		s = "%.1f" % x
	else:
		s = "%.2f" % x
	return s.replace(".", ",") if _tr() else s


static func _scaled(a: float) -> String:
	if a < 1e6:
		return group_int(int(roundf(a)))
	var suffix: Array = SUFFIX_TR if _tr() else SUFFIX_EN
	var tier := int(floor(log(a) / log(10.0) + 1e-9)) / 3
	if tier >= suffix.size():
		var e := int(floor(log(a) / log(10.0) + 1e-9))
		return dec(a / pow(10.0, e), 2) + "e" + str(e)
	var scaled := a / pow(10.0, tier * 3)
	return dec(scaled, 2 if scaled < 100.0 else 1) + String(suffix[tier])


static func _cur(sgn: String, body: String) -> String:
	return sgn + body + "$" if _tr() else sgn + "$" + body


## Para: "12,50$" / "$12.50", "12.345$" / "$12,345", "1,25 Mn$" / "$1.25M"
static func money(v: float) -> String:
	var a := absf(v)
	var sgn := "-" if v < 0.0 else ""
	if a < 100.0 and absf(a - roundf(a)) > 0.004:
		return _cur(sgn, dec(a, 2))
	return _cur(sgn, _scaled(a))


## İşaretli para: "+30$" / "+$30"
static func money_signed(v: float) -> String:
	if v >= 0.0:
		return "+" + money(v)
	return money(v)


static func num(v: float) -> String:
	var a := absf(v)
	return ("-" if v < 0.0 else "") + _scaled(a)


## Yüzde: "%45,8" / "45.8%"
static func pct(p: float, digits: int = 1) -> String:
	var body := dec(p * 100.0, digits)
	return "%" + body if _tr() else body + "%"


## Çarpan: "×3,11" / "×3.11"
static func mult(m: float) -> String:
	if m >= 1000.0:
		return "×" + num(m)
	return "×" + dec(m, 2)


## X cinsinden etiket: "+1,2X" / "+1.2X"
static func xlabel(v: float) -> String:
	var s := dec(absf(v), 2)
	var d := "," if _tr() else "."
	if s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with(d + "0"):
		s = s.substr(0, s.length() - 2)
	return ("+" if v >= 0.0 else "-") + s + "X"


## Saniye: "0,45 sn" / "0.45s"
static func secs(v: float, digits: int = 2) -> String:
	return dec(v, digits) + (" sn" if _tr() else "s")


## Süre: "4 sn", "2 dk 05 sn", "1 sa 03 dk" / "4s", "2m 05s", "1h 03m"
static func duration(sec: float) -> String:
	var s := int(sec)
	if _tr():
		if s < 60:
			return "%d sn" % s
		if s < 3600:
			return "%d dk %02d sn" % [s / 60, s % 60]
		return "%d sa %02d dk" % [s / 3600, (s % 3600) / 60]
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
