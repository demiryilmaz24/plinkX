#!/usr/bin/env python3
"""Son Bilye — tasarım zamanı ekonomi modeli.

Bu dosya YALNIZCA tasarım/dengeleme aşamasında çalıştırılır. Oyun çalışırken
hiçbir değer burada hesaplanmaz; oyun sabit `data/economy.json` dosyasını okur.

Kullanım:
    python3 tools/economy_model.py export   # data/economy.json üretir
    python3 tools/economy_model.py sim      # oyuncu profillerini simüle eder
    python3 tools/economy_model.py report   # docs/EKONOMI_TABLOLARI.md üretir
"""
import json
import math
import os
import copy
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# 1. SABİT VERİLER (oyunun okuduğu tablo burada tanımlanır)
# ---------------------------------------------------------------------------

X_VALUE = 10            # Masa bahsi: 1X = 10$ (atış ücreti)
FALL_TIME = 2.4         # Bir topun tahtadan düşüş süresi (sn)
SLOT_CYCLE = FALL_TIME + 0.35  # Hava yuvasının etkin döngüsü: iniş + yeniden atış gecikmesi (oyunda ölçüldü)
ROWS = 8                # Çivi sırası; 9 kova genişliğinde alt eksen (az ama iri çivi: okunaklı tahta)
MIN_PLACE_ROW = 2       # Özel çiviler 3. sıradan (indeks 2) itibaren yerleştirilebilir

# Aralık türleri: net sonuç X cinsinden (ücret dahil). Pozitifler top seviyesiyle çarpılır.
INTERVALS = {
    "M": {"net": 2.5, "positive": True, "max": True},    # ★ MAX
    "W": {"net": 1.2, "positive": True, "max": False},   # Kazanç
    "L": {"net": -0.5, "positive": False, "max": False}, # Kayıp
    "E": {"net": -0.2, "positive": False, "max": False}, # Kenar (küçük kayıp)
}
# Merkezden dışa sıralama: M | W | L | E (simetrik). Yarı genişlikler kova biriminde.
BOARD_LEVELS = [
    # (M, W, L) üst sınırları; E kalan kenar. 8 sıra için, 12 sıralı ilk tasarımın olasılıklarını
    # birebir koruyacak şekilde çözüldü (tools/economy_model.py: solve_levels).
    (0.165, 0.656, 2.400),
    (0.173, 0.788, 2.473),
    (0.182, 0.921, 2.664),
    (0.190, 1.054, 2.922),
    (0.198, 1.186, 3.059),
    (0.206, 1.302, 3.137),
    (0.214, 1.385, 3.214),
    (0.223, 1.468, 3.291),
    (0.231, 1.602, 3.369),
    (0.239, 1.767, 3.446),
    (0.248, 1.933, 3.687),
    (0.256, 2.099, 3.800),
    (0.264, 2.203, 3.912),
    (0.272, 2.277, 4.025),
    (0.280, 2.350, 4.138),
    (0.289, 2.424, 4.250),
]

BALL_LEVEL = {"mult_growth": 1.12, "cost_base": 3.6, "cost_growth": 1.30}
BOARD_LEVEL_COST = {"base": 17.0, "growth": 2.2}

START_CASH = 24.0        # X cinsinden gün başı nakit (temel)

DAYS = [
    # target: X cinsinden günlük taksit; caps: gün tavanları
]
DAY_COUNT = 10
BALL_CAP_START, BALL_CAP_STEP = 12, 3     # 12, 15, ..., 39
BOARD_CAP_START, BOARD_CAP_STEP = 3, 1    # 3, 4, ..., 12
DAY_PRICE = [1.1, 4.1, 4.0, 3.0, 3.1, 2.7, 2.5, 2.0, 1.7, 1.7]   # Günlük fiyat katsayısı (kalibre, telefon olayları dahil)
DAY_TARGETS_X = [2100, 6900, 29000, 66000, 110000, 330000, 560000, 1200000, 2200000, 4600000]

FREE_JOB = {"pay": 1.0, "duration": 4.0}  # X ve saniye; tek tıkla başlar (otomatikleşmez)

UPGRADES = {
    # Her seviye: maliyet = cost_base * cost_growth^seviye (X). level_day_caps: gün başına izin verilen en yüksek seviye
    "air": {"base": 4, "per_level": 2, "max_level": 14, "cost_base": 9, "cost_growth": 1.55,
             "unlock_day": 1, "level_day_caps": [3, 5, 6, 7, 8, 9, 10, 12, 13, 14]},
    "batch": {"sizes": [1, 3, 5, 10, 20], "costs": [0, 7, 24, 170, 1000], "unlock_days": [1, 1, 1, 3, 5]},
    "auto_unlock": {"cost": 30, "unlock_day": 1},
    "auto_speed": {"base_interval": 0.6, "factor": 0.85, "max_level": 14, "cost_base": 17, "cost_growth": 1.6,
                    "unlock_day": 1, "level_day_caps": [4, 6, 8, 10, 12, 14, 14, 14, 14, 14]},
    "auto_batch": {"max_level": 3, "cost_base": 90, "cost_growth": 4.0, "unlock_day": 1,
                    "level_day_caps": [1, 1, 2, 3, 3, 3, 3, 3, 3, 3]},
    "polish": {"per_level": 0.15, "max_level": 6, "cost_base": 290, "cost_growth": 2.4, "unlock_day": 3,
                "level_day_caps": [0, 0, 1, 2, 3, 4, 5, 6, 6, 6]},
    "sockets": {"base": 2, "max_level": 6, "cost_base": 23, "cost_growth": 2.6, "unlock_day": 1,
                 "level_day_caps": [1, 2, 3, 4, 5, 6, 6, 6, 6, 6]},
}

# Telefon: iyi karakterler (Nevin, gece bekçisi) arayıp 15 sn "Ateş Modu" hediye eder (oyun hızı ×2, hava sınırı yok);
# Sadık Bey taksit bitmemişse arayıp tehdit eder ve ihtimalle ceza keser: kasadaki nakdin %15'i.
# Ceza ihtimali = fine_chance_max × (1 − bugün ödenen / taksit) → taksiti erken yatırmak korur.
# Süreler oyun açık ve oyuncu masadayken (pencere/düzenleme yokken) sayar; çalma süresi içinde açılmazsa kaçar.
PHONE = {
    "ring_secs": 9.0, "boost_secs": 15.0, "boost_speed": 2.0, "boost_air_cap": 200,
    "good_first": [70, 130], "good_every": [200, 320],
    "threat_first": [220, 340], "threat_every": [260, 420],
    "fine_rate": 0.15, "fine_chance_max": 0.6, "collect_leave_x": 10,
}
PHONE_ANSWER_RATE = 0.85      # model: iyi aramaların açılma oranı
PHONE_BOOST_CLICK_MULT = 2.0  # model: Ateş Modunda oyuncu daha sık tıklar

RARITIES = ["common", "rare", "epic", "legendary"]
# sell: çark ödülünü satma fiyatı = o açılışın ücreti × oran (nadirliğe göre). Beklenen satış değeri
# her zaman ücretin altında kalır (en iyi şans ağacıyla bile ~%86-90) → aç-sat döngüsü kâr getirmez.
# Top Çarkında kopyanın iadesi yoktur: zaten sahip olunan top satılır ya da ustalık yıldızı olarak saklanır.
BALL_SLOT = {"cost_base": 29, "cost_growth": 1.8, "weights": [55, 30, 12, 3], "sell": [0.35, 0.7, 1.4, 3.0],
             "max_mastery": 3}
PEG_SLOT = {"cost_base": 9, "cost_growth": 1.45, "weights": [52, 31, 13, 4], "sell": [0.35, 0.7, 1.4, 3.0],
            "dup_refund": 0.5, "stack_caps": [4, 3, 2, 1]}

# Top türleri: kalıcı koleksiyon. star_* = her ustalık yıldızı başına ek.
# Güç nadirlikle artar: Sıradan 1 yetenek (~+%8–15 getiri), Ender 2 yetenek (~+%25), Destansı 3 yetenek
# (biri özel mekanik), Efsanevi 3 güçlü yetenek. Getiriler `python3 tools/economy_model.py balls` ile görülür.
BALLS = [
    {"id": "demir", "rarity": "common", "starter": True, "loss_mult": 0.92, "star": {"loss_mult": -0.02}},
    {"id": "cam", "rarity": "common", "w_mult": 1.25, "star": {"w_mult": 0.05}},
    {"id": "kil", "rarity": "common", "bias": 0.535, "star": {"bias": 0.005}},
    {"id": "kaucuk", "rarity": "common", "max_mult": 1.50, "star": {"max_mult": 0.10}},
    {"id": "bakir", "rarity": "common", "pos_mult": 1.10, "star": {"pos_mult": 0.03}},
    {"id": "miknatis", "rarity": "rare", "bias": 0.55, "pos_mult": 1.12, "star": {"bias": 0.01}},
    {"id": "volkan", "rarity": "rare", "max_mult": 1.80, "pos_mult": 1.06, "star": {"max_mult": 0.15}},
    {"id": "altin", "rarity": "rare", "pos_mult": 1.18, "max_mult": 1.20, "star": {"pos_mult": 0.03}},
    {"id": "ikiz", "rarity": "epic", "split_chance": 0.25, "pos_mult": 1.08, "w_mult": 1.08, "star": {"split_chance": 0.05}},
    {"id": "kuyruklu", "rarity": "epic", "bias": 0.555, "max_mult": 1.70, "w_mult": 1.12, "star": {"max_mult": 0.10}},
    {"id": "anka", "rarity": "legendary", "rebirth_chance": 0.40, "pos_mult": 1.35, "loss_mult": 0.85, "star": {"rebirth_chance": 0.05}},
    {"id": "kara_inci", "rarity": "legendary", "bias": 0.56, "pos_mult": 1.32, "max_mult": 1.30, "star": {"pos_mult": 0.05}},
]
BIAS_CAP = 0.57

