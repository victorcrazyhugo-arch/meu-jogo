class_name Vehicle
extends CharacterBody3D
## Veiculo dirigivel. Modelo cinematico "arcade com peso": direcao tipo bicicleta com esterco
## maximo limitado pela aderencia, aceleracao pela potencia do motor, arrasto e resistencia
## de rolagem conforme o piso, e transferencia de carga visivel na carroceria.
## Pecas com condicao, combustivel, bateria, porta-malas e servicos de mecanica.
## Parado e sem motorista o veiculo nao executa fisica (fica "dormindo").

const MAX_STEER := 0.60          # rad
const LIGHT_DRAIN := 0.0021      # carga por minuto de jogo com farois acesos e motor desligado
const CHARGE_RATE := 0.012       # carga por minuto de jogo com o motor ligado
const EXIT_SPEED := 2.5          # m/s: acima disso nao se sai do veiculo (exceto forcado ou morto)

const TYRES := ["pneu_de", "pneu_dd", "pneu_te", "pneu_td"]
const PARTS := ["motor", "bateria", "tanque", "escapamento", "freios", "suspensao", "pneu_de", "pneu_dd", "pneu_te", "pneu_td",
	"capo", "portas", "vidros", "farois", "porta_malas"]
const PART_NAMES := {"motor": "Motor", "bateria": "Bateria", "tanque": "Tanque de combustível", "escapamento": "Escapamento",
	"freios": "Freios", "suspensao": "Suspensão", "pneu_de": "Pneu dianteiro esquerdo", "pneu_dd": "Pneu dianteiro direito",
	"pneu_te": "Pneu traseiro esquerdo", "pneu_td": "Pneu traseiro direito", "capo": "Capô", "portas": "Portas", "vidros": "Vidros",
	"farois": "Faróis", "porta_malas": "Porta-malas"}
const TOOL_NAMES := {"chave_inglesa": "chave inglesa", "chave_roda": "chave de roda", "macaco": "macaco hidráulico",
	"chave_fenda": "chave de fenda", "martelo": "martelo", "mangueira": "mangueira"}

## Pecas removiveis: item correspondente, ferramentas, habilidade/nivel, tempo base (s) e XP.
const SWAP := {
	"bateria": {"item": "bateria_carro", "lab": "bateria", "tools": ["chave_fenda"], "sk": "eletrica", "lvl": 0, "t": 6.0, "xp": 6.0},
	"escapamento": {"item": "escapamento", "lab": "escapamento", "tools": ["chave_inglesa"], "sk": "mecanica", "lvl": 1, "t": 12.0, "xp": 10.0},
	"freios": {"item": "freio", "lab": "freios", "tools": ["chave_inglesa", "macaco"], "sk": "mecanica", "lvl": 2, "t": 16.0, "xp": 14.0},
	"suspensao": {"item": "suspensao", "lab": "suspensão", "tools": ["chave_inglesa", "macaco"], "sk": "mecanica", "lvl": 3, "t": 20.0, "xp": 18.0},
	"pneu": {"item": "pneu", "lab": "pneu", "tools": ["chave_roda", "macaco"], "sk": "mecanica", "lvl": 0, "t": 10.0, "xp": 8.0},
}
## Reparos com material: item consumido, ferramentas, habilidade/nivel, ganho e teto de condicao.
const FIX := {
	"motor": {"label": "Reparar motor (1 peça de motor)", "item": "peca_motor", "tools": ["chave_inglesa"], "sk": "mecanica", "lvl": 2, "gain": 0.14, "max": 1.0, "t": 14.0, "xp": 16.0},
	"tanque": {"label": "Remendar tanque (fita adesiva)", "item": "fita", "tools": [], "sk": "mecanica", "lvl": 1, "gain": 0.25, "max": 0.8, "t": 7.0, "xp": 8.0},
	"capo": {"label": "Desamassar capô (1 chapa de metal)", "item": "chapa_metal", "tools": ["martelo"], "sk": "mecanica", "lvl": 1, "gain": 0.30, "max": 1.0, "t": 10.0, "xp": 9.0},
	"portas": {"label": "Consertar portas (1 chapa de metal)", "item": "chapa_metal", "tools": ["martelo"], "sk": "mecanica", "lvl": 1, "gain": 0.30, "max": 1.0, "t": 10.0, "xp": 9.0},
	"porta_malas": {"label": "Consertar porta-malas (1 chapa de metal)", "item": "chapa_metal", "tools": ["martelo"], "sk": "mecanica", "lvl": 1, "gain": 0.30, "max": 1.0, "t": 9.0, "xp": 8.0},
	"farois": {"label": "Trocar lâmpadas (1 lâmpada)", "item": "lampada", "tools": ["chave_fenda"], "sk": "eletrica", "lvl": 0, "gain": 0.5, "max": 1.0, "t": 6.0, "xp": 6.0},
}

## Dados por tipo. Frente do veiculo = -Z. Medidas em metros; "acc" m/s2, "top" m/s, "tank" litros, "trunk" kg.
## Perfil da carroceria: yb base, belt linha de cintura, roof teto, ws/rw base do para-brisa/vidro traseiro,
## rf/rr inicio/fim do teto, tuck recuo lateral do teto, bed inicio da cacamba.
const SPECS := {
	"sedan": {"n": "Sedã", "fem": false, "style": "sedan", "len": 4.40, "wid": 1.76, "wr": 0.31, "ax_f": -1.36, "ax_r": 1.26,
		"mass": 1250.0, "acc": 4.3, "top": 41.0, "tank": 50.0, "trunk": 45.0, "cons": 1.0,
		"yb": 0.26, "belt": 0.84, "roof": 1.40, "ws": -0.74, "rf": -0.20, "rr": 0.88, "rw": 1.40, "tuck": 0.16, "seat": Vector3(-0.39, 0.0, 0.16)},
	"hatch": {"n": "Hatch", "fem": false, "style": "hatch", "len": 3.80, "wid": 1.68, "wr": 0.29, "ax_f": -1.22, "ax_r": 1.22,
		"mass": 1000.0, "acc": 4.5, "top": 38.0, "tank": 42.0, "trunk": 30.0, "cons": 0.85,
		"yb": 0.25, "belt": 0.85, "roof": 1.44, "ws": -0.66, "rf": -0.14, "rr": 1.48, "rw": 1.82, "tuck": 0.15, "seat": Vector3(-0.37, 0.0, 0.18)},
	"picape": {"n": "Picape", "fem": true, "style": "pickup", "len": 5.10, "wid": 1.90, "wr": 0.37, "ax_f": -1.62, "ax_r": 1.52,
		"mass": 1900.0, "acc": 3.7, "top": 37.0, "tank": 75.0, "trunk": 120.0, "cons": 1.4,
		"yb": 0.38, "belt": 1.10, "roof": 1.78, "ws": -1.16, "rf": -0.72, "rr": 0.30, "rw": 0.36, "tuck": 0.12, "bed": 0.44, "seat": Vector3(-0.42, 0.22, -0.28)},
	"van": {"n": "Van", "fem": true, "style": "van", "len": 5.00, "wid": 1.94, "wr": 0.34, "ax_f": -1.70, "ax_r": 1.40,
		"mass": 2100.0, "acc": 3.1, "top": 33.0, "tank": 70.0, "trunk": 150.0, "cons": 1.5,
		"yb": 0.32, "belt": 1.04, "roof": 2.04, "ws": -2.04, "rf": -1.58, "rr": -0.80, "rw": -0.80, "tuck": 0.035, "seat": Vector3(-0.44, 0.26, -1.18)},
	"utilitario": {"n": "Utilitário", "fem": false, "style": "suv", "len": 4.55, "wid": 1.86, "wr": 0.36, "ax_f": -1.38, "ax_r": 1.32,
		"mass": 1700.0, "acc": 3.9, "top": 39.0, "tank": 62.0, "trunk": 75.0, "cons": 1.25,
		"yb": 0.34, "belt": 1.00, "roof": 1.70, "ws": -0.86, "rf": -0.40, "rr": 1.96, "rw": 2.20, "tuck": 0.12, "seat": Vector3(-0.41, 0.14, 0.05)},
	"policia": {"n": "Viatura policial", "fem": true, "style": "sedan", "extra": "policia", "col": 0, "len": 4.40, "wid": 1.76, "wr": 0.31, "ax_f": -1.36, "ax_r": 1.26,
		"mass": 1350.0, "acc": 5.0, "top": 46.0, "tank": 55.0, "trunk": 45.0, "cons": 1.15,
		"yb": 0.26, "belt": 0.84, "roof": 1.40, "ws": -0.74, "rf": -0.20, "rr": 0.88, "rw": 1.40, "tuck": 0.16, "seat": Vector3(-0.39, 0.0, 0.16)},
	"ambulancia": {"n": "Ambulância", "fem": true, "style": "van", "extra": "ambulancia", "col": 0, "len": 5.00, "wid": 1.94, "wr": 0.34, "ax_f": -1.70, "ax_r": 1.40,
		"mass": 2300.0, "acc": 3.3, "top": 35.0, "tank": 75.0, "trunk": 130.0, "cons": 1.55,
		"yb": 0.32, "belt": 1.04, "roof": 2.04, "ws": -2.04, "rf": -1.58, "rr": -0.80, "rw": -0.80, "tuck": 0.035, "seat": Vector3(-0.44, 0.26, -1.18)},
}

## 12 cores de carroceria (sRGB) com nome no masculino/feminino e peso de sorteio.
const COLORS := [Color(0.90, 0.90, 0.87), Color(0.63, 0.65, 0.67), Color(0.34, 0.36, 0.38), Color(0.08, 0.08, 0.09),
	Color(0.70, 0.11, 0.10), Color(0.40, 0.08, 0.13), Color(0.15, 0.32, 0.64), Color(0.09, 0.14, 0.32),
	Color(0.14, 0.38, 0.24), Color(0.74, 0.67, 0.50), Color(0.87, 0.70, 0.13), Color(0.82, 0.40, 0.11)]
const COLOR_NAMES := [["branco", "branca"], ["prata", "prata"], ["cinza", "cinza"], ["preto", "preta"],
	["vermelho", "vermelha"], ["vinho", "vinho"], ["azul", "azul"], ["azul-marinho", "azul-marinho"],
	["verde", "verde"], ["bege", "bege"], ["amarelo", "amarela"], ["laranja", "laranja"]]
const COLOR_WEIGHTS := [18, 16, 12, 12, 9, 5, 8, 5, 4, 5, 3, 3]

static var _paint: StandardMaterial3D
static var _mesh_cache := {}     # "tipo:cor" -> malha da carroceria
static var _aux_cache := {}      # tipo -> {glass, glow, brake}
static var _wheel_cache := {}    # raio em cm -> malha da roda
static var _shape_cache := {}    # tipo -> BoxShape3D
static var _probe: CapsuleShape3D

