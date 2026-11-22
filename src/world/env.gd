extends Node3D
## Ceu, sol e lua, neblina, clima, temperatura e sons de ambiente (sem fauna).

const WEATHER_NAMES := {"limpo": "Céu limpo", "nublado": "Nublado", "chuva": "Chuva", "tempestade": "Tempestade", "neblina": "Neblina"}

var we: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain_fx: CPUParticles3D

var weather := "limpo"
var weather_left := 180.0      # minutos de jogo ate a proxima mudanca
var rain := 0.0
var fog := 0.0
var cloud := 0.0
var wind := 0.3
var flash := 0.0
var _last_min := 0.0
var _t := 0.0
var draw_dist := 130.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12
	# nuvens procedurais (textura propria gerada em tempo de execucao)
	var cn := FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.012
	cn.fractal_octaves = 4
	cn.seed = 77
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.52, 0.78, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 1), Color(0.75, 0.75, 0.75, 1), Color(1, 1, 1, 1)])
	var ct := NoiseTexture2D.new()
	ct.width = 1024
	ct.height = 512
	ct.seamless = true
	ct.noise = cn
	ct.color_ramp = grad
	sky_mat.sky_cover = ct
	sky_mat.sky_cover_modulate = Color(1, 1, 1, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.35
	env.fog_sky_affect = 0.75
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	sun.shadow_blur = 1.2
	add_child(sun)
	# chuva
	rain_fx = CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.55, 0.018)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.78, 0.84, 0.9, 0.34)
	bm.material = rm
	rain_fx.mesh = bm
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(16, 0.5, 16)
	rain_fx.direction = Vector3(0.08, -1, 0.03)
	rain_fx.spread = 2.0
	rain_fx.gravity = Vector3(0, -6, 0)
	rain_fx.initial_velocity_min = 19.0
	rain_fx.initial_velocity_max = 24.0
	rain_fx.lifetime = 0.75
	rain_fx.amount = 700
	rain_fx.local_coords = false
	rain_fx.emitting = false
	add_child(rain_fx)
	_last_min = G.time_min
	apply_graphics()
	G.settings_changed.connect(apply_graphics)
	_update_sky(1.0)


func apply_graphics() -> void:
	var g := int(G.settings["graphics"])
	draw_dist = [95.0, 135.0, 185.0][clampi(g, 0, 2)]
	sun.shadow_enabled = g >= 1
	sun.directional_shadow_max_distance = [0.0, 48.0, 80.0][clampi(g, 0, 2)]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if g >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	env.glow_enabled = g >= 2
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	rain_fx.amount = [320, 600, 950][clampi(g, 0, 2)]
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_DISABLED if g == 0 else Viewport.MSAA_2X
		vp.scaling_3d_scale = 0.8 if g == 0 else 1.0


func raining() -> bool:
	return rain > 0.15


func light_level() -> float:
	return clampf(G.daylight() * (1.0 - cloud * 0.35) * (1.0 - fog * 0.3) + 0.06, 0.0, 1.0)


func temperature() -> float:
	var yf := G.year_frac()
	var t := 19.0 + 7.5 * cos(TAU * (yf - 0.04))
	t += 5.0 * cos((G.hour() - 15.0) / 24.0 * TAU)
	t -= rain * 4.0 + cloud * 1.5 + fog * 1.5
	t -= wind * 1.5
	return t


func set_weather(w: String, minutes: float = -1.0) -> void:
	weather = w
	weather_left = minutes if minutes > 0.0 else rng.randf_range(120.0, 420.0)


func _pick_weather() -> void:
	var rainm := float(G.sandbox.get("rain", 1.0))
	var h := G.hour()
	var winter := G.season_name() == "inverno"
	var opts := [["limpo", 44.0], ["nublado", 22.0], ["chuva", 16.0 * rainm], ["tempestade", 5.0 * rainm],
		["neblina", (22.0 if (h < 9.0 or h > 20.0) else 6.0) * (1.5 if winter else 1.0)]]
	var tot := 0.0
	for o in opts:
		tot += float(o[1])
	var r := rng.randf() * tot
	for o in opts:
		r -= float(o[1])
		if r <= 0.0:
			set_weather(o[0])
			return
	set_weather("limpo")


func _process(dt: float) -> void:
	if not G.in_game or G.paused:
		return
	_t += dt
	var dm := G.time_min - _last_min
	_last_min = G.time_min
	weather_left -= dm
	if weather_left <= 0.0:
		_pick_weather()
	var tr := 0.0
	var tf := 0.0
	var tc := 0.0
	var tw := 0.25
	match weather:
		"nublado":
			tc = 0.7
			tw = 0.4
		"chuva":
			tr = 0.6
			tc = 0.9
			tw = 0.5
			tf = 0.25
		"tempestade":
			tr = 1.0
			tc = 1.0
			tw = 0.95
			tf = 0.3
		"neblina":
			tf = 1.0
			tc = 0.4
			tw = 0.1
	var k := clampf(dt * 0.25 * maxf(1.0, G.time_mult * 0.2), 0.0, 1.0)
	rain = lerpf(rain, tr, k)
	fog = lerpf(fog, tf, k)
	cloud = lerpf(cloud, tc, k)
	wind = lerpf(wind, tw + 0.1 * sin(_t * 0.07), k)
	if weather == "tempestade" and rng.randf() < dt * 0.06:
		flash = 1.0
	flash = maxf(0.0, flash - dt * 2.5)
	_update_sky(dt)
	_update_fx(dt)