PEGS = [
    {"id": "bakir_civi", "rarity": "common", "add": 0.10},
    {"id": "yay", "rarity": "common", "bias": 0.70},
    {"id": "kalkan", "rarity": "common", "loss_mult": 0.70},
    {"id": "gumus", "rarity": "rare", "add": 0.20},
    {"id": "ayna", "rarity": "rare", "split": 0.10},
    {"id": "huni", "rarity": "rare", "bias": 0.85},
    {"id": "altin_civi", "rarity": "epic", "mult": 1.3},
    {"id": "yildiz", "rarity": "epic", "max_add": 0.8},
    {"id": "bilet", "rarity": "legendary", "ticket_chance": 0.0005, "daily_cap": 5},
    {"id": "elmas", "rarity": "legendary", "mult": 1.6},
]

TICKETS = {
    "card_base": 25, "card_step": 10,           # Şans Kartı: günün k. kartı = base + step*(k-1) delik
    "jackpot_streak": 4,                         # ardışık MAX sayısı
    "jackpot_cash_max_payouts": 25,              # Jackpot nakdi = 25 x o topun MAX ödemesi
    "jackpot_holes": 3, "jackpot_first_daily_tickets": 2,
    "first_max_bonus": {"common": 3, "rare": 5, "epic": 8, "legendary": 12},
    "prestige_base": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "prestige_perf_k": 4.0,                      # + floor(k*sqrt(kar/taksit))
    "prestige_perf_cap": 40,
    "free_mode_ref_target": 1300000,
}

TREE = [
    # id, dal, maliyetler, önkoşul, (sütun, satır) — ağaç ekranındaki konum
    ("start_cash", "kaynak", [3, 6, 12, 20, 35], None, (0, 0)),
    ("free_shots", "kaynak", [4, 8, 15], "start_cash", (0, 1)),
    ("job_pay", "kaynak", [2, 5], "start_cash", (1, 1)),
    ("bulk_buy", "kolaylik", [3], "free_shots", (0, 2)),
    ("layouts", "kolaylik", [4], "bulk_buy", (0, 3)),
    ("stats", "kolaylik", [2], "bulk_buy", (1, 3)),
    ("start_ball", "top", [5, 10, 18, 30, 50], None, (2, 0)),
    ("card_size", "bilet", [10, 22, 40], "start_ball", (2, 1)),
    ("prestige_bonus", "bilet", [10, 25, 45], "card_size", (2, 2)),
    ("auto_ready", "otomasyon", [6], None, (4, 0)),
    ("auto_speed_perm", "otomasyon", [5, 12, 25], "auto_ready", (3, 1)),
    ("air_perm", "otomasyon", [5, 12, 25], "auto_ready", (4, 1)),
    ("auto_pay", "kolaylik", [4], "air_perm", (4, 2)),
    ("start_board", "tahta", [6, 14, 28, 50], None, (6, 0)),
    ("start_sockets", "tahta", [5, 15], "start_board", (6, 1)),
    ("peg_gift", "tahta", [6, 16], "start_sockets", (6, 2)),
    ("ball_luck", "koleksiyon", [8, 18, 35], None, (8, 0)),
    ("ball_slot_cost", "koleksiyon", [6, 15], "ball_luck", (7, 1)),
    ("peg_luck", "koleksiyon", [6, 14, 28], "ball_luck", (8, 1)),
    ("peg_slot_cost", "koleksiyon", [5, 12], "peg_luck", (8, 2)),
]
# Başarımlar: tek seferlik bilet ödülü. stat: oyunun izlediği istatistik anahtarı.
ACHIEVEMENTS = [
    # id, stat, eşik, bilet, serbest_mod_mu
    ("ilk_atis", "shots_total", 1, 2, False),
    ("ilk_max", "max_total", 1, 2, False),
    ("max_100", "max_total", 100, 3, False),
    ("max_1000", "max_total", 1000, 6, False),
    ("max_10000", "max_total", 10000, 12, True),
    ("ilk_jackpot", "jackpots", 1, 4, False),
    ("jackpot_10", "jackpots", 10, 8, False),
    ("oto_500", "auto_shots", 500, 3, False),
    ("oto_10000", "auto_shots", 10000, 6, False),
    ("nadir_ender", "rarity_rare", 1, 2, False),
    ("nadir_destansi", "rarity_epic", 1, 4, False),
    ("nadir_efsanevi", "rarity_legendary", 1, 6, False),
    ("tum_nadirlikler", "rarities_owned", 4, 5, False),
    ("top_6", "ball_types", 6, 4, False),
    ("top_hepsi", "ball_types", 12, 10, False),
    ("usta_yildiz", "max_mastery", 3, 4, False),
    ("kar_1", "run_profit_best", 1.0e5, 3, False),
    ("kar_2", "run_profit_best", 1.0e7, 5, False),
    ("tahta_6", "board_level_best", 6, 3, False),
    ("tahta_12", "board_level_best", 12, 5, False),
    ("bilet_civisi", "peg_tickets", 1, 4, False),
    ("gun_3", "days_closed", 3, 3, False),
    ("gun_7", "days_closed", 7, 5, False),
    ("borc_bitti", "debt_cleared", 1, 15, False),
    ("cilaci", "jobs_done", 10, 1, False),
    ("serbest_top", "free_ball_level_best", 60, 10, True),
    ("serbest_tahta", "free_board_level_best", 16, 8, True),
    ("serbest_kar", "free_profit_best", 1.0e10, 12, True),
    ("serbest_prestij", "free_prestiges", 10, 10, True),
]

AUTO = {
    "reserve_presets_x": [2, 10, 50, 200, 1000, 5000, 25000, 100000, 500000],
    "default_reserve_index": 0,
    "launch_stagger": 0.07,
}

TREE_EFFECTS = {
    "start_cash": {"per_level": "start cash x2"},
    "free_shots": {"per_level": 10},
    "job_pay": {"per_level": 1.0},
    "start_ball": {"per_level": 3},
    "auto_speed_perm": {"per_level": 0.08},
    "air_perm": {"per_level": 2},
    "start_board": {"per_level": 1},
    "start_sockets": {"per_level": 1},
    "peg_gift": {"per_level": 1},
    "ball_luck": {"weights": [[55, 30, 12, 3], [48, 33, 15, 4], [42, 35, 18, 5], [36, 37, 21, 6]]},
    "ball_slot_cost": {"per_level": 0.15},
    "peg_luck": {"weights": [[52, 31, 13, 4], [46, 33, 16, 5], [40, 35, 19, 6], [34, 37, 22, 7]]},
    "peg_slot_cost": {"per_level": 0.15},
    "card_size": {"per_level": 3},
    "prestige_bonus": {"per_level": 0.15},
}


# ---------------------------------------------------------------------------
# 2. OLASILIK MODELİ (oyundaki outcome sistemiyle aynı matematik)
# ---------------------------------------------------------------------------

def interval_bounds(level):
    m, w, l = BOARD_LEVELS[level - 1]
    half = (ROWS + 1) / 2.0
    return [("M", 0.0, m), ("W", m, w), ("L", w, l), ("E", l, half)]


def bin_overlaps(level):
    """Her kova k için aralık türlerinin payı (kova içinde düzgün dağılım)."""
    c = (ROWS + 1) / 2.0
    res = []
    for k in range(ROWS + 1):
        d = {"M": 0.0, "W": 0.0, "L": 0.0, "E": 0.0}
        for name, a, b in interval_bounds(level):
            for lo, hi in ((c - b, c - a), (c + a, c + b)):
                d[name] += max(0.0, min(hi, k + 1) - max(lo, k))
        res.append(d)
    return res


def toward_center_q(r, j, b):
    off = j - r / 2.0
    if off < 0:
        return b
    if off > 0:
        return 1.0 - b
    return 0.5


def ball_params(ball, stars=0):
    p = {"pos_mult": 1.0, "w_mult": 1.0, "max_mult": 1.0, "loss_mult": 1.0, "bias": 0.5,
         "split_chance": 0.0, "rebirth_chance": 0.0}
    for k in p:
        if k in ball:
            p[k] = ball[k]
    for k, v in ball.get("star", {}).items():
        p[k] += v * stars
    p["bias"] = min(p["bias"], BIAS_CAP)
    return p


def path_dp(ball_bias, layout):
    """layout: {(r,j): peg_dict}. Döner: final kütleleri ve beklenti dizileri."""
    P = [1.0]; A = [1.0]; S = [0.0]; T = [0.0]; LM = [1.0]
    hits = {}
    split_mass = 0.0
    tickets = 0.0
    for r in range(ROWS):
        n = len(P) + 1
        nP = [0.0] * n; nA = [0.0] * n; nS = [0.0] * n; nT = [0.0] * n; nL = [0.0] * n
        for j in range(len(P)):
            p, a, s, t, lm = P[j], A[j], S[j], T[j], LM[j]
            b = ball_bias
            peg = layout.get((r, j))
            if peg:
                hits[(r, j)] = p
                if "mult" in peg:
                    a *= peg["mult"]; s *= peg["mult"]; t *= peg["mult"]
                if "add" in peg:
                    s += peg["add"] * a
                if "max_add" in peg:
                    t += peg["max_add"] * a
                if "loss_mult" in peg:
                    lm *= peg["loss_mult"]
                if "bias" in peg:
                    b = max(b, peg["bias"])
                if "split" in peg:
                    split_mass += p * peg["split"]
                if "ticket_chance" in peg:
                    tickets += p * peg["ticket_chance"]
            q = toward_center_q(r, j, b)
            for jj, w in ((j, 1 - q), (j + 1, q)):
                nP[jj] += p * w; nA[jj] += a * w; nS[jj] += s * w; nT[jj] += t * w; nL[jj] += lm * w
        P, A, S, T, LM = nP, nA, nS, nT, nL
    return {"P": P, "A": A, "S": S, "T": T, "LM": LM, "hits": hits, "split": split_mass, "tickets": tickets}