# ---- campos publicos
var id := -1
var type := "sedan"
var spec: Dictionary = SPECS["sedan"]
var state: Dictionary = {}       # dicionario persistente (mesma referencia guardada pelo gerenciador)
var parts: Dictionary = {}       # chave da peca -> condicao 0..1 (-1 = ausente)
var press: Dictionary = {}       # chave do pneu -> pressao 0..1 (1 = 32 psi)
var insp: Dictionary = {}        # pecas ja inspecionadas
var trunk: Array = []            # itens no porta-malas
var trunk_cap := 45.0
var display_name := "Veículo"
var speed := 0.0                 # m/s; negativo = re
var steer := 0.0                 # angulo de esterco atual (rad; positivo = esquerda)
var fuel := 0.0
var fuel_cap := 50.0
var battery := 0.0               # carga 0..1
var engine_on := false
var lights_on := false
var locked := false
var has_key := false             # chave na ignicao
var hotwired := false
var driver: Node3D = null

# ---- nos
var body: Node3D
var wheels: Array = []
var _glass: MeshInstance3D
var _glow: MeshInstance3D
var _brake_mi: MeshInstance3D
var _lamps: Array = []

# ---- medidas em cache
var _len := 4.4
var _wid := 1.76
var _wb := 2.62
var _wr := 0.31
var _ax_f := -1.36
var _ax_r := 1.26
var _mass := 1250.0
var _seat := Vector3(-0.39, 0.0, 0.16)
var _c_air := 0.0007
var _desktop := false

# ---- fatores derivados das pecas e do piso (atualizados a 5 Hz)
var _ft := 0.0
var _acc := 4.0
var _vt := 50.0
var _grip := 1.0
var _brake := 9.0
var _roll_res := 0.3
var _roll_v := 0.0
var _rough := 0.0
var _pull := 0.0
var _soft := 1.0
var _zeta := 0.7
var _loud := 1.0
var _bat_max := 1.0
var _tilt_p := 0.0
var _tilt_r := 0.0

# ---- estado dinamico
var _awake := false
var _t_last := 0.0
var _pitch := 0.0
var _roll := 0.0
var _pv := 0.0
var _rv := 0.0
var _spin := 0.0
var _steer_vis := 0.0
var _start_cd := 0.0
var _crash_cd := 0.0
var _skid_cd := 0.0
var _noise_t := 0.0
var _horn_ms := 0
var _loop_nm := ""
var _loop_want := ""
var _loop_t := 0.0
var _snd_pitch := 1.0
var _rest_t := 0.0
var _hit_t := {}                 # id do zumbi -> instante (ms) ate o qual nao e atingido de novo


# =====================================================================================
#  ESTADO PERSISTENTE
# =====================================================================================
## Cria o estado inicial deterministico de um carro do mundo.
static func new_state(car_id: int, car_type: String, pos: Vector3, rot: float, seed_v: int) -> Dictionary:
	var t := car_type if SPECS.has(car_type) else "sedan"
	var sp: Dictionary = SPECS[t]
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var ci := 0
	if sp.has("col"):
		ci = int(sp["col"])
		r.randi()
	else:
		var tot := 0
		for w in COLOR_WEIGHTS:
			tot += int(w)
		var pick := r.randi() % tot
		for i in COLOR_WEIGHTS.size():
			pick -= int(COLOR_WEIGHTS[i])
			if pick < 0:
				ci = i
				break
	var p := {}
	var pr := {}
	p["motor"] = _r2(r.randf_range(0.05, 0.3) if r.randf() < 0.08 else r.randf_range(0.3, 1.0))
	p["bateria"] = -1.0 if r.randf() < 0.07 else _r2(r.randf_range(0.3, 1.0))
	p["tanque"] = _r2(r.randf_range(0.5, 1.0))
	p["escapamento"] = -1.0 if r.randf() < 0.05 else _r2(r.randf_range(0.3, 1.0))
	p["freios"] = _r2(r.randf_range(0.3, 1.0))
	p["suspensao"] = _r2(r.randf_range(0.3, 1.0))
	for tk in TYRES:
		var roll := r.randf()
		var c := _r2(r.randf_range(0.3, 1.0))
		var ps := _r2(r.randf_range(0.55, 1.0))
		if roll < 0.03:
			c = -1.0
			ps = 0.0
		elif roll < 0.10:
			ps = 0.0
		p[tk] = c
		pr[tk] = ps
	p["capo"] = _r2(r.randf_range(0.5, 1.0))
	p["portas"] = _r2(r.randf_range(0.5, 1.0))
	p["vidros"] = 0.0 if r.randf() < 0.08 else _r2(r.randf_range(0.6, 1.0))
	p["farois"] = 0.0 if r.randf() < 0.08 else _r2(r.randf_range(0.4, 1.0))
	p["porta_malas"] = _r2(r.randf_range(0.5, 1.0))
	var tank: float = sp["tank"]
	var fuel_v := clampf(r.randf_range(0.0, 0.7) * tank * float(G.sandbox.get("fuel", 1.0)), 0.0, tank)
	var bat := 0.0
	var dead_bat := r.randf() < 0.15
	var chg := r.randf_range(0.3, 1.0)
	if float(p["bateria"]) > 0.0:
		bat = r.randf_range(0.0, 0.05) if dead_bat else minf(chg, float(p["bateria"]))
	var key := r.randf() < 0.12
	var unlocked := key or r.randf() < 0.15
	var q := _r2(r.randf_range(0.8, 1.15))
	var loot: Array = Items.roll_loot("porta_malas", seed_v + 7)
	if t == "policia":
		loot.append_array(Items.roll_loot("zumbi_policia", seed_v + 11))
	elif t == "ambulancia":
		loot.append_array(Items.roll_loot("zumbi_medico", seed_v + 11))
	return {"id": car_id, "type": t, "pos": Vector3(pos.x, 0.0, pos.z), "rot": rot, "col": ci, "q": q,
		"fuel": snappedf(fuel_v, 0.1), "bat": _r2(bat), "parts": p, "press": pr, "key": key, "locked": not unlocked,
		"hot": false, "lights": false, "trunk": loot, "insp": {}, "xp": {}, "t": G.time_min}


static func _r2(v: float) -> float:
	return snappedf(v, 0.01)


## Garante que um estado (salvo antigo ou parcial) tenha todas as chaves.
static func fill_defaults(st: Dictionary) -> void:
	var base := {"id": -1, "type": "sedan", "pos": Vector3.ZERO, "rot": 0.0, "col": 0, "q": 1.0, "fuel": 0.0, "bat": 0.0,
		"key": false, "locked": false, "hot": false, "lights": false, "t": G.time_min}
	for k in base:
		if not st.has(k):
			st[k] = base[k]
	for k2 in ["parts", "press", "insp", "xp"]:
		if not st.has(k2) or typeof(st[k2]) != TYPE_DICTIONARY:
			st[k2] = {}
	if not st.has("trunk") or typeof(st["trunk"]) != TYPE_ARRAY:
		st["trunk"] = []
	var p: Dictionary = st["parts"]
	for k3 in PARTS:
		if not p.has(k3):
			p[k3] = 1.0
	var pr: Dictionary = st["press"]
	for k4 in TYRES:
		if not pr.has(k4):
			pr[k4] = 0.9


static func name_for(vtype: String, ci: int) -> String:
	var sp: Dictionary = SPECS.get(vtype, SPECS["sedan"])
	if sp.has("col"):
		return String(sp["n"])
	var cn: Array = COLOR_NAMES[clampi(ci, 0, COLOR_NAMES.size() - 1)]
	return "%s %s" % [sp["n"], cn[1] if sp["fem"] else cn[0]]


func setup(st: Dictionary) -> void:
	state = st
	fill_defaults(st)
	type = String(st["type"])
	if not SPECS.has(type):
		type = "sedan"
		st["type"] = type
	spec = SPECS[type]
	if spec.has("col"):
		st["col"] = int(spec["col"])
	id = int(st["id"])
	parts = st["parts"]
	press = st["press"]
	insp = st["insp"]
	trunk = st["trunk"]
	fuel_cap = float(spec["tank"])
	trunk_cap = float(spec["trunk"])
	fuel = clampf(float(st["fuel"]), 0.0, fuel_cap)
	battery = clampf(float(st["bat"]), 0.0, 1.0)
	has_key = bool(st["key"])
	locked = bool(st["locked"])
	hotwired = bool(st["hot"])
	lights_on = bool(st["lights"])
	engine_on = false
	speed = 0.0
	steer = 0.0
	velocity = Vector3.ZERO
	_len = float(spec["len"])
	_wid = float(spec["wid"])
	_wr = float(spec["wr"])
	_ax_f = float(spec["ax_f"])
	_ax_r = float(spec["ax_r"])
	_wb = _ax_r - _ax_f
	_mass = float(spec["mass"])
	_seat = spec["seat"]
	var top: float = spec["top"]
	_c_air = maxf(0.0002, (0.36 * float(spec["acc"]) - 0.3) / (top * top))
	display_name = name_for(type, int(st["col"]))
	var pos: Vector3 = st["pos"]
	position = Vector3(pos.x, 0.0, pos.z)
	rotation = Vector3(0.0, float(st["rot"]), 0.0)
	_t_last = float(st["t"])
	_refresh()
	if is_inside_tree():
		_build()
	_settle()


## Grava o estado atual no dicionario persistente.
func save_state() -> void:
	_settle()
	var pos := global_position if is_inside_tree() else position
	state["pos"] = Vector3(pos.x, 0.0, pos.z)
	state["rot"] = rotation.y
	state["fuel"] = fuel
	state["bat"] = battery
	state["key"] = has_key
	state["locked"] = locked
	state["hot"] = hotwired
	state["lights"] = lights_on
	state["parts"] = parts
	state["press"] = press
	state["insp"] = insp
	state["trunk"] = trunk
	state["t"] = G.time_min


# =====================================================================================
#  NOS E MODELO
# =====================================================================================
func _ready() -> void:
	collision_layer = G.L_VEHICLE
	collision_mask = G.L_WORLD | G.L_GLASS | G.L_VEHICLE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	axis_lock_linear_y = true
	_desktop = not OS.has_feature("mobile")
	if state.is_empty():
		setup({})
	else:
		_build()
	_awake = false
	set_physics_process(false)


func _exit_tree() -> void:
	_stop_loop()


