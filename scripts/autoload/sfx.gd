extends Node
## Özgün, çalışma anında sentezlenen sesler (harici ses dosyası yok).
## Efekt ve müzik ayrı veri yollarında (bus) ve ayrı ses ayarlarındadır.

const RATE := 22050
const MUSIC_RATE := 16000
const POOL := 10

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _tick_budget := 0.0
var _sfx_bus := 0
var _music_bus := 0
var _music_task := -1
var _quitting := false


func _ready() -> void:
	_sfx_bus = _ensure_bus("SFX")
	_music_bus = _ensure_bus("Music")
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_sfx()
	_music_task = WorkerThreadPool.add_task(_build_music_threaded)


## Çıkıştan önce çağrılır: tüm sesleri durdurur. Ses sunucusu akışları bir sonraki karede bırakır,
## bu yüzden çağıran taraf kapatmadan önce birkaç kare beklemelidir (Game.quit_game).
func shutdown() -> void:
	_quitting = true
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	_music.stop()
	_music.stream = null
	for p in _players:
		p.stop()
		p.stream = null


func _exit_tree() -> void:
	shutdown()


func _ensure_bus(name_: String) -> int:
	var idx := AudioServer.get_bus_index(name_)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name_)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func apply_volumes(settings: Dictionary) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings["master"]), 0.0001)))
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(float(settings["sfx"]), 0.0001)))
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(float(settings["music"]), 0.0001)))
	AudioServer.set_bus_mute(_music_bus, float(settings["music"]) <= 0.001)
	AudioServer.set_bus_mute(_sfx_bus, float(settings["sfx"]) <= 0.001)


func _process(delta: float) -> void:
	_tick_budget = minf(_tick_budget + delta * 30.0, 6.0)


func play(name_: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(name_):
		return
	if name_ == "peg":
		if _tick_budget < 1.0:
			return
		_tick_budget -= 1.0
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name_]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# ------------------------------------------------------------------ sentez