def hit_probabilities(ball_bias):
    P = [1.0]
    out = {}
    for r in range(ROWS):
        n = [0.0] * (len(P) + 1)
        for j, p in enumerate(P):
            out[(r, j)] = p
            q = toward_center_q(r, j, ball_bias)
            n[j] += p * (1 - q); n[j + 1] += p * q
        P = n
    return out


def outcome_probs(level, bias=0.5, layout=None):
    dp = path_dp(bias, layout or {})
    ov = bin_overlaps(level)
    pr = {"M": 0.0, "W": 0.0, "L": 0.0, "E": 0.0}
    for k, pk in enumerate(dp["P"]):
        for name in pr:
            pr[name] += pk * ov[k][name]
    return pr


_EV_CACHE = {}


def layout_key(layout):
    return tuple(sorted((k, v["id"]) for k, v in layout.items()))


def shot_ev_base(level, ball, stars, layout):
    """Top seviyesi=1, cila=0 iken tek ücretli atışın bileşenleri (önbellekli)."""
    key = (level, ball["id"], stars, layout_key(layout))
    if key in _EV_CACHE:
        return _EV_CACHE[key]
    bp = ball_params(ball, stars)
    dp = path_dp(bp["bias"], layout)
    ov = bin_overlaps(level)
    pos = 0.0; neg = 0.0; pmax = 0.0; ploss = 0.0
    for k in range(ROWS + 1):
        for name, iv in INTERVALS.items():
            f = ov[k][name]
            if f == 0:
                continue
            if iv["positive"]:
                tm = bp["max_mult"] if iv["max"] else bp["w_mult"]
                ex = dp["A"][k] + dp["S"][k] + (dp["T"][k] if iv["max"] else 0.0)
                pos += f * iv["net"] * tm * ex * bp["pos_mult"]
                if iv["max"]:
                    pmax += f * dp["P"][k]
            else:
                neg += f * iv["net"] * bp["loss_mult"] * dp["LM"][k]
                ploss += f * dp["P"][k]
    bonus_balls = dp["split"] + bp["split_chance"] + ploss * bp["rebirth_chance"]
    res = {"pos1": pos, "neg": neg, "pmax": pmax, "ploss": ploss, "bonus_balls": bonus_balls,
           "peg_tickets": dp["tickets"]}
    _EV_CACHE[key] = res
    return res


def shot_ev(level, ball_level, ball, stars, layout, polish):
    b = shot_ev_base(level, ball, stars, layout)
    mball = BALL_LEVEL["mult_growth"] ** (ball_level - 1)
    pos = b["pos1"] * mball * (1 + polish)
    # Bonus toplar: ücretsiz, yalnızca pozitif sonuç öder (kayıpta ceza yok), zincirleme yapmaz.
    return {"ev": pos * (1 + b["bonus_balls"]) + b["neg"], "pos": pos, "neg": b["neg"], "pmax": b["pmax"],
            "bonus_balls": b["bonus_balls"], "peg_tickets": b["peg_tickets"], "ploss": b["ploss"]}


# ---------------------------------------------------------------------------
# 3. OYUNCU SİMÜLASYONU (beklenen değer temelli, 0.5 sn adımlı)
# ---------------------------------------------------------------------------

PROFILES = {
    # click_rate: elle toplu atış tıklaması/sn; roi_h: geri dönüş süresi eşiği (sn);
    # *_slot_s: slot çevirmeye razı olduğu "kaç saniyelik gelir"; overtime: taksit dolduktan sonra devam (sn)
    "normal":    {"auto": "roi",   "click_rate": 0.25, "roi_f": 0.8, "ball_slot_s": 45,  "peg_slot_s": 30, "overtime": 0,   "ball_pick": "best"},
    "manuel":    {"auto": "never", "click_rate": 0.60, "roi_f": 0.8, "ball_slot_s": 45,  "peg_slot_s": 30, "overtime": 0,   "ball_pick": "best"},
    "erken_oto": {"auto": "first", "click_rate": 0.10, "roi_f": 0.8, "ball_slot_s": 45,  "peg_slot_s": 30, "overtime": 0,   "ball_pick": "best"},
    "slotcu":    {"auto": "roi",   "click_rate": 0.25, "roi_f": 0.8, "ball_slot_s": 160, "peg_slot_s": 100, "overtime": 0,  "ball_pick": "best"},
    "temkinli":  {"auto": "roi",   "click_rate": 0.20, "roi_f": 0.5,  "ball_slot_s": 15,  "peg_slot_s": 10, "overtime": 0,   "ball_pick": "safe"},
    "riskci":    {"auto": "roi",   "click_rate": 0.25, "roi_f": 1.0, "ball_slot_s": 60,  "peg_slot_s": 30, "overtime": 0,   "ball_pick": "risky"},
    "uzatan":    {"auto": "roi",   "click_rate": 0.25, "roi_f": 0.8, "ball_slot_s": 45,  "peg_slot_s": 30, "overtime": 300, "ball_pick": "best"},
}

# Normal oyuncunun gün süresi hedefi (simülasyon dakikası). Gerçek oyunda okuma, karar,
# çivi yerleştirme ve hikâye ekranları ~%20 ekler -> toplam ≈ 2,6–2,9 saat.
DAY_MINUTES = [8, 10, 11, 12, 13, 14, 15, 16, 17, 19]

TREE_PRIORITY = [
    "auto_ready", "start_ball", "start_cash", "start_board", "start_ball", "air_perm", "card_size",
    "start_cash", "auto_speed_perm", "start_ball", "start_board", "ball_luck", "start_sockets",
    "free_shots", "prestige_bonus", "start_cash", "air_perm", "start_ball", "peg_luck", "start_board",
    "auto_speed_perm", "bulk_buy", "peg_gift", "start_ball", "card_size", "ball_luck", "air_perm",
    "prestige_bonus", "start_cash", "start_board", "auto_speed_perm", "card_size", "ball_luck",
]


def tree_node(node):
    return [t[:4] for t in TREE if t[0] == node][0]


class Meta:
    def __init__(self):
        self.tickets = 0.0
        self.tree = {t[0]: 0 for t in TREE}
        self.balls = {"demir": 0}   # id -> ustalık yıldızı
        self.first_max_done = set()
        self.ticket_log = {"prestij": 0, "kart": 0, "ilk_max": 0, "jackpot": 0, "civi": 0, "basarim": 0}
        self.spent_tree = 0

    def buy_tree(self):
        while True:
            progressed = False
            for node in TREE_PRIORITY:
                nid, _b, costs, prereq = tree_node(node)
                lvl = self.tree[nid]
                if lvl >= len(costs):
                    continue
                if prereq and self.tree[prereq] == 0:
                    continue
                c = costs[lvl]
                if self.tickets >= c:
                    self.tickets -= c
                    self.spent_tree += c
                    self.tree[nid] += 1
                    progressed = True
                break  # öncelik sırasındaki ilk alınabilir düğüm için biriktir
            if not progressed:
                return


def ball_by_id(bid):
    return [b for b in BALLS if b["id"] == bid][0]


def peg_by_id(pid):
    return [p for p in PEGS if p["id"] == pid][0]


_PLACE_CACHE = {}
_HIT_SPOTS = None


def place_pegs(inv, sockets):
    """Basit yerleşim stratejisi: en değerli çiviler en yoğun konumlara (sıra>=2)."""
    global _HIT_SPOTS
    key = (tuple(sorted(inv.items())), sockets)
    if key in _PLACE_CACHE:
        return _PLACE_CACHE[key]
    if _HIT_SPOTS is None:
        hp = hit_probabilities(0.5)
        _HIT_SPOTS = sorted([k for k in hp if k[0] >= MIN_PLACE_ROW], key=lambda k: (-hp[k], k))
    order = ["elmas", "altin_civi", "bilet", "gumus", "yildiz", "huni", "ayna", "bakir_civi", "yay", "kalkan"]
    items = []
    for pid in order:
        items += [pid] * inv.get(pid, 0)
    items = items[:sockets]
    layout = {}
    for pid in items:
        for s in _HIT_SPOTS:
            if s not in layout:
                layout[s] = peg_by_id(pid)
                break
    _PLACE_CACHE[key] = layout
    return layout


def choose_ball(meta, level, ball_level, layout, polish, mode):
    best = None
    for bid, stars in meta.balls.items():
        b = ball_by_id(bid)
        e = shot_ev(level, ball_level, b, stars, layout, polish)
        if mode == "safe":
            score = e["ev"] + 1.5 * e["neg"]          # kayba ekstra ağırlık
        elif mode == "risky":
            score = e["ev"] * (1.25 if b.get("max_mult", 1) >= 2 else 1.0)
        else:
            score = e["ev"]
        if best is None or score > best[0]:
            best = (score, bid, e)
    return best[1], best[2]


def roll_rarity(weights, rng):
    x = rng.random() * sum(weights)
    for i, w in enumerate(weights):
        x -= w
        if x < 0:
            return RARITIES[i]
    return RARITIES[-1]


def upgrade_cost(key, level):
    u = UPGRADES[key]
    return u["cost_base"] * u["cost_growth"] ** level


def ball_level_cost(level):
    return BALL_LEVEL["cost_base"] * BALL_LEVEL["cost_growth"] ** (level - 1)


def board_level_cost(level):
    return BOARD_LEVEL_COST["base"] * BOARD_LEVEL_COST["growth"] ** (level - 1)


def day_caps(day):
    d = day - 1
    return BALL_CAP_START + BALL_CAP_STEP * d, min(BOARD_CAP_START + BOARD_CAP_STEP * d, len(BOARD_LEVELS))