func _build() -> void:
	Mats.init()
	for ch in get_children():
		ch.queue_free()
	wheels.clear()
	_lamps.clear()
	var roof: float = spec["roof"]
	var cs := CollisionShape3D.new()
	if not _shape_cache.has(type):
		var bs := BoxShape3D.new()
		bs.size = Vector3(_wid, roof + 0.03 - 0.30, _len)
		_shape_cache[type] = bs
	cs.shape = _shape_cache[type]
	cs.position = Vector3(0.0, (roof + 0.03 + 0.30) * 0.5, 0.0)
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var ci: int = state["col"]
	var bm := MeshInstance3D.new()
	bm.mesh = _body_mesh(type, ci)
	body.add_child(bm)
	var aux: Dictionary = _aux_cache[type]
	_glass = MeshInstance3D.new()
	_glass.mesh = aux["glass"]
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(_glass)
	_glow = MeshInstance3D.new()
	_glow.mesh = aux["glow"]
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	body.add_child(_glow)
	_brake_mi = MeshInstance3D.new()
	_brake_mi.mesh = aux["brake"]
	_brake_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brake_mi.visible = false
	body.add_child(_brake_mi)
	var wm := _wheel_mesh(_wr)
	var wx := _wid * 0.5 - 0.075
	for i in 4:
		var w := MeshInstance3D.new()
		w.mesh = wm
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position = Vector3(-wx if i % 2 == 0 else wx, _wr, _ax_f if i < 2 else _ax_r)
		add_child(w)
		wheels.append(w)
	_refresh_visual()
	_apply_lights()


## Atualiza o que depende das pecas: rodas ausentes, vidros quebrados e inclinacao da carroceria.
func _refresh_visual() -> void:
	if body == null:
		return
	for i in wheels.size():
		var w: MeshInstance3D = wheels[i]
		w.visible = float(parts[TYRES[i]]) >= 0.0
	_glass.visible = float(parts["vidros"]) > 0.0
	_pose_wheels()
	body.rotation = Vector3(_pitch + _tilt_p, 0.0, _roll + _tilt_r)


func _pose_wheels() -> void:
	for i in wheels.size():
		var w: MeshInstance3D = wheels[i]
		var st := _steer_vis if i < 2 else 0.0
		if i % 2 == 0:
			w.rotation = Vector3(_spin, st, 0.0)
		else:
			w.rotation = Vector3(-_spin, PI + st, 0.0)


func _apply_lights() -> void:
	if body == null:
		return
	var fc := part_cond("farois")
	var on := lights_on and battery > 0.0 and fc > 0.0
	if on and _lamps.is_empty():
		var ly: float = float(spec["belt"]) - 0.17
		for i in 2:
			var l := SpotLight3D.new()
			l.spot_range = 38.0
			l.spot_angle = 34.0
			l.light_color = Color(1.0, 0.96, 0.86)
			l.shadow_enabled = false
			l.position = Vector3((-1.0 if i == 0 else 1.0) * (_wid * 0.5 - 0.26), ly, -_len * 0.5 - 0.08)
			l.rotation = Vector3(-0.055, 0.0, 0.0)
			add_child(l)
			_lamps.append(l)
	for i in _lamps.size():
		var lamp: SpotLight3D = _lamps[i]
		lamp.visible = on and (i == 1 or fc >= 0.45)     # com farois muito danificados so um acende
		lamp.light_energy = 2.4 * (0.55 + 0.45 * fc)
	_glow.visible = on


static func _body_mesh(vtype: String, ci: int) -> ArrayMesh:
	var key := "%s:%d" % [vtype, ci]
	if _mesh_cache.has(key) and _aux_cache.has(vtype):
		return _mesh_cache[key]
	Mats.init()
	if _paint == null:
		_paint = StandardMaterial3D.new()
		_paint.vertex_color_use_as_albedo = true
		_paint.vertex_color_is_srgb = true
		_paint.roughness = 0.42
		_paint.metallic_specular = 0.5
	var col: Color = COLORS[clampi(ci, 0, COLORS.size() - 1)]
	var mbs := build_mbs(vtype, col)
	var mesh: ArrayMesh = mbs[0].to_mesh(_paint)
	_mesh_cache[key] = mesh
	if not _aux_cache.has(vtype):
		_aux_cache[vtype] = {"glass": mbs[1].to_mesh(Mats.glass), "glow": mbs[2].to_mesh(Mats.glow), "brake": mbs[3].to_mesh(Mats.glow)}
	return mesh


static func _wheel_mesh(r: float) -> ArrayMesh:
	var key := roundi(r * 100.0)
	if _wheel_cache.has(key):
		return _wheel_cache[key]
	Mats.init()
	var mesh := build_wheel(r).to_mesh(Mats.flat)
	_wheel_cache[key] = mesh
	return mesh


## Roda com eixo em X; a face de fora (calota) fica em -X (lado esquerdo do veiculo).
static func build_wheel(r: float) -> MB:
	var t := MB.new()
	var w := 0.22 if r < 0.34 else 0.25
	var tyre := Color(0.07, 0.07, 0.075)
	t.tube(0.0, 0.0, -w * 0.5, w * 0.5, Vector2(r, r), Vector2(r, r), tyre, 10, true, true)
	# calota com gomos alternados: deixa o giro visivel
	var rr := r * 0.64
	var y := w * 0.5 + 0.012
	for i in 6:
		var a0 := TAU * float(i) / 6.0
		var a1 := TAU * float(i + 1) / 6.0
		var c := Color(0.62, 0.63, 0.65) if i % 2 == 0 else Color(0.30, 0.31, 0.33)
		t.tri_auto(Vector3(0.0, y, 0.0), Vector3(cos(a0) * rr, y, sin(a0) * rr), Vector3(cos(a1) * rr, y, sin(a1) * rr), Vector3.UP, c)
	var m := MB.new()
	var xf := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)      # +Y -> -X
	for i in t.v.size():
		m.v.append(xf * t.v[i])
		m.n.append((xf.basis * t.n[i]).normalized())
		m.c.append(t.c[i])
	for i in t.ix.size():
		m.ix.append(t.ix[i])
	return m


static func _face_z(m: MB, x0: float, x1: float, y0: float, y1: float, z: float, dir: float, col: Color) -> void:
	m.quad_auto(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), Vector3(0.0, 0.0, dir), col)


static func _face_x(m: MB, z0: float, z1: float, y0: float, y1: float, x: float, dir: float, col: Color) -> void:
	m.quad_auto(Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0), Vector3(dir, 0.0, 0.0), col)


static func _quad_hint(m: MB, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, col: Color) -> void:
	var nor := (b - a).cross(c - a).normalized()
	if nor.dot(hint) < 0.0:
		nor = -nor
	m.quad_auto(a, b, c, d, nor, col)


## Coluna de secao quadrada (4 faces, sem tampas) entre dois pontos.
static func _beam(m: MB, a: Vector3, b: Vector3, t: float, col: Color) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.RIGHT)
	if u.length() < 0.01:
		u = d.cross(Vector3.UP)
	u = u.normalized()
	var w := d.cross(u).normalized()
	var hu := u * (t * 0.5)
	var hv := w * (t * 0.5)
	m.quad_auto(a + hu - hv, a + hu + hv, b + hu + hv, b + hu - hv, u, col)
	m.quad_auto(a - hu - hv, a - hu + hv, b - hu + hv, b - hu - hv, -u, col)
	m.quad_auto(a + hv - hu, a + hv + hu, b + hv + hu, b + hv - hu, w, col)
	m.quad_auto(a - hv - hu, a - hv + hu, b - hv + hu, b - hv - hu, -w, col)


