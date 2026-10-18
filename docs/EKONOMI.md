# Son Bilye — Ekonomi Modeli ve Sabit Tablolar

> Bu belge `python3 tools/economy_model.py report` ile **otomatik üretilir**. Oyunun okuduğu `data/economy.json` aynı modelden dışa aktarılır; bu yüzden aşağıdaki sayılar oyundakilerle birebir aynıdır. Hesaplar yalnızca tasarım aşamasında yapılır; oyun çalışırken hiçbir fiyat, oran veya ödül dinamik olarak hesaplanmaz.

## 1. Temel birimler

- **X = Masa bahsi = atış ücreti = 10$.** Tüm sonuç etiketleri X cinsinden **net** sonuçtur (ücret dahil).
- Ücret atış anında düşülür; inişte bakiyeye `ücret + net sonuç` eklenir. Örn. `-0,5X` → 10$ ödenir, 5$ geri gelir.
- Pozitif net = aralık × X × Top Sv. çarpanı × Cila × top türü × çivi çarpanı. Negatif net = aralık × X × top türü kaybı × çivi kaybı.
- **Top seviyesi kaybı ve atış ücretini etkilemez**; yalnızca pozitif ödemeyi büyütür.
- Tahta: 8 çivi sırası, alt eksen 9 kova genişliğinde. Bir topun düşüşü 2.4 sn.

## 2. Sonuç aralıkları ve Tahta Seviyesi

| Tür | Net sonuç | Açıklama |
|---|---|---|
| ★MAX | +2,5X | Merkez bant. Maksimum kazanç = topun ★MAX bandına inmesi. |
| Kazanç | +1,2X | MAX'in iki yanı |
| Kayıp | -0,5X | Kazancın dışı |
| Kenar | -0,2X | En dış kenarlar (küçük kayıp) |


Çarpan etiketleri her tahta seviyesinde aynıdır; tahta seviyesi yalnızca bant **genişliklerini** değiştirir. Olasılıklar, topun gerçek yol modeli (her çivide sola/sağa, kova içinde düzgün iniş) üzerinden kesin hesaplanır ve oyunda `--verify-probs` ile 200.000 atışlık Monte Carlo karşılaştırmasıyla doğrulanmıştır.

| Sv | MAX yarı-gen. | Kazanç sınırı | Kayıp sınırı | P(MAX) | P(Kazanç) | P(Kayıp) | P(Kenar) | Kazanma | Artıyor mu | Maliyet (tarife 1) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ±0,17 | ±0,66 | ±2,40 | %9,0 | %25,1 | %56,6 | %9,2 | %34,2 | evet | — |
| 2 | ±0,17 | ±0,79 | ±2,47 | %9,5 | %30,5 | %52,4 | %7,6 | %39,9 | evet | 170$ |
| 3 | ±0,18 | ±0,92 | ±2,66 | %10,0 | %35,8 | %48,2 | %6,0 | %45,8 | evet | 374$ |
| 4 | ±0,19 | ±1,05 | ±2,92 | %10,4 | %41,2 | %44,0 | %4,4 | %51,6 | evet | 823$ |
| 5 | ±0,20 | ±1,19 | ±3,06 | %10,8 | %46,5 | %39,1 | %3,5 | %57,4 | evet | 1.810$ |
| 6 | ±0,21 | ±1,30 | ±3,14 | %11,3 | %51,2 | %34,5 | %3,0 | %62,4 | evet | 3.982$ |
| 7 | ±0,21 | ±1,39 | ±3,21 | %11,7 | %54,4 | %31,4 | %2,6 | %66,1 | evet | 8.761$ |
| 8 | ±0,22 | ±1,47 | ±3,29 | %12,2 | %57,5 | %28,2 | %2,1 | %69,7 | evet | 19.275$ |
| 9 | ±0,23 | ±1,60 | ±3,37 | %12,6 | %60,7 | %25,1 | %1,6 | %73,3 | evet | 42.404$ |
| 10 | ±0,24 | ±1,77 | ±3,45 | %13,1 | %63,9 | %21,9 | %1,1 | %76,9 | evet | 93.289$ |
| 11 | ±0,25 | ±1,93 | ±3,69 | %13,6 | %67,0 | %18,8 | %0,6 | %80,6 | evet | 205.236$ |
| 12 | ±0,26 | ±2,10 | ±3,80 | %14,0 | %70,2 | %15,3 | %0,5 | %84,2 | evet | 451.519$ |
| 13 | ±0,26 | ±2,20 | ±3,91 | %14,4 | %72,0 | %13,1 | %0,5 | %86,5 | evet | 993.341$ |
| 14 | ±0,27 | ±2,28 | ±4,03 | %14,9 | %73,2 | %11,5 | %0,4 | %88,1 | evet | 2,19 Mn$ |
| 15 | ±0,28 | ±2,35 | ±4,14 | %15,3 | %74,4 | %10,0 | %0,3 | %89,7 | evet | 4,81 Mn$ |
| 16 | ±0,29 | ±2,42 | ±4,25 | %15,8 | %75,5 | %8,5 | %0,2 | %91,3 | evet | 10,58 Mn$ |