def simulate_day(day, meta, prof, rng, target, stop_time=None, pf=None, log=None):
    """target=None -> kalibrasyon: stop_time'a kadar oyna, ödenebilen toplamı döndür."""
    d = day - 1
    tr = meta.tree
    if pf is None:
        pf = DAY_PRICE[d]
    ball_cap, board_cap = day_caps(day)
    st = {
        "cash": START_CASH * pf * (2 ** tr["start_cash"]),
        "ball": min(1 + 3 * tr["start_ball"], ball_cap),
        "board": min(1 + tr["start_board"], board_cap),
        "air": 0, "batch": 0, "auto_speed": 0, "auto_batch": 0, "polish": 0, "sockets": 0,
        "auto": tr["auto_ready"] > 0,
    }
    free_shots = 10 * tr["free_shots"]
    inv = {}
    for _ in range(tr["peg_gift"]):
        pid = rng.choice([p["id"] for p in PEGS if p["rarity"] == "common"])
        inv[pid] = inv.get(pid, 0) + 1
    ball_spins = peg_spins = 0
    paid = 0.0; profit = 0.0; t = 0.0; dt = 0.5
    shots = auto_shots = max_wins = peg_tix = jackpots = 0.0
    done_t = None; cap_t = None
    overtime_left = prof["overtime"]

    def sockets_total(s):
        return UPGRADES["sockets"]["base"] + s["sockets"] + tr["start_sockets"]

    def air_cap(s):
        return (UPGRADES["air"]["base"] + UPGRADES["air"]["per_level"] * s["air"] + 2 * tr["air_perm"]) / SLOT_CYCLE

    def throughput(s):
        cap = air_cap(s)
        manual = prof["click_rate"] * UPGRADES["batch"]["sizes"][s["batch"]]
        auto_r = 0.0
        if s["auto"]:
            iv = UPGRADES["auto_speed"]["base_interval"] * UPGRADES["auto_speed"]["factor"] ** s["auto_speed"]
            iv *= (1 - TREE_EFFECTS["auto_speed_perm"]["per_level"] * tr["auto_speed_perm"])
            auto_r = (1 + s["auto_batch"]) / iv
        total = min(cap, manual + auto_r)
        return total, min(total, auto_r)

    def boost_mult(s):
        """Ateş Modu süresince gelir çarpanı (beklenen değer, açılma oranı dahil)."""
        cap = air_cap(s)
        manual = prof["click_rate"] * UPGRADES["batch"]["sizes"][s["batch"]]
        auto_r = 0.0
        if s["auto"]:
            iv = UPGRADES["auto_speed"]["base_interval"] * UPGRADES["auto_speed"]["factor"] ** s["auto_speed"]
            iv *= (1 - TREE_EFFECTS["auto_speed_perm"]["per_level"] * tr["auto_speed_perm"])
            auto_r = (1 + s["auto_batch"]) / iv
        normal = max(1e-9, min(cap, manual + auto_r))
        boosted = manual * PHONE_BOOST_CLICK_MULT + auto_r * PHONE["boost_speed"]
        boosted = min(boosted, PHONE["boost_air_cap"] / (FALL_TIME / PHONE["boost_speed"]))
        return 1.0 + PHONE_ANSWER_RATE * max(0.0, boosted / normal - 1.0)

    def income(s):
        layout = place_pegs(inv, sockets_total(s))
        bid, e = choose_ball(meta, s["board"], s["ball"], layout, s["polish"] * UPGRADES["polish"]["per_level"], prof["ball_pick"])
        tp, tpa = throughput(s)
        return tp * e["ev"], e, tp, tpa, bid

    cur = income(st)
    ph_good = sum(PHONE["good_first"]) / 2.0
    ph_threat = sum(PHONE["threat_first"]) / 2.0
    boost_left = 0.0
    while True:
        inc = cur[0]
        # ---- adaylar ----
        cands = []
        if st["ball"] < ball_cap:
            cands.append(("ball", pf * ball_level_cost(st["ball"])))
        if st["board"] < board_cap:
            cands.append(("board", pf * board_level_cost(st["board"])))
        for key in ("air", "auto_speed", "auto_batch", "polish", "sockets"):
            u = UPGRADES[key]
            lim = min(u["max_level"], u["level_day_caps"][min(d, 9)])
            if day < u["unlock_day"] or st[key] >= lim:
                continue
            if key in ("auto_speed", "auto_batch") and not st["auto"]:
                continue
            if key == "sockets" and sum(inv.values()) <= sockets_total(st):
                continue
            cands.append((key, pf * upgrade_cost(key, st[key])))
        nb = st["batch"] + 1
        if nb < len(UPGRADES["batch"]["sizes"]) and day >= UPGRADES["batch"]["unlock_days"][nb]:
            cands.append(("batch", pf * UPGRADES["batch"]["costs"][nb]))
        if not st["auto"] and prof["auto"] != "never":
            cands.append(("auto", pf * UPGRADES["auto_unlock"]["cost"]))
        if target is not None:
            rem = max(40.0, (target - paid - st["cash"]) / max(inc, 1e-9))
        else:
            rem = max(40.0, stop_time - t)
        horizon = prof["roi_f"] * rem
        # Tamamlayıcı yükseltmeler (hava sınırı + atıcı hızı) birlikte de değerlendirilir.
        keys = [c[0] for c in cands]
        if "air" in keys and "auto_speed" in keys:
            cands.append(("air+auto_speed", dict(cands)["air"] + dict(cands)["auto_speed"]))
        best = None
        for key, cost in cands:
            s2 = dict(st)
            for k1 in key.split("+"):
                if k1 == "auto":
                    s2["auto"] = True
                else:
                    s2[k1] += 1
            gain = income(s2)[0] - inc
            if gain <= 0:
                continue
            roi = cost / gain
            if key == "auto" and prof["auto"] == "first":
                roi = 0.0
            if best is None or roi < best[0]:
                best = (roi, key, cost)
        bcost = pf * BALL_SLOT["cost_base"] * BALL_SLOT["cost_growth"] ** ball_spins * (1 - TREE_EFFECTS["ball_slot_cost"]["per_level"] * tr["ball_slot_cost"])
        pcost = pf * PEG_SLOT["cost_base"] * PEG_SLOT["cost_growth"] ** peg_spins * (1 - TREE_EFFECTS["peg_slot_cost"]["per_level"] * tr["peg_slot_cost"])
        want = None
        if best and best[0] < horizon:
            want = ("up", best[2])
        elif inc > 0 and bcost / inc < prof["ball_slot_s"]:
            want = ("ball_slot", bcost)
        elif inc > 0 and pcost / inc < prof["peg_slot_s"]:
            want = ("peg_slot", pcost)
        acted = False
        if want and st["cash"] >= want[1]:
            st["cash"] -= want[1]
            if want[0] == "up":
                for k1 in best[1].split("+"):
                    if k1 == "auto":
                        st["auto"] = True
                    else:
                        st[k1] += 1
                    if log is not None:
                        gk = {"auto": "auto_unlock", "ball": "ball_level", "board": "board_level"}.get(k1, k1)
                        log.append({"t": round(t, 1), "a": "buy", "k": gk, "lv": 1 if k1 == "auto" else st[k1]})
                if cap_t is None and st["ball"] >= ball_cap and st["board"] >= board_cap:
                    cap_t = t
            elif want[0] == "ball_slot":
                if log is not None:
                    log.append({"t": round(t, 1), "a": "ball_slot", "n": ball_spins + 1})
                ball_spins += 1
                rar = roll_rarity(TREE_EFFECTS["ball_luck"]["weights"][tr["ball_luck"]], rng)
                b = rng.choice([x for x in BALLS if x["rarity"] == rar and not x.get("starter")])
                if b["id"] in meta.balls:
                    if SELL_ON and b["id"] != cur[4] and meta.balls[b["id"]] < BALL_SLOT["max_mastery"]:
                        # kullanılmayan topun kopyası: yıldız yerine sat
                        st["cash"] += bcost * BALL_SLOT["sell"][RARITIES.index(rar)]
                    elif meta.balls[b["id"]] < BALL_SLOT["max_mastery"]:
                        meta.balls[b["id"]] += 1
                    else:
                        # yıldızları dolu kopya: yalnızca satılabilir (oyunda satılmazsa otomatik satılır)
                        st["cash"] += bcost * BALL_SLOT["sell"][RARITIES.index(rar)]
                else:
                    meta.balls[b["id"]] = 0
            else:
                if log is not None:
                    log.append({"t": round(t, 1), "a": "peg_slot", "n": peg_spins + 1})
                peg_spins += 1
                rar = roll_rarity(TREE_EFFECTS["peg_luck"]["weights"][tr["peg_luck"]], rng)
                pg = rng.choice([x for x in PEGS if x["rarity"] == rar])
                if SELL_ON and sum(inv.values()) >= sockets_total(st) + 1 and RARITIES.index(rar) <= 1:
                    # yuvalar dolu: sıradan/ender fazlalığı sat
                    st["cash"] += pcost * PEG_SLOT["sell"][RARITIES.index(rar)]
                elif inv.get(pg["id"], 0) < PEG_SLOT["stack_caps"][RARITIES.index(rar)]:
                    inv[pg["id"]] = inv.get(pg["id"], 0) + 1
                else:
                    st["cash"] += pcost * PEG_SLOT["dup_refund"]
            acted = True
        elif want is None:
            # yapılacak verimli yatırım yok -> taksit öde
            if target is None:
                paid += st["cash"]; st["cash"] = 0.0
            elif paid < target:
                if log is not None and (not log or log[-1]["a"] != "pay"):
                    log.append({"t": round(t, 1), "a": "pay"})
                pay = min(st["cash"], target - paid)
                paid += pay; st["cash"] -= pay
        if acted:
            cur = income(st)
            continue
        if target is not None and paid >= target - 1e-9:
            if done_t is None:
                done_t = t
            if overtime_left <= 0:
                break
            overtime_left -= dt
        if target is None and t >= stop_time:
            break
        # ---- zaman akar ----
        inc, e, tp, tpa, bid = cur
        # telefon (beklenen değer): Ateş Modu geliri artırır, Sadık Bey cezası nakdi azaltır
        if PHONE_ON:
            if t >= ph_good:
                boost_left = PHONE["boost_secs"]
                ph_good += sum(PHONE["good_every"]) / 2.0
            if t >= ph_threat:
                ph_threat += sum(PHONE["threat_every"]) / 2.0
                paid_ratio = (paid / target) if target else 1.0
                if target and paid <= 0.0:
                    # kasa boş: bugün hiç ödeme yoksa Sadık Bey cebe collect_leave_x bırakıp kalan nakdi taksite yatırır
                    give = min(max(0.0, st["cash"] - PHONE["collect_leave_x"]), target - paid)
                    st["cash"] -= give
                    paid += give
                elif paid_ratio < 1.0:
                    # kısmen ödenmiş: oyuncu kapatır, ceza zarı (beklenen değer)
                    p_fine = PHONE["fine_chance_max"] * (1.0 - paid_ratio)
                    lost = st["cash"] * PHONE["fine_rate"] * p_fine
                    st["cash"] -= lost
                    profit -= lost
            if boost_left > 0:
                m = boost_mult(st)
                inc *= m
                tp *= m
                tpa *= m
                boost_left -= dt
        if free_shots > 0:
            fs = min(free_shots, tp * dt)
            free_shots -= fs
            st["cash"] += fs
        st["cash"] += inc * dt
        profit += inc * dt
        shots += tp * dt; auto_shots += tpa * dt
        max_wins += tp * dt * e["pmax"]
        peg_tix += tp * dt * e["peg_tickets"]
        p = e["pmax"]
        jackpots += tp * dt * (p ** TICKETS["jackpot_streak"]) * (1 - p)
        t += dt
        if t > 6 * 3600:
            break
    return {"day": day, "paid": paid, "time": done_t if done_t is not None else t, "total_time": t, "cap_t": cap_t,
            "st": st, "profit": profit, "shots": shots, "auto_shots": auto_shots, "max_wins": max_wins,
            "jackpots": jackpots, "peg_tix": peg_tix, "ball": cur[4], "income": cur[0], "pmax": cur[1]["pmax"],
            "tp": cur[2], "ball_spins": ball_spins, "peg_spins": peg_spins, "inv": dict(inv)}


