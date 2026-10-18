#!/usr/bin/env python3
"""Pixelify Sans'ın "5" rakamını oyun için yeniden çizer.

Özgün yazı tipinde 5, üst köşeleri yuvarlak olduğu için küçük boyutta "S" harfiyle karışıyor
(ör. "5.555$" -> "S.SSS$"). Bu araç yalnızca 'five' glifini, yazı tipinin 11'lik piksel ızgarasında
düz üstlü, keskin köşeli klasik bir piksel 5 ile değiştirir; glifin ağırlık varyasyonu (gvar) verisi
kaldırılır, diğer her şey aynen korunur. Lisans: SIL OFL 1.1 (ayrılmış yazı tipi adı yok), değişiklik
serbesttir. Ek bağımlılık gerektirmez.

Kullanım:  python3 tools/patch_font.py
Girdi:     assets/fonts/PixelifySans.ttf
Çıktı:     assets/fonts/PixelifySans-SB.ttf
"""
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "fonts", "PixelifySans.ttf")
DST = os.path.join(ROOT, "assets", "fonts", "PixelifySans-SB.ttf")

# Izgara kenarları (yazı tipinin kendi koordinatları; y yukarı)
XS = [60, 151, 242, 333, 424, 525]
YS = [631, 540, 450, 359, 270, 179, 88, -12]   # satır 0 (üst) ... satır 6 (alt)

# Yeni "5": her kontur saat yönünde (y yukarı) dikdörtgen birleşimleri
def rect(c0, c1, r0, r1):
    """c0..c1 sütunları, r0..r1 satırları (dahil) kaplayan dikdörtgen, saat yönünde."""
    x0, x1 = XS[c0], XS[c1 + 1]
    y_top, y_bot = YS[r0], YS[r1 + 1]
    return [(x0, y_top), (x1, y_top), (x1, y_bot), (x0, y_bot)]


FIVE = [
    # üst çubuk + sol dikme + orta çubuk (tek kontur)
    [(XS[0], YS[0]), (XS[5], YS[0]), (XS[5], YS[1]), (XS[1], YS[1]), (XS[1], YS[3]), (XS[4], YS[3]),
     (XS[4], YS[4]), (XS[0], YS[4])],
    rect(4, 4, 4, 5),   # sağ dikme (satır 4-5)
    rect(1, 3, 6, 6),   # alt çubuk
    rect(0, 0, 5, 5),   # sol alt kanca
]


def read_tables(d):
    num = struct.unpack(">H", d[4:6])[0]
    tables = {}
    order = []
    for i in range(num):
        tag, _cs, off, ln = struct.unpack(">4sIII", d[12 + 16 * i:28 + 16 * i])
        tag = tag.decode("latin-1")
        tables[tag] = bytearray(d[off:off + ln])
        order.append(tag)
    return tables, order


def cmap_glyph(cmap, ch):
    n = struct.unpack(">H", cmap[2:4])[0]
    for i in range(n):
        _pid, _eid, off = struct.unpack(">HHI", cmap[4 + 8 * i:12 + 8 * i])
        fmt = struct.unpack(">H", cmap[off:off + 2])[0]
        if fmt != 4:
            continue
        segx2 = struct.unpack(">H", cmap[off + 6:off + 8])[0]
        seg = segx2 // 2
        ends = struct.unpack(">" + "H" * seg, cmap[off + 14:off + 14 + segx2])
        starts = struct.unpack(">" + "H" * seg, cmap[off + 16 + segx2:off + 16 + 2 * segx2])
        deltas = struct.unpack(">" + "h" * seg, cmap[off + 16 + 2 * segx2:off + 16 + 3 * segx2])
        ro = off + 16 + 3 * segx2
        ros = struct.unpack(">" + "H" * seg, cmap[ro:ro + segx2])
        c = ord(ch)
        for k in range(seg):
            if starts[k] <= c <= ends[k]:
                if ros[k] == 0:
                    return (c + deltas[k]) & 0xFFFF
                a = ro + 2 * k + ros[k] + 2 * (c - starts[k])
                g = struct.unpack(">H", cmap[a:a + 2])[0]
                return (g + deltas[k]) & 0xFFFF if g else 0
    raise ValueError("glif yok: " + ch)


def build_glyph(contours):
    pts = [p for c in contours for p in c]
    ends = []
    n = 0
    for c in contours:
        n += len(c)
        ends.append(n - 1)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    out = struct.pack(">hhhhh", len(contours), min(xs), min(ys), max(xs), max(ys))
    out += struct.pack(">" + "H" * len(ends), *ends)
    out += struct.pack(">H", 0)                      # talimat yok
    out += bytes([1] * len(pts))                     # hepsi eğri üstü nokta, 16 bit delta
    px = py = 0
    xb = b""
    yb = b""
    for x, y in pts:
        xb += struct.pack(">h", x - px)
        yb += struct.pack(">h", y - py)
        px, py = x, y
    out += xb + yb
    if len(out) % 2:
        out += b"\0"
    return out


