extends RefCounted
## Oda ve Kader Tahtası temaları. Tekin para kazandıkça Bilye Sarayı'nda daha gösterişli odalara geçer:
##   1. gün Arka Oda, 2-4 Ön Salon, 5-7 Kırmızı Salon, 8-9 Gece Salonu, 10. gün ve Serbest Mod Büyük Salon.
## Her odanın kendi dolap (tahta) teması vardır; tahta da her odada daha dolu ve süslü olur.
## Renk rampaları koyudan açığa 4 (bazen 3) tondur.

const ROOM_START_DAYS := [1, 2, 5, 8, 10]


static func tier_for(day: int, free_mode: bool) -> int:
	if free_mode:
		return 4
	var t := 0
	for i in range(ROOM_START_DAYS.size()):
		if day >= int(ROOM_START_DAYS[i]):
			t = i
	return t


static func current() -> int:
	return tier_for(Game.day(), Game.is_free_mode())


## Kader Tahtası dolabı
const CABINETS := [
	{   # 0 · Arka Oda: eski ceviz, yeşil keçe, pirinç
		"body": [Color("2a140c"), Color("4a2616"), Color("6a3a20"), Color("8a5230")],
		"felt": [Color("0b5c3f"), Color("0f7a52"), Color("13925f"), Color("1aa96f")],
		"trim": [Color("8f5f17"), Color("c9902a"), Color("f0c04a"), Color("fff0a0")],
		"marquee": [Color("4a0d1c"), Color("7a1a2c"), Color("a32a3a")],
		"outl": Color("120806"),
		"bulbs": [Color("ffd23f")], "bulb_n": 14,
		"sign": Color("f0c04a"),
		"peg": "brass",
	},
	{   # 1 · Ön Salon: boyalı turkuaz, kraliyet mavisi keçe, gümüş, renkli ampuller
		"body": [Color("0b3440"), Color("12586c"), Color("1b7f96"), Color("3fb4c8")],
		"felt": [Color("0d2a66"), Color("143f94"), Color("1a52b4"), Color("2a6ad4")],
		"trim": [Color("56607a"), Color("8a96b0"), Color("c8d2e6"), Color("f6faff")],
		"marquee": [Color("6e2406"), Color("b4440c"), Color("e8661a")],
		"outl": Color("061620"),
		"bulbs": [Color("ffd23f"), Color("ff5fa8"), Color("6ee0ff"), Color("6dff9a")], "bulb_n": 30,
		"sign": Color("fff3c8"),
		"peg": "brass",
	},
	{   # 2 · Kırmızı Salon: kırmızı lake, mor kadife, altın
		"body": [Color("3e0612"), Color("700e24"), Color("a01a36"), Color("d03458")],
		"felt": [Color("26103f"), Color("3c1866"), Color("522488"), Color("6c36ac")],
		"trim": [Color("7a4a08"), Color("c08a12"), Color("f2c434"), Color("fff2a6")],
		"marquee": [Color("24040e"), Color("440a1c"), Color("66122e")],
		"outl": Color("16020a"),
		"bulbs": [Color("fff2c0"), Color("ffcf3d")], "bulb_n": 36,
		"sign": Color("ffd23f"),
		"peg": "gold",
	},
	{   # 3 · Gece Salonu: siyah gövde, neon tüpler, lacivert ızgaralı keçe, krom
		"body": [Color("06051a"), Color("0f0c2c"), Color("1a1646"), Color("28225e")],
		"felt": [Color("07123a"), Color("0d1f62"), Color("13307e"), Color("1c40a2")],
		"trim": [Color("38486a"), Color("6a80a8"), Color("aac4ea"), Color("eaf6ff")],
		"marquee": [Color("08061c"), Color("120e34"), Color("1c174c")],
		"outl": Color("02010a"),
		"bulbs": [Color("3ff0ff"), Color("ff4fd8")], "bulb_n": 0,
		"sign": Color("ff6ae0"),
		"peg": "chrome",
	},
	{   # 4 · Büyük Salon: altın gövde, zümrüt keçe, inci çiviler, mücevherler
		"body": [Color("664006"), Color("a66e0c"), Color("dca21c"), Color("ffdb62")],
		"felt": [Color("043a25"), Color("085a38"), Color("0d784c"), Color("159a68")],
		"trim": [Color("8a86a8"), Color("c6c4e0"), Color("eeeefc"), Color("ffffff")],
		"marquee": [Color("26083e"), Color("441270"), Color("641ea0")],
		"outl": Color("1a0e02"),
		"bulbs": [Color("ffffff"), Color("ffe27a")], "bulb_n": 40,
		"sign": Color("fff4c8"),
		"peg": "pearl",
	},
]


static func cabinet(tier: int) -> Dictionary:
	return CABINETS[clampi(tier, 0, CABINETS.size() - 1)]


## Masa malzemesi (üst yüzey, kenar, ayak) ve lamba ışığı
const TABLES := [
	{"top": [Color("7a4022"), Color("a35a30"), Color("c47843"), Color("dc9a5e")], "edge": [Color("4a2412"), Color("68361b"), Color("8a4a26")],
		"leg": [Color("4a2412"), Color("68361b"), Color("8a4a26")], "light": Color(1.0, 0.82, 0.5, 0.028)},
	{"top": [Color("8a5426"), Color("b87a40"), Color("d89a58"), Color("f0bc78")], "edge": [Color("5a3214"), Color("7a4620"), Color("9a5e2c")],
		"leg": [Color("5a3214"), Color("7a4620"), Color("9a5e2c")], "light": Color(1.0, 0.88, 0.6, 0.036),
		"inlay": [Color("0f5a36"), Color("17784a"), Color("21925c")]},
	{"top": [Color("3a0c08"), Color("5a1a10"), Color("7a2a18"), Color("9a4024")], "edge": [Color("2a0604"), Color("44100a"), Color("641c10")],
		"leg": [Color("2a0604"), Color("44100a"), Color("641c10")], "light": Color(1.0, 0.8, 0.4, 0.04),
		"inlay": [Color("0a3e30"), Color("125a46"), Color("1a765c")]},
	{"top": [Color("07051a"), Color("120e2a"), Color("1e1840"), Color("2e2858")], "edge": [Color("04030e"), Color("0c0a20"), Color("16123a")],
		"leg": [Color("5a6a8a"), Color("9aacc8"), Color("dce8ff")], "light": Color(1.0, 0.4, 0.9, 0.03)},
	{"top": [Color("bdb6a6"), Color("dcd6c8"), Color("eeeae0"), Color("fbf9f2")], "edge": [Color("8a5a0c"), Color("c08a14"), Color("f0c43a")],
		"leg": [Color("8a5a0c"), Color("c08a14"), Color("f0c43a")], "light": Color(1.0, 0.95, 0.75, 0.045)},
]


static func table(tier: int) -> Dictionary:
	return TABLES[clampi(tier, 0, TABLES.size() - 1)]