Maliyet = 17.0X × 2.2^(sv−1) × günlük tarife.

## 3. Top Seviyesi

Çarpan = 1.12^(sv−1); maliyet = 3.6X × 1.3^(sv−1) × günlük tarife. Maliyet büyümesi çarpandan hızlıdır (1,30/1,12 ≈ 1,16): her yeni seviye bir öncekinden ~%16 daha uzun sürede kendini öder; bu, gün tavanlarının günün ortasında dolmasını sağlar.

| Sv | Pozitif ödeme çarpanı | Sonraki seviyenin maliyeti (tarife 1) |
|---|---|---|
| 1 | ×1,00 | 36$ |
| 2 | ×1,12 | 47$ |
| 5 | ×1,57 | 103$ |
| 10 | ×2,77 | 382$ |
| 12 | ×3,48 | 645$ |
| 15 | ×4,89 | 1.417$ |
| 20 | ×8,61 | 5.263$ |
| 25 | ×15,18 | 19.541$ |
| 30 | ×26,75 | 72.554$ |
| 35 | ×47,14 | 269.387$ |
| 39 | ×74,18 | 769.396$ |
| 50 | ×258,04 | 13,79 Mn$ |
| 60 | ×801,43 | 190,09 Mn$ |


## 4. Günler, taksitler ve tavanlar

Taksitler rastgele seçilmedi: her gün için normal oyuncu modeli (aşağıda) hedef süreye göre simüle edildi; **günlük tarife**, normal oyuncunun Top/Tahta tavanlarına günün yaklaşık %40'ında ulaşacağı şekilde, **taksit** ise günün hedef dakikada biteceği şekilde ikili aramayla kalibre edildi. Sonra yuvarlandı.

| Gün | Taksit | Toplam ödenen | Top Sv. tavanı | Tahta Sv. tavanı | Günlük tarife | Hedef süre (dk, saf oyun) |
|---|---|---|---|---|---|---|
| 1 | 21.000$ | 21.000$ | 12 | 3 | 1,1 | 8 |
| 2 | 69.000$ | 90.000$ | 15 | 4 | 4,1 | 10 |
| 3 | 290.000$ | 380.000$ | 18 | 5 | 4,0 | 11 |
| 4 | 660.000$ | 1,04 Mn$ | 21 | 6 | 3,0 | 12 |
| 5 | 1,10 Mn$ | 2,14 Mn$ | 24 | 7 | 3,1 | 13 |
| 6 | 3,30 Mn$ | 5,44 Mn$ | 27 | 8 | 2,7 | 14 |
| 7 | 5,60 Mn$ | 11,04 Mn$ | 30 | 9 | 2,5 | 15 |
| 8 | 12,00 Mn$ | 23,04 Mn$ | 33 | 10 | 2,0 | 16 |
| 9 | 22,00 Mn$ | 45,04 Mn$ | 36 | 11 | 1,7 | 17 |
| 10 | 46,00 Mn$ | 91,04 Mn$ | 39 | 12 | 1,7 | 19 |


