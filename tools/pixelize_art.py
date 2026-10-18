#!/usr/bin/env python3
"""Üretilmiş (büyütülmüş) piksel sanat görsellerini gerçek piksel ızgarasına indirger.

Higgsfield ile üretilen görseller 1024x1024'tür ve her "piksel" yaklaşık 9-10 ekran pikselinden oluşur;
ızgara tam hizalı değildir. Bu araç:
  1. Renk geçişlerinden piksel aralığını (pitch) ve kaymayı (phase) bulur,
  2. Her hücrenin ortasından medyan rengi alarak küçük, gerçek bir piksel görseli üretir,
  3. Düz magenta arka planı şeffaf yapar (--key), isteğe bağlı olarak kırpar ve köşeleri yuvarlar.
Böylece oyunda tam sayı katlarla büyütüldüğünde keskin ve eşit pikselli görünür.
Ek bağımlılık yoktur (yalnızca zlib).

Kullanım:
  python3 tools/pixelize_art.py girdi.png çıktı.png [--key] [--crop x0,y0,x1,y1] [--round r]
"""
import struct
import sys
import zlib


# ----------------------------------------------------------------- PNG okuma / yazma

def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "PNG değil"
    pos = 8
    idat = b""
    w = h = bitdepth = ctype = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h, bitdepth, ctype, _c, _f, inter = struct.unpack(">IIBBBBB", body)
            assert bitdepth == 8 and inter == 0, "yalnızca 8 bit, taramasız PNG"
        elif tag == b"IDAT":
            idat += body
        pos += 12 + ln
    ch = {2: 3, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for i in range(ch, stride):
                line[i] = (line[i] + line[i - ch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    px = []
    for y in range(h):
        row = []
        for x in range(w):
            i = y * stride + x * ch
            row.append((out[i], out[i + 1], out[i + 2], out[i + 3] if ch == 4 else 255))
        px.append(row)
    return px


def write_png(path, px):
    h = len(px)
    w = len(px[0])
    raw = bytearray()
    for row in px:
        raw.append(0)
        for (r, g, b, a) in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, body):
        c = struct.pack(">I", len(body)) + tag + body
        return c + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


# ----------------------------------------------------------------- ızgara tespiti

def _diff(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def edges(px, axis):
    """Belirgin renk geçişlerinin konumları (axis=0: yatay tarama -> x, 1: dikey -> y)."""
    h = len(px)
    w = len(px[0])
    out = []
    if axis == 0:
        for y in range(4, h - 4, 5):
            row = px[y]
            for x in range(1, w):
                if _diff(row[x], row[x - 1]) > 60:
                    out.append(x)
    else:
        for x in range(4, w - 4, 5):
            for y in range(1, h):
                if _diff(px[y][x], px[y - 1][x]) > 60:
                    out.append(y)
    return out


def find_grid(ed, lo=5.0, hi=16.0):
    """Kenar konumlarını en iyi açıklayan (aralık, kayma) çifti."""
    best = (0.0, lo, 0.0)
    p = lo
    while p <= hi:
        # kayma: kenarların p'ye göre kalanlarının dairesel ortalaması
        import math
        sx = sum(math.cos(2 * math.pi * e / p) for e in ed)
        sy = sum(math.sin(2 * math.pi * e / p) for e in ed)
        score = math.hypot(sx, sy) / max(1, len(ed))
        if score > best[0]:
            ph = (math.atan2(sy, sx) / (2 * math.pi)) * p
            best = (score, p, ph % p)
        p += 0.01
    return best[1], best[2]


def sample(px, pitch_x, phase_x, pitch_y, phase_y):
    h = len(px)
    w = len(px[0])
    cols = int((w - phase_x) // pitch_x)
    rows = int((h - phase_y) // pitch_y)
    out = []
    for j in range(rows):
        row = []
        cy = phase_y + (j + 0.5) * pitch_y
        for i in range(cols):
            cx = phase_x + (i + 0.5) * pitch_x
            vals = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    x = min(w - 1, max(0, int(cx) + dx))
                    y = min(h - 1, max(0, int(cy) + dy))
                    vals.append(px[y][x])
            vals.sort(key=lambda c: c[0] * 3 + c[1] * 6 + c[2])
            row.append(vals[4])
        out.append(row)
    return out


def is_key(c):
    r, g, b, a = c
    return a < 128 or (r > 170 and b > 170 and g < 120 and abs(r - b) < 90)


def main():
    args = sys.argv[1:]
    src, dst = args[0], args[1]
    key = "--key" in args
    crop = None
    rnd = 0
    if "--crop" in args:
        crop = [int(v) for v in args[args.index("--crop") + 1].split(",")]
    if "--round" in args:
        rnd = int(args[args.index("--round") + 1])
    px = read_png(src)
    if crop:
        px = [row[crop[0]:crop[2]] for row in px[crop[1]:crop[3]]]
    pxx, phx = find_grid(edges(px, 0))
    pxy, phy = find_grid(edges(px, 1))
    small = sample(px, pxx, phx, pxy, phy)
    h = len(small)
    w = len(small[0])
    if key:
        small = [[(0, 0, 0, 0) if is_key(c) else (c[0], c[1], c[2], 255) for c in row] for row in small]
        # tek başına kalmış arka plan kırıntılarını temizle
        for y in range(h):
            for x in range(w):
                if small[y][x][3] == 0:
                    continue
                n = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and small[yy][xx][3] > 0:
                        n += 1
                if n == 0:
                    small[y][x] = (0, 0, 0, 0)
    if rnd > 0:
        for y in range(h):
            for x in range(w):
                cx = min(x, w - 1 - x)
                cy = min(y, h - 1 - y)
                if cx < rnd and cy < rnd and (rnd - cx - 0.5) ** 2 + (rnd - cy - 0.5) ** 2 > rnd * rnd:
                    small[y][x] = (0, 0, 0, 0)
    write_png(dst, small)
    print(f"{src} -> {dst}: {w}x{h} (aralık {pxx:.2f}/{pxy:.2f})")


if __name__ == "__main__":
    main()