## Constroi as malhas de um tipo: [pintura, vidros, luzes acesas, luz de freio].
static func build_mbs(vtype: String, col: Color) -> Array:
	var sp: Dictionary = SPECS[vtype]
	var m := MB.new()
	var g := MB.new()
	var e := MB.new()
	var b := MB.new()
	var style: String = sp["style"]
	var extra: String = sp.get("extra", "")
	var hl: float = float(sp["len"]) * 0.5
	var hw: float = float(sp["wid"]) * 0.5
	var yb: float = sp["yb"]
	var belt: float = sp["belt"]
	var roof: float = sp["roof"]
	var wr: float = sp["wr"]
	var zf: float = sp["ax_f"]
	var zr: float = sp["ax_r"]
	var ws: float = sp["ws"]
	var rf: float = sp["rf"]
	var rr: float = sp["rr"]
	var rw: float = sp["rw"]
	var tuck: float = sp["tuck"]
	var seat: Vector3 = sp["seat"]
	var bed: float = sp.get("bed", 99.0)
	var dark := Color(0.09, 0.09, 0.10)
	var trim := Color(0.20, 0.20, 0.21)
	var inner := Color(0.17, 0.17, 0.19)
	var seam := col.darkened(0.6)
	var white := Color.WHITE
	var tall := style == "suv" or style == "pickup" or style == "van"
	var four_doors := style == "sedan" or style == "hatch" or style == "suv"

	# ---- carroceria inferior, com recortes reais para as rodas
	var a := wr + 0.08
	var y_arch := wr * 2.0 + 0.07
	var cuts: Array = [-hl, zf - a, zf + a, zr - a, zr + a, hl]
	if bed < 90.0:
		cuts.insert(3, bed)
	for i in cuts.size() - 1:
		var z0: float = cuts[i]
		var z1: float = cuts[i + 1]
		var zm := (z0 + z1) * 0.5
		var arch := absf(zm - zf) < 0.01 or absf(zm - zr) < 0.01
		var y0 := y_arch if arch else yb
		var faces := 48
		if zm < bed:
			faces |= 1
		if arch:
			faces |= 2
		else:
			faces |= 12
		m.box(Vector3(0.0, (y0 + belt) * 0.5, zm), Vector3(hw * 2.0, belt - y0, z1 - z0), col, faces)
		if arch:
			var xi := hw - 0.27
			_face_x(m, z0, z1, yb, y_arch, -xi, -1.0, dark)
			_face_x(m, z0, z1, yb, y_arch, xi, 1.0, dark)
		elif style == "suv":
			_face_x(m, z0, z1, yb, yb + 0.13, -(hw + 0.004), -1.0, trim)
			_face_x(m, z0, z1, yb, yb + 0.13, hw + 0.004, 1.0, trim)

	# ---- para-choques
	var bh := 0.30 if tall else 0.24
	m.box(Vector3(0.0, yb + bh * 0.5 - 0.02, -hl - 0.03), Vector3(hw * 2.0 + 0.04, bh, 0.16), trim, 59)
	m.box(Vector3(0.0, yb + bh * 0.5 - 0.02, hl + 0.03), Vector3(hw * 2.0 + 0.04, bh, 0.16), trim, 55)

	# ---- farois, lanternas, grade e placas
	var ly := belt - 0.17
	var zfr := -hl - 0.003
	var zbk := hl + 0.003
	for s in [-1.0, 1.0]:
		var sg: float = s
		_face_z(m, sg * (hw - 0.44), sg * (hw - 0.07), ly - 0.075, ly + 0.075, zfr, -1.0, Color(0.80, 0.80, 0.74))
		_face_z(e, sg * (hw - 0.44), sg * (hw - 0.07), ly - 0.075, ly + 0.075, zfr - 0.004, -1.0, Color(1.0, 0.97, 0.84))
		var t0 := sg * (hw - 0.34)
		var t1 := sg * (hw - 0.05)
		var ty0 := ly - 0.08
		var ty1 := ly + 0.07
		if style == "van" or style == "pickup":
			t0 = sg * (hw - 0.17)
			t1 = sg * (hw - 0.03)
			ty0 = ly - 0.24
		_face_z(m, t0, t1, ty0, ty1, zbk, 1.0, Color(0.42, 0.05, 0.05))
		_face_z(e, t0, t1, ty0, ty1, zbk + 0.004, 1.0, Color(1.0, 0.13, 0.08))
		_face_z(b, t0, t1, ty0 - 0.02, ty1 + 0.02, zbk + 0.008, 1.0, Color(1.0, 0.32, 0.22))
	_face_z(m, -(hw - 0.50), hw - 0.50, ly - 0.07, ly + 0.05, zfr, -1.0, dark)
	_face_z(m, -0.19, 0.19, yb + 0.05, yb + 0.17, -hl - 0.113, -1.0, Color(0.82, 0.82, 0.78))
	_face_z(m, -0.19, 0.19, yb + 0.05, yb + 0.17, hl + 0.113, 1.0, Color(0.82, 0.82, 0.78))

	# ---- retrovisores e frisos das portas
	var zb := lerpf(ws, rw, 0.47)
	var seams: Array = [ws + 0.04, zb]
	if style == "pickup":
		seams = [ws + 0.04, rw - 0.06]
	elif style == "van":
		seams = [-1.24, rr, 0.55]
	for s in [-1.0, 1.0]:
		var sg2: float = s
		m.box(Vector3(sg2 * (hw + 0.07), belt + 0.07, ws + 0.16), Vector3(0.15, 0.10, 0.07), col, 63 - (32 if sg2 > 0.0 else 16))
		for sz in seams:
			var z: float = sz
			_face_x(m, z - 0.012, z + 0.012, yb + 0.05, belt - 0.02, sg2 * (hw + 0.005), sg2, seam)

	# ---- cabine: vidros, colunas, teto e interior
	var hb := hw - 0.035
	var ht := hw - tuck
	var rear_glass := style != "van"
	_quad_hint(g, Vector3(-hb, belt, ws), Vector3(hb, belt, ws), Vector3(ht, roof, rf), Vector3(-ht, roof, rf), Vector3(0.0, 0.3, -1.0), white)
	if rear_glass:
		_quad_hint(g, Vector3(hb, belt, rw), Vector3(-hb, belt, rw), Vector3(-ht, roof, rr), Vector3(ht, roof, rr), Vector3(0.0, 0.3, 1.0), white)
	for s in [-1.0, 1.0]:
		var sg3: float = s
		var pa := Vector3(sg3 * hb, belt, ws)
		var pb := Vector3(sg3 * ht, roof, rf)
		var pc := Vector3(sg3 * ht, roof, rr)
		var pd := Vector3(sg3 * hb, belt, rw)
		_quad_hint(g, pa, pb, pc, pd, Vector3(sg3, 0.2, 0.0), white)
		_beam(m, pa, pb, 0.07, col)
		if rear_glass:
			_beam(m, pd, pc, 0.09, col)
		if four_doors:
			var xb := sg3 * (hb + 0.006)
			var xt := sg3 * (ht + 0.006)
			_quad_hint(m, Vector3(xb, belt, zb - 0.045), Vector3(xb, belt, zb + 0.045), Vector3(xt, roof, zb + 0.045), Vector3(xt, roof, zb - 0.045), Vector3(sg3, 0.2, 0.0), col)
	var r0 := rf - 0.03
	var r1 := rr + (0.0 if style == "van" else 0.03)
	m.box(Vector3(0.0, roof + 0.02, (r0 + r1) * 0.5), Vector3(ht * 2.0 + 0.06, 0.06, r1 - r0), col)
	m.quad_auto(Vector3(-hb, belt + 0.004, ws), Vector3(hb, belt + 0.004, ws), Vector3(hb, belt + 0.004, rw), Vector3(-hb, belt + 0.004, rw), Vector3.UP, dark)
	var sx := absf(seat.x)
	m.box(Vector3(-sx, belt + 0.19, seat.z + 0.25), Vector3(0.44, 0.40, 0.10), inner, 61)
	m.box(Vector3(sx, belt + 0.19, seat.z + 0.25), Vector3(0.44, 0.40, 0.10), inner, 61)
	if four_doors:
		var bz := minf(seat.z + 1.05, rw - 0.17 - (rw - rr) * 0.5)
		m.box(Vector3(0.0, belt + 0.13, bz), Vector3(hb * 2.0 - 0.24, 0.26, 0.10), inner, 61)

	# ---- particularidades de cada carroceria
	if style == "pickup":
		# cacamba aberta: piso, paredes internas e bordas
		var fy := y_arch + 0.03
		var bx := hw - 0.07
		var bz1 := hl - 0.07
		var liner := Color(0.15, 0.15, 0.16)
		m.quad_auto(Vector3(-bx, fy, bed), Vector3(bx, fy, bed), Vector3(bx, fy, bz1), Vector3(-bx, fy, bz1), Vector3.UP, liner)
		_face_x(m, bed, bz1, fy, belt, -bx, 1.0, liner)
		_face_x(m, bed, bz1, fy, belt, bx, -1.0, liner)
		_face_z(m, -bx, bx, fy, belt, bz1, -1.0, liner)
		m.quad_auto(Vector3(-hw, belt, bed), Vector3(-bx, belt, bed), Vector3(-bx, belt, hl), Vector3(-hw, belt, hl), Vector3.UP, col)
		m.quad_auto(Vector3(bx, belt, bed), Vector3(hw, belt, bed), Vector3(hw, belt, hl), Vector3(bx, belt, hl), Vector3.UP, col)
		m.quad_auto(Vector3(-bx, belt, bz1), Vector3(bx, belt, bz1), Vector3(bx, belt, hl), Vector3(-bx, belt, hl), Vector3.UP, col)
	elif style == "van":
		# bau fechado atras da cabine, com duas janelas nas portas traseiras
		var py1 := roof + 0.05
		m.box(Vector3(0.0, (belt + py1) * 0.5, (rr + hl) * 0.5), Vector3(hb * 2.0, py1 - belt, hl - rr), col, 61)
		_face_z(g, -(hb - 0.16), -0.07, belt + 0.38, roof - 0.20, hl + 0.006, 1.0, white)
		_face_z(g, 0.07, hb - 0.16, belt + 0.38, roof - 0.20, hl + 0.006, 1.0, white)
		_face_z(m, -0.012, 0.012, yb + 0.32, roof - 0.04, hl + 0.004, 1.0, seam)
	elif style == "suv":
		# barras de teto
		m.box(Vector3(-(ht - 0.08), roof + 0.085, (rf + rr) * 0.5), Vector3(0.05, 0.07, (rr - rf) * 0.82), trim, 61)
		m.box(Vector3(ht - 0.08, roof + 0.085, (rf + rr) * 0.5), Vector3(0.05, 0.07, (rr - rf) * 0.82), trim, 61)
	if extra == "policia":
		# faixa lateral azul, capo marcado e giroflex vermelho/azul
		var navy := Color(0.07, 0.13, 0.40)
		_face_x(m, zf + a, zr - a, yb + 0.10, belt - 0.05, -(hw + 0.003), -1.0, navy)
		_face_x(m, zf + a, zr - a, yb + 0.10, belt - 0.05, hw + 0.003, 1.0, navy)
		m.quad_auto(Vector3(-hw + 0.22, belt + 0.003, -hl + 0.10), Vector3(hw - 0.22, belt + 0.003, -hl + 0.10), Vector3(hw - 0.22, belt + 0.003, ws - 0.08),
			Vector3(-hw + 0.22, belt + 0.003, ws - 0.08), Vector3.UP, navy)
		var gz := (rf + rr) * 0.5 - 0.10
		m.box(Vector3(-0.24, roof + 0.105, gz), Vector3(0.44, 0.11, 0.22), Color(0.82, 0.08, 0.08), 61)
		m.box(Vector3(0.24, roof + 0.105, gz), Vector3(0.44, 0.11, 0.22), Color(0.10, 0.22, 0.88), 61)
	elif extra == "ambulancia":
		# faixas e cruzes vermelhas, barra de luzes no teto
		var red := Color(0.80, 0.10, 0.08)
		var cz := (rr + hl) * 0.5 + 0.2
		var cy := (belt + roof) * 0.5 + 0.08
		for s in [-1.0, 1.0]:
			var sg4: float = s
			_face_x(m, ws + 0.10, hl - 0.03, belt - 0.22, belt - 0.07, sg4 * (hw + 0.003), sg4, red)
			_face_x(m, cz - 0.34, cz + 0.34, cy - 0.11, cy + 0.11, sg4 * (hb + 0.004), sg4, red)
			_face_x(m, cz - 0.11, cz + 0.11, cy - 0.34, cy + 0.34, sg4 * (hb + 0.006), sg4, red)
		m.box(Vector3(0.0, roof + 0.105, rf + 0.40), Vector3(1.10, 0.11, 0.20), red, 61)
	return [m, g, e, b]


# =====================================================================================
#  CONSULTAS
# =====================================================================================
## Condicao 0..1 de uma peca (0 se ausente ou destruida).
func part_cond(key: String) -> float:
	return maxf(0.0, float(parts.get(key, 0.0)))


func part_missing(key: String) -> bool:
	return float(parts.get(key, 0.0)) < 0.0


func seat_position() -> Vector3:
	return global_transform * _seat


## Fracao de potencia entregue pelo motor (condicao e qualidade de fabrica).
func engine_factor() -> float:
	var c := part_cond("motor")
	if c <= 0.0:
		return 0.0
	return (0.4 + 0.6 * c) * float(state.get("q", 1.0))


func trunk_weight() -> float:
	return Inv.weight_of_list(trunk)


## Chave deste veiculo como item de inventario.
func make_key() -> Dictionary:
	var it := Items.make("chave_carro")
	it["car"] = id
	it["nm"] = display_name
	return it


func _player_key(p) -> Variant:
	if p == null or p.inv == null:
		return null
	for it in p.inv.items:
		if it["id"] == "chave_carro" and int(it.get("car", -999)) == id:
			return it
	return null