Toplam borç: **91,04 Mn$**. Tavan ilkesi iki seviye için de aynı: her gün sabit adımla artar (Top +3, Tahta +1). Serbest Modda tavan yoktur (Tahta en fazla 16).

## 5. Sefer içi nakit yükseltmeleri

| Yükseltme | Etki | Maliyet | Açılış | Gün başına seviye tavanı (G1..G10) |
|---|---|---|---|---|
| Fırlatma Rampası | +2 hava (taban 4) | 9X × 1.55^n (en fazla 14) | gün 1 | 3/5/6/7/8/9/10/12/13/14 |
| Çoklu Atış | boylar 1/3/5/10/20 | 7X / 24X / 170X / 1000X | gün 1/1/3/5 | — |
| Otomatik Atıcı | açar | 30X | gün 1 | — |
| Atıcı Hızı | aralık ×0.85 (taban 0.6 sn) | 17X × 1.6^n (en fazla 14) | gün 1 | 4/6/8/10/12/14/14/14/14/14 |
| Atıcı Şarjörü | +1 top/tetik | 90X × 4.0^n (en fazla 3) | gün 1 | 1/1/2/3/3/3/3/3/3/3 |
| Parlak Cila | +%15 pozitif ödeme | 290X × 2.4^n (en fazla 6) | gün 3 | 0/0/1/2/3/4/5/6/6/6 |
| Çivi Yuvası | +1 çivi yuvası (taban 2) | 23X × 2.6^n (en fazla 6) | gün 1 | 1/2/3/4/5/6/6/6/6/6 |


Tüm nakit fiyatları ayrıca günlük tarifeyle çarpılır. Otomatik atıcının varsayılan rezervi 2X'tir (seçenekler 2X, 10X, 50X, 200X, 1000X, 5000X, 25000X, 100000X, 500000X) ve rezervin altına inmez. "Tümünü Öde" de rezerv kadar nakdi elde bırakır.

## 6. Çarklar ve nadirlik

- **Top Çarkı:** ücret = 29X × 1.8^(bugünkü açılış) × tarife. Top koleksiyonu kalıcı olsa da fiyat artışı **her gün sıfırlanır**; böylece her gün birkaç makul çevirme yapılabilir, koleksiyon ise ortalama olarak hikâye boyunca dolar. Zaten sahip olunan top gelirse oyuncuya “zaten sende” denir ve satışa yönlendirilir (fiyat aşağıda); satmazsa Ustalık yıldızı olarak kalır (+1, en fazla 3). Yıldızları dolu kopya yalnızca satılabilir; satılmadan yeni açılış yapılır ya da pencere kapanırsa otomatik satılır.
- **Çivi Çarkı:** ücret = 9X × 1.45^(bugünkü açılış) × tarife; çiviler günlük olduğu için fiyat da günlük sıfırlanır. Kopya: aynı çividen +1 (yığın sınırı Sıradan/Ender/Destansı/Efsanevi = 4/3/2/1); sınırdaysa ücretin %50'i iade.
- **Satış:** çıkan ödül istenmiyorsa satılabilir: fiyat = o açılışın ücreti × 0,35/0,7/1,4/3,0 (Sıradan/Ender/Destansı/Efsanevi; iki çarkta aynı). Beklenen satış değeri ücretin altında kalır (temel oranlarla ~%66–70, en iyi şans ağacıyla ~%86–90), açılış fiyatı da her açılışta büyür → aç-sat döngüsü kâr getirmez. Model oyuncusu kullanmadığı topun kopyasını ve yuvalara sığmayan Sıradan/Ender çivileri satar; bu, normal oyuncunun süresini ~%1 kısaltır.

