# Son Bilye — Tasarım Belgesi

2D Plinko + incremental/idle ilerleme oyunu. Motor: **Godot 4.7 (GDScript)**, hedef: PC. Arayüz dili Türkçe; tüm metinler
`data/lang/tr.json` içinde anahtar–metin olarak tutulur (yeni dil = aynı anahtarlarla yeni JSON).
Oyun içi para tamamen kurgusaldır; gerçek para, bahis veya çevrimiçi sistem yoktur.

Sayısal tabloların tamamı **[EKONOMI.md](EKONOMI.md)** içindedir (modelden otomatik üretilir).

---

## 1. Varsayımlar ve küçük kararlar

Prompt'ta açık bırakılan ayrıntılar için verilen kararlar:

| # | Konu | Karar |
|---|---|---|
| 1 | Motor | Proje boştu → Godot 4 (kurulu sürüm 4.7.2). Sahne yapısı kodla kurulur; tek sahne `scenes/main.tscn`. |
| 2 | **X'in tanımı** | X = masa bahsi = atış ücreti = **10$** (hikâye boyunca sabit). Etiketler X cinsinden **net** sonuçtur: `+1,2X` = ücret geri + 1,2X kâr; `-0,5X` = ücretin yarısı geri gelir. |
| 3 | Top seviyesi ve kayıp/ücret | Top seviyesi **yalnızca pozitif ödemeyi** çarpar. Atış ücretini ve kayıp miktarını değiştirmez. |
| 4 | Sonuç modeli | Top her çivide sola/sağa gider (ayrık Galton adımı), son sırada bir kovaya iner ve kova içinde düzgün dağılımlı bir noktaya düşer. Ekonomik sonuç, **animasyonda topun indiği noktadaki banttır**. Aynı model olasılıkları kesin (dinamik programlama) hesaplar → gösterilen olasılık = gerçek olasılık. |
| 5 | Yol ne zaman belirlenir | Atış anında rastgele üretilir, animasyon bu yolu izler. Bant ise **iniş anındaki** tahta seviyesine göre okunur (havadayken tahta yükseltilirse ekranda görülen bant geçerlidir). |
| 6 | Maksimum kazanç | Topun **★MAX** (merkez) bandına inmesi. Tahtada dar orta bant ★ ile işaretli. |
| 7 | Jackpot serisi | Topların **iniş sırasına** göre sayılır; otomatik atışlar ve bonus toplar dahildir. MAX olmayan her iniş seriyi sıfırlar; Jackpot tetiklenince seri sıfırlanır. |
| 8 | Bonus toplar | Bölünme (Ayna Çivi, İkiz Bilye) ve yeniden doğuş (Anka) topları ücretsizdir, **yalnızca kazanç öder** (kayıpta ceza yok), zincirleme bölünmez, hava sınırına sayılmaz. İkram atışlar da aynı kurala tabidir. |
| 9 | Çark fiyatları | Her iki çarkta da fiyat açtıkça geometrik artar ve **gün kapanınca sıfırlanır**. |
| 10 | Kopya top | Sonuç **"ZATEN SENDE"** diye yazılır, karta "SENDE VAR" damgası basılır ve oyuncu SAT düğmesine yönlendirilir (yanıp sönen çerçeve + ok). Satmazsa kopya Ustalık yıldızı olarak kalır (+1, en fazla 3; topun **kendi** özelliğini güçlendirir). Yıldızlar doluysa yalnızca satılabilir; satılmadan yeniden açılır ya da pencere kapanırsa otomatik satılır. |
| 11 | Kopya çivi | Aynı çividen +1 adet (yığın sınırı 4/3/2/1). Sınırdaysa ücretin %50'si iade. |
| 12 | Çivi yerleşimi | 4.–12. sıralar, topun çarpabildiği konumlar; konum başına 1 çivi; tahtada en fazla "Çivi Yuvası" kadar özel çivi; bir türden sahip olunan kadar. Yalnızca **Düzenleme Modu**nda değiştirilebilir; mod açılırken havadaki toplar inene kadar beklenir ve atış kapanır. |
| 13 | Günlük tarife | Nakit mağazası ve çark fiyatları gün başına sabit bir katsayıyla çarpılır (1. gün = 1). Katsayı, normal oyuncunun gün tavanlarına günün ~%40'ında ulaşacağı şekilde kalibre edildi. |
| 14 | Taksit ödemesi | "Öde %25/%50" bakiyenin o kadarını, "Tümünü Öde" kalan taksiti öder; atışa devam edilebilsin diye **rezerv kadar nakit elde kalır**. Günlük hedefin üzerinde ödeme yapılamaz. |
| 15 | Final | Son taksit ödendiği an final sahnesi gösterilir; 10. gün kapatıldığında Serbest Mod başlar. |
| 16 | Kayıt | JSON, sürüm numaralı (`version`), 15 sn'de bir ve çıkışta. Havadaki ücretli topların ücreti kayda **iade edilmiş** yazılır (kapanışta kazanç/kayıp oluşmaz). Çevrimdışı ilerleme yok; zaman damgası yalnızca bilgi amaçlıdır. |
| 17 | Ses | Harici dosya yok; efektler ve kısa caz döngüsü çalışma anında sentezlenir. Efekt ve müzik ayrı ses yolu ve ayrı ayardır. |
| 18 | İkonlar | Emoji/görsel dosyası yok; tüm ikonlar vektör olarak çizilir. Nadirlik **şekil + etiket + renk** ile gösterilir (● Sıradan, ◆ Ender, ★ Destansı, taç Efsanevi). |
| 19 | Otomatik atıcı rezervi | Varsayılan 2X (20$); oyuncu 2X–500.000X arası seçebilir. Rezerv altına düşünce bekler veya (seçenekle) kendini kapatır. |
| 20 | Büyük sayılar | Türkçe biçim: `12.345$`, `1,25 Mn$`, `3,4 Mr$`, `Tn`, `Kt`, `Kn`, sonra bilimsel gösterim. |
| 21 | Ağaçtan alınan başlangıç bonusları | Satın alındığı an **bugünkü sefere de** uygulanır (atıcı kurulur, Top/Tahta seviyesi yeni tabana çıkar, ilk atıştan önceyse başlangıç nakdi farkı eklenir). Gün kapanışında biletler verildikten sonra alınan bir düğüm oyuncuyu bir gün bekletmez. |