func can_start_with(p) -> bool:
	return has_key or hotwired or _player_key(p) != null


static func _cond_word(c: float) -> String:
	if c < 0.0:
		return "ausente"
	if c <= 0.0:
		return "destruído"
	if c < 0.15:
		return "crítico"
	if c < 0.35:
		return "ruim"
	if c < 0.6:
		return "desgastado"
	if c < 0.85:
		return "bom estado"
	return "ótimo estado"


func _part_info(key: String) -> String:
	var c: float = parts.get(key, 0.0)
	if c < 0.0:
		return "sem peça instalada"
	var s := _cond_word(c)
	var seen: bool = insp.has(key)
	if TYRES.has(key):
		var ps: float = press.get(key, 0.0)
		if ps < 0.15:
			s += " • vazio"
		elif seen:
			s += " • %d psi" % roundi(ps * 32.0)
		else:
			s += " • murcho" if ps < 0.7 else " • cheio"
		return s
	match key:
		"motor":
			if seen:
				s += " • potência %d%%" % roundi(engine_factor() * 100.0)
			s += " • ligado" if engine_on else ""
		"bateria":
			s += " • carga %d%%" % roundi(battery * 100.0)
		"tanque":
			s += " • %.1f/%.0f L" % [fuel, fuel_cap]
			if c < 0.35:
				s += " • vazando"
		"escapamento":
			if c < 0.35:
				s += " • barulhento"
		"freios":
			if seen:
				s += " • frenagem %d%%" % roundi((0.25 + 0.75 * c) * 100.0)
		"portas":
			s += " • trancadas" if locked else " • destrancadas"
		"vidros":
			if c <= 0.0:
				s = "quebrados"
		"farois":
			if c <= 0.0:
				s = "quebrados"
			elif lights_on:
				s += " • acesos"
		"porta_malas":
			s += " • %.1f/%.0f kg" % [trunk_weight(), trunk_cap]
	return s


## Lista de pecas para a tela de mecanica.
func parts_list() -> Array:
	_settle()
	var out: Array = []
	for k in PARTS:
		var key: String = k
		var c: float = parts.get(key, 0.0)
		out.append({"key": key, "name": PART_NAMES[key], "cond": -1.0 if c < 0.0 else c, "info": _part_info(key)})
	return out


# =====================================================================================
#  ENTRAR, SAIR, MOTOR, LUZES
# =====================================================================================
func enter_player(p, force: bool = false) -> bool:
	if p == null:
		return false
	if driver != null and driver != p and is_instance_valid(driver):
		return false
	_settle()
	if not force and locked:
		if part_cond("vidros") <= 0.0:
			locked = false          # alcanca o pino pela janela quebrada
		elif _player_key(p) != null:
			locked = false
			G.say("Você destrancou o veículo com a chave.")
		else:
			G.say("Veículo trancado. Use a chave ou quebre um vidro (Mecânica > Vidros).")
			Sfx.play3d("door_locked", global_position + Vector3(0, 1.0, 0), -4.0, 1.0, 25.0)
			return false
	driver = p
	p.vehicle = self
	Sfx.play3d("car_door", global_position + Vector3(0, 1.0, 0), -4.0, 1.0, 30.0)
	Sfx.noise(global_position, 6.0)
	if not force and not can_start_with(p):
		G.say("Sem chave: faça uma ligação direta para dar partida.")
	_start_cd = 0.4
	_wake()
	return true


## Tira o jogador do veiculo e o coloca ao lado da porta do motorista (ou no ponto livre mais proximo).
func exit_player(p, force: bool = false) -> void:
	if p == null:
		return
	var dead: bool = p.sv != null and p.sv.dead
	if driver == p and not force and not dead and absf(speed) > EXIT_SPEED:
		G.say("Pare o veículo antes de sair.")
		return
	var spot := _exit_spot()
	if driver == p:
		driver = null
	p.vehicle = null
	p.global_position = spot
	p.velocity = Vector3.ZERO
	stop_engine()
	_show_brake(false)
	Sfx.play3d("car_door", global_position + Vector3(0, 1.0, 0), -4.0, 1.0, 30.0)
	Sfx.noise(global_position, 6.0)


func _exit_spot() -> Vector3:
	var hw := _wid * 0.5 + 0.60
	var hl := _len * 0.5 + 0.70
	var sz := _seat.z
	var cands: Array = [Vector3(-hw, 0, sz), Vector3(hw, 0, sz), Vector3(-hw, 0, sz + 1.2), Vector3(-hw, 0, sz - 1.2), Vector3(hw, 0, sz + 1.2),
		Vector3(hw, 0, sz - 1.2), Vector3(0, 0, hl), Vector3(0, 0, -hl), Vector3(-hw - 0.9, 0, sz), Vector3(hw + 0.9, 0, sz)]
	var xf := global_transform
	var first: Vector3 = xf * cands[0]
	first.y = global_position.y
	if not is_inside_tree() or get_world_3d() == null:
		return first
	var space := get_world_3d().direct_space_state
	if space == null:
		return first
	if _probe == null:
		_probe = CapsuleShape3D.new()
		_probe.radius = 0.30
		_probe.height = 1.60
	var from := global_position + Vector3(0, 1.0, 0)
	for c in cands:
		var wp: Vector3 = xf * c
		wp.y = global_position.y
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _probe
		q.transform = Transform3D(Basis.IDENTITY, wp + Vector3(0, 0.95, 0))
		q.collision_mask = G.L_WORLD | G.L_GLASS | G.L_VEHICLE
		if not space.intersect_shape(q, 1).is_empty():
			continue
		# nao atravessa paredes: precisa haver caminho livre do carro ate o ponto
		var rq := PhysicsRayQueryParameters3D.create(from, wp + Vector3(0, 1.0, 0), G.L_WORLD | G.L_GLASS)
		if not space.intersect_ray(rq).is_empty():
			continue
		return wp
	return first


## Tenta dar partida. Precisa de chave ou ligacao direta, carga na bateria e combustivel.
func try_start() -> bool:
	if engine_on:
		return true
	_settle()
	var mine := driver != null
	var pos := global_position + Vector3(0, 0.8, 0)
	if not can_start_with(driver):
		if mine:
			G.say("Sem chave. Faça uma ligação direta para dar partida.")
		return false
	if part_missing("bateria"):
		if mine:
			G.say("O veículo está sem bateria.")
		return false
	if part_cond("motor") <= 0.0:
		if mine:
			G.say("O motor está destruído.")
		Sfx.play3d("engine_fail", pos, -4.0, 0.9, 40.0)
		return false
	if battery < 0.08:
		if mine:
			G.say("Bateria descarregada.")
		Sfx.play3d("gun_empty", pos, -6.0, 0.8, 15.0)
		return false
	battery = maxf(0.0, battery - 0.03)
	Sfx.noise(global_position, 16.0)
	if fuel <= 0.0:
		if mine:
			G.say("Sem combustível.")
		Sfx.play3d("engine_fail", pos, -2.0, 1.0, 45.0)
		return false
	# motor ruim e bateria fraca fazem a partida falhar
	var motor := part_cond("motor")
	var fail := clampf((1.0 - motor) * 0.75 - 0.12, 0.0, 0.75)
	if battery < 0.25:
		fail = minf(0.85, fail + 0.2)
	if randf() < fail:
		if mine:
			G.say("O motor não pegou.")
		Sfx.play3d("engine_fail", pos, -2.0, 1.0, 45.0)
		return false
	engine_on = true
	_noise_t = 0.0
	Sfx.play3d("engine_start", pos, -1.0, 1.0, 55.0)
	Sfx.noise(global_position, 24.0 * _loud)
	_wake()
	return true


func stop_engine() -> void:
	engine_on = false
	_stop_loop()


func toggle_lights() -> void:
	_settle()
	if not lights_on:
		if part_cond("farois") <= 0.0:
			G.say("Os faróis estão quebrados.")
			return
		if part_missing("bateria") or battery <= 0.02:
			G.say("Sem carga na bateria: os faróis não acendem.")
			return
	lights_on = not lights_on
	_apply_lights()


func horn() -> void:
	_settle()
	var now := Time.get_ticks_msec()
	if now < _horn_ms:
		return
	_horn_ms = now + 350
	if part_missing("bateria") or battery <= 0.02:
		G.say("A buzina não funciona sem bateria.")
		return
	battery = maxf(0.0, battery - 0.002)
	Sfx.play3d("horn", global_position + Vector3(0, 1.0, 0), 2.0, 1.0, 140.0)
	Sfx.noise(global_position, 80.0)


## Um zumbi ataca o veiculo ocupado: danifica vidros ou portas; sem vidros, alcanca o motorista.
func zombie_hit(z) -> void:
	var pos := global_position + Vector3(0, 1.0, 0)
	var st := 1
	if z != null and is_instance_valid(z):
		pos = z.global_position + Vector3(0, 1.2, 0)
		st = int(z.strength)
	var k: float = [0.7, 1.0, 1.4][clampi(st, 0, 2)]
	var glass := part_cond("vidros")
	if glass > 0.0 and randf() < 0.6:
		_damage("vidros", randf_range(0.05, 0.09) * k)
		Sfx.play3d("zombie_thump", pos, -2.0, 1.2, 35.0)
	else:
		_damage("portas", randf_range(0.03, 0.06) * k)
		Sfx.play3d("hit_metal", pos, -4.0, 0.8, 35.0)
	Sfx.noise(global_position, 10.0)
	if driver != null and is_instance_valid(driver):
		driver.trauma = minf(1.0, float(driver.trauma) + 0.2)
		if part_cond("vidros") <= 0.0 and randf() < 0.5:
			driver.hurt(randf_range(3.0, 7.0) * k, "Atacado por zumbis dentro do veículo")


func refuel(liters: float) -> float:
	var take := clampf(liters, 0.0, maxf(0.0, fuel_cap - fuel))
	fuel += take
	return take


func siphon(liters: float) -> float:
	var take := clampf(liters, 0.0, fuel)
	fuel -= take
	if fuel <= 0.0 and engine_on:
		stop_engine()
	return take