| Çark / ağaç seviyesi | Sıradan | Ender | Destansı | Efsanevi |
|---|---|---|---|---|
| Top, Uğurlu Çark 0 | %55 | %30 | %12 | %3 |
| Top, Uğurlu Çark 1 | %48 | %33 | %15 | %4 |
| Top, Uğurlu Çark 2 | %42 | %35 | %18 | %5 |
| Top, Uğurlu Çark 3 | %36 | %37 | %21 | %6 |
| Çivi, Çivi Falı 0 | %52 | %31 | %13 | %4 |
| Çivi, Çivi Falı 1 | %46 | %33 | %16 | %5 |
| Çivi, Çivi Falı 2 | %40 | %35 | %19 | %6 |
| Çivi, Çivi Falı 3 | %34 | %37 | %22 | %7 |


## 7. Top türleri (kalıcı)

| Top | Nadirlik | Özellik | Ustalık yıldızı başına |
|---|---|---|---|
| demir | common | loss_mult=0.92 | loss_mult -0.02/★ |
| cam | common | w_mult=1.25 | w_mult +0.05/★ |
| kil | common | bias=0.535 | bias +0.005/★ |
| kaucuk | common | max_mult=1.5 | max_mult +0.1/★ |
| bakir | common | pos_mult=1.1 | pos_mult +0.03/★ |
| miknatis | rare | bias=0.55, pos_mult=1.12 | bias +0.01/★ |
| volkan | rare | max_mult=1.8, pos_mult=1.06 | max_mult +0.15/★ |
| altin | rare | pos_mult=1.18, max_mult=1.2 | pos_mult +0.03/★ |
| ikiz | epic | split_chance=0.25, pos_mult=1.08, w_mult=1.08 | split_chance +0.05/★ |
| kuyruklu | epic | bias=0.555, max_mult=1.7, w_mult=1.12 | max_mult +0.1/★ |
| anka | legendary | rebirth_chance=0.4, pos_mult=1.35, loss_mult=0.85 | rebirth_chance +0.05/★ |
| kara_inci | legendary | bias=0.56, pos_mult=1.32, max_mult=1.3 | pos_mult +0.05/★ |


Merkeze yönelme (bias) her topta en fazla 0.57 ile sınırlıdır; aksi hâlde MAX ve Jackpot oranı patlar. Riskli (Volkan) ve temkinli (Kil) toplar bilinçli ödünleşimlerdir.

## 8. Çivi türleri (günlük)

| Çivi | Nadirlik | Etki |
|---|---|---|
| bakir_civi | common | add=0.1 |
| yay | common | bias=0.7 |
| kalkan | common | loss_mult=0.7 |
| gumus | rare | add=0.2 |
| ayna | rare | split=0.1 |
| huni | rare | bias=0.85 |
| altin_civi | epic | mult=1.3 |
| yildiz | epic | max_add=0.8 |
| bilet | legendary | ticket_chance=0.0005, daily_cap=5 |
| elmas | legendary | mult=1.6 |


Yerleştirme: 3. sıradan itibaren (en yoğun ilk sıralar kapalı; bilet çivisinin en iyi konumda bile çarpma olasılığı ≤ %37,5).

## 9. Bilet ekonomisi

| Kaynak | Kural | Sürdürülebilirlik önlemi |
|---|---|---|
| Maksimum kazanç | Her ★MAX = Şans Kartı'na 1 delik; kart dolunca 1 bilet. Günün k. kartı 25 + 10×(k−1) delik | Kart günde büyür → bilet ~karekök(MAX sayısı) |
| Topa özel ilk MAX | Sıradan/Ender/Destansı/Efsanevi: 3/5/8/12 bilet, tür başına bir kez | Kalıcı kayıtta işaretli |
| Bilet Çivisi | Çarpma başına %0.05, günde en fazla 5 | Günlük tavan |
| Prestij | ⌊(gün tabanı + min(40, ⌊4.0×√(sefer kârı ÷ taksit)⌋)) × (1 + ağaç primi)⌋; gün tabanı 3/4/5/6/7/8/9/10/11/12 | Karekök: uzun AFK sınırlı fayda |
| Jackpot | 4 ardışık ★MAX → nakit = 25× o MAX ödemesi, +3 delik; günün ilk Jackpot'u +2 bilet | Doğrudan bilet günde bir kez |
| Başarımlar | Tek seferlik (bkz. bölüm 11) | Tekrar alınamaz |