## 2. Ana döngü (bir hikâye günü = bir sefer)

1. Gün başında hikâye notu (kısa, bir pencere). Başlangıç nakdi, Top/Tahta seviyesi ve otomasyon bilet ağacından gelir.
2. Günlük taksit, sefer bakiyesi ve toplam kalan borç sol sütunda **ayrı sayaçlarda** görünür.
3. Oyuncu top atar (tek/toplu), nakitle yükseltme alır, Top/Çivi Çarkı açar, çivileri yerleştirir, otomatik atıcıyı açar.
4. Taksit dolunca gösterge yeşil ve dolu kalır; ek kazanç taksiti artırmaz. **Günü Kapat ve Prestij Yap** açılır.
5. Oyuncu ister hemen kapatır, ister prestij bileti (sefer kârı) ve MAX/kart biletleri için devam eder.
6. **Gün sonu akışı:** GÜNÜ KAPAT → gece geçişi (perde iner, ay ve "N. GÜN BİTTİ") → gün sonu ekranı: bugünün sayıları
   (ikonlu karolar), kazanılacak biletler (kısa çipler, formül araç ipucunda), sıfırlanan/kalan (ikon çipleri), yarının taksit ve
   tavanları; İstatistik düğmesi tüm istatistikleri gösterir. "Masaya Dön" günü sürdürür, "GÜNÜ BİTİR" kapatır.
7. Gün bitince **Bilet Ağacı** otomatik açılır; oyuncu biletlerini harcar ve "N. GÜNÜ BAŞLAT"a basar → gün doğumu geçişi
   (takvim yaprağı) → masa ve günün hikâye notu. Ağaç gün içinde açılamaz. Oyun bu aşamada kapatılırsa açılışta ağaçtan devam
   edilir (`meta.tree_pending`). Gün sonu boyunca oyun duraklar (hiçbir şey ilerlemez).

## 3. Seviyeler — iki bağımsız etki

- **Top Seviyesi:** pozitif ödeme çarpanı = 1,12^(sv−1). Olasılığı, bant genişliğini, ücreti ve kaybı değiştirmez.
- **Tahta Seviyesi:** yalnızca bant genişlikleri. Kazandıran bantlar (★MAX, Kazanç) genişler, Kayıp ve Kenar daralır; çarpan etiketleri her seviyede aynıdır. 16 seviyenin her birinde kazanma olasılığının **kesin olarak arttığı** hem modelde hem oyunda (`--verify-probs`, 200.000 atışlık Monte Carlo) doğrulandı.
- Her iki seviye de gün kapanınca sıfırlanır; bilet ağacı başlangıç seviyesini yükseltebilir (gün tavanını aşmadan).
- **Gün tavanı:** Top 12 + 3×(gün−1), Tahta 3 + (gün−1). Aynı ilke (sabit günlük adım). Tavana ulaşınca para kazanmaya ve diğer harcamalara devam edilebilir. Seviyeler top/çivi türü açmaz.

## 4. Top koleksiyonu ve Top Çarkı

12 tür (1 başlangıç + 4 Sıradan + 3 Ender + 2 Destansı + 2 Efsanevi). Toplar yalnızca görünüm değildir: her türün Top Seviyesinden
ayrı **yetenekleri** vardır ve yetenek sayısı/gücü nadirlikle artar — Sıradan 1, Ender 2, Destansı ve Efsanevi 3 yetenek.
Yetenekler: tüm kazanç çarpanı, yalnızca Kazanç veya yalnızca ★MAX çarpanı, kayıp azaltma, merkeze çekim (olasılığı değiştirir,
tahtadaki yüzdelere yansır), İkiz top (ilk çivide bölünme), Yeniden doğuş (kayıpta ücretsiz tekrar).