def award_tickets(meta, r, target):
    """Gün sonu bilet hesabı (oyundaki formüllerle aynı)."""
    d = r["day"] - 1
    tr = meta.tree
    card_base = TICKETS["card_base"] - TREE_EFFECTS["card_size"]["per_level"] * tr["card_size"]
    holes = r["max_wins"] + TICKETS["jackpot_holes"] * r["jackpots"]
    k = 0; need = card_base
    while holes >= need:
        holes -= need; k += 1; need = card_base + TICKETS["card_step"] * k
    perf = math.floor(TICKETS["prestige_perf_k"] * math.sqrt(max(r["profit"], 0) / target))
    perf = min(perf, TICKETS["prestige_perf_cap"])
    prest = math.floor((TICKETS["prestige_base"][d] + perf) * (1 + TREE_EFFECTS["prestige_bonus"]["per_level"] * tr["prestige_bonus"]))
    peg = int(min(5, r["peg_tix"]))
    jp = TICKETS["jackpot_first_daily_tickets"] if r["jackpots"] >= 1 else 0
    first = 0
    for bid in list(meta.balls):     # oyuncu yeni topu deneyip ilk MAX'ını alır
        if bid not in meta.first_max_done:
            meta.first_max_done.add(bid)
            first += TICKETS["first_max_bonus"][ball_by_id(bid)["rarity"]]
    ach = ACH_TICKETS_PER_DAY_EST[d]
    for k2, v in (("prestij", prest), ("kart", k), ("civi", peg), ("jackpot", jp), ("ilk_max", first), ("basarim", ach)):
        meta.ticket_log[k2] += v
    total = prest + k + peg + jp + first + ach
    meta.tickets += total
    return {"prest": prest, "card": k, "peg": peg, "jp": jp, "first": first, "ach": ach, "total": total}


ACH_TICKETS_PER_DAY_EST = [8, 6, 5, 6, 5, 5, 4, 4, 4, 20]  # başarım tablosundan beklenen dağılım


def nice_round(v):
    if v <= 0:
        return 0
    e = 10 ** max(0, int(math.floor(math.log10(v))) - 1)
    return int(round(v / e) * e)


PHONE_ON = os.environ.get("PHONE", "1") == "1"    # telefon olayları modele dahil
SELL_ON = os.environ.get("SELL", "1") == "1"   # oyuncu gereksiz çark ödüllerini satar (modelde akılcı kural)
CAP_FRACTION = 0.50   # normal oyuncu seviye tavanlarına en geç günün ~%50'sinde ulaşsın
PRICE_SAFETY = 0.85   # tarife eşiğin %15 altında seçilir (tavan güvenle ulaşılabilir kalsın)