Jackpot sıklığı (seri iniş sırasına göre sayılır, MAX olmayan her sonuç seriyi sıfırlar):

| P(MAX) | Atış başına Jackpot | 10 atış/sn ile saatte |
|---|---|---|
| %9 | 0,0060% | 2,1 |
| %12 | 0,0182% | 6,6 |
| %15 | 0,0430% | 15,5 |
| %20 | 0,1280% | 46,1 |


## 10. Kalıcı bilet ağacı

| Düğüm | Dal | Seviye | Maliyetler | Toplam | Ön koşul |
|---|---|---|---|---|---|
| start_cash | kaynak | 5 | 3/6/12/20/35 | 76 | — |
| free_shots | kaynak | 3 | 4/8/15 | 27 | start_cash |
| job_pay | kaynak | 2 | 2/5 | 7 | start_cash |
| bulk_buy | kolaylik | 1 | 3 | 3 | free_shots |
| layouts | kolaylik | 1 | 4 | 4 | bulk_buy |
| stats | kolaylik | 1 | 2 | 2 | bulk_buy |
| start_ball | top | 5 | 5/10/18/30/50 | 113 | — |
| card_size | bilet | 3 | 10/22/40 | 72 | start_ball |
| prestige_bonus | bilet | 3 | 10/25/45 | 80 | card_size |
| auto_ready | otomasyon | 1 | 6 | 6 | — |
| auto_speed_perm | otomasyon | 3 | 5/12/25 | 42 | auto_ready |
| air_perm | otomasyon | 3 | 5/12/25 | 42 | auto_ready |
| auto_pay | kolaylik | 1 | 4 | 4 | air_perm |
| start_board | tahta | 4 | 6/14/28/50 | 98 | — |
| start_sockets | tahta | 2 | 5/15 | 20 | start_board |
| peg_gift | tahta | 2 | 6/16 | 22 | start_sockets |
| ball_luck | koleksiyon | 3 | 8/18/35 | 61 | — |
| ball_slot_cost | koleksiyon | 2 | 6/15 | 21 | ball_luck |
| peg_luck | koleksiyon | 3 | 6/14/28 | 48 | ball_luck |
| peg_slot_cost | koleksiyon | 2 | 5/12 | 17 | peg_luck |


Ağacın tamamı **765 bilet**. Normal oyuncu hikâye boyunca ~400 bilet kazanır (aşağıda); ağacın yaklaşık yarısı hikâyede, kalanı Serbest Modda tamamlanır. Ağaç başlangıç değerlerini değiştirir; Top Seviyesinin yalnızca nakdi, Tahta Seviyesinin yalnızca olasılığı artırması korunur.

## 11. Başarımlar

