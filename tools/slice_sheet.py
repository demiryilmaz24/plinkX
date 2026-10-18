#!/usr/bin/env python3
"""Üretilmiş bir sprite sayfasını gerçek piksel ızgarasına indirir ve tek tek sprite'lara böler.

1. Piksel aralığı otomatik bulunur (pixelize_art.py ile aynı yöntem), sayfa küçük gerçek piksel görsele çevrilir.
2. Arka plan, kenarlardan taşan "arka plan rengine benzer" (aynı ton, yeterli doygunluk) pikseller flood-fill ile
   silinir. Sprite içindeki benzer renkli alanlar koyu konturla çevrili olduğu için korunur. Gölgeler de gider.
3. Kalan pikseller bağlı bileşenlere ayrılır, küçük kırıntılar atılır, bileşenler satır satır (yukarıdan aşağı,
   soldan sağa) sıralanır ve verilen adlarla kaydedilir. "-" adı o bileşeni atlar.

Kullanım:
  python3 tools/slice_sheet.py sayfa.png çıktı_klasörü ad1,ad2,-,ad3,... [--min 40] [--pitch-min 8] [--hue-tol 0.07] [--extra-hue 0.75:0.06] [--holes]
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelize_art as pa  # noqa: E402


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def main():
    src, outdir, names = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
    min_px = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 40
    lo = float(sys.argv[sys.argv.index("--pitch-min") + 1]) if "--pitch-min" in sys.argv else 5.0
    tol = float(sys.argv[sys.argv.index("--hue-tol") + 1]) if "--hue-tol" in sys.argv else 0.07
    # --extra-hue 0.75:0.06 -> bu tondaki pikseller de (ör. arka plana düşen mor gölge) arka plan sayılır
    extra = None
    if "--extra-hue" in sys.argv:
        eh, et = sys.argv[sys.argv.index("--extra-hue") + 1].split(":")
        extra = (float(eh), float(et))
    px = pa.read_png(src)
    pxx, phx = pa.find_grid(pa.edges(px, 0), lo, lo * 3.0)
    pxy, phy = pa.find_grid(pa.edges(px, 1), lo, lo * 3.0)
    img = pa.sample(px, pxx, phx, pxy, phy)
    h, w = len(img), len(img[0])
    # arka plan tonu: kenar piksellerinin en sık rengi
    border = [img[0][x] for x in range(w)] + [img[h - 1][x] for x in range(w)] + [img[y][0] for y in range(h)] + [img[y][w - 1] for y in range(h)]
    counts = {}
    for c in border:
        k = (c[0] // 8, c[1] // 8, c[2] // 8)
        counts[k] = counts.get(k, 0) + 1
    kk = max(counts, key=counts.get)
    key = (kk[0] * 8 + 4, kk[1] * 8 + 4, kk[2] * 8 + 4, 255)
    kh, ks, kv = hsv(key)

    def bg_like(c):
        hh, ss, vv = hsv(c)
        dh = min(abs(hh - kh), 1.0 - abs(hh - kh))
        if dh < tol and ss > 0.30 and vv > 0.25:
            return True
        if extra:
            de = min(abs(hh - extra[0]), 1.0 - abs(hh - extra[0]))
            return de < extra[1] and ss > 0.25 and vv > 0.15
        return False

    bg = [[False] * w for _ in range(h)]
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or bg[y][x] or not bg_like(img[y][x]):
            continue
        bg[y][x] = True
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    # --holes: sprite içinde kapalı kalan arka plan cepleri de silinir (sprite'ta arka plan tonu yoksa güvenli)
    if "--holes" in sys.argv:
        for y in range(h):
            for x in range(w):
                c = img[y][x]
                if not bg[y][x] and abs(c[0] - key[0]) + abs(c[1] - key[1]) + abs(c[2] - key[2]) < 70:
                    bg[y][x] = True
    # bileşenler (8 komşuluk)
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if bg[y][x] or seen[y][x]:
                continue
            pts = []
            st = [(x, y)]
            seen[y][x] = True
            while st:
                cx, cy = st.pop()
                pts.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and not bg[ny][nx]:
                            seen[ny][nx] = True
                            st.append((nx, ny))
            if len(pts) >= min_px:
                comps.append(pts)
    # yakın bileşenleri birleştir (ör. İkiz'in uyduları, alev parçaları): kutuları 3 piksel büyütüp çakışanları topla
    boxes = []
    for pts in comps:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        boxes.append([min(xs), min(ys), max(xs), max(ys), pts])
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if a[0] - 3 <= b[2] and b[0] - 3 <= a[2] and a[1] - 3 <= b[3] and b[1] - 3 <= a[3]:
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]), a[4] + b[4]]
                    del boxes[j]
                    merged = True
                    break
            if merged:
                break
    # satırlara göre sırala
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2.0)
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2.0
        if rows and abs(cy - rows[-1][0]) < (b[3] - b[1]) * 0.5:
            rows[-1][1].append(b)
        else:
            rows.append([cy, [b]])
    ordered = []
    for _cy, rb in rows:
        ordered += sorted(rb, key=lambda b: b[0])
    print(f"ızgara {w}x{h} (aralık {pxx:.2f}), {len(ordered)} sprite:", [f"{b[2]-b[0]+1}x{b[3]-b[1]+1}" for b in ordered])
    os.makedirs(outdir, exist_ok=True)
    for name, b in zip(names, ordered):
        if name == "-":
            continue
        x0, y0, x1, y1, pts = b
        out = [[(0, 0, 0, 0)] * (x1 - x0 + 3) for _ in range(y1 - y0 + 3)]
        for (x, y) in pts:
            c = img[y][x]
            out[y - y0 + 1][x - x0 + 1] = (c[0], c[1], c[2], 255)
        pa.write_png(os.path.join(outdir, name + ".png"), out)
    print("yazıldı:", outdir)


if __name__ == "__main__":
    main()
