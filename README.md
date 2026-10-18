# Son Bilye

Borcunu kapatmak için her gün bir Plinko salonuna giden Tekin'in hikâyesi: 2D Plinko + incremental/idle ilerleme oyunu.
Godot 4.7 (GDScript), PC. Ana dil **İngilizce** (oyun adı: *Last Marble*); **Türkçe** ana menüdeki dil düğmesinden
veya Ayarlar'dan seçilebilir. Dil değişince arayüz anında yeniden kurulur, oyun kaldığı yerden sürer.

## Çalıştırma

Godot 4.7 ile `project.godot` dosyasını aç ve oynat (F5). Komut satırından:

```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/demiryilmaz/plinlkX
```

Kayıt: `~/Library/Application Support/Godot/app_userdata/Son Bilye/son_bilye_save.json` (her 15 sn ve çıkışta).

## Kontroller

- Oyun **ana menüden** başlar: Devam Et / Yeni Oyun / Ayarlar / Oyundan Çık.
- **Boşluk** veya **AT** düğmesi: seçili toplu atış miktarı kadar top atar. **Esc**: duraklatma menüsü.
- Sol: kasa ve **ÖDE** (ilk basışta tek seferlik uyarı), Yükseltme / Otomasyon kartları (tıkla = satın al, açıklama fare üstündeyken), Bilye Cilası işi.
- Masa: takvim (gün), zarf (hikâye), Borç Defteri (taksitler), bilye kavanozu (koleksiyon) ve **telefon** tıklanabilir.
  Telefon çalınca (altında arayanın adı yazar) tıkla: iyi karakterler 15 sn **Ateş Modu** hediye eder (hız ×2, hava sınırı yok),
  Sadık Bey taksiti hatırlatır: o gün hiç ödeme yapılmamışsa kasadaki nakde el koyup taksite yatırır; kısmen ödenmişse
  **ŞİMDİ ÖDE** (tutar düğmede yazar, ceza yok) ya da **KAPAT** (ceza zarı). Esc = kapat/reddet.
- Sağ: bilet rozeti, Başarımlar ve Menü, **Top Çarkı** / **Çivi Çarkı** (kasa açma penceresi), bugünkü çiviler + **DİZ**, **GÜNÜ KAPAT**.
- Gün sonu: özet ve istatistikler → **GÜNÜ BİTİR** → Bilet Ağacı (yalnızca burada) → **N. GÜNÜ BAŞLAT**.

Pencere, ekrana sığan en büyük tam sayı ölçekle açılır (Retina'da 2x); tüm piksel sanat ve yazılar keskin kalır.

## Belgeler

- [docs/TASARIM.md](docs/TASARIM.md): tasarım kararları, varsayımlar ve kod yapısı.
- [docs/EKONOMI.md](docs/EKONOMI.md): sabit ekonomi tabloları ve dengeleme simülasyonu (otomatik üretilir).

## Ekonomi modelini yeniden üretmek

```bash
python3 tools/economy_model.py calibrate
```

```bash
python3 tools/economy_model.py export
```

```bash
python3 tools/economy_model.py report
```

Yazı tipindeki "5" rakamının düzeltilmiş hâli (`assets/fonts/PixelifySans-SB.ttf`) özgün dosyadan üretilir:

```bash
python3 tools/patch_font.py
```

Üretilmiş görselleri gerçek piksel ızgarasına indirmek (magenta arka plan şeffaf olur):

```bash
python3 tools/pixelize_art.py assets/art/src/tekin_raw.png assets/art/portrait_tekin.png --key
```

Üretilmiş bir sprite sayfasını tek tek sprite'lara bölmek ("-" o sıradaki öğeyi atlar):

```bash
python3 tools/slice_sheet.py assets/art/src/balls_raw.png assets/art/balls demir,cam,kil,kaucuk,bakir,miknatis,volkan,altin,-,-,-,ikiz,kuyruklu,anka,kara_inci --min 15 --pitch-min 8 --hue-tol 0.035
```

Top yeteneklerinin nadirliğe göre getirisi: `python3 tools/economy_model.py balls`.

`calibrate` günlük tarife ve taksitleri bulur (sonucu `tools/economy_model.py` içine yazılır), `export` oyunun okuduğu
`data/economy.json` dosyasını, `report` ise `docs/EKONOMI.md` belgesini üretir. Oyun çalışırken hiçbir değer dinamik hesaplanmaz.

## Geliştirici argümanları

`--` sonrasına yazılır; gerçek kayda dokunmamak için `--test-save` kullan.

| Argüman | İşlev |
|---|---|
| `--test-save` / `--fresh` | Ayrı test kaydı kullan / onu sil |
| `--skip-menu` / `--menu` | Ana menüyü atla / zorla göster |
| `--open=tree`, `--pause`, `--edit`, `--jackpot-fx` | Pencere, duraklatma, çivi düzenleyici, Jackpot efekti |
| `--skip-story` | Gün başı hikâye penceresini açma |
| `--cash=N`, `--day=N`, `--tickets=N` | Durum ayarla |
| `--buy=ball_level:5,board_level:2` | Mağazadan satın al (kurallara uyar) |
| `--spin=ball:3,peg:5`, `--give-pegs=huni:1`, `--place=3:1:huni`, `--select-ball=kara_inci` | Slot/çivi/top |
| `--pay-all`, `--open-prestige`, `--do-prestige` | Taksit ve gün kapanışı |
| `--demo`, `--autoplay`, `--timescale=N` | Otomatik atış / hata ayıklama oyuncusu / hızlandırma |
| `--verify-probs` | Her tahta seviyesinde kesin olasılık ile 200.000 atışlık Monte Carlo karşılaştırması; ayrıca animasyonun gerçek iniş noktalarından okunan sonuçların tahtada yazan olasılıklarla karşılaştırması |
| `--wheel=ball`, `--ui-spin=ball+peg` | Çark penceresini aç / açıp çevir |
| `--tree-phase`, `--open-prestige` | Günü kapatıp Bilet Ağacı aşamasına geç / gün sonu ekranını aç |
| `--win=1440x810`, `--crop=x,y,w,h` | Pencere boyutu / ekran görüntüsünden 2x yakın plan |
| `--lang=tr`, `--toggle-lang` | Dili zorla / açılıştan kısa süre sonra dili değiştir (yeniden kurulum testi) |
| `--sprite-sheet=yol.png` | Tüm top/çivi sprite karelerini inceleme sayfalarına dök |
| `--measure`, `--print` | Atış başı net sonucu / durumu çıkışta yazdır |
| `--seconds=N --screenshot=yol.png` | N oyun saniyesi sonra ekran görüntüsü alıp çık |
| `--give-balls=N`, `--wheel-call=SN:_on_sell` | Tüm topları N ustalık yıldızıyla ver (kopya testi) / SN saniye sonra çark penceresinde yöntem çağır |
| `--phone=good` / `--phone=threat`, `--answer` | Telefonu yarım saniye içinde çaldır / çalınca arama penceresini aç |
| `--call-act=pay\|hang\|boost`, `--boost` | Açık arama penceresinde 2 sn sonra düğmeye bas / Ateş Modunu hemen başlat |
