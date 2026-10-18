extends RefCounted
## Hikâye ve gün ilerlemesi metinleri. Metinler dil dosyasındadır (story.dayN.*, story.finale.*, story.free.*).
## Her gün başında bir kez, kısa bir pencere olarak gösterilir; atışları diyalogla bölmez.


## Hikâye penceresindeki konuşan/öne çıkan karakterin portresi (assets/art/portrait_*.png)
const PORTRAITS := {
	"1": "tekin", "2": "nevin", "3": "nevin", "4": "tekin", "5": "nevin", "6": "nevin",
	"7": "sadik", "8": "guard", "9": "tekin", "10": "nevin", "finale": "sadik", "free": "tekin",
}


static func base_key(key: String) -> String:
	if key.is_valid_int():
		return "story.day" + key
	return "story." + key


static func entry(key: String) -> Dictionary:
	var b := base_key(key)
	var e := {
		"kicker": Loc.t(b + ".kicker"),
		"title": Loc.t(b + ".title"),
		"body": Loc.t(b + ".body"),
	}
	if Loc.has(b + ".note"):
		e["note"] = Loc.t(b + ".note")
	if Loc.has(b + ".info"):
		e["info"] = Loc.t(b + ".info")
	e["portrait"] = "res://assets/art/portrait_%s.png" % String(PORTRAITS.get(key, "tekin"))
	e["name"] = Loc.t("char." + String(PORTRAITS.get(key, "tekin")))
	return e