| Başarım | İstatistik | Eşik | Bilet | Serbest Mod |
|---|---|---|---|---|
| ilk_atis | shots_total | 1 | 2 |  |
| ilk_max | max_total | 1 | 2 |  |
| max_100 | max_total | 100 | 3 |  |
| max_1000 | max_total | 1000 | 6 |  |
| max_10000 | max_total | 10000 | 12 | evet |
| ilk_jackpot | jackpots | 1 | 4 |  |
| jackpot_10 | jackpots | 10 | 8 |  |
| oto_500 | auto_shots | 500 | 3 |  |
| oto_10000 | auto_shots | 10000 | 6 |  |
| nadir_ender | rarity_rare | 1 | 2 |  |
| nadir_destansi | rarity_epic | 1 | 4 |  |
| nadir_efsanevi | rarity_legendary | 1 | 6 |  |
| tum_nadirlikler | rarities_owned | 4 | 5 |  |
| top_6 | ball_types | 6 | 4 |  |
| top_hepsi | ball_types | 12 | 10 |  |
| usta_yildiz | max_mastery | 3 | 4 |  |
| kar_1 | run_profit_best | 100000.0 | 3 |  |
| kar_2 | run_profit_best | 10000000.0 | 5 |  |
| tahta_6 | board_level_best | 6 | 3 |  |
| tahta_12 | board_level_best | 12 | 5 |  |
| bilet_civisi | peg_tickets | 1 | 4 |  |
| gun_3 | days_closed | 3 | 3 |  |
| gun_7 | days_closed | 7 | 5 |  |
| borc_bitti | debt_cleared | 1 | 15 |  |
| cilaci | jobs_done | 10 | 1 |  |
| serbest_top | free_ball_level_best | 60 | 10 | evet |
| serbest_tahta | free_board_level_best | 16 | 8 | evet |
| serbest_kar | free_profit_best | 10000000000.0 | 12 | evet |
| serbest_prestij | free_prestiges | 10 | 10 | evet |


Hikâye içinde ulaşılması beklenen başarımlar ~67 bilet verir.

## 12. Ücretsiz geri dönüş işi

Bilye Cilası: 4.0 sn, +1.0X = 10$ (≈0.250X/sn). Karşılaştırma: gün başında hiçbir yükseltme yokken ücretli atışın beklenen değeri 0.250X, 4 top havadayken ≈0.417X/sn; 1. gün sonunda bu ~8X/sn olur. İş garanti ama her zaman daha az verimlidir, otomatikleşmez ve yalnızca oyun açıkken yapılabilir.

## 12.1 Telefon: Ateş Modu ve Sadık Bey

Masadaki telefon yalnızca oyuncu masadayken (oyun duraklatılmamış, pencere/düzenleme açık değil, oyun penceresi odakta) sayan iki zamanlayıcıyla çalar; oyun kapalıyken hiçbir şey ilerlemez. Telefon 9 sn çalar.

- **İyi arama** (Nevin Abla %65, Gece Bekçisi %35): ilk arama 70–130 sn, sonra her 200–320 sn. Açılırsa **15 sn Ateş Modu**: oyun hızı ×2 (düşüş, kuyruk ve otomatik atıcı hızlanır), hava sınırı 200 (fiilen sınırsız). Olasılıklar ve ödemeler değişmez; yalnızca atış sıklığı artar. Açılmayan arama kaçar.
- **Sadık Bey**: ilk arama 220–340 sn, sonra her 260–420 sn; yalnızca bugünkü taksit tamamlanmamışken ve Serbest Mod dışında. **Kasa boşsa** (bugün hiç ödeme yoksa) cebe 10X bırakıp kalan nakde el koyar ve bugünkü taksite yatırır (para kaybolmaz, yükseltmeye gidemez → gün uzar). **Kısmen ödenmişse** ceza riski: ihtimal = %60 × (1 − bugün ödenen / taksit); ceza = kasadaki nakdin %15'i. Telefonda **Şimdi Öde** rezervin üstündeki nakdi taksite yatırır ve ceza kesilmez; **Kapat** zarı atar. Açılmayan arama sesli mesaj bırakır; tahsilat ya da zar yine uygulanır.

Model (beklenen değer): iyi aramaların %85'i açılır, Ateş Modunda oyuncu ×2 sık tıklar; kasa boşsa tahsilat uygulanır, kısmen ödenmişse oyuncu ödemeden kapatır (beklenen ceza). Model oyuncusu parayı hemen yükseltmeye harcadığından tahsilatın ona etkisi küçüktür (~%0,5); parayı biriktiren oyuncunun günü daha çok uzar. Gün tarifeleri ve hedefleri bu olaylar dahil kalibre edilmiştir (`PHONE=0` ortam değişkeni telefonsuz karşılaştırma verir).