def calibrate(seeds=5):
    """Her gün için Günlük Tarife (pf) ve taksit hedefi (T) kalibrasyonu, hedef tabanlı modda:
      - verilen pf için T, normal oyuncunun medyan bitiş süresi DAY_MINUTES olacak şekilde ikili aramayla bulunur;
      - pf, seviye tavanlarına ulaşma anı / bitiş süresi oranı CAP_FRACTION olacak şekilde ikili aramayla bulunur."""
    metas = [Meta() for _ in range(seeds)]
    rngs = [random.Random(100 + s) for s in range(seeds)]
    targets = []; prices = []

    def trial(day, pf, T):
        res = []
        for i in range(seeds):
            m = copy.deepcopy(metas[i]); r = copy.deepcopy(rngs[i])
            res.append((simulate_day(day, m, PROFILES["normal"], r, T, None, pf), m, r))
        times = sorted(x[0]["time"] for x in res)
        fr = sorted(((x[0]["cap_t"] if x[0]["cap_t"] is not None else 2 * x[0]["time"]) / max(x[0]["time"], 1)) for x in res)
        return times[len(times) // 2], fr[len(fr) // 2], res

    def solve_T(day, pf, minutes):
        lo, hi = math.log10(50), math.log10(1e9)
        for _ in range(16):
            mid = (lo + hi) / 2
            t, _, _ = trial(day, pf, 10 ** mid)
            if t < minutes * 60:
                lo = mid
            else:
                hi = mid
        return 10 ** ((lo + hi) / 2)

    for day in range(1, DAY_COUNT + 1):
        minutes = DAY_MINUTES[day - 1]
        if True:
            lo, hi = -1.0, 4.0
            for _ in range(9):
                mid = (lo + hi) / 2
                T = solve_T(day, 10 ** mid, minutes)
                _, frac, _ = trial(day, 10 ** mid, T)
                if frac < CAP_FRACTION:
                    lo = mid
                else:
                    hi = mid
            pf = PRICE_SAFETY * 10 ** ((lo + hi) / 2)
            pf = nice_round(pf) if pf >= 10 else round(pf, 1)
        T = nice_round(solve_T(day, pf, minutes))
        tmed, frac, res = trial(day, pf, T)
        targets.append(T); prices.append(pf)
        for i, (r, m, rg) in enumerate(res):
            metas[i] = m; rngs[i] = rg
            award_tickets(metas[i], r, T)
            metas[i].buy_tree()
        times = sorted(x[0]["time"] / 60 for x in res)
        print(f"G{day}: tarife x{pf}  hedef {T}X  medyan {tmed/60:.1f} dk (aralık {times[0]:.1f}–{times[-1]:.1f})  tavan oranı {frac:.2f}", flush=True)
    print("DAY_PRICE =", prices)
    print("DAY_TARGETS_X =", targets)
    # 1. günün katsayısını taban maliyetlere katlayarak normalleştirme önerisi
    base = prices[0]
    print("NORMALIZE_BASE =", base, " -> DAY_PRICE_NORM =", [round(p_ / base, 2) for p_ in prices])
    return targets


def run_profile(name, seeds=5, verbose=True):
    prof = PROFILES[name]
    totals = []
    keep = None
    for s in range(seeds):
        meta = Meta(); rng = random.Random(1000 + s)
        rows = []; total = 0.0
        for day in range(1, DAY_COUNT + 1):
            r = simulate_day(day, meta, prof, rng, DAY_TARGETS_X[day - 1])
            r["tix"] = award_tickets(meta, r, DAY_TARGETS_X[day - 1])
            meta.buy_tree()
            total += r["total_time"]
            rows.append(r)
        totals.append(total)
        if s == 0:
            keep = (rows, meta)
    totals.sort()
    if verbose:
        rows, meta = keep
        print(f"== {name} == medyan {totals[len(totals)//2]/3600:.2f} sa (aralık {totals[0]/3600:.2f}–{totals[-1]/3600:.2f})")
        for r in rows:
            s = r["st"]
            cap = f"{r['cap_t']/60:4.1f}" if r["cap_t"] is not None else "  - "
            print(f" G{r['day']:2d} {r['time']/60:5.1f}dk tavan@{cap} top{s['ball']:3d} tahta{s['board']:3d} hava{s['air']:3d} hız{s['auto_speed']:3d} "
                  f"şarj{s['auto_batch']} cila{s['polish']} yuva{s['sockets']} oto{'+' if s['auto'] else '-'} atış{r['shots']:7.0f} "
                  f"MAX{r['max_wins']:6.0f} p{r['pmax']:.3f} JP{r['jackpots']:5.2f} {r['tp']:4.1f}/s top={r['ball']:9s} "
                  f"slot{r['ball_spins']}/{r['peg_spins']} bilet+{r['tix']['total']:3d} (pr{r['tix']['prest']} k{r['tix']['card']} i{r['tix']['first']} c{r['tix']['peg']})")
        print(f"   bilet kaynakları: {meta.ticket_log}; ağaca harcanan {meta.spent_tree}, eldeki {meta.tickets:.0f}")
    return totals


def risk_check(trials=4000):
    """Gün başında (top sv1, tahta sv1, 20X) iflas olasılığı: 60 elle atış içinde nakit < 1X."""
    rng = random.Random(7)
    pr = outcome_probs(1)
    names = list(pr); weights = [pr[n] for n in names]
    broke = 0
    for _ in range(trials):
        cash = START_CASH
        for _s in range(60):
            if cash < 1:
                broke += 1
                break
            x = rng.random(); acc = 0
            for n, w in zip(names, weights):
                acc += w
                if x < acc:
                    break
            cash += INTERVALS[n]["net"]
    print(f"Gün başı iflas olasılığı (60 atış, {START_CASH:.0f}X): %{broke / trials * 100:.2f}")
    e = shot_ev(1, 1, ball_by_id("demir"), 0, {}, 0)
    job_rate = FREE_JOB["pay"] / FREE_JOB["duration"]
    print(f"Sv1 beklenen atış değeri {e['ev']:.3f}X; 4 top havada iken ~{e['ev'] * 4 / FALL_TIME:.3f}X/sn; ücretsiz iş {job_rate:.3f}X/sn")


def _md_table(headers, rows):
    out = "| " + " | ".join(headers) + " |\n|" + "|".join(["---"] * len(headers)) + "|\n"
    for r in rows:
        out += "| " + " | ".join(str(x) for x in r) + " |\n"
    return out


def _money(v):
    v = v * X_VALUE
    if v >= 1e6:
        return f"{v/1e6:,.2f} Mn$".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"{v:,.0f}$".replace(",", ".")


def _pct(p, d=1):
    return ("%" + f"{p*100:.{d}f}").replace(".", ",")


def report(seeds=5):
    lines = []
    w = lines.append
    w("# Son Bilye — Ekonomi Modeli ve Sabit Tablolar\n")
    w("> Bu belge `python3 tools/economy_model.py report` ile **otomatik üretilir**. Oyunun okuduğu "
      "`data/economy.json` aynı modelden dışa aktarılır; bu yüzden aşağıdaki sayılar oyundakilerle birebir aynıdır. "
      "Hesaplar yalnızca tasarım aşamasında yapılır; oyun çalışırken hiçbir fiyat, oran veya ödül dinamik olarak hesaplanmaz.\n")
    w("## 1. Temel birimler\n")
    w(f"- **X = Masa bahsi = atış ücreti = {X_VALUE}$.** Tüm sonuç etiketleri X cinsinden **net** sonuçtur (ücret dahil).\n"
      f"- Ücret atış anında düşülür; inişte bakiyeye `ücret + net sonuç` eklenir. Örn. `-0,5X` → 10$ ödenir, 5$ geri gelir.\n"
      f"- Pozitif net = aralık × X × Top Sv. çarpanı × Cila × top türü × çivi çarpanı. Negatif net = aralık × X × top türü kaybı × çivi kaybı.\n"
      f"- **Top seviyesi kaybı ve atış ücretini etkilemez**; yalnızca pozitif ödemeyi büyütür.\n"
      f"- Tahta: {ROWS} çivi sırası, alt eksen {ROWS+1} kova genişliğinde. Bir topun düşüşü {FALL_TIME} sn.\n")
    w("## 2. Sonuç aralıkları ve Tahta Seviyesi\n")
    w(_md_table(["Tür", "Net sonuç", "Açıklama"], [
        ["★MAX", "+%sX" % str(INTERVALS["M"]["net"]).replace(".", ","), "Merkez bant. Maksimum kazanç = topun ★MAX bandına inmesi."],
        ["Kazanç", "+%sX" % str(INTERVALS["W"]["net"]).replace(".", ","), "MAX'in iki yanı"],
        ["Kayıp", "%sX" % str(INTERVALS["L"]["net"]).replace(".", ","), "Kazancın dışı"],
        ["Kenar", "%sX" % str(INTERVALS["E"]["net"]).replace(".", ","), "En dış kenarlar (küçük kayıp)"],
    ]))
    w("\nÇarpan etiketleri her tahta seviyesinde aynıdır; tahta seviyesi yalnızca bant **genişliklerini** değiştirir. "
      "Olasılıklar, topun gerçek yol modeli (her çivide sola/sağa, kova içinde düzgün iniş) üzerinden kesin hesaplanır "
      "ve oyunda `--verify-probs` ile 200.000 atışlık Monte Carlo karşılaştırmasıyla doğrulanmıştır.\n")
    rows = []
    prev = 0
    for lv in range(1, len(BOARD_LEVELS) + 1):
        m, wd, l = BOARD_LEVELS[lv - 1]
        pr = outcome_probs(lv)
        win = pr["M"] + pr["W"]
        cost = "—" if lv == 1 else _money(board_level_cost(lv - 1))
        rows.append([lv, f"±{m:.2f}".replace(".", ","), f"±{wd:.2f}".replace(".", ","), f"±{l:.2f}".replace(".", ","),
                     _pct(pr["M"]), _pct(pr["W"]), _pct(pr["L"]), _pct(pr["E"]), _pct(win), "evet" if win > prev else "HAYIR", cost])
        prev = win
    w(_md_table(["Sv", "MAX yarı-gen.", "Kazanç sınırı", "Kayıp sınırı", "P(MAX)", "P(Kazanç)", "P(Kayıp)", "P(Kenar)", "Kazanma", "Artıyor mu", "Maliyet (tarife 1)"], rows))
    w(f"\nMaliyet = {BOARD_LEVEL_COST['base']}X × {BOARD_LEVEL_COST['growth']}^(sv−1) × günlük tarife.\n")
    w("## 3. Top Seviyesi\n")
    w(f"Çarpan = {BALL_LEVEL['mult_growth']}^(sv−1); maliyet = {BALL_LEVEL['cost_base']}X × {BALL_LEVEL['cost_growth']}^(sv−1) × günlük tarife. "
      "Maliyet büyümesi çarpandan hızlıdır (1,30/1,12 ≈ 1,16): her yeni seviye bir öncekinden ~%16 daha uzun sürede kendini öder; "
      "bu, gün tavanlarının günün ortasında dolmasını sağlar.\n")
    rows = []
    for lv in [1, 2, 5, 10, 12, 15, 20, 25, 30, 35, 39, 50, 60]:
        rows.append([lv, f"×{BALL_LEVEL['mult_growth'] ** (lv - 1):,.2f}".replace(",", "X").replace(".", ",").replace("X", "."), _money(ball_level_cost(lv))])
    w(_md_table(["Sv", "Pozitif ödeme çarpanı", "Sonraki seviyenin maliyeti (tarife 1)"], rows))
    w("\n## 4. Günler, taksitler ve tavanlar\n")
    w("Taksitler rastgele seçilmedi: her gün için normal oyuncu modeli (aşağıda) hedef süreye göre simüle edildi; "
      "**günlük tarife**, normal oyuncunun Top/Tahta tavanlarına günün yaklaşık %40'ında ulaşacağı şekilde, **taksit** ise "
      "günün hedef dakikada biteceği şekilde ikili aramayla kalibre edildi. Sonra yuvarlandı.\n")
    rows = []
    cum = 0
    for i in range(DAY_COUNT):
        bc, tc = day_caps(i + 1)
        cum += DAY_TARGETS_X[i]
        rows.append([i + 1, _money(DAY_TARGETS_X[i]), _money(cum), bc, tc, str(DAY_PRICE[i]).replace(".", ","), DAY_MINUTES[i]])
    w(_md_table(["Gün", "Taksit", "Toplam ödenen", "Top Sv. tavanı", "Tahta Sv. tavanı", "Günlük tarife", "Hedef süre (dk, saf oyun)"], rows))
    w(f"\nToplam borç: **{_money(sum(DAY_TARGETS_X))}**. Tavan ilkesi iki seviye için de aynı: her gün sabit adımla artar "
      f"(Top +{BALL_CAP_STEP}, Tahta +{BOARD_CAP_STEP}). Serbest Modda tavan yoktur (Tahta en fazla {len(BOARD_LEVELS)}).\n")
    w("## 5. Sefer içi nakit yükseltmeleri\n")
    rows = []
    for key, u in UPGRADES.items():
        if key == "batch":
            rows.append(["Çoklu Atış", "boylar " + "/".join(map(str, u["sizes"])), " / ".join(f"{c}X" for c in u["costs"][1:]),
                         "gün " + "/".join(map(str, u["unlock_days"][1:])), "—"])
        elif key == "auto_unlock":
            rows.append(["Otomatik Atıcı", "açar", f"{u['cost']}X", f"gün {u['unlock_day']}", "—"])
        else:
            eff = {"air": f"+{u.get('per_level', 0)} hava (taban {u.get('base', '')})",
                   "auto_speed": f"aralık ×{u.get('factor', '')} (taban {u.get('base_interval', '')} sn)",
                   "auto_batch": "+1 top/tetik",
                   "polish": f"+%{int(u.get('per_level', 0)*100)} pozitif ödeme",
                   "sockets": f"+1 çivi yuvası (taban {u.get('base', '')})"}[key]
            name = {"air": "Fırlatma Rampası", "auto_speed": "Atıcı Hızı", "auto_batch": "Atıcı Şarjörü",
                    "polish": "Parlak Cila", "sockets": "Çivi Yuvası"}[key]
            rows.append([name, eff, f"{u['cost_base']}X × {u['cost_growth']}^n (en fazla {u['max_level']})",
                         f"gün {u['unlock_day']}", "/".join(map(str, u["level_day_caps"]))])
    w(_md_table(["Yükseltme", "Etki", "Maliyet", "Açılış", "Gün başına seviye tavanı (G1..G10)"], rows))
    rp = AUTO["reserve_presets_x"]
    w(f"\nTüm nakit fiyatları ayrıca günlük tarifeyle çarpılır. Otomatik atıcının varsayılan rezervi {rp[AUTO['default_reserve_index']]}X'tir "
      f"(seçenekler {', '.join(str(v) + 'X' for v in rp)}) ve rezervin altına inmez. \"Tümünü Öde\" de rezerv kadar nakdi elde bırakır.\n")
    w("## 6. Çarklar ve nadirlik\n")
    w(f"- **Top Çarkı:** ücret = {BALL_SLOT['cost_base']}X × {BALL_SLOT['cost_growth']}^(bugünkü açılış) × tarife. "
      "Top koleksiyonu kalıcı olsa da fiyat artışı **her gün sıfırlanır**; böylece her gün birkaç makul çevirme yapılabilir, "
      "koleksiyon ise ortalama olarak hikâye boyunca dolar. Zaten sahip olunan top gelirse oyuncuya “zaten sende” denir ve satışa "
      f"yönlendirilir (fiyat aşağıda); satmazsa Ustalık yıldızı olarak kalır (+1, en fazla {BALL_SLOT['max_mastery']}). Yıldızları dolu kopya "
      "yalnızca satılabilir; satılmadan yeni açılış yapılır ya da pencere kapanırsa otomatik satılır.\n"
      f"- **Çivi Çarkı:** ücret = {PEG_SLOT['cost_base']}X × {PEG_SLOT['cost_growth']}^(bugünkü açılış) × tarife; çiviler günlük olduğu için fiyat da günlük sıfırlanır. "
      f"Kopya: aynı çividen +1 (yığın sınırı Sıradan/Ender/Destansı/Efsanevi = {'/'.join(map(str, PEG_SLOT['stack_caps']))}); "
      f"sınırdaysa ücretin %{int(PEG_SLOT['dup_refund']*100)}'i iade.\n"
      f"- **Satış:** çıkan ödül istenmiyorsa satılabilir: fiyat = o açılışın ücreti × {'/'.join(str(v).replace('.', ',') for v in BALL_SLOT['sell'])} "
      "(Sıradan/Ender/Destansı/Efsanevi; iki çarkta aynı). Beklenen satış değeri ücretin altında kalır (temel oranlarla ~%66–70, en iyi "
      "şans ağacıyla ~%86–90), açılış fiyatı da her açılışta büyür → aç-sat döngüsü kâr getirmez. Model oyuncusu kullanmadığı topun "
      "kopyasını ve yuvalara sığmayan Sıradan/Ender çivileri satar; bu, normal oyuncunun süresini ~%1 kısaltır.\n")
    rows = []
    for i, wts in enumerate(TREE_EFFECTS["ball_luck"]["weights"]):
        t = sum(wts)
        rows.append([f"Top, Uğurlu Çark {i}"] + [_pct(x / t, 0) for x in wts])
    for i, wts in enumerate(TREE_EFFECTS["peg_luck"]["weights"]):
        t = sum(wts)
        rows.append([f"Çivi, Çivi Falı {i}"] + [_pct(x / t, 0) for x in wts])
    w(_md_table(["Çark / ağaç seviyesi", "Sıradan", "Ender", "Destansı", "Efsanevi"], rows))
    w("\n## 7. Top türleri (kalıcı)\n")
    rows = []
    for b in BALLS:
        traits = ", ".join(f"{k}={v}" for k, v in b.items() if k not in ("id", "rarity", "starter", "star"))
        stars = ", ".join(f"{k} {'+' if v >= 0 else ''}{v}/★" for k, v in b.get("star", {}).items())
        rows.append([b["id"], b["rarity"], traits or "—", stars or "—"])
    w(_md_table(["Top", "Nadirlik", "Özellik", "Ustalık yıldızı başına"], rows))
    w(f"\nMerkeze yönelme (bias) her topta en fazla {BIAS_CAP} ile sınırlıdır; aksi hâlde MAX ve Jackpot oranı patlar. "
      "Riskli (Volkan) ve temkinli (Kil) toplar bilinçli ödünleşimlerdir.\n")
    w("## 8. Çivi türleri (günlük)\n")
    rows = []
    for p in PEGS:
        rows.append([p["id"], p["rarity"], ", ".join(f"{k}={v}" for k, v in p.items() if k not in ("id", "rarity"))])
    w(_md_table(["Çivi", "Nadirlik", "Etki"], rows))
    w(f"\nYerleştirme: {MIN_PLACE_ROW + 1}. sıradan itibaren (en yoğun ilk sıralar kapalı; bilet çivisinin en iyi konumda bile çarpma olasılığı ≤ %37,5).\n")
    w("## 9. Bilet ekonomisi\n")
    T = TICKETS
    w(_md_table(["Kaynak", "Kural", "Sürdürülebilirlik önlemi"], [
        ["Maksimum kazanç", f"Her ★MAX = Şans Kartı'na 1 delik; kart dolunca 1 bilet. Günün k. kartı {T['card_base']} + {T['card_step']}×(k−1) delik", "Kart günde büyür → bilet ~karekök(MAX sayısı)"],
        ["Topa özel ilk MAX", "Sıradan/Ender/Destansı/Efsanevi: " + "/".join(str(v) for v in T["first_max_bonus"].values()) + " bilet, tür başına bir kez", "Kalıcı kayıtta işaretli"],
        ["Bilet Çivisi", f"Çarpma başına %{PEGS[8]['ticket_chance']*100:.2f}, günde en fazla {PEGS[8]['daily_cap']}", "Günlük tavan"],
        ["Prestij", f"⌊(gün tabanı + min({T['prestige_perf_cap']}, ⌊{T['prestige_perf_k']}×√(sefer kârı ÷ taksit)⌋)) × (1 + ağaç primi)⌋; gün tabanı " + "/".join(map(str, T["prestige_base"])), "Karekök: uzun AFK sınırlı fayda"],
        ["Jackpot", f"{T['jackpot_streak']} ardışık ★MAX → nakit = {T['jackpot_cash_max_payouts']}× o MAX ödemesi, +{T['jackpot_holes']} delik; günün ilk Jackpot'u +{T['jackpot_first_daily_tickets']} bilet", "Doğrudan bilet günde bir kez"],
        ["Başarımlar", "Tek seferlik (bkz. bölüm 11)", "Tekrar alınamaz"],
    ]))
    w("\nJackpot sıklığı (seri iniş sırasına göre sayılır, MAX olmayan her sonuç seriyi sıfırlar):\n")
    rows = []
    for p in [0.09, 0.12, 0.15, 0.20]:
        rate = p ** T["jackpot_streak"] * (1 - p)
        rows.append([_pct(p, 0), f"{rate*100:.4f}".replace(".", ",") + "%", f"{rate*10*3600:.1f}".replace(".", ",")])
    w(_md_table(["P(MAX)", "Atış başına Jackpot", "10 atış/sn ile saatte"], rows))
    w("\n## 10. Kalıcı bilet ağacı\n")
    rows = []
    total = 0
    for nid, br, costs, pre, _pos in TREE:
        total += sum(costs)
        rows.append([nid, br, len(costs), "/".join(map(str, costs)), sum(costs), pre or "—"])
    w(_md_table(["Düğüm", "Dal", "Seviye", "Maliyetler", "Toplam", "Ön koşul"], rows))
    w(f"\nAğacın tamamı **{total} bilet**. Normal oyuncu hikâye boyunca ~400 bilet kazanır (aşağıda); ağacın yaklaşık yarısı hikâyede, "
      "kalanı Serbest Modda tamamlanır. Ağaç başlangıç değerlerini değiştirir; Top Seviyesinin yalnızca nakdi, Tahta Seviyesinin yalnızca olasılığı artırması korunur.\n")
    w("## 11. Başarımlar\n")
    rows = [[a[0], a[1], a[2], a[3], "evet" if a[4] else ""] for a in ACHIEVEMENTS]
    w(_md_table(["Başarım", "İstatistik", "Eşik", "Bilet", "Serbest Mod"], rows))
    w(f"\nHikâye içinde ulaşılması beklenen başarımlar ~{sum(ACH_TICKETS_PER_DAY_EST)} bilet verir.\n")
    w("## 12. Ücretsiz geri dönüş işi\n")
    e = shot_ev(1, 1, ball_by_id("demir"), 0, {}, 0)
    w(f"Bilye Cilası: {FREE_JOB['duration']} sn, +{FREE_JOB['pay']}X = {FREE_JOB['pay']*X_VALUE:.0f}$ (≈{FREE_JOB['pay']/FREE_JOB['duration']:.3f}X/sn). "
      f"Karşılaştırma: gün başında hiçbir yükseltme yokken ücretli atışın beklenen değeri {e['ev']:.3f}X, 4 top havadayken "
      f"≈{e['ev']*4/FALL_TIME:.3f}X/sn; 1. gün sonunda bu ~8X/sn olur. İş garanti ama her zaman daha az verimlidir, otomatikleşmez ve yalnızca oyun açıkken yapılabilir.\n")
    w("## 12.1 Telefon: Ateş Modu ve Sadık Bey\n")
    ph = PHONE
    w(f"Masadaki telefon yalnızca oyuncu masadayken (oyun duraklatılmamış, pencere/düzenleme açık değil, oyun penceresi odakta) sayan iki zamanlayıcıyla çalar; "
      f"oyun kapalıyken hiçbir şey ilerlemez. Telefon {ph['ring_secs']:.0f} sn çalar.\n\n"
      f"- **İyi arama** (Nevin Abla %65, Gece Bekçisi %35): ilk arama {ph['good_first'][0]}–{ph['good_first'][1]} sn, sonra her "
      f"{ph['good_every'][0]}–{ph['good_every'][1]} sn. Açılırsa **{ph['boost_secs']:.0f} sn Ateş Modu**: oyun hızı ×{ph['boost_speed']:.0f} "
      f"(düşüş, kuyruk ve otomatik atıcı hızlanır), hava sınırı {ph['boost_air_cap']} (fiilen sınırsız). Olasılıklar ve ödemeler değişmez; "
      f"yalnızca atış sıklığı artar. Açılmayan arama kaçar.\n"
      f"- **Sadık Bey**: ilk arama {ph['threat_first'][0]}–{ph['threat_first'][1]} sn, sonra her {ph['threat_every'][0]}–{ph['threat_every'][1]} sn; "
      f"yalnızca bugünkü taksit tamamlanmamışken ve Serbest Mod dışında. **Kasa boşsa** (bugün hiç ödeme yoksa) cebe "
      f"{ph['collect_leave_x']}X bırakıp kalan nakde el koyar ve bugünkü taksite yatırır (para kaybolmaz, yükseltmeye gidemez → gün uzar). "
      f"**Kısmen ödenmişse** ceza riski: ihtimal = %{ph['fine_chance_max']*100:.0f} × (1 − bugün ödenen / taksit); ceza = kasadaki nakdin "
      f"%{ph['fine_rate']*100:.0f}'i. Telefonda **Şimdi Öde** rezervin üstündeki nakdi taksite yatırır ve ceza kesilmez; **Kapat** zarı atar. "
      f"Açılmayan arama sesli mesaj bırakır; tahsilat ya da zar yine uygulanır.\n\n"
      f"Model (beklenen değer): iyi aramaların %{PHONE_ANSWER_RATE*100:.0f}'i açılır, Ateş Modunda oyuncu ×{PHONE_BOOST_CLICK_MULT:.0f} sık tıklar; "
      f"kasa boşsa tahsilat uygulanır, kısmen ödenmişse oyuncu ödemeden kapatır (beklenen ceza). Model oyuncusu parayı hemen "
      f"yükseltmeye harcadığından tahsilatın ona etkisi küçüktür (~%0,5); parayı biriktiren oyuncunun günü daha çok uzar. Gün tarifeleri ve hedefleri bu olaylar dahil kalibre edilmiştir "
      f"(`PHONE=0` ortam değişkeni telefonsuz karşılaştırma verir).\n")
    w("## 13. Oyuncu profilleri (simülasyon)\n")
    w("Model: 0,5 sn adımlı beklenen-değer simülasyonu. Oyuncu, gün bitmeden kendini amorti eden yükseltmeleri (geri dönüş süresi < kalan sürenin "
      "belirli bir oranı) alır, çarkları gelirine göre açar, kalanı taksite yatırır; günler arasında ağaçtan öncelik sırasına göre bilet harcar. "
      "Her profil 5 farklı rastgele tohumla oynatıldı (çark şansı). Süreler **saf oyun süresidir**; gerçek oyunda okuma, karar ve çivi "
      "yerleştirme ~%15–20 ekler.\n")
    rows = []
    names = {"normal": "Normal", "manuel": "Çoğunlukla elle oynayan", "erken_oto": "Otomasyonu erken açan",
             "slotcu": "Çarklara fazla harcayan", "temkinli": "Güvenli ve yavaş", "riskci": "Riskli sonuçları deneyen",
             "uzatan": "Taksit dolunca 5 dk devam eden"}
    for key in PROFILES:
        totals = run_profile(key, seeds=seeds, verbose=False)
        med = totals[len(totals) // 2] / 3600
        rows.append([names[key], f"{med:.2f}".replace(".", ",") + " sa", f"{totals[0]/3600:.2f}–{totals[-1]/3600:.2f}".replace(".", ","),
                     f"{med*1.15:.1f}–{med*1.2:.1f}".replace(".", ",") + " sa"])
    w(_md_table(["Profil", "Medyan saf süre", "Aralık", "Tahmini gerçek süre"], rows))
    totals, keep_rows, meta = None, None, None
    meta = Meta(); rng = random.Random(1000)
    day_rows = []
    for day in range(1, DAY_COUNT + 1):
        r = simulate_day(day, meta, PROFILES["normal"], rng, DAY_TARGETS_X[day - 1])
        tix = award_tickets(meta, r, DAY_TARGETS_X[day - 1])
        meta.buy_tree()
        day_rows.append([day, f"{r['time']/60:.1f}".replace(".", ","), f"{(r['cap_t'] or 0)/60:.1f}".replace(".", ","),
                         r["st"]["ball"], r["st"]["board"], f"{r['tp']:.1f}".replace(".", ","), int(r["shots"]), int(r["max_wins"]),
                         f"{r['jackpots']:.1f}".replace(".", ","), tix["total"], r["ball"]])
    w("\nNormal oyuncunun gün gün akışı (tohum 1000):\n")
    w(_md_table(["Gün", "Süre (dk)", "Tavanlara ulaşma (dk)", "Top Sv.", "Tahta Sv.", "Atış/sn", "Atış", "★MAX", "Jackpot", "Bilet", "Kullanılan top"], day_rows))
    w("\nBilet kaynakları (hikâye toplamı): " + ", ".join(f"{k} {v}" for k, v in meta.ticket_log.items()) + f"; ağaca harcanan {meta.spent_tree}.\n")
    w("## 14. Bir parametre değişince kontrol listesi\n")
    w("- Tahta olasılığı, top çarpanı veya bilet kaynağı değiştirildiğinde `calibrate` yeniden çalıştırılır: tarife ve taksitler yeniden bulunur.\n"
      "- Ardından `sim` ile tüm profillerin 2–3,3 saat bandında kaldığı ve bilet toplamının ağaç maliyetinin ~%50'si civarında olduğu doğrulanır.\n"
      "- `export` ile `data/economy.json`, `report` ile bu belge yenilenir.\n")
    path = os.path.join(ROOT, "docs", "EKONOMI.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("yazıldı:", path)


def export_replay(path, seed=1000):
    """Normal oyuncunun kararlarını oyun içinde tekrar oynatmak için kaydeder (doğrulama aracı)."""
    meta = Meta(); rng = random.Random(seed)
    days = []
    for day in range(1, DAY_COUNT + 1):
        log = []
        r = simulate_day(day, meta, PROFILES["normal"], rng, DAY_TARGETS_X[day - 1], log=log)
        award_tickets(meta, r, DAY_TARGETS_X[day - 1])
        meta.buy_tree()
        days.append({"day": day, "model_minutes": round(r["time"] / 60, 2), "actions": log})
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"click_rate": PROFILES["normal"]["click_rate"], "tree_priority": TREE_PRIORITY, "days": days,
                   "phone_answer_rate": PHONE_ANSWER_RATE if PHONE_ON else 0.0, "boost_click_mult": PHONE_BOOST_CLICK_MULT}, f)
    print("yazıldı:", path, [d["model_minutes"] for d in days])


def export_json():
    data = {
        "format": 1,
        "x_value": X_VALUE,
        "fall_time": FALL_TIME,
        "rows": ROWS,
        "min_place_row": MIN_PLACE_ROW,
        "intervals": INTERVALS,
        "board_levels": [list(b) for b in BOARD_LEVELS],
        "ball_level": BALL_LEVEL,
        "board_level_cost": BOARD_LEVEL_COST,
        "start_cash": START_CASH,
        "days": [{"day": i + 1, "target": DAY_TARGETS_X[i] * X_VALUE, "price": DAY_PRICE[i],
                  "ball_cap": day_caps(i + 1)[0], "board_cap": day_caps(i + 1)[1]} for i in range(DAY_COUNT)],
        "free_job": FREE_JOB,
        "upgrades": UPGRADES,
        "rarities": RARITIES,
        "ball_slot": BALL_SLOT,
        "peg_slot": PEG_SLOT,
        "balls": BALLS,
        "bias_cap": BIAS_CAP,
        "pegs": PEGS,
        "tickets": TICKETS,
        "tree": [{"id": t[0], "branch": t[1], "costs": t[2], "prereq": t[3], "pos": list(t[4])} for t in TREE],
        "tree_effects": TREE_EFFECTS,
        "achievements": [{"id": a[0], "stat": a[1], "value": a[2], "tickets": a[3], "free_mode": a[4]} for a in ACHIEVEMENTS],
        "auto": AUTO,
        "phone": PHONE,
        "free_mode": {"price": DAY_PRICE[-1], "board_cap": len(BOARD_LEVELS)},
    }
    data["tickets"] = dict(TICKETS)
    data["tickets"]["free_mode_ref_target"] = DAY_TARGETS_X[-1]
    path = os.path.join(ROOT, "data", "economy.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("yazıldı:", path)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sim"
    if cmd == "export":
        export_json()
    elif cmd == "probs":
        for lv in range(1, len(BOARD_LEVELS) + 1):
            pr = outcome_probs(lv)
            print(lv, {k: round(v * 100, 2) for k, v in pr.items()}, "kazanma %.1f" % ((pr["M"] + pr["W"]) * 100))
    elif cmd == "balls":
        # her topun atış başına beklenen net getirisi (X), Demir'e göre; tahta sv 1/4/8, çivisiz
        for lv in (1, 4, 8):
            base = shot_ev(lv, 1, ball_by_id("demir"), 0, {}, 0)["ev"]
            print(f"tahta {lv}: demir {base:.3f}X")
            for b in BALLS:
                e = shot_ev(lv, 1, b, 0, {}, 0)["ev"]
                print(f"   {b['id']:10s} {b['rarity']:10s} {e:.3f}X  {100*(e/base-1):+5.0f}%")
    elif cmd == "calibrate":
        calibrate()
    elif cmd == "risk":
        risk_check()
    elif cmd == "report":
        report()
    elif cmd == "replay":
        export_replay(sys.argv[2])
    else:
        names = sys.argv[2:] or list(PROFILES)
        for n in names:
            run_profile(n)