func hotwire(p) -> String:
	if hotwired:
		return "Este veículo já está com ligação direta."
	if has_key:
		return "A chave já está na ignição."
	if p == null or p.sv == null:
		return "Não é possível."
	var ele: int = p.sv.level("eletrica")
	var mec: int = p.sv.level("mecanica")
	var knows: bool = p.sv.knows("ligacao_direta")
	if not knows and not (ele >= 1 and mec >= 2):
		return "Você não sabe fazer ligação direta (requer a revista de elétrica automotiva ou Elétrica 1 e Mecânica 2)."
	if p.inv.find_tag("chave_fenda") == null:
		return "Falta: chave de fenda."
	var chance := clampf(0.35 + 0.08 * ele + 0.05 * mec + (0.25 if knows else 0.0), 0.1, 0.95)
	Sfx.noise(global_position, 5.0)
	if randf() < chance:
		hotwired = true
		p.sv.add_xp("eletrica", 12.0)
		return "Ligação direta feita: o motor liga sem a chave."
	p.sv.add_xp("eletrica", 3.0)
	if randf() < 0.15:
		battery = maxf(0.0, battery - 0.05)
		return "Você causou um curto e a ligação direta falhou. Tente de novo."
	return "A ligação direta falhou. Tente de novo."


func take_key(p) -> String:
	if not has_key:
		return "Não há chave na ignição."
	has_key = false
	p.inv.add(make_key())
	return "Você pegou a chave do veículo."


func toggle_lock(p) -> String:
	if locked:
		if driver == p or _player_key(p) != null or part_cond("vidros") <= 0.0:
			locked = false
			Sfx.play3d("door_open", global_position + Vector3(0, 1.0, 0), -8.0, 1.3, 20.0)
			return "Veículo destrancado."
		return "Você precisa da chave para destrancar."
	if driver == p or _player_key(p) != null:
		locked = true
		Sfx.play3d("door_close", global_position + Vector3(0, 1.0, 0), -8.0, 1.3, 20.0)
		return "Veículo trancado."
	return "Você precisa da chave para trancar."


# =====================================================================================
#  MECANICA
# =====================================================================================
func _act(aid: String, label: String, secs: float, why: String = "") -> Dictionary:
	return {"id": aid, "label": label, "ok": why == "", "why": why, "time": secs}


static func _time(base: float, lvl: int) -> float:
	return snappedf(base * clampf(1.25 - 0.07 * float(lvl), 0.55, 1.25), 0.1)


static func _fail_chance(lvl: int, req: int) -> float:
	return clampf(0.28 - 0.07 * float(lvl - req) - 0.015 * float(lvl), 0.02, 0.45)


## Primeiro requisito nao atendido ("" se tudo certo).
func _need(p, tools: Array, sk: String, lvl: int, item: String = "", n: int = 1) -> String:
	if engine_on:
		return "Desligue o motor antes."
	if absf(speed) > 0.2:
		return "O veículo precisa estar parado."
	for t in tools:
		var tag: String = t
		if p.inv.find_tag(tag) == null:
			return "Falta: %s." % TOOL_NAMES.get(tag, tag)
	if lvl > 0 and int(p.sv.level(sk)) < lvl:
		return "Requer %s nível %d." % [Survivor.SKILLS.get(sk, sk), lvl]
	if item != "" and int(p.inv.count(item)) < n:
		var nm: String = Items.def(item)["n"]
		return "Falta: %s." % nm.to_lower()
	return ""


func _has_air(p) -> bool:
	if p.inv.find_tag("bomba_ar") != null:
		return true
	if G.world == null or not is_instance_valid(G.world) or not G.power_on():
		return false
	var gen = G.world.gen
	for o in [Vector2.ZERO, Vector2(10, 0), Vector2(-10, 0), Vector2(0, 10), Vector2(0, -10), Vector2(7, 7), Vector2(-7, 7), Vector2(7, -7), Vector2(-7, -7)]:
		var off: Vector2 = o
		var li: int = gen.lot_at(global_position.x + off.x, global_position.z + off.y)
		if li >= 0:
			var lt: String = gen.lots[li]["type"]
			if lt == "posto" or lt == "oficina":
				return true
	return false


## Servicos disponiveis para uma peca: [{id, label, ok, why, time}].
func mechanic_actions(key: String, p) -> Array:
	var out: Array = []
	if not PART_NAMES.has(key) or p == null:
		return out
	_settle()
	var c: float = parts.get(key, 0.0)
	var mec: int = p.sv.level("mecanica")
	var ele: int = p.sv.level("eletrica")
	var is_tyre := TYRES.has(key)
	out.append(_act("inspecionar", "Inspecionar", 1.0 if insp.has(key) else 2.5, "" if c >= 0.0 else "Não há peça instalada."))
	var sw: Dictionary = SWAP.get("pneu" if is_tyre else key, {})
	if not sw.is_empty():
		var sk: String = sw["sk"]
		var secs := _time(float(sw["t"]), ele if sk == "eletrica" else mec)
		if c >= 0.0:
			out.append(_act("remover", "Remover %s" % sw["lab"], secs, _need(p, sw["tools"], sk, int(sw["lvl"]))))
		else:
			out.append(_act("instalar", "Instalar %s" % sw["lab"], secs, _need(p, sw["tools"], sk, int(sw["lvl"]), String(sw["item"]), 1)))
	if is_tyre and c >= 0.0:
		var why := ""
		if c <= 0.02:
			why = "O pneu está destruído."
		elif float(press.get(key, 0.0)) >= 0.97:
			why = "O pneu já está calibrado."
		elif not _has_air(p):
			why = "Requer o calibrador de um posto ou oficina com energia."
		out.append(_act("calibrar", "Calibrar pneu", 4.0, why))
	var fx: Dictionary = FIX.get(key, {})
	if not fx.is_empty() and c >= 0.0:
		var sk2: String = fx["sk"]
		var why2 := _need(p, fx["tools"], sk2, int(fx["lvl"]), String(fx["item"]), 1)
		if why2 == "" and c >= float(fx["max"]) - 0.005:
			why2 = "Não precisa de reparo." if float(fx["max"]) >= 1.0 else "Esse remendo não melhora mais do que isso."
		out.append(_act("reparar", String(fx["label"]), _time(float(fx["t"]), ele if sk2 == "eletrica" else mec), why2))
	match key:
		"motor":
			var why3 := _need(p, ["chave_inglesa"], "mecanica", 3)
			if why3 == "" and c < 0.2:
				why3 = "O motor está ruim demais para aproveitar peças."
			out.append(_act("desmontar", "Retirar peças do motor", _time(18.0, mec), why3))
			if driver == p:
				if engine_on:
					out.append(_act("desligar", "Desligar o motor", 0.0))
				else:
					out.append(_act("ligar", "Dar partida", 0.0))
			if has_key:
				out.append(_act("pegar_chave", "Pegar a chave da ignição", 0.5))
		"portas":
			if locked:
				var can_open: bool = driver == p or _player_key(p) != null or part_cond("vidros") <= 0.0
				out.append(_act("destrancar", "Destrancar", 0.5, "" if can_open else "Falta: chave deste veículo."))
			else:
				var can_lock: bool = driver == p or _player_key(p) != null
				out.append(_act("trancar", "Trancar", 0.5, "" if can_lock else "Falta: chave deste veículo."))
		"vidros":
			if c > 0.0:
				out.append(_act("quebrar", "Quebrar um vidro", 1.5, "" if driver != p else "Saia do veículo primeiro."))
	return out


## Aplica o resultado de um servico (depois da acao cronometrada). Retorna a mensagem para o jogador.
func mechanic_do(key: String, action_id: String, p) -> String:
	if p == null or not PART_NAMES.has(key):
		return "Ação indisponível."
	var found: Dictionary = {}
	for a in mechanic_actions(key, p):
		if a["id"] == action_id:
			found = a
			break
	if found.is_empty():
		return "Ação indisponível."
	if not found["ok"]:
		return String(found["why"])
	var msg := ""
	match action_id:
		"inspecionar":
			msg = _do_inspect(key, p)
		"remover":
			msg = _do_remove(key, p)
		"instalar":
			msg = _do_install(key, p)
		"reparar":
			msg = _do_fix(key, p)
		"calibrar":
			press[key] = 1.0
			p.sv.add_xp("mecanica", 1.0)
			msg = "Pneu calibrado (32 psi)."
		"desmontar":
			msg = _do_salvage(p)
		"ligar":
			msg = "Motor ligado." if try_start() else "O motor não ligou."
		"desligar":
			stop_engine()
			msg = "Motor desligado."
		"pegar_chave":
			msg = take_key(p)
		"trancar", "destrancar":
			msg = toggle_lock(p)
		"quebrar":
			msg = _do_break_window(p)
		_:
			msg = "Ação indisponível."
	_ft = 0.0
	_refresh()
	_refresh_visual()
	_apply_lights()
	return msg


func _xp(p, key: String, sk: String, amount: float) -> void:
	# o XP cheio de cada peca vale uma vez por dia (evita repetir o mesmo servico para treinar)
	var xd: Dictionary = state.get("xp", {})
	var tag := key + ":" + sk
	if int(xd.get(tag, -1)) == G.day():
		amount *= 0.2
	xd[tag] = G.day()
	state["xp"] = xd
	p.sv.add_xp(sk, amount)


func _do_inspect(key: String, p) -> String:
	if not insp.has(key):
		insp[key] = true
		p.sv.add_xp("mecanica", 3.0)
	var c: float = parts.get(key, 0.0)
	return "%s: %d%% — %s." % [PART_NAMES[key], roundi(c * 100.0), _part_info(key)]


func _do_remove(key: String, p) -> String:
	var sw: Dictionary = SWAP["pneu" if TYRES.has(key) else key]
	var sk: String = sw["sk"]
	var lvl: int = p.sv.level(sk)
	var c: float = parts[key]
	if randf() < _fail_chance(lvl, int(sw["lvl"])):
		parts[key] = maxf(0.0, c - randf_range(0.04, 0.12))
		_xp(p, key, sk, float(sw["xp"]) * 0.3)
		return "Você se atrapalhou e danificou a peça. Tente de novo."
	var it := Items.make(String(sw["item"]))
	it["c"] = c
	if TYRES.has(key):
		it["psi"] = float(press.get(key, 0.0))
		press[key] = 0.0
	elif key == "bateria":
		it["chg"] = battery
		battery = 0.0
		if lights_on:
			lights_on = false
	parts[key] = -1.0
	insp.erase(key)
	p.inv.add(it)
	_xp(p, key, sk, float(sw["xp"]))
	var nm: String = Items.def(String(sw["item"]))["n"]
	return "Você removeu: %s (%d%%)." % [nm, roundi(c * 100.0)]