def checksum(b):
    b = bytes(b) + b"\0" * ((4 - len(b) % 4) % 4)
    s = 0
    for i in range(0, len(b), 4):
        s = (s + struct.unpack(">I", b[i:i + 4])[0]) & 0xFFFFFFFF
    return s


def main():
    d = open(SRC, "rb").read()
    t, order = read_tables(d)
    head = t["head"]
    locfmt = struct.unpack(">h", head[50:52])[0]
    ng = struct.unpack(">H", t["maxp"][4:6])[0]
    gid = cmap_glyph(t["cmap"], "5")
    # --- glyf + loca
    loca = t["loca"]
    def lget(i):
        if locfmt == 0:
            return struct.unpack(">H", loca[2 * i:2 * i + 2])[0] * 2
        return struct.unpack(">I", loca[4 * i:4 * i + 4])[0]
    offs = [lget(i) for i in range(ng + 1)]
    glyf = t["glyf"]
    new_g = build_glyph(FIVE)
    glyphs = [bytes(glyf[offs[i]:offs[i + 1]]) for i in range(ng)]
    glyphs[gid] = new_g
    nglyf = b""
    noffs = [0]
    for g in glyphs:
        nglyf += g
        noffs.append(len(nglyf))
    if locfmt == 0:
        nloca = b"".join(struct.pack(">H", o // 2) for o in noffs)
    else:
        nloca = b"".join(struct.pack(">I", o) for o in noffs)
    t["glyf"] = bytearray(nglyf)
    t["loca"] = bytearray(nloca)
    # --- gvar: bu glifin varyasyon verisini kaldır (nokta sayısı değişti)
    gv = t["gvar"]
    (_maj, _min, _axc, _stc, _sto, gcount, flags, data_off) = struct.unpack(">HHHHIHHI", gv[:20])
    long_off = flags & 1
    def gvo(i):
        if long_off:
            return struct.unpack(">I", gv[20 + 4 * i:24 + 4 * i])[0]
        return struct.unpack(">H", gv[20 + 2 * i:22 + 2 * i])[0] * 2
    goffs = [gvo(i) for i in range(gcount + 1)]
    datas = [bytes(gv[data_off + goffs[i]:data_off + goffs[i + 1]]) for i in range(gcount)]
    datas[gid] = b""
    nd = b""
    no = [0]
    for x in datas:
        nd += x
        no.append(len(nd))
    off_bytes = b"".join(struct.pack(">I", o) for o in no) if long_off else b"".join(struct.pack(">H", o // 2) for o in no)
    pre = bytes(gv[20 + (4 if long_off else 2) * (gcount + 1):data_off])   # paylaşılan tuple'lar vb.
    new_data_off = 20 + len(off_bytes) + len(pre)
    hdr = struct.pack(">HHHHIHHI", _maj, _min, _axc, _stc, _sto + (new_data_off - data_off) if _sto >= data_off else _sto, gcount, flags, new_data_off)
    t["gvar"] = bytearray(hdr + off_bytes + pre + nd)
    # --- maxp: kontur/nokta üst sınırları
    mp = t["maxp"]
    maxpts, maxcont = struct.unpack(">HH", mp[6:10])
    pts = sum(len(c) for c in FIVE)
    mp[6:10] = struct.pack(">HH", max(maxpts, pts), max(maxcont, len(FIVE)))
    # --- dosyayı yeniden yaz
    head[8:12] = b"\0\0\0\0"
    num = len(order)
    es = 1
    while es * 2 <= num:
        es *= 2
    sr = es * 16
    out = struct.pack(">IHHHH", 0x00010000, num, sr, es.bit_length() - 1, num * 16 - sr)
    pos = 12 + 16 * num
    dirs = b""
    body = b""
    for tag in sorted(order):
        b = bytes(t[tag])
        dirs += struct.pack(">4sIII", tag.encode("latin-1"), checksum(b), pos + len(body), len(b))
        body += b + b"\0" * ((4 - len(b) % 4) % 4)
    font = bytearray(out + dirs + body)
    adj = (0xB1B0AFBA - checksum(font)) & 0xFFFFFFFF
    # head tablosunun dosyadaki yerini bul ve checkSumAdjustment yaz
    for i in range(num):
        tag, _cs, off, _ln = struct.unpack(">4sIII", font[12 + 16 * i:28 + 16 * i])
        if tag == b"head":
            font[off + 8:off + 12] = struct.pack(">I", adj)
    open(DST, "wb").write(font)
    print("yazıldı:", DST, "five glifi:", gid)


if __name__ == "__main__":
    main()