## 13. Oyuncu profilleri (simülasyon)

Model: 0,5 sn adımlı beklenen-değer simülasyonu. Oyuncu, gün bitmeden kendini amorti eden yükseltmeleri (geri dönüş süresi < kalan sürenin belirli bir oranı) alır, çarkları gelirine göre açar, kalanı taksite yatırır; günler arasında ağaçtan öncelik sırasına göre bilet harcar. Her profil 5 farklı rastgele tohumla oynatıldı (çark şansı). Süreler **saf oyun süresidir**; gerçek oyunda okuma, karar ve çivi yerleştirme ~%15–20 ekler.

| Profil | Medyan saf süre | Aralık | Tahmini gerçek süre |
|---|---|---|---|
| Normal | 2,36 sa | 2,27–2,38 | 2,7–2,8 sa |
| Çoğunlukla elle oynayan | 2,22 sa | 2,08–2,27 | 2,6–2,7 sa |
| Otomasyonu erken açan | 2,51 sa | 2,38–2,53 | 2,9–3,0 sa |
| Çarklara fazla harcayan | 2,96 sa | 2,75–3,05 | 3,4–3,5 sa |
| Güvenli ve yavaş | 2,31 sa | 2,02–2,40 | 2,7–2,8 sa |
| Riskli sonuçları deneyen | 2,42 sa | 2,25–2,45 | 2,8–2,9 sa |
| Taksit dolunca 5 dk devam eden | 3,10 sa | 3,02–3,13 | 3,6–3,7 sa |


Normal oyuncunun gün gün akışı (tohum 1000):

| Gün | Süre (dk) | Tavanlara ulaşma (dk) | Top Sv. | Tahta Sv. | Atış/sn | Atış | ★MAX | Jackpot | Bilet | Kullanılan top |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 7,8 | 3,5 | 12 | 3 | 3,6 | 1360 | 134 | 0,1 | 38 | volkan |
| 2 | 11,9 | 6,1 | 15 | 4 | 5,0 | 3038 | 359 | 0,6 | 35 | kuyruklu |
| 3 | 11,8 | 5,3 | 18 | 5 | 5,8 | 4069 | 563 | 1,3 | 30 | kuyruklu |
| 4 | 11,9 | 5,2 | 21 | 6 | 6,5 | 4647 | 667 | 1,7 | 39 | kuyruklu |
| 5 | 11,5 | 5,7 | 24 | 7 | 7,3 | 4865 | 754 | 2,5 | 29 | kuyruklu |
| 6 | 16,3 | 6,1 | 27 | 8 | 8,0 | 7811 | 1311 | 5,5 | 41 | kuyruklu |
| 7 | 18,3 | 6,8 | 30 | 9 | 8,7 | 10083 | 1633 | 5,9 | 48 | kara_inci |
| 8 | 16,2 | 6,7 | 33 | 10 | 10,2 | 10234 | 1735 | 7,2 | 36 | kara_inci |
| 9 | 18,1 | 6,2 | 36 | 11 | 10,9 | 12285 | 2140 | 9,5 | 40 | kara_inci |
| 10 | 18,0 | 6,5 | 39 | 12 | 13,8 | 15290 | 2738 | 13,2 | 60 | kara_inci |


Bilet kaynakları (hikâye toplamı): prestij 119, kart 121, ilk_max 70, jackpot 16, civi 3, basarim 67; ağaca harcanan 367.

## 14. Bir parametre değişince kontrol listesi

- Tahta olasılığı, top çarpanı veya bilet kaynağı değiştirildiğinde `calibrate` yeniden çalıştırılır: tarife ve taksitler yeniden bulunur.
- Ardından `sim` ile tüm profillerin 2–3,3 saat bandında kaldığı ve bilet toplamının ağaç maliyetinin ~%50'si civarında olduğu doğrulanır.
- `export` ile `data/economy.json`, `report` ile bu belge yenilenir.