| Top | Nadirlik | Yetenekler | Güç (Sv8 tahta, Demir'e göre) |
|---|---|---|---|
| Demir | Sıradan (başlangıç) | kayıp ×0,92 | — |
| Cam | Sıradan | Kazanç ×1,25 | +%19 |
| Kil | Sıradan | merkeze çekim %53,5 | +%13 |
| Kauçuk | Sıradan | ★MAX ×1,5 | +%16 |
| Bakır | Sıradan | tüm kazanç ×1,10 | +%10 |
| Mıknatıs | Ender | çekim %55, tüm kazanç ×1,12 | +%35 |
| Volkan | Ender | ★MAX ×1,8, tüm kazanç ×1,06 | +%36 |
| Altın | Ender | tüm kazanç ×1,18, ★MAX ×1,2 | +%28 |
| İkiz | Destansı | İkiz %25, tüm kazanç ×1,08, Kazanç ×1,08 | +%48 |
| Kuyruklu Yıldız | Destansı | çekim %55,5, ★MAX ×1,7, Kazanç ×1,12 | +%64 |
| Anka | Efsanevi | Yeniden doğuş %40, tüm kazanç ×1,35, kayıp ×0,85 | +%61 |
| Kara İnci | Efsanevi | çekim %56, tüm kazanç ×1,32, ★MAX ×1,3 | +%85 |

Ustalık yıldızları bir yeteneği güçlendirir. Yetenekler renkli çiplerle (koleksiyon kartı, çark sonucu, atış çubuğu ipucu) ve
nadirlik renginde **Güç +%** değeriyle gösterilir (güncel tahta seviyesinde atış başı beklenen getirinin Demir'e oranı).
Tahtada yetenek bir sonucu değiştirdiğinde tutarın yanında küçük "×1,25" etiketi, İkiz/Yeniden doğuşta "İKİZ!" / "YENİDEN DOĞUŞ!"
yazısı çıkar. Her topun animasyonlu, özgün piksel tasarımı vardır (Volkan alev saçar, Mıknatıs çevresine dalga yayar, İkiz'in
iki uydusu döner, Kuyruklu ışıltılı kuyruk bırakır, Anka ateş kanat çırpar, Kara İnci mor aura yayar).
Koleksiyon kalıcıdır, istenen an değiştirilir. Her tür için **ilk ★MAX bonusu** kalıcı kayıtta işaretlenir.

**Çarklar (kasa açma):** sağ sütunda iki küçük düğme (Top Çarkı, Çivi Çarkı). Tıklayınca pencere açılır; AÇ'a basınca sonuç o anda
sabit oranlarla belirlenir, ardından olası öğeler yatay şeritte akar, yavaşlar ve sonucun üstünde durur (şeride tıklamak atlar).
Şerit yalnızca gösterimdir. Pencere dönerken kapatılırsa sonuç bildirim olarak gösterilir; sonuç kaybolmaz.
Çıkan ödül istenmiyorsa **SAT** düğmesiyle nakde çevrilir (düğme ödülün nadirlik renginde, fiyat üstünde): fiyat = o açılışın
ücreti × Sıradan 0,35 / Ender 0,7 / Destansı 1,4 / Efsanevi 3. Satılan yeni top koleksiyondan çıkar, kopyanın verdiği yıldız geri
alınır, satılan çivi envanterden düşer. Zaten sahip olunan top gelirse başlık turuncu "ZATEN SENDE: …" olur, şeritteki karta
"SENDE VAR" damgası basılır, Kullan düğmesi gizlenir ve SAT düğmesi nabız gibi atan çerçeve ve zıplayan okla vurgulanır; satınca
damga "SATILDI" olur. Yıldızları dolu kopya otomatik satılır (değeri kaybolmaz). Yığın sınırındaki çivi otomatik iade edilir, satılamaz.
Beklenen satış değeri her zaman ücretin altında kaldığı için aç-sat döngüsü kâr getirmez (EKONOMI.md §6).

## 5. Çiviler ve Çivi Çarkı

10 tür, günlük envanter. Etkiler: +% kazanç (toplanır), ×kazanç (çarpılır), merkeze yönlendirme, kayıp kalkanı, topu ikiye bölme,
MAX'e ek ödeme ve **Bilet Çivisi** (çarpma başına %0,05 ile 1 bilet, günde en fazla 5; otomatik atışlarda da çalışır). Çiviler
çarpmada tükenmez. Her çivinin animasyonlu piksel tasarımı etkisini anlatır (dönen girdap huni, yaylanan yay, nabız atan kalkan,
dönen yıldız, parıldayan elmas, sallanan bilet...). Özel çivinin geçtiği top altın halkayla işaretlenir; çarpılan çivi kısa süre
parlar. Bugünkü çiviler sağ sütunda ikon ızgarasında görünür; DİZ düzenleyiciyi açar (öğretici kısa yazı yalnızca orada).

**Tahta:** 8 çivi sırası, 9 kova (önceki 12 sıra yerine: daha az ama iri, okunaklı çivi ve daha büyük tahta). Bant genişlikleri,
12 sıralı tasarımın her seviyedeki olasılıklarını birebir koruyacak şekilde yeniden çözüldü. Özel çiviler 3. sıradan itibaren konur.

## 6. Atış, ücret, hava sınırı

- Tek tık 1/3/5/10/20 top (açılan boylar); toplar 0,07 sn arayla sıraya girer, ücret **topun çıktığı anda** düşülür.
- Bakiye yetmezse yalnızca karşılanabilen kadar atılır ve neden bildirilir; eksi bakiye oluşmaz.
- **Hava sınırı** (Fırlatma Rampası) aynı anda havadaki ücretli top sayısını sınırlar; asıl verim kısıtı budur.
- Ödül hesabı tek merkezde: `scripts/systems/economy.gd` → `resolve()`.
- **ÖDE** ilk kez basıldığında tek seferlik uyarı çıkar: kasadaki paranın neredeyse tamamı (taksit dolana kadar, otomatik atıcı
  rezervi hariç) yatırılır ve geri alınamaz.

## 6.1 Telefon: Ateş Modu ve Sadık Bey

Masada, zarfın altında eski kırmızı bir telefon durur (Higgsfield ile çizildi, `tools/slice_sheet.py` ile piksel ızgarasına
indirildi). İki zamanlayıcıyla çalar; zamanlayıcılar **yalnızca oyuncu masadayken** sayar (oyun duraklatılmamış, pencere veya
çivi düzenleyici açık değil, oyun penceresi odakta). Başka pencereye geçilince çalan telefon da bekler; oyun kapalıyken hiçbir şey
ilerlemez. Çalarken telefon titrer, zil çalar, üstünde **ZIRR ZIRR / RING RING**, altında arayanın adı yazar (iyi arama altın,
Sadık Bey kırmızı ışık). 9 sn içinde tıklanırsa arama penceresi (portre + konuşma) açılır ve oyun durur.

- **İyi arama (Nevin Abla %65, Gece Bekçisi %35):** ilki ~1-2 dk sonra, sonra her 3,5-5 dk. **ATEŞLE!** → 15 sn **Ateş Modu**:
  ekranın dört kenarında piksel alevler, tabelanın üstünde geri sayımlı şerit, müzik hızlanır; oyun hızı ×2 (düşüş, atış sırası,
  otomatik atıcı), hava sınırı kalkar (atış çubuğunda `∞`). Olasılıklar ve ödemeler değişmez; yalnızca daha çok top atılır.
  Açılmayan arama kaçar ("Cevapsız arama").
- **Sadık Bey'in tehdidi:** yalnızca bugünkü taksit tamamlanmamışken (Serbest Modda hiç aramaz); ilki ~4-5,5 dk sonra, sonra
  her 4,5-7 dk. Tavrı arandığı andaki duruma göredir:
  - **Kasa boş (bugün taksite hiç ödeme yapılmamış):** "Kasa hâlâ boş" der, cebe 10X (oynamaya devam etmeye yetecek kadar) bırakıp
    kalan nakde el koyar ve **bugünkü taksite yatırır**. Para kaybolmaz, borçtan düşer; ama yükseltmelere gidemediği için gün uzar.
    Pencerede ne kadarın taksite gittiği ve taksitin yüzdesi açıkça yazar. Gün içinde biraz erken ödeme yapan oyuncu bundan kaçar.
  - **Kısmen ödenmiş:** ceza riski. Ceza ihtimali = **%60 × taksitin ödenmemiş oranı**, ceza = **kasadaki nakdin %15'i**
    (pencerede önceden yazar). **ŞİMDİ ÖDE · tutar** düğmesi rezervin üstündeki nakdi taksite yatırır; Sadık Bey memnun kalır ve
    **ceza kesmez** (yalnızca rezerv çok yüksek tutulup yatırılan, kesilecek cezadan bile azsa zar yine atılır). Sonuçta yatırılan
    tutar ve taksit yüzdesi yazar. **KAPAT** ceza zarını atar.
  - Açılmayan arama sesli mesaj bırakır: kasa boşsa tahsilat, değilse ceza zarı yine uygulanır.
- **Ceza tasarımının gerekçesi:** (1) borç temasını oynanışa bağlar, erken ödemeyi ödüllendirir; (2) gerçek bir karar yaratır:
  parayı yükseltmeye mi yatırmalı, taksite mi kilitlemeli; (3) kalıcı ilerlemeye dokunmaz: seviye, top, çivi, bilet asla alınmaz;
  (4) ödeme yapan oyuncu cezalandırılmaz; (5) kayıplar küçüktür: tahsilat parayı yok etmez, ceza en çok nakdin %9'u (beklenen) ve
  taksit doldukça sıfıra iner.
- Telefon olayları ekonomi modeline beklenen değer olarak eklendi; günlük tarifeler ve taksitler bunlar dahil yeniden kalibre
  edildi (EKONOMI.md §12.1). Kod: `scripts/systems/phone_calls.gd`.

## 7. Biletler, Jackpot, başarımlar

Kaynaklar ve sürdürülebilirlik önlemleri EKONOMI.md §9'da. Özet: MAX → Şans Kartı deliği (kart günde büyür),
topa özel ilk MAX bonusu, Bilet Çivisi (günlük tavanlı), prestij (karekök formül), günün ilk Jackpot'u, tek seferlik başarımlar.
**Jackpot:** 4 ardışık MAX → MAX ödemesinin 25 katı nakit, 3 delik, günün ilk Jackpot'unda +2 bilet; güçlü ama kısa görsel/işitsel
geri bildirim. Jackpot sonuçları değiştirmez, olasılıkları gizlemez.

## 8. Ücretsiz geri dönüş: Bilye Cilası

Tek tık, 4 sn ilerleme çubuğu, +10$ (ağaçla artar). Otomatikleşmez; yalnızca oyun açıkken. Gün başındaki en kötü atış
veriminden bile düşüktür (EKONOMI.md §12), ama her zaman çalışır → para bitse de ilerleme kilitlenmez.

## 9. Sefer içi nakit mağazası ve otomasyon

Top Seviyesi, Çoklu Atış, Fırlatma Rampası, Parlak Cila (top seviyesinden ayrı ödeme çarpanı), Tahta Seviyesi, Çivi Yuvası,
Otomatik Atıcı, Atıcı Hızı, Atıcı Şarjörü. Gün kilitli satırlar görünür kalır ve "Gün kilidi: N. günde açılır" ya da
"Bugünün tavanı X, yarın Y" yazar; bunlar bilet ağacından açılmaz. Otomatik atıcı: başlat/durdur, durum göstergesi
(çalışıyor / rezerv koruması / hava sınırı / düzenleme modu), aralık ve top sayısı, rezerv seçimi, "rezerve düşünce kapat".

## 10. Kalıcı bilet ağacı

7 dal, 20 düğüm, toplam 765 bilet: Başlangıç Kaynakları, Top, Tahta ve Çiviler, Otomasyon, Koleksiyon ve Çarklar,
Bilet Ekonomisi, Yaşam Kalitesi (Toplu Alım, Defter/istatistik, Kalıp Defteri, Taksit Otomatiği). **Yalnızca gün sonunda**
açılır (bkz. §2); nakit mağazasından görsel ve işlevsel olarak ayrıdır. Ağaç başlangıç değerlerini değiştirir; Top/Tahta
seviyelerinin görev ayrımını bozmaz.

## 11. Hikâye

Tekin, dedesinin batan bilye fabrikasından kalan borcu **10 günde, 10 taksitte** Sadık Bey'e ödemeye çalışır; her gün
Bilye Sarayı'nın arka odasındaki "Kader Tahtası"na gelir. Nevin Abla (salon sahibi) ve kısa alacaklı notları; mizahi,
hafif gergin, aşağılamayan ton. Gün başına tek kısa pencere; atışlar diyalogla bölünmez. Final: senet ikiye yırtılır.

**Karakter portreleri:** Tekin, Nevin Abla, Sadık Bey ve gece bekçisi için piksel sanat portreleri hikâye pencerelerinde
(günün öne çıkan karakteri) ve gün kapanış geçişinde (Sadık Bey) gösterilir. Portreler ve oyun ikonu Higgsfield (Nano Banana 2)
ile üretildi; aynı tarz için Tekin portresi referans verildi. Kaynak görseller `assets/art/src/` altında (Godot içe aktarmaz),
`tools/pixelize_art.py` ile gerçek piksel ızgarasına (99×99) indirgendi ve magenta arka plan şeffaf yapıldı; oyunda tam 2 katla
çizilir.

**Top ve çivi çizimleri:** 12 topun hepsi (Nano Banana 2, mevcut yordamsal tasarımlarımız referans verilerek tek sayfada) ve
7 özel çivi (yay, kalkan, ayna, huni, yıldız, bilet, elmas; Z Image ile tek sayfada) çizimden gelir; bakır, gümüş ve altın düz
çiviler yordamsal kaldı. `tools/slice_sheet.py` sayfayı piksel ızgarasına indirip arka planı flood-fill ile siler ve sprite'lara
böler (`assets/art/balls|pegs/<id>.png`, top 24×24). `sprite_gen.gd` gövdeyi bu görselden alır (tahta boyu için alan ortalamasıyla
küçültülüp kenarı koyulaştırılır), üstüne her karede geçen parlama şeridi ve yordamsal hareketli efektleri ekler: Volkan alevleri,
Mıknatıs dalgaları, Kuyruklu ışıltıları, Anka kıvılcımları, Kara İnci aurası, çivi parıltıları/halkaları; çizimde zaten olan
öğeler (İkiz uyduları, Anka kanatları, Kuyruklu kuyruğu) tekrar çizilmez. Görsel yoksa tamamen yordamsal tasarıma döner.

## 12. Serbest Mod

Son kapanıştan sonra: taksit ve gün tavanı yok (Tahta en fazla 16), istenen an prestij. Prestij bileti sefer kârına göre
(karekök, tavanlı; anında prestij 0 bilet verir → istismar yok). Koleksiyon, ağaç, başarımlar korunur. 4 ek uzun vadeli başarım.

## 13. Arayüz ve erişilebilirlik

İlke: **az metin, merkezde büyük tahta, canlı renkler, keskin piksel sanat.** Açıklamalar araç ipuçlarındadır.

- **Keskin görüntü:** arayüz 1280x720 tabanından yalnızca **tam sayı katlarla** büyütülür (pencereye sığan en büyük kat; Retina'da
  genellikle 2), kalan alan düzene eklenir. Sahne yarım çözünürlükte çizilip tam 2 katla büyütülür. Piksel yazı tipi (Pixelify
  Sans) 11'lik piksel ızgarasında çizildiği için yazı boyutları 11/22/33/44'e oturtulur ve kenar yumuşatmasız çizilir: her harf
  pikseli eşit ve net. Yarım çözünürlükteki sahnenin yazıları (bant oranları, sonuç tutarları, tabela, takvim, Jackpot) ayrı,
  tam çözünürlüklü bir yazı katmanında çizilir. Yazı tipindeki "5" küçük boyutta "S" ile karıştığı için yeniden çizildi
  (`tools/patch_font.py`, OFL izinli değişiklik).
- **Odalar (ilerleme hissi):** Tekin kazandıkça Bilye Sarayı'nda daha gösterişli odalara geçer; oda, masa, masa süsleri ve
  Kader Tahtası birlikte değişir (`scripts/stage/themes.gd`, `room_painter.gd`):

  | Gün | Oda | Oda | Tahta |
  |---|---|---|---|
  | 1 | Arka Oda | kirli tuğla, paslı boru, çıplak ampuller, beton; kaba kalas masa | ceviz gövde, yeşil keçe, pirinç çivi, az ampul |
  | 2–4 | Ön Salon | turkuaz çizgili duvar kâğıdı, afişler, renkli ampul dizisi, dama zemin; yeşil keçeli masa, kaktüs, radyo | turkuaz gövde, çizgili mavi keçe, gümüş ray yıldızları, rengârenk ampuller |
  | 5–7 | Kırmızı Salon | kadife duvar, altın korniş, perdeler, şamdanlar, halı; zümrüt örtülü maun masa, altın saçak, şamdan, güller | kırmızı lake, mor kadife baklava desen, altın çivi, kayan ışıklı tabela, süslü köşeler |
  | 8–9 | Gece Salonu | gece şehri pencereleri, neon tüpler, parlak zemin; neon çerçeveli siyah lake masa, lav lambası, neon zarlar | siyah gövde, neon tüp çerçeve, parlayan ızgaralı keçe, krom çivi, kayan gökkuşağı LED |
  | 10 ve Serbest Mod | Büyük Salon | mermer sütunlar, avizeler, altın kurdeleler, mermer zemin + kırmızı halı; altın kakmalı mermer masa, kupa, altın para yığını | altın gövde ve mücevherler, zümrüt keçe altın kakma, inci çiviler, taçlı tabela, parıltılar |

  Yeni odaya geçilen günün gün doğumu geçişinde "YENİ ODA: …" yazar; hikâye notları da taşınmayı anlatır.
- **Ana menü:** Devam Et / Yeni Oyun / Ayarlar / Oyundan Çık; arkada güncel oda ve masa. Menü açıkken oyun durur.
- **Duraklatma (Esc veya ⚙):** Devam / Ayarlar / Ana Menü / Oyundan Çık.
- **Sol (250 px):** kasa kartı (büyük nakit, taksit çubuğu, ÖDE, kalan borç), Yükseltme / Otomasyon sekmeleri ve kompakt resimli
  kartlar (ikon, kısa ad, büyük fiyat, seviye çubuğu).
- **Orta:** masa ve üzerinde Kader Tahtası dolabı (masadan duvara yükselir); masa nesneleri tıklanabilir: takvim (günün bilgisi),
  zarf (hikâye), Borç Defteri (10 günün taksitleri), bilye kavanozu (koleksiyon). Bantlarda yalnızca net sonuç yazar
  (ör. "-0,5X"; yüzde ve lejant yok, dar bantlarda küçük yazı, MAX bandında ★). Olasılıklar tahta seviyesi kartının ipucunda. Altta seçili top, AT, toplu atış, OTO.
- **Sağ (196 px):** küçük bilet rozeti + Başarımlar ve Menü düğmeleri, ince MAX serisi/Şans Kartı şeridi, alt alta iki çark
  düğmesi, bugünkü çiviler + DİZ, bildirimler ve GÜNÜ KAPAT. Koleksiyon/hikâye/istatistik düğmeleri kaldırıldı (kavanoz, zarf ve
  gün sonu ekranından erişilir).
- **Efektler ve geçişler:** Jackpot kutlaması; MAX kıvılcımı; gün kapanışında basamaklı gece perdesi ve ay, yeni günde gün doğumu
  ve takvim yaprağı.
- **Diller:** ana dil İngilizce (`data/lang/en.json`), Türkçe (`tr.json`) seçilebilir; iki dosya aynı 641 anahtarı içerir.
  Oyuncu dili kendisi seçmediyse oyun İngilizce açılır (`settings.lang_chosen`). Sayılar dile göre biçimlenir
  (`$12,345` / `12.345$`, `45.8%` / `%45,8`, `1.25M` / `1,25 Mn`). Dil değişince ana arayüz sahnesi yeniden kurulur.
- **Erişilebilirlik:** nadirlik şekil + etiket + renk; azaltılmış hareket (geçişler ve parçacıklar kısalır); ayrı ses ayarları;
  tam ekran; ısı haritası; dil seçimi.

## 14. Kod yapısı

| Sorumluluk | Dosya |
|---|---|
| Top hareketi ve geometri | `scripts/board/ball_flight.gd`, `scripts/board/board_geometry.gd` |
| Tahta çizimi ve etkileşim | `scripts/board/board_view.gd` |
| Sonuç aralıkları ve olasılık | `scripts/systems/outcome_model.gd` |
| Ekonomi ve ödül (merkezi) | `scripts/systems/economy.gd` |
| Top envanteri, Top Çarkı, top gücü | `scripts/systems/ball_collection.gd` |
| Çivi envanteri, Çivi Çarkı, yerleştirme | `scripts/systems/peg_system.gd` |
| Sefer içi yükseltmeler, gün kilitleri | `scripts/systems/run_shop.gd` |
| Otomatik atıcı | `scripts/systems/auto_launcher.gd` |
| Günlük taksit ve toplam borç | `scripts/systems/debt.gd` |
| Telefon aramaları, Ateş Modu, ceza | `scripts/systems/phone_calls.gd` (masadaki telefon `stage.gd`, alev çerçevesi `fx_layer.gd`, arama penceresi `main_ui.gd`) |
| Prestij ve biletler | `scripts/systems/prestige.gd`, `scripts/autoload/game.gd` (MAX/kart/Jackpot) |
| Kalıcı ağaç | `scripts/systems/meta_tree.gd` |
| Başarımlar | `scripts/systems/achievements.gd` |
| Hikâye ve gün ilerlemesi | `scripts/systems/story.gd` + `data/lang/tr.json` |
| Kayıt | `scripts/systems/save_system.gd` |
| Ana menü, duraklatma, ayarlar | `scripts/ui/main_menu.gd`, `scripts/ui/main_ui.gd` |
| Arayüz parçaları | `scripts/ui/panels/*` (kasa, kenar çubukları, atış çubuğu, pencereler), `scripts/ui/widgets/*` (kart, çark düğmesi, kasa açma penceresi, yetenek çipleri) |
| Gün sonu ve geçişler | `scripts/ui/day_end.gd`, `scripts/ui/transition.gd` |
| Piksel sahne, yazı katmanı | `scripts/stage/stage.gd`, `scripts/ui/text_layer.gd` |
| Animasyonlu top/çivi sprite'ları | `scripts/art/sprite_gen.gd` (yordamsal, iş parçacığında üretilir), `scripts/autoload/pixel_art.gd` |
| Efektler ve ses | `scripts/ui/fx_layer.gd`, `scripts/autoload/sfx.gd` |
| Geliştirici araçları | `scripts/ui/debug_tools.gd` (yalnızca komut satırı argümanlarıyla) |
| Merkezi durum, atış/iniş döngüsü | `scripts/autoload/game.gd` |
| Veri | `data/economy.json` (modelden üretilir), `data/lang/tr.json` |
| Tasarım zamanı ekonomi modeli | `tools/economy_model.py` |

## 15. Kayıt içeriği

`meta`: biletler, ağaç seviyeleri, top koleksiyonu + ustalık, topa özel ilk MAX bayrakları, seçili top, başarımlar, gün,
ödenen borç, Serbest Mod/final durumu, Şans Kartı delikleri, çivi kalıbı, otomasyon ayarları (rezerv, kapanma, taksit otomatiği),
görülen hikâyeler, istatistikler. `run`: nakit, seviyeler, yükseltmeler, günlük taksit, kâr, çark sayaçları, çivi envanteri ve
yerleşimi, ikram atışlar, seri, kart/jackpot/bilet çivisi günlük sayaçları, otomatik atıcı açık/kapalı, telefon zamanlayıcıları. Ayarlar ayrı dosyada.
Eksik anahtarlar yüklemede varsayılanlarla tamamlanır; sürüm göçleri `_migrate()` içinde (v2: 12→8 sıra geçişinde eski çivi
yerleşimi ve şablonlar temizlenir, çiviler envanterde kalır). `meta.tree_pending`: gün kapandı, ağaç aşaması sürüyor.

## 16. Doğrulama

- **Olasılık:** `--verify-probs` → 16 tahta seviyesinin hepsinde kesin olasılık ile gerçek yol üretimi (200.000 atış) ±%0,3 içinde;
  kazanma olasılığı her seviyede artıyor (%34,2 → %91,3). Ayrıca oyunun kendi top uçuşu üretilip **animasyonun son karesindeki
  iniş noktasından** sonuç okundu: tahtada yazan ile birebir (ör. Sv.3: yazan W %35,8 / animasyon %36,0; çekimli top %41,8 / %41,8;
  iki özel çiviyle Sv.5: %49,2 / %48,9). Toplar yazan olasılıklara göre iner; her çivide sağ/sol kararı bu olasılıklarla verilir
  ve top o yöne belirgin bir sekmeyle gider.
- **8 sıraya geçiş:** bant sınırları, 12 sıralı tasarımın tür olasılıklarını koruyacak şekilde ikili aramayla çözüldü; ödeme
  ölçümü (`--measure`): Demir Sv.1 tahta 0,257X/atış (model 0,250X), Volkan 0,422X (model 0,449X, örnek varyansı içinde).
- **Ödeme hesabı (12 sıralı ilk sürümde):** `--measure` ile oyunda ölçülen atış başı net sonuç, Python modeliyle karşılaştırıldı: çivisiz durumda 1,681X (model 1,628X + Jackpot ≈ 0,015X); Kara İnci + 5 özel çivi durumunda 17,58X (model 17,23X, Jackpot hariç). Fark Jackpot varyansı ve bonus topların sayımı içinde.
- **Uçtan uca tempo:** Python modelindeki normal oyuncunun kararları (`tools/economy_model.py replay`) gerçek oyun kodunda `--replay` ile hızlandırılmış zamanda oynatıldı (8 sıra, telefon olayları dahil yeniden kalibre edilmiş tarife ve taksitler; bot iyi aramaların %85'ini açar, Sadık Bey'i ödemeden kapatır): 10 gün toplam **142,7 dk** (model 141,4 dk; fark %1). Oturumda 26 Ateş Modu açıldı, Sadık Bey 20 kez aradı ve 7'sinde ceza kesti. Günlük sapma −%20…+%40 (1. gün oyunda sistematik olarak 2-3 dk uzun; diğerleri çark şansı). Modelde normal oyuncu 2,36 sa saf oyun → gerçekte okuma/karar ile ~2,7-2,8 sa.
- **Kayıt göçü:** v1 kaydı (12 sıra) v2'ye taşındı: gün, nakit, seviyeler ve biletler korundu, eski çivi yerleşimi temizlendi.
- **Atış hızı:** hava sınırlı durumda oyunun ölçülen etkin döngüsü (iniş + yeniden atış ≈ 2,75 sn) modele işlendi.
- **Kayıt:** iki ayrı çalıştırmada durum (gün, nakit, seviyeler, biletler) birebir korunuyor.
- **Performans:** 47 top havadayken ~100 FPS (Apple M5, Compatibility renderer).
- **Akış:** taksit → Günü Kapat (gece geçişi) → gün sonu özeti → Günü Bitir → Bilet Ağacı → Yeni Günü Başlat (gün doğumu) → hikâye; çarklar, çivi düzenleme, otomatik atıcı/rezerv, ek iş, Jackpot, ÖDE uyarısı ekranları 1280x720 ve 1440x810'da gözle kontrol edildi.

## 17. Tamamlananlar ve ertelenenler

Tamamlanan: prompt'taki 7 geliştirme aşamasının tamamı (çekirdek Plinko, çarklar ve günlük sefer, ekonomi/yükseltme/otomasyon,
biletler/ağaç/başarımlar, hikâye/final/Serbest Mod, görsel-işitsel geri bildirim/ayarlar/erişilebilirlik/kayıt).
Ek içerikten: istatistikler, kayıtlı çivi dizilimi (Kalıp Defteri), alacaklı notları, Serbest Mod başarımları.

Ertelenen (çekirdek döngüyü gölgelememek için bilinçli olarak): günlük/haftalık hedefler, kozmetik görünümler ve salon dekorasyonu,
özel meydan okumalar, ikinci dil çevirisi (altyapı hazır), elle çizilmiş sanat ve kaydedilmiş ses dosyaları (şimdilik vektör çizim ve
sentezlenmiş ses), oyun içi telefon mesajları (gün başı notları bu işlevi kısmen görüyor).