func _wav(samples: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Basit tonlar: notes = [[frekans, başlangıç sn, süre sn, genlik], ...]
func _tones(notes: Array, length: float, shape: String = "sine", decay: float = 6.0) -> PackedFloat32Array:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for note in notes:
		var f: float = note[0]
		var start := int(float(note[1]) * RATE)
		var dur := int(float(note[2]) * RATE)
		var amp: float = note[3]
		for i in range(dur):
			var idx := start + i
			if idx >= n:
				break
			var t := float(i) / RATE
			var env := exp(-decay * t) * minf(1.0, t * 400.0)
			var ph := TAU * f * t
			var v := sin(ph)
			if shape == "bell":
				v = sin(ph) * 0.7 + sin(ph * 2.76) * 0.2 + sin(ph * 5.4) * 0.1
			elif shape == "square":
				v = 0.6 if sin(ph) >= 0.0 else -0.6
			buf[idx] += v * amp * env
	return buf


func _noise(length: float, amp: float, decay: float, lowpass: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(n):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		prev = prev + lowpass * (x - prev)
		buf[i] = prev * amp * exp(-decay * t)
	return buf


## Eski tip telefon zili: iki çan tonu, hızlı (≈22 Hz) titreşimli tokmak vuruşuyla; iki kısa çalma.
func _phone_bell() -> PackedFloat32Array:
	var length := 1.3
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var on := t < 0.42 or (t > 0.62 and t < 1.04)
		if not on:
			continue
		var clap := 0.55 + 0.45 * signf(sin(TAU * 22.0 * t))
		var tt := fposmod(t, 0.62)
		var env := minf(1.0, tt * 60.0) * (1.0 - 0.35 * tt)
		var v := sin(TAU * 1180.0 * t) * 0.55 + sin(TAU * 1460.0 * t) * 0.35 + sin(TAU * 2950.0 * t) * 0.1
		buf[i] = v * clap * env * 0.22
	return buf


## Ateş Modu: yükselen arpej + alev hışırtısı
func _boost_sound() -> PackedFloat32Array:
	var buf := _tones([[392.0, 0.0, 0.18, 0.2], [523.25, 0.07, 0.18, 0.2], [659.25, 0.14, 0.2, 0.2], [783.99, 0.21, 0.3, 0.22], [1046.5, 0.28, 0.45, 0.2]], 0.8, "square", 7.0)
	var whoosh := _noise(0.8, 0.35, 3.0, 0.08)
	for i in range(mini(buf.size(), whoosh.size())):
		var t := float(i) / RATE
		buf[i] += whoosh[i] * minf(1.0, t * 3.0)
	return buf


func _build_sfx() -> void:
	_streams["phone_ring"] = _wav(_phone_bell(), RATE)
	_streams["boost"] = _wav(_boost_sound(), RATE)
	_streams["fine"] = _wav(_tones([[392.0, 0.0, 0.22, 0.22], [349.23, 0.18, 0.22, 0.22], [311.13, 0.36, 0.22, 0.22], [261.63, 0.54, 0.5, 0.24]], 1.05, "square", 4.0), RATE)
	_streams["peg"] = _wav(_tones([[1850.0, 0.0, 0.05, 0.22], [2700.0, 0.0, 0.03, 0.08]], 0.05, "sine", 70.0), RATE)
	_streams["win"] = _wav(_tones([[880.0, 0.0, 0.18, 0.28], [1318.5, 0.05, 0.2, 0.22]], 0.26, "bell", 14.0), RATE)
	_streams["loss"] = _wav(_tones([[196.0, 0.0, 0.16, 0.30], [146.8, 0.03, 0.16, 0.2]], 0.2, "sine", 18.0), RATE)
	_streams["max"] = _wav(_tones([[1046.5, 0.0, 0.25, 0.22], [1318.5, 0.07, 0.25, 0.22], [1568.0, 0.14, 0.3, 0.24], [2093.0, 0.21, 0.35, 0.18]], 0.6, "bell", 7.0), RATE)
	var jp: Array = []
	var seq := [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5, 1568.0]
	for i in range(seq.size()):
		jp.append([seq[i], i * 0.09, 0.5, 0.2])
	jp.append([1046.5, 0.75, 0.9, 0.18])
	jp.append([1318.5, 0.75, 0.9, 0.14])
	jp.append([1568.0, 0.75, 0.9, 0.12])
	_streams["jackpot"] = _wav(_tones(jp, 1.7, "bell", 3.0), RATE)
	_streams["buy"] = _wav(_tones([[660.0, 0.0, 0.07, 0.25], [990.0, 0.03, 0.07, 0.2]], 0.1, "square", 30.0), RATE)
	_streams["tick"] = _wav(_tones([[1200.0, 0.0, 0.03, 0.18]], 0.03, "square", 90.0), RATE)
	_streams["slot_common"] = _wav(_tones([[784.0, 0.0, 0.3, 0.25]], 0.32, "bell", 9.0), RATE)
	_streams["slot_rare"] = _wav(_tones([[784.0, 0.0, 0.3, 0.22], [1174.7, 0.08, 0.3, 0.22]], 0.4, "bell", 8.0), RATE)
	_streams["slot_epic"] = _wav(_tones([[784.0, 0.0, 0.4, 0.2], [987.8, 0.07, 0.4, 0.2], [1174.7, 0.14, 0.45, 0.22]], 0.6, "bell", 6.0), RATE)
	_streams["slot_legendary"] = _wav(_tones([[784.0, 0.0, 0.5, 0.2], [987.8, 0.06, 0.5, 0.2], [1174.7, 0.12, 0.5, 0.2], [1568.0, 0.2, 0.8, 0.22]], 1.0, "bell", 4.0), RATE)
	_streams["ticket"] = _wav(_tones([[1568.0, 0.0, 0.25, 0.22], [2093.0, 0.06, 0.3, 0.2]], 0.36, "bell", 9.0), RATE)
	_streams["error"] = _wav(_tones([[180.0, 0.0, 0.14, 0.25]], 0.14, "square", 12.0), RATE)
	var scrub := _noise(0.35, 0.35, 8.0, 0.25)
	_streams["job"] = _wav(scrub, RATE)
	_streams["pay"] = _wav(_tones([[523.25, 0.0, 0.15, 0.25], [783.99, 0.06, 0.2, 0.22]], 0.28, "bell", 10.0), RATE)
	_streams["day"] = _wav(_tones([[392.0, 0.0, 0.6, 0.18], [493.9, 0.12, 0.6, 0.16], [587.3, 0.24, 0.8, 0.16]], 1.1, "bell", 3.5), RATE)


## Arka oda müziği: yavaş, hafif caz armonisi ve yumuşak arpej (12 sn döngü).
func _build_music_threaded() -> void:
	var length := 12.0
	var n := int(length * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chords := [
		[146.83, 174.61, 220.0, 261.63],   # Dm7
		[196.0, 246.94, 293.66, 349.23],   # G7
		[130.81, 164.81, 196.0, 246.94],   # Cmaj7
		[110.0, 138.59, 164.81, 196.0],    # A7
	]
	var beat := 0.375
	for ci in range(chords.size()):
		var chord: Array = chords[ci]
		var c_start := ci * 3.0
		# pad
		for f in chord:
			var s0 := int(c_start * MUSIC_RATE)
			var s1 := int((c_start + 3.0) * MUSIC_RATE)
			for i in range(s0, mini(s1, n)):
				var t := float(i - s0) / MUSIC_RATE
				var env := minf(1.0, t * 3.0) * minf(1.0, (3.0 - t) * 3.0)
				buf[i] += sin(TAU * float(f) * t) * 0.035 * env
		# arpej
		for b in range(8):
			var f2: float = float(chord[b % 4]) * 2.0
			var s2 := int((c_start + b * beat) * MUSIC_RATE)
			var dur := int(0.33 * MUSIC_RATE)
			for i in range(dur):
				var idx := s2 + i
				if idx >= n:
					break
				var t2 := float(i) / MUSIC_RATE
				buf[idx] += (sin(TAU * f2 * t2) * 0.7 + sin(TAU * f2 * 2.0 * t2) * 0.15) * 0.05 * exp(-7.0 * t2)
		# bas
		var bf: float = float(chord[0]) * 0.5
		for half in range(2):
			var s3 := int((c_start + half * 1.5) * MUSIC_RATE)
			for i in range(int(1.2 * MUSIC_RATE)):
				var idx2 := s3 + i
				if idx2 >= n:
					break
				var t3 := float(i) / MUSIC_RATE
				buf[idx2] += sin(TAU * bf * t3) * 0.09 * exp(-2.5 * t3) * minf(1.0, t3 * 200.0)
	var stream := _wav(buf, MUSIC_RATE, true)
	call_deferred("_start_music", stream)


## Ateş Modunda müzik hızlanır (perde biraz yükselir)
func set_music_pitch(p: float) -> void:
	if _music:
		_music.pitch_scale = p


func _start_music(stream: AudioStreamWAV) -> void:
	if _quitting or not is_inside_tree():
		return
	_music.stream = stream
	_music.play()
