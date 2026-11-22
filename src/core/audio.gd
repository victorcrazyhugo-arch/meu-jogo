extends Node
## Sfx - audio espacial com variacoes, barramentos separados e eventos de ruido
## compartilhados com a percepcao dos zumbis (o ruido afeta a IA mesmo que o som nao toque).

const POOL_3D := 14
const POOL_2D := 5
var _p3: Array = []
var _p2: Array = []
var _i3 := 0
var _i2 := 0
var _cache := {}
var _variants := {}
var _loops := {}
var _music: AudioStreamPlayer
var _music_name := ""
var _reverb: AudioEffectReverb
var _lowpass: AudioEffectLowPassFilter
var indoor := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["SFX", "Ambiente", "Musica"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, b)
		AudioServer.set_bus_send(idx, "Master")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.35
	_reverb.damping = 0.6
	_reverb.wet = 0.0
	_reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), _reverb)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Ambiente"), _lowpass)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 4.0
		p.max_distance = 60.0
		add_child(p)
		_p3.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_p2.append(p2)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musica"
	add_child(_music)
	G.settings_changed.connect(apply_volumes)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = G.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(s["vol_master"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s["vol_sfx"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambiente"), linear_to_db(maxf(0.0001, float(s["vol_amb"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), linear_to_db(maxf(0.0001, float(s["vol_music"]))))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Musica"), not bool(s["music_on"]))


func _stream(nm: String, looped: bool = false) -> AudioStream:
	if _cache.has(nm):
		return _cache[nm]
	var path := "res://audio/%s.wav" % nm
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
		if looped and st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			var bytes_per := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
			if w.stereo:
				bytes_per *= 2
			w.loop_end = w.data.size() / bytes_per
	_cache[nm] = st
	return st


## Resolve "passo_grama" -> uma das variacoes "passo_grama_N" existentes.
func _pick(nm: String) -> AudioStream:
	if not _variants.has(nm):
		var n := 0
		while ResourceLoader.exists("res://audio/%s_%d.wav" % [nm, n + 1]):
			n += 1
		_variants[nm] = n
	var cnt: int = _variants[nm]
	if cnt == 0:
		return _stream(nm)
	return _stream("%s_%d" % [nm, randi() % cnt + 1])


func play3d(nm: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 45.0) -> void:
	var st := _pick(nm)
	if st == null:
		return
	if G.player != null and is_instance_valid(G.player):
		if pos.distance_squared_to(G.player.global_position) > max_dist * max_dist:
			return
	var p: AudioStreamPlayer3D = _p3[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	p.stream = st
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.max_distance = max_dist
	p.play()


func ui(nm: String, vol_db: float = -6.0) -> void:
	var st := _pick(nm)
	if st == null:
		return
	var p: AudioStreamPlayer = _p2[_i2]
	_i2 = (_i2 + 1) % POOL_2D
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = 1.0
	p.play()


## Laco de ambiente identificado por id. vol 0 desliga.
func loop(id: String, nm: String, vol: float, pitch: float = 1.0, bus: String = "Ambiente") -> void:
	var p: AudioStreamPlayer = _loops.get(id, null)
	if vol <= 0.005:
		if p != null and p.playing:
			p.stop()
		return
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_loops[id] = p
	if p.stream == null or not p.playing:
		var st := _stream(nm, true)
		if st == null:
			return
		p.stream = st
		p.play()
	p.volume_db = linear_to_db(clampf(vol, 0.0001, 1.5))
	p.pitch_scale = pitch


func stop_loops() -> void:
	for id in _loops:
		var p: AudioStreamPlayer = _loops[id]
		p.stop()


func music(nm: String) -> void:
	if nm == _music_name:
		return
	_music_name = nm
	if nm == "":
		_music.stop()
		return
	var st := _stream(nm, true)
	if st == null:
		return
	_music.stream = st
	_music.volume_db = -8.0
	_music.play()


func set_indoor(v: bool) -> void:
	if v == indoor:
		return
	indoor = v
	_reverb.wet = 0.16 if v else 0.03
	_lowpass.cutoff_hz = 1400.0 if v else 20000.0


## Evento de ruido para a IA (independe de o som ser reproduzido).
func noise(pos: Vector3, radius: float) -> void:
	if G.zombies != null and is_instance_valid(G.zombies):
		G.zombies.hear(pos, radius)