func _update_sky(_dt: float) -> void:
	var h := G.hour()
	var dl := G.daylight()
	var t := clampf((h - 5.5) / 14.0, 0.0, 1.0)
	var night := dl <= 0.02
	var golden := clampf(1.0 - absf(dl - 0.35) / 0.35, 0.0, 1.0) * (1.0 if dl < 0.8 else 0.0)
	# posicao do sol / lua
	var ang := t * PI
	var sp := Vector3(cos(ang) * 0.9, maxf(0.12, sin(ang)), 0.38).normalized()
	if night:
		var tn := fmod(h + 4.5, 24.0) / 10.0
		sp = Vector3(cos(tn * PI) * 0.7, maxf(0.35, sin(tn * PI)), -0.4).normalized()
	sun.look_at_from_position(sp * 100.0, Vector3.ZERO, Vector3.UP)
	var day_top := Color(0.22, 0.42, 0.74)
	var day_hor := Color(0.62, 0.73, 0.84)
	var gray := Color(0.50, 0.53, 0.57)
	var top := Color(0.012, 0.018, 0.04).lerp(day_top, dl)
	var hor := Color(0.03, 0.04, 0.07).lerp(day_hor, dl)
	hor = hor.lerp(Color(0.96, 0.56, 0.30), golden * 0.75 * (1.0 - cloud * 0.8))
	top = top.lerp(Color(0.36, 0.30, 0.45), golden * 0.35 * (1.0 - cloud * 0.8))
	var ov := maxf(cloud * 0.85, fog * 0.9)
	top = top.lerp(gray * (0.08 + 0.92 * dl), ov)
	hor = hor.lerp(gray * (0.10 + 1.0 * dl), ov)
	if flash > 0.0:
		top = top.lerp(Color(0.8, 0.85, 1.0), flash * 0.7)
		hor = hor.lerp(Color(0.9, 0.92, 1.0), flash * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.3)
	sky_mat.sun_angle_max = 28.0 * (1.0 - ov)
	# luz direta e ambiente
	var sun_col := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.36), golden * 0.8)
	if night:
		sun.light_color = Color(0.55, 0.65, 0.95)
		sun.light_energy = 0.16 * (1.0 - cloud * 0.6)
	else:
		sun.light_color = sun_col
		sun.light_energy = (0.25 + 1.15 * dl) * (1.0 - cloud * 0.72) * (1.0 - fog * 0.4)
	sun.light_energy += flash * 2.0
	# ambiente mais neutro (interiores nao ficam azulados) e nuvens conforme o clima
	env.ambient_light_color = hor.lerp(top, 0.3).lerp(Color(0.86, 0.86, 0.84), 0.55 if not night else 0.2)
	env.ambient_light_energy = lerpf(0.30, 0.78, dl) + flash
	var cl := clampf(0.28 + cloud * 0.6, 0.0, 1.0) * (0.12 + 0.88 * dl)
	sky_mat.sky_cover_modulate = Color(cl, cl, cl * 1.02, 1.0).lerp(Color(cl, cl * 0.72, cl * 0.5, 1.0), golden * 0.6)
	# neblina (a "bruma" tambem esconde o limite de carregamento do mapa)
	var far := draw_dist * lerpf(1.0, 0.36, fog) * lerpf(1.0, 0.72, rain) * lerpf(0.72, 1.0, dl)
	env.fog_light_color = hor.lerp(gray * (0.12 + 0.9 * dl), 0.35)
	env.fog_depth_begin = far * lerpf(0.34, 0.06, fog)
	env.fog_depth_end = far
	env.fog_light_energy = 1.0


func _update_fx(_dt: float) -> void:
	var p: Node3D = G.player
	if p == null or not is_instance_valid(p):
		return
	var indoors: bool = p.indoors
	rain_fx.emitting = rain > 0.08
	if rain_fx.emitting:
		rain_fx.global_position = p.cam.global_position + Vector3(0, 11.0, 0) - p.cam.global_basis.z * 6.0
		rain_fx.speed_scale = 1.0
	var amb_out := 0.35 if indoors else 1.0
	Sfx.loop("rain", "rain_loop", rain * 0.9 * amb_out)
	Sfx.loop("wind", "wind_loop", (0.10 + wind * 0.55) * amb_out)
	var zone: int = G.world.zone_at(p.global_position.x, p.global_position.z) if G.world != null else 0
	var forest := 0.0
	if zone == WorldGen.Z_FOREST and not indoors:
		forest = 0.35 + wind * 0.4
	Sfx.loop("forest", "forest_loop", forest)
	var river := 0.0
	if G.world != null:
		var dr: float = G.world.river_dist(p.global_position.x, p.global_position.z)
		river = clampf(1.0 - dr / 45.0, 0.0, 1.0) * 0.7 * amb_out
	Sfx.loop("river", "river_loop", river)
	Sfx.loop("room", "room_tone", 0.3 if indoors else 0.0)
	if bool(G.settings["music_on"]):
		Sfx.music("music_tension" if p._threat >= 3 else "music_calm")
	else:
		Sfx.music("")


func to_dict() -> Dictionary:
	return {"weather": weather, "left": weather_left, "rain": rain, "fog": fog, "cloud": cloud}


func from_dict(d: Dictionary) -> void:
	weather = d.get("weather", "limpo")
	weather_left = d.get("left", 120.0)
	rain = d.get("rain", 0.0)
	fog = d.get("fog", 0.0)
	cloud = d.get("cloud", 0.0)
	_last_min = G.time_min