func _do_install(key: String, p) -> String:
	var sw: Dictionary = SWAP["pneu" if TYRES.has(key) else key]
	var sk: String = sw["sk"]
	var lvl: int = p.sv.level(sk)
	var iid: String = sw["item"]
	var best = null
	for it in p.inv.items:
		if it["id"] == iid and (best == null or float(it.get("c", 1.0)) > float(best.get("c", 1.0))):
			best = it
	if best == null:
		return "Falta a peça."
	var c: float = clampf(float(best.get("c", 1.0)), 0.0, 1.0)
	if randf() < _fail_chance(lvl, int(sw["lvl"])):
		best["c"] = maxf(0.0, c - randf_range(0.04, 0.12))
		_xp(p, key, sk, float(sw["xp"]) * 0.3)
		return "A instalação falhou e a peça foi danificada. Tente de novo."
	p.inv.remove_item(best)
	parts[key] = c
	if TYRES.has(key):
		press[key] = clampf(float(best.get("psi", 0.85)), 0.0, 1.0)
	elif key == "bateria":
		battery = clampf(float(best.get("chg", 0.7 * c)), 0.0, c)
	_xp(p, key, sk, float(sw["xp"]))
	var nm: String = Items.def(iid)["n"]
	return "Peça instalada: %s (%d%%)." % [nm, roundi(c * 100.0)]


func _do_fix(key: String, p) -> String:
	var fx: Dictionary = FIX[key]
	var sk: String = fx["sk"]
	var lvl: int = p.sv.level(sk)
	var iid: String = fx["item"]
	var mat = p.inv.find(iid)
	if mat == null:
		return "Falta o material."
	p.inv.use_charge(mat)
	if randf() < _fail_chance(lvl, int(fx["lvl"])):
		_xp(p, key, sk, float(fx["xp"]) * 0.3)
		return "O reparo não deu certo e o material foi perdido."
	var c: float = parts[key]
	var gain: float = float(fx["gain"]) * (1.0 + 0.06 * float(lvl))
	c = minf(float(fx["max"]), c + gain)
	parts[key] = c
	_xp(p, key, sk, float(fx["xp"]))
	return "Reparo feito: %s agora em %d%%." % [String(PART_NAMES[key]).to_lower(), roundi(c * 100.0)]


func _do_salvage(p) -> String:
	var lvl: int = p.sv.level("mecanica")
	var c: float = parts["motor"]
	parts["motor"] = maxf(0.0, c - 0.3)
	if randf() < _fail_chance(lvl, 3):
		_xp(p, "motor_d", "mecanica", 5.0)
		return "Você desmontou parte do motor, mas não aproveitou nenhuma peça."
	var n := 1 + (1 if c > 0.6 else 0) + (1 if lvl >= 6 else 0)
	p.inv.add(Items.make("peca_motor", n))
	_xp(p, "motor_d", "mecanica", 14.0)
	return "Você retirou %d %s do motor." % [n, "peça" if n == 1 else "peças"]


func _do_break_window(p) -> String:
	parts["vidros"] = 0.0
	locked = false
	var pos := global_position + Vector3(0, 1.1, 0)
	Sfx.play3d("glass_break", pos, 0.0, 1.0, 60.0)
	Sfx.noise(global_position, 26.0)
	if p.inv.primary == null and randf() < 0.25:
		p.sv.add_wound(1, "laceracao")
		return "Você quebrou o vidro com a mão e se cortou. O veículo está destrancado."
	return "Você quebrou o vidro e destrancou o veículo."


# =====================================================================================
#  DANOS
# =====================================================================================
func _damage(key: String, amt: float) -> void:
	var c: float = parts.get(key, -1.0)
	if c <= 0.0 or amt <= 0.0:
		return
	c = maxf(0.0, c - amt)
	parts[key] = c
	_ft = 0.0
	if c > 0.0:
		return
	var mine := driver != null
	match key:
		"vidros":
			Sfx.play3d("glass_break", global_position + Vector3(0, 1.1, 0), 0.0, 1.0, 60.0)
			Sfx.noise(global_position, 22.0)
			if mine:
				G.say("Os vidros do veículo quebraram!")
		"motor":
			stop_engine()
			if mine:
				G.say("O motor quebrou de vez.")
		"farois":
			if lights_on:
				lights_on = false
			_apply_lights()
		"bateria":
			battery = 0.0
		_:
			if TYRES.has(key):
				press[key] = 0.0
				if mine:
					G.say("Um pneu estourou!")
	_refresh_visual()


func _impact(imp: float, nrm: Vector3, col: Object, dirf: float) -> void:
	_crash_cd = 0.45
	var fwd := -global_transform.basis.z
	var sev := (imp - 2.0) / 20.0                 # ~1.0 a 80 km/h
	var head_on := nrm.dot(fwd * dirf) < -0.5
	if head_on and dirf > 0.0:
		_damage("capo", sev * 0.45)
		if imp > 7.0:
			_damage("motor", sev * 0.28 * (1.5 - part_cond("capo")))
			_damage("farois", sev * 0.6 * randf())
	elif head_on:
		_damage("porta_malas", sev * 0.45)
	else:
		_damage("portas", sev * 0.35)
		_damage("capo", sev * 0.12)
	_damage("suspensao", sev * 0.10)
	if imp > 9.0:
		_damage("vidros", sev * 0.35 * randf())
	if imp > 12.0 and randf() < 0.25:
		_damage(String(TYRES[randi() % 4]), randf_range(0.15, 0.4))
	if col is Vehicle:
		var other: Vehicle = col
		other._damage("portas", sev * 0.25)
		other._refresh_visual()
	var k := clampf(sev, 0.0, 1.0)
	Sfx.play3d("crash", global_position + Vector3(0, 0.8, 0), lerpf(-8.0, 4.0, k), randf_range(0.9, 1.1), 90.0)
	Sfx.noise(global_position, 30.0 + 40.0 * k)
	if driver != null and is_instance_valid(driver):
		driver.trauma = minf(1.0, float(driver.trauma) + 0.3 + sev)
		if imp > 11.0:
			driver.hurt((imp - 11.0) * 2.4, "Acidente de veículo")


## Atropelamento: zumbis na faixa do para-choque (no sentido do movimento) sofrem dano pela velocidade.
func _run_over() -> void:
	var av := absf(speed)
	if av < 1.8 or G.zombies == null or not is_instance_valid(G.zombies):
		return
	var dirf := signf(speed)
	var bas := global_transform.basis
	var fwd := -bas.z
	var hl := _len * 0.5
	var hw := _wid * 0.5
	var now := Time.get_ticks_msec()
	if _hit_t.size() > 48:
		_hit_t.clear()
	for z in G.zombies.query(global_position + fwd * dirf * (hl + 0.1), hw + 0.8):
		if z.dead:
			continue
		var zid: int = z.get_instance_id()
		if int(_hit_t.get(zid, 0)) > now:
			continue
		var l: Vector3 = to_local(z.global_position)
		if absf(l.x) > hw + 0.32:
			continue
		var ahead: float = -l.z * dirf
		if ahead < hl - 0.75 or ahead > hl + 0.75:
			continue
		_hit_t[zid] = now + 700
		var dmg := (av - 1.0) * 13.0 * clampf(_mass / 1250.0, 0.8, 1.5) * randf_range(0.8, 1.2)
		var dir := (fwd * dirf + bas.x * signf(l.x) * 0.35).normalized()
		z.take_hit(dmg, dir, clampf(av * 0.22, 0.6, 3.5), av > 8.0, false)
		speed *= 1.0 - clampf(0.07 * 1250.0 / _mass, 0.03, 0.09)
		_damage("capo" if dirf > 0.0 else "porta_malas", 0.004 + av * 0.0006)
		if av > 10.0 and randf() < 0.10:
			_damage("farois", 0.08)
		if av > 13.0 and randf() < 0.12:
			_damage("vidros", 0.06)
		Sfx.play3d("hit_blunt", z.global_position + Vector3(0, 0.8, 0), 0.0, 0.8, 40.0)
		Sfx.noise(global_position, 12.0)
		if driver != null and is_instance_valid(driver):
			driver.trauma = minf(1.0, float(driver.trauma) + 0.2)


# =====================================================================================
#  SIMULACAO
# =====================================================================================
func _wake() -> void:
	if _awake:
		return
	_awake = true
	_t_last = G.time_min
	_rest_t = 0.0
	_ft = 0.0
	set_physics_process(true)


func _sleep() -> void:
	_awake = false
	speed = 0.0
	velocity = Vector3.ZERO
	_pitch = 0.0
	_roll = 0.0
	_pv = 0.0
	_rv = 0.0
	_t_last = G.time_min
	_stop_loop()
	_show_brake(false)
	if body != null:
		body.rotation = Vector3(_tilt_p, 0.0, _tilt_r)
	set_physics_process(false)


## Consumo "preguicoso" enquanto dorme: farois acesos gastam a bateria pelo tempo de jogo decorrido.
func _settle() -> void:
	var now: float = G.time_min
	var dm := now - _t_last
	_t_last = now
	if _awake or dm <= 0.0:
		return
	if lights_on and not engine_on:
		battery = maxf(0.0, battery - LIGHT_DRAIN * dm)
		if battery <= 0.0:
			lights_on = false
			_apply_lights()


## Chamado de tempos em tempos pelo gerenciador para veiculos parados com farois acesos.
func idle_update() -> void:
	_settle()


func _show_brake(on: bool) -> void:
	if _brake_mi != null and _brake_mi.visible != on:
		_brake_mi.visible = on


func _stop_loop() -> void:
	if _loop_nm != "":
		Sfx.loop("engine", _loop_nm, 0.0)
		_loop_nm = ""


func _surface() -> String:
	if not is_inside_tree() or G.world == null or not is_instance_valid(G.world):
		return "asphalt"
	var s: String = G.world.surface_at(global_position)
	if s == "grass":
		var gen = G.world.gen
		var ri: int = gen.road_at(global_position.x, global_position.z)
		if ri >= 0:
			return "dirt"
		return "grass"
	return "asphalt"


## Recalcula os fatores que dependem das pecas e do piso.
func _refresh() -> void:
	_acc = float(spec["acc"]) * engine_factor()
	var motor := part_cond("motor")
	# pneus: aderencia media, limite de velocidade e puxada lateral
	var g := 0.0
	var cap := 1.0
	var pull := 0.0
	var tr := 0.0
	var tp := 0.0
	for i in 4:
		var k: String = TYRES[i]
		var c: float = parts.get(k, 1.0)
		var ps: float = press.get(k, 0.9)
		var gi := 0.0
		var bad := 0.0
		if c < 0.0:
			gi = 0.15
			bad = 1.0
		elif c <= 0.02 or ps < 0.15:
			gi = 0.40
			bad = 0.7
		else:
			gi = (0.6 + 0.4 * c) * (0.8 + 0.2 * clampf((ps - 0.15) / 0.55, 0.0, 1.0))
		g += gi * 0.25
		if bad > 0.0:
			cap *= 1.0 - 0.42 * bad
			var side := -1.0 if i % 2 == 0 else 1.0       # -1 = lado esquerdo
			pull += -side * bad * (0.05 if i < 2 else 0.025)
			tr += -side * 0.030 * bad
			tp += (-0.018 if i < 2 else 0.018) * bad
	_pull = pull
	_tilt_r = tr
	_tilt_p = tp
	var sg := 1.0
	_roll_res = 0.30
	_roll_v = 0.0
	_rough = 0.0
	match _surface():
		"grass":
			sg = 0.62
			_roll_res = 1.2
			_roll_v = 0.09
			_rough = 1.0
		"dirt":
			sg = 0.80
			_roll_res = 0.6
			_roll_v = 0.035
			_rough = 0.45
	_grip = g * sg
	_vt = float(spec["top"]) * 1.25 * cap * (0.75 + 0.25 * motor)
	var fr := 0.12 if part_missing("freios") else 0.25 + 0.75 * part_cond("freios")
	_brake = 9.5 * fr * clampf(_grip * 1.1, 0.3, 1.0)
	var su := part_cond("suspensao")
	_soft = lerpf(2.4, 1.0, su)
	_zeta = lerpf(0.18, 0.70, su)
	_loud = 1.6 if part_cond("escapamento") < 0.35 else 1.0
	_bat_max = part_cond("bateria")
	if part_missing("bateria"):
		battery = 0.0


func _physics_process(dt: float) -> void:
	if not G.in_game:
		return
	if G.paused:
		_stop_loop()
		return
	if driver != null and not is_instance_valid(driver):
		driver = null
		stop_engine()
	if driver == null:
		if absf(speed) < 0.03 and absf(_pitch) + absf(_roll) < 0.004 and absf(_pv) + absf(_rv) < 0.03:
			_sleep()
			return
		_rest_t += dt
		if absf(speed) < 0.03 and _rest_t > 3.0:
			_sleep()
			return
	_tick(dt)


func _tick(dt: float) -> void:
	var has_driver := driver != null
	_t_last = G.time_min
	# ---- entrada
	var steer_in := 0.0
	var gas := false
	var brk := false
	if has_driver:
		steer_in = clampf(G.mv.x, -1.0, 1.0)
		if absf(steer_in) < 0.08:
			steer_in = 0.0
		gas = G.held.has("gas")
		brk = G.held.has("brake")
		if _desktop and (G.ui == null or not G.ui.is_open()):
			gas = gas or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
			brk = brk or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	_ft -= dt
	if _ft <= 0.0:
		_ft = 0.2
		_refresh()
	_start_cd = maxf(0.0, _start_cd - dt)
	_crash_cd = maxf(0.0, _crash_cd - dt)
	_skid_cd = maxf(0.0, _skid_cd - dt)
	if has_driver and gas and not engine_on and _start_cd <= 0.0:
		_start_cd = 1.8
		try_start()

	# ---- comando longitudinal: acelerar, frear ou dar re
	var throttle := 0.0
	var braking := false
	if not has_driver:
		braking = true                 # freio de estacionamento ao abandonar o veiculo
	elif gas and brk:
		braking = true
	elif gas:
		if speed < -0.4:
			braking = true
		elif engine_on:
			throttle = 1.0
	elif brk:
		if speed > 0.5 or not engine_on:
			braking = true
		else:
			throttle = -1.0
	var v0 := speed
	var av := absf(speed)
	var drive := 0.0
	var trac := minf(1.0, _grip * 1.15)
	if throttle > 0.0:
		var f := 1.0 - pow(maxf(speed, 0.0) / maxf(_vt, 1.0), 2.0)
		drive = _acc * clampf(f, 0.0, 1.0) * trac
	elif throttle < 0.0:
		var vr := minf(9.0, _vt * 0.25)
		var f2 := 1.0 - pow(maxf(-speed, 0.0) / maxf(vr, 1.0), 2.0)
		drive = -_acc * 0.7 * clampf(f2, 0.0, 1.0) * trac
	var res := _roll_res + _roll_v * av + _c_air * av * av
	if throttle == 0.0:
		res += 0.55 if engine_on else 0.25         # freio-motor
	if braking:
		res += _brake * (1.0 if has_driver else 0.4)
	var skid := false
	if absf(steer_in) > 0.9 and av > 11.0:
		res += 1.4                                 # pneus arrastando em curva no limite
		skid = true
	if braking and has_driver and av > 9.0:
		skid = true
	speed += drive * dt
	if speed > 0.0:
		speed = maxf(0.0, speed - res * dt)
	elif speed < 0.0:
		speed = minf(0.0, speed + res * dt)
	av = absf(speed)
	if skid and _skid_cd <= 0.0 and av > 6.0:
		_skid_cd = 0.9
		Sfx.play3d("skid", global_position, -8.0, 1.0, 50.0)
		Sfx.noise(global_position, 30.0)

	# ---- direcao (modelo bicicleta): esterco maximo cai com a velocidade e com a aderencia
	var max_st := minf(MAX_STEER, atan(8.5 * _grip * _wb / maxf(av * av, 1.0)))
	var want := -steer_in * max_st + _pull * clampf(av / 6.0, 0.0, 1.0)
	steer = move_toward(steer, want, (3.4 if absf(want) < absf(steer) else 2.2) * dt)
	var omega := speed * tan(steer) / _wb
	var moving := av > 0.001
	if moving:
		rotation.y = wrapf(rotation.y + omega * dt, -PI, PI)
	var bas := global_transform.basis
	var fwd := -bas.z
	velocity = fwd * speed - bas.x * (omega * _ax_r)       # o eixo traseiro e o pivo da curva
	if moving:
		var pre := velocity
		move_and_slide()
		var nc := get_slide_collision_count()
		if nc > 0:
			var worst := 0.0
			var wn := Vector3.ZERO
			var wc: Object = null
			for i in nc:
				var kc := get_slide_collision(i)
				var imp := -pre.dot(kc.get_normal())
				if imp > worst:
					worst = imp
					wn = kc.get_normal()
					wc = kc.get_collider()
			speed = velocity.dot(fwd)
			if worst > 4.0 and absf(speed) < absf(v0) * 0.35:
				speed = -signf(v0) * minf(worst * 0.1, 1.2)       # pequeno ricochete
			if worst > 2.5 and _crash_cd <= 0.0:
				_impact(worst, wn, wc, signf(v0))
		if absf(global_position.y) > 0.001:
			global_position.y = 0.0
		_run_over()

	# ---- motor: consumo, carga da bateria e pane seca
	var dm := dt * G.minutes_per_second() * G.time_mult
	if engine_on:
		var eload := absf(throttle) * (0.35 + 0.65 * clampf(av / maxf(_vt, 1.0), 0.0, 1.0))
		var motor := part_cond("motor")
		fuel -= (0.0016 + 0.017 * eload) * float(spec["cons"]) * (1.3 - 0.3 * motor) * dt
		var tank := part_cond("tanque")
		if tank < 0.35:
			fuel -= (0.35 - tank) * 0.02 * dt          # tanque furado vaza
		battery = minf(maxf(battery, _bat_max), battery + CHARGE_RATE * dm)
		if fuel <= 0.0:
			fuel = 0.0
			stop_engine()
			if has_driver:
				G.say("Acabou o combustível.")
		elif motor < 0.15 and randf() < dt * 0.03:
			stop_engine()
			if has_driver:
				G.say("O motor morreu.")
		else:
			_noise_t -= dt
			if _noise_t <= 0.0:
				_noise_t = 0.5
				Sfx.noise(global_position, lerpf(22.0, 45.0, clampf(av / 25.0, 0.0, 1.0)) * _loud)
	elif lights_on:
		battery = maxf(0.0, battery - LIGHT_DRAIN * dm)
		if battery <= 0.0:
			lights_on = false
			_apply_lights()

	# ---- carroceria: arfagem e rolagem por transferencia de carga
	var a_long := clampf((speed - v0) / maxf(dt, 0.001), -12.0, 12.0)
	var a_lat := clampf(speed * omega, -10.0, 10.0)
	var tp := clampf(a_long * 0.0065 * _soft, -0.10, 0.10)
	var tr := clampf(-a_lat * 0.011 * _soft, -0.15, 0.15)
	var ks := 55.0 / _soft
	var cd := 2.0 * _zeta * sqrt(ks)
	if _rough > 0.0 and av > 1.0:
		var kick := minf(av, 16.0) * 0.016 * _rough * _soft
		_pv += randf_range(-1.0, 1.0) * kick
		_rv += randf_range(-1.0, 1.0) * kick
	_pv += (ks * (tp - _pitch) - cd * _pv) * dt
	_pitch += _pv * dt
	_rv += (ks * (tr - _roll) - cd * _rv) * dt
	_roll += _rv * dt
	body.rotation = Vector3(_pitch + _tilt_p, 0.0, _roll + _tilt_r)
	_spin = wrapf(_spin - speed / _wr * dt, -TAU, TAU)
	_steer_vis = move_toward(_steer_vis, -steer_in * lerpf(0.55, 0.18, clampf(av / 28.0, 0.0, 1.0)) + _pull, 2.5 * dt)
	_pose_wheels()
	_show_brake(braking and has_driver and battery > 0.0)

	# ---- som do motor (apenas no carro do jogador)
	if has_driver and driver == G.player:
		_engine_sound(dt, av, throttle)
	else:
		_stop_loop()


func _engine_sound(dt: float, av: float, throttle: float) -> void:
	if not engine_on:
		_stop_loop()
		return
	var want := "engine_run" if (av > 1.5 or throttle != 0.0) else "engine_idle"
	if want != _loop_want:
		_loop_want = want
		_loop_t = 0.0
	_loop_t += dt
	if _loop_nm == "" or (_loop_nm != want and _loop_t > 0.25):
		_stop_loop()
		_loop_nm = want
	var pitch := 0.95
	var vol := 0.30
	if _loop_nm == "engine_run":
		var gears := [0.0, 9.0, 18.0, 28.0, 80.0]
		var gi := 0
		while gi < 3 and av >= float(gears[gi + 1]):
			gi += 1
		var fr := clampf((av - float(gears[gi])) / (float(gears[gi + 1]) - float(gears[gi])), 0.0, 1.0)
		pitch = 0.74 + 0.58 * fr + 0.07 * float(gi) + 0.08 * absf(throttle)
		vol = 0.42 + 0.26 * absf(throttle) + 0.20 * clampf(av / maxf(_vt, 1.0), 0.0, 1.0)
	if part_cond("motor") < 0.4:
		pitch *= 1.0 + randf_range(-0.04, 0.04)         # motor falhando
	_snd_pitch = lerpf(_snd_pitch, pitch, 1.0 - exp(-7.0 * dt))
	Sfx.loop("engine", _loop_nm, vol * (1.35 if _loud > 1.0 else 1.0), clampf(_snd_pitch, 0.5, 2.0))
