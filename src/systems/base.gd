class_name Base
extends RefCounted
## Estruturas construidas pelo jogador (paredes, portas, cercas, recipientes, fogueira,
## coletor de chuva, composteira, secador, gerador) e canteiros de agricultura.
## Tudo fica no estado persistente da regiao e evolui com o relogio do mundo.

## estrutura: n nome, need materiais, tool etiqueta de ferramenta, sk [habilidade, nivel], hp, solid, low, cat
const STRUCTS := {
	"parede_madeira": {"n": "Parede de madeira", "need": {"tabua": 3, "pregos": 6}, "tool": "martelo", "sk": ["carpintaria", 2], "hp": 220.0, "solid": true, "cat": "Construção"},
	"porta_madeira": {"n": "Porta de madeira", "need": {"tabua": 4, "pregos": 8}, "tool": "martelo", "sk": ["carpintaria", 3], "hp": 160.0, "solid": true, "cat": "Construção"},
	"cerca_madeira": {"n": "Cerca de madeira", "need": {"tabua": 2, "pregos": 4}, "tool": "martelo", "sk": ["carpintaria", 1], "hp": 120.0, "solid": true, "low": true, "cat": "Construção"},
	"piso_madeira": {"n": "Piso de madeira", "need": {"tabua": 1, "pregos": 2}, "tool": "martelo", "sk": ["carpintaria", 1], "hp": 60.0, "cat": "Construção"},
	"parede_pedra": {"n": "Muro de pedra", "need": {"pedra": 6, "argila": 2}, "tool": "colher_pedreiro", "sk": ["alvenaria", 1], "hp": 420.0, "solid": true, "cat": "Construção"},
	"parede_metal": {"n": "Parede de chapa metálica", "need": {"chapa_metal": 2, "barra_metal": 1}, "tool": "macarico", "sk": ["metalurgia", 2], "hp": 380.0, "solid": true, "cat": "Construção"},
	"escada_madeira": {"n": "Escada de madeira", "need": {"tabua": 8, "pregos": 12}, "tool": "martelo", "sk": ["carpintaria", 4], "hp": 150.0, "cat": "Construção"},
	"telhado_madeira": {"n": "Cobertura de madeira", "need": {"tabua": 2, "pregos": 4}, "tool": "martelo", "sk": ["carpintaria", 3], "hp": 80.0, "cat": "Construção"},
	"caixote": {"n": "Caixote de armazenamento", "need": {"tabua": 3, "pregos": 6}, "tool": "martelo", "sk": ["carpintaria", 2], "hp": 100.0, "solid": true, "low": true, "cat": "Móveis"},
	"cama_simples": {"n": "Cama simples", "need": {"tabua": 5, "pregos": 8, "lencol": 2}, "tool": "martelo", "sk": ["carpintaria", 3], "hp": 100.0, "solid": true, "low": true, "cat": "Móveis"},
	"bancada": {"n": "Bancada de trabalho", "need": {"tabua": 5, "pregos": 10}, "tool": "martelo", "sk": ["carpintaria", 3], "hp": 140.0, "solid": true, "low": true, "cat": "Móveis"},
	"fogueira": {"n": "Fogueira", "need": {"pedra": 3, "graveto": 4}, "tool": "", "sk": ["coleta", 0], "hp": 60.0, "cat": "Sobrevivência"},
	"coletor_chuva": {"n": "Coletor de chuva", "need": {"tabua": 4, "pregos": 8, "saco_lixo": 4}, "tool": "martelo", "sk": ["carpintaria", 3], "hp": 100.0, "solid": true, "low": true, "cat": "Sobrevivência"},
	"composteira": {"n": "Composteira", "need": {"tabua": 5, "pregos": 8}, "tool": "martelo", "sk": ["carpintaria", 2], "hp": 100.0, "solid": true, "low": true, "cat": "Sobrevivência"},
	"secador": {"n": "Secador de alimentos", "need": {"galho": 4, "corda": 1}, "tool": "", "sk": ["carpintaria", 1], "hp": 60.0, "solid": true, "low": true, "cat": "Sobrevivência"},
	"gerador": {"n": "Gerador", "item": "gerador", "hp": 150.0, "solid": true, "low": true, "cat": ""},
	"saco_dormir": {"n": "Saco de dormir", "item": "saco_dormir", "hp": 30.0, "cat": ""},
	"barraca": {"n": "Barraca", "item": "barraca", "hp": 60.0, "solid": true, "cat": ""},
	"bolsa_acampamento": {"n": "Mochila abandonada", "hp": 30.0, "cat": ""},
}
const BUILD_ORDER := ["parede_madeira", "porta_madeira", "cerca_madeira", "piso_madeira", "telhado_madeira", "escada_madeira", "parede_pedra", "parede_metal",
	"caixote", "cama_simples", "bancada", "fogueira", "coletor_chuva", "composteira", "secador"]

## cultura: n nome, days dias ate amadurecer, y rendimento, seed semente, cold tolera frio
const CROPS := {
	"batata": {"n": "Batata", "days": 7.0, "y": [3, 6], "seed": "sem_batata", "cold": true, "col": Color(0.3, 0.5, 0.25)},
	"tomate": {"n": "Tomate", "days": 6.0, "y": [3, 6], "seed": "sem_tomate", "cold": false, "col": Color(0.75, 0.2, 0.15)},
	"cenoura": {"n": "Cenoura", "days": 5.0, "y": [3, 6], "seed": "sem_cenoura", "cold": true, "col": Color(0.85, 0.5, 0.15)},
	"repolho": {"n": "Repolho", "days": 5.0, "y": [1, 3], "seed": "sem_repolho", "cold": true, "col": Color(0.55, 0.72, 0.45)},
	"milho": {"n": "Milho", "days": 8.0, "y": [2, 5], "seed": "sem_milho", "cold": false, "col": Color(0.85, 0.75, 0.25)},
	"morango": {"n": "Morango", "days": 5.0, "y": [4, 8], "seed": "sem_morango", "cold": false, "col": Color(0.8, 0.15, 0.2)},
	"alface": {"n": "Alface", "days": 4.0, "y": [2, 4], "seed": "sem_alface", "cold": true, "col": Color(0.5, 0.75, 0.35)},
	"abobora": {"n": "Abóbora", "days": 9.0, "y": [1, 2], "seed": "sem_abobora", "cold": false, "col": Color(0.9, 0.5, 0.1)},
	"feijao_verde": {"n": "Vagem", "days": 6.0, "y": [4, 8], "seed": "sem_feijao", "cold": false, "col": Color(0.35, 0.6, 0.25)},
}

static var _acc := 0.0
static var _camp_done := {}


# =====================================================================================
#  CICLO DE VIDA POR REGIAO
# =====================================================================================
static func load_chunk(w: Node3D, k: Vector2i, ch: Dictionary) -> void:
	var st: Dictionary = w.cstate[k]
	# mochilas e fogueiras dos acampamentos: criadas uma unica vez
	if not st.get("camp", false) and w.gen.chunk_camps.has(k):
		st["camp"] = true
		for ci in w.gen.chunk_camps[k]:
			var cp: Vector2 = w.gen.camps[ci]["p"]
			_add(st, {"t": "bolsa_acampamento", "p": Vector3(cp.x + 1.9, 0, cp.y - 0.6), "r": 0, "hp": 30.0,
				"items": Items.roll_loot("acampamento", G.hash2(ci, 8, G.world_seed))})
			_add(st, {"t": "fogueira", "p": Vector3(cp.x + 3.5, 0, cp.y), "r": 0, "hp": 60.0, "fuel": 0.0, "on": false})
	for s in st.get("structs", []):
		_spawn_struct(w, ch, s)
	for p in st.get("plots", []):
		advance_plot(p)
		_spawn_plot(ch, p)


static func _add(st: Dictionary, s: Dictionary) -> void:
	if not st.has("structs"):
		st["structs"] = []
	st["structs"].append(s)


static func unload_chunk(w: Node3D, _k: Vector2i, ch: Dictionary) -> void:
	for s in ch["structs"]:
		s.erase("node")
		if s.get("on", false) and s["t"] == "fogueira":
			w.fires.erase(s["p"])
	for p in ch["plots"]:
		p.erase("node")


static func nav_chunk(w: Node3D, _k: Vector2i, ch: Dictionary) -> void:
	for s in ch["structs"]:
		if STRUCTS[s["t"]].get("solid", false) and not s.get("open", false):
			w.nav_set(Vector2i(floori(s["p"].x), floori(s["p"].z)), true)


static func process(w: Node3D, dt: float) -> void:
	_acc += dt
	if _acc < 1.0:
		return
	var el := _acc
	_acc = 0.0
	var gm := el * G.minutes_per_second() * G.time_mult
	var raining: bool = G.env != null and G.env.raining()
	for k in w.chunks:
		var ch: Dictionary = w.chunks[k]
		for s in ch["structs"]:
			match s["t"]:
				"fogueira":
					if s.get("on", false):
						s["fuel"] = float(s.get("fuel", 0.0)) - gm
						if float(s["fuel"]) <= 0.0 or (raining and w.building_at(s["p"]) == null and randf() < 0.05):
							set_fire(w, s, false)
				"coletor_chuva":
					if raining:
						s["liq"] = minf(40.0, float(s.get("liq", 0.0)) + gm * 0.12)
				"gerador":
					if s.get("on", false):
						s["fuel"] = float(s.get("fuel", 0.0)) - gm * 0.004
						Sfx.noise(s["p"], 20.0)
						if float(s["fuel"]) <= 0.0:
							s["on"] = false
							G.say("O gerador ficou sem combustível.")
				"composteira":
					s["prog"] = float(s.get("prog", 0.0)) + gm / (3.0 * 1440.0) * float(s.get("load", 0))
					if float(s["prog"]) >= 1.0 and int(s.get("load", 0)) > 0:
						s["prog"] = 0.0
						s["load"] = int(s["load"]) - 4
						s["out"] = int(s.get("out", 0)) + 1
				"secador":
					if int(s.get("load", 0)) > 0 and not raining:
						s["prog"] = float(s.get("prog", 0.0)) + gm / (2.0 * 1440.0)
						if float(s["prog"]) >= 1.0:
							s["out"] = int(s.get("out", 0)) + int(s["load"])
							s["load"] = 0
							s["prog"] = 0.0
		for p in ch["plots"]:
			var stg := plot_stage(p)
			if raining and w.building_at(p["p"]) == null:
				p["w"] = minf(1.0, float(p["w"]) + gm * 0.004)
			advance_plot(p)
			if plot_stage(p) != stg:
				_refresh_plot(ch, p)


static func generator_power(w: Node3D, pos: Vector3) -> bool:
	var k: Vector2i = w.key_of(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var ch = w.chunks.get(Vector2i(k.x + dx, k.y + dz), null)
			if ch == null:
				continue
			for s in ch["structs"]:
				if s["t"] == "gerador" and s.get("on", false) and s["p"].distance_to(pos) < 22.0:
					return true
	return false


## Energia disponivel em um ponto: rede publica ou gerador ligado por perto.
static func has_power(w: Node3D, pos: Vector3) -> bool:
	return G.power_on() or generator_power(w, pos)


# =====================================================================================
#  ESTRUTURAS
# =====================================================================================
static func can_place(w: Node3D, type: String, pos: Vector3) -> String:
	if w.gen.zone_at(pos.x, pos.z) == WorldGen.Z_RIVER:
		return "Não dá para construir na água."
	var solid: bool = STRUCTS[type].get("solid", false)
	if solid and w.cell_blocked(pos.x, pos.z):
		return "Espaço ocupado."
	var ch = w.chunk_at(pos)
	if ch == null:
		return "Região não carregada."
	for s in ch["structs"]:
		if Vector2(s["p"].x - pos.x, s["p"].z - pos.z).length() < 0.4 and (solid or s["t"] == type):
			return "Já existe uma estrutura aqui."
	if solid and G.player.global_position.distance_to(pos) < 0.6:
		return "Você está no caminho."
	return ""


static func place(w: Node3D, type: String, pos: Vector3, rot: int, extra: Dictionary = {}) -> Dictionary:
	var k: Vector2i = w.key_of(pos)
	var st: Dictionary = w.cstate[k]
	var d: Dictionary = STRUCTS[type]
	var lvl: int = G.player.sv.level(String(d["sk"][0])) if d.has("sk") else 0
	var hp: float = float(d["hp"]) * (1.0 + lvl * 0.12) * (1.2 if G.player.sv.has("pratico") else 1.0)
	var s := {"t": type, "p": pos, "r": rot, "hp": hp}
	for key in extra:
		s[key] = extra[key]
	if type == "caixote":
		s["items"] = []
	_add(st, s)
	if w.chunks.has(k):
		_spawn_struct(w, w.chunks[k], s)
	if d.get("solid", false):
		w.nav_set(Vector2i(floori(pos.x), floori(pos.z)), true)
	return s


static func remove_struct(w: Node3D, s: Dictionary) -> void:
	var k: Vector2i = w.key_of(s["p"])
	if s.has("node") and is_instance_valid(s["node"]):
		s["node"].queue_free()
	s.erase("node")
	if s["t"] == "fogueira":
		w.fires.erase(s["p"])
	if w.chunks.has(k):
		w.chunks[k]["structs"].erase(s)
	w.cstate[k].get("structs", []).erase(s)
	if STRUCTS[s["t"]].get("solid", false):
		w.nav_set(Vector2i(floori(s["p"].x), floori(s["p"].z)), false)


static func damage_struct(w: Node3D, s: Dictionary, dmg: float) -> void:
	s["hp"] = float(s["hp"]) - dmg
	if float(s["hp"]) <= 0.0:
		Sfx.play3d("door_break", s["p"], 0.0, 1.0, 60.0)
		Sfx.noise(s["p"], 18.0)
		for it in s.get("items", []):
			w.drop_item(s["p"] + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), it)
		remove_struct(w, s)


## Zumbi bloqueado ataca a estrutura a frente. Retorna true se bateu em algo.
static func zombie_thump(w: Node3D, z: Node3D) -> bool:
	var ahead: Vector3 = z.global_position - z.global_transform.basis.z * 0.8
	var ch = w.chunk_at(ahead)
	if ch == null:
		return false
	for s in ch["structs"]:
		if STRUCTS[s["t"]].get("solid", false) and not s.get("open", false) and Vector2(s["p"].x - ahead.x, s["p"].z - ahead.z).length() < 1.0:
			Sfx.play3d("zombie_thump", s["p"], -2.0, 1.0, 40.0)
			Sfx.noise(s["p"], 9.0)
			damage_struct(w, s, [6.0, 10.0, 16.0][z.strength])
			return true
	return false


static func set_fire(w: Node3D, s: Dictionary, on: bool) -> void:
	s["on"] = on
	if on:
		if not w.fires.has(s["p"]):
			w.fires.append(s["p"])
	else:
		w.fires.erase(s["p"])
	if s.has("node") and is_instance_valid(s["node"]):
		var l: Node = s["node"].get_node_or_null("luz")
		if l != null:
			l.visible = on
		var fx: Node = s["node"].get_node_or_null("chama")
		if fx != null:
			fx.visible = on


static func set_door(w: Node3D, s: Dictionary, open: bool) -> void:
	s["open"] = open
	if s.has("node") and is_instance_valid(s["node"]):
		var n: Node3D = s["node"]
		var leaf: Node3D = n.get_node("folha")
		leaf.rotation.y = PI * 0.5 if open else 0.0
		var sb: StaticBody3D = n.get_node("corpo")
		sb.get_child(0).disabled = open
	w.nav_set(Vector2i(floori(s["p"].x), floori(s["p"].z)), not open)
	Sfx.play3d("door_open" if open else "door_close", s["p"], -4.0)


static func _mesh(type: String) -> MB:
	var m := MB.new()
	var wood := Color(0.55, 0.42, 0.28)
	if type in ["parede_madeira", "porta_madeira", "cerca_madeira", "piso_madeira", "telhado_madeira", "escada_madeira", "caixote", "cama_simples", "bancada", "composteira", "secador"]:
		m.mat_a = MB.M_WOOD
	elif type == "parede_pedra":
		m.mat_a = MB.M_STONE
	elif type == "parede_metal":
		m.mat_a = MB.M_CORR
	elif type in ["saco_dormir", "barraca", "bolsa_acampamento"]:
		m.mat_a = MB.M_FABRIC
	match type:
		"parede_madeira":
			for i in 5:
				m.box(Vector3(-0.4 + i * 0.2, 1.3, 0), Vector3(0.19, 2.6, 0.12), wood.darkened(0.05 * (i % 2)))
		"porta_madeira":
			m.box(Vector3(-0.47, 1.3, 0), Vector3(0.06, 2.6, 0.14), wood.darkened(0.2))
			m.box(Vector3(0.47, 1.3, 0), Vector3(0.06, 2.6, 0.14), wood.darkened(0.2))
			m.box(Vector3(0, 2.4, 0), Vector3(1.0, 0.4, 0.14), wood.darkened(0.2))
		"cerca_madeira":
			m.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.1, 0.05), wood)
			m.box(Vector3(0, 0.9, 0), Vector3(1.0, 0.1, 0.05), wood)
			m.box(Vector3(-0.45, 0.55, 0), Vector3(0.1, 1.1, 0.1), wood.darkened(0.15))
			m.box(Vector3(0.45, 0.55, 0), Vector3(0.1, 1.1, 0.1), wood.darkened(0.15))
		"piso_madeira":
			for i in 4:
				m.box(Vector3(-0.375 + i * 0.25, 0.04, 0), Vector3(0.24, 0.05, 0.98), wood.darkened(0.06 * (i % 2)))
		"telhado_madeira":
			m.box(Vector3(0, 2.72, 0), Vector3(1.0, 0.08, 1.0), wood.darkened(0.1))
		"escada_madeira":
			for i in 6:
				m.box(Vector3(0, 0.25 + i * 0.5, -0.4 + i * 0.16), Vector3(0.9, 0.08, 0.3), wood)
		"parede_pedra":
			m.box(Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 0.35), Color(0.5, 0.5, 0.48))
			m.box(Vector3(0.2, 0.6, 0.18), Vector3(0.4, 0.3, 0.02), Color(0.42, 0.42, 0.41))
			m.box(Vector3(-0.2, 1.4, 0.18), Vector3(0.45, 0.3, 0.02), Color(0.56, 0.56, 0.54))
		"parede_metal":
			m.box(Vector3(0, 1.3, 0), Vector3(1.0, 2.6, 0.08), Color(0.5, 0.53, 0.56))
			m.box(Vector3(0, 1.3, 0.05), Vector3(0.06, 2.6, 0.04), Color(0.38, 0.4, 0.43))
		"caixote", "bolsa_acampamento":
			if type == "caixote":
				m.box(Vector3(0, 0.4, 0), Vector3(0.86, 0.8, 0.86), wood)
				m.box(Vector3(0, 0.4, 0.435), Vector3(0.86, 0.1, 0.01), wood.darkened(0.25))
			else:
				m.box(Vector3(0, 0.22, 0), Vector3(0.4, 0.44, 0.3), Color(0.3, 0.36, 0.25))
				m.box(Vector3(0, 0.3, 0.16), Vector3(0.28, 0.2, 0.05), Color(0.24, 0.29, 0.2))
		"cama_simples":
			m.box(Vector3(0, 0.2, 0), Vector3(0.95, 0.3, 1.9), wood.darkened(0.15))
			m.box(Vector3(0, 0.42, 0), Vector3(0.9, 0.16, 1.85), Color(0.7, 0.68, 0.6))
		"bancada":
			m.box(Vector3(0, 0.86, 0), Vector3(1.0, 0.08, 0.8), wood)
			m.box(Vector3(-0.42, 0.42, 0), Vector3(0.1, 0.84, 0.7), wood.darkened(0.2))
			m.box(Vector3(0.42, 0.42, 0), Vector3(0.1, 0.84, 0.7), wood.darkened(0.2))
		"fogueira":
			for i in 7:
				var a := TAU * i / 7.0
				m.box(Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), Vector3(0.22, 0.2, 0.22), Color(0.45, 0.45, 0.44))
			m.box_t(Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, 0.1, 0)), Vector3(0.7, 0.1, 0.1), Color(0.2, 0.14, 0.1))
			m.box_t(Transform3D(Basis(Vector3.UP, -0.7), Vector3(0, 0.14, 0)), Vector3(0.7, 0.1, 0.1), Color(0.16, 0.12, 0.09))
		"coletor_chuva":
			m.tube(0, 0, 0.0, 0.9, Vector2(0.42, 0.42), Vector2(0.46, 0.46), Color(0.3, 0.42, 0.55), 10, true, false)
			m.tube(0, 0, 0.9, 1.2, Vector2(0.46, 0.46), Vector2(0.75, 0.75), Color(0.16, 0.16, 0.18), 10, false, false)
		"composteira":
			m.box(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), wood.darkened(0.2))
			m.box(Vector3(0, 0.91, 0), Vector3(0.8, 0.03, 0.8), Color(0.25, 0.2, 0.14))
		"secador":
			m.box(Vector3(-0.45, 0.7, 0), Vector3(0.06, 1.4, 0.06), wood)
			m.box(Vector3(0.45, 0.7, 0), Vector3(0.06, 1.4, 0.06), wood)
			m.box(Vector3(0, 1.3, 0), Vector3(0.96, 0.03, 0.03), Color(0.7, 0.66, 0.5))
			m.box(Vector3(0, 0.9, 0), Vector3(0.96, 0.03, 0.03), Color(0.7, 0.66, 0.5))
		"gerador":
			m.box(Vector3(0, 0.35, 0), Vector3(0.8, 0.5, 0.55), Color(0.75, 0.2, 0.15))
			m.box(Vector3(0, 0.66, 0), Vector3(0.6, 0.12, 0.4), Color(0.15, 0.15, 0.16))
			m.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.6), Color(0.2, 0.2, 0.22))
		"saco_dormir":
			m.box(Vector3(0, 0.08, 0), Vector3(0.7, 0.14, 1.9), Color(0.25, 0.4, 0.55))
		"barraca":
			m.gable(-1.1, 1.1, -1.4, 1.4, 0.0, 1.4, Color(0.55, 0.4, 0.2), Color(0.4, 0.3, 0.16), true)
	return m


static var _mesh_cache := {}


static func _spawn_struct(w: Node3D, ch: Dictionary, s: Dictionary) -> void:
	var type: String = s["t"]
	var d: Dictionary = STRUCTS[type]
	if not _mesh_cache.has(type):
		_mesh_cache[type] = _mesh(type).to_mesh(Mats.world)
	var n := Node3D.new()
	ch["node"].add_child(n)
	n.position = s["p"]
	n.rotation.y = int(s["r"]) * PI * 0.5
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_cache[type]
	n.add_child(mi)
	if type == "porta_madeira":
		var leaf := Node3D.new()
		leaf.name = "folha"
		leaf.position = Vector3(-0.44, 0, 0)
		var lm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.88, 2.15, 0.06)
		lm.mesh = bm
		lm.position = Vector3(0.44, 1.08, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.36, 0.22)
		lm.material_override = mat
		leaf.add_child(lm)
		n.add_child(leaf)
		leaf.rotation.y = PI * 0.5 if s.get("open", false) else 0.0
	if d.get("solid", false):
		var sb := StaticBody3D.new()
		sb.name = "corpo"
		sb.collision_layer = G.L_GLASS if d.get("low", false) else G.L_WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var h := 1.0 if d.get("low", false) else 2.6
		var thin: bool = type in ["parede_madeira", "porta_madeira", "cerca_madeira", "parede_pedra", "parede_metal"]
		cs.shape = Building.box_shape(Vector3(1.0, h, 0.2 if thin else 0.9))
		if type == "barraca":
			cs.shape = Building.box_shape(Vector3(2.0, 1.3, 2.6))
		cs.position.y = h * 0.5
		cs.disabled = s.get("open", false)
		sb.add_child(cs)
		sb.set_meta("struct", s)
		n.add_child(sb)
	if type == "fogueira":
		var l := OmniLight3D.new()
		l.name = "luz"
		l.position = Vector3(0, 0.7, 0)
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.shadow_enabled = false
		l.visible = s.get("on", false)
		n.add_child(l)
		var fl := MeshInstance3D.new()
		fl.name = "chama"
		var fm := MB.new()
		fm.tube(0, 0, 0.12, 0.75, Vector2(0.24, 0.24), Vector2(0.02, 0.02), Color(1.0, 0.55, 0.12), 6, false, false)
		fm.tube(0, 0, 0.12, 0.5, Vector2(0.14, 0.14), Vector2(0.02, 0.02), Color(1.0, 0.85, 0.3), 6, false, false)
		fl.mesh = fm.to_mesh(Mats.glow)
		fl.visible = s.get("on", false)
		n.add_child(fl)
		if s.get("on", false) and not w.fires.has(s["p"]):
			w.fires.append(s["p"])
	s["node"] = n
	ch["structs"].append(s)


# =====================================================================================
#  AGRICULTURA
# =====================================================================================
static func new_plot(w: Node3D, pos: Vector3) -> Dictionary:
	var k: Vector2i = w.key_of(pos)
	var st: Dictionary = w.cstate[k]
	if not st.has("plots"):
		st["plots"] = []
	var p := {"p": Vector3(floorf(pos.x) + 0.5, 0, floorf(pos.z) + 0.5), "crop": "", "g": 0.0, "w": 0.3, "hl": 1.0, "fz": 0.0, "dis": 0.0, "last": G.time_min}
	st["plots"].append(p)
	if w.chunks.has(k):
		_spawn_plot(w.chunks[k], p)
	return p


static func plot_at(w: Node3D, pos: Vector3) -> Variant:
	var ch = w.chunk_at(pos)
	if ch == null:
		return null
	for p in ch["plots"]:
		if absf(p["p"].x - pos.x) < 0.5 and absf(p["p"].z - pos.z) < 0.5:
			return p
	return null


static func remove_plot(w: Node3D, p: Dictionary) -> void:
	var k: Vector2i = w.key_of(p["p"])
	if p.has("node") and is_instance_valid(p["node"]):
		p["node"].queue_free()
	p.erase("node")
	if w.chunks.has(k):
		w.chunks[k]["plots"].erase(p)
	w.cstate[k].get("plots", []).erase(p)


## 0 vazio, 1 semeado, 2 broto, 3 crescendo, 4 maduro, 5 passado, 6 morto
static func plot_stage(p: Dictionary) -> int:
	if p["crop"] == "":
		return 0
	if float(p["hl"]) <= 0.0:
		return 6
	var g: float = p["g"]
	if g < 0.15:
		return 1
	if g < 0.5:
		return 2
	if g < 1.0:
		return 3
	if g < 1.7:
		return 4
	return 5


## Avanca o canteiro ate o instante atual (tambem usado quando a regiao recarrega).
static func advance_plot(p: Dictionary) -> void:
	var now := G.time_min
	var dd: float = (now - float(p["last"])) / 1440.0
	p["last"] = now
	if dd <= 0.0 or p["crop"] == "":
		return
	var c: Dictionary = CROPS[p["crop"]]
	var steps := maxi(1, int(ceil(dd / 0.25)))
	var h := dd / steps
	var winter := G.season_name() == "inverno"
	for i in steps:
		p["w"] = maxf(0.0, float(p["w"]) - 0.38 * h)
		if steps > 4 and (G.hash2(int(now / 1440.0) - i / 4, int(p["p"].x), 3) % 100) < 26:
			p["w"] = minf(1.0, float(p["w"]) + 0.5)
		var rate := 1.0 / float(c["days"]) * float(G.sandbox.get("crop_speed", 1.0))
		if float(p["w"]) < 0.12:
			rate *= 0.15
			p["hl"] = float(p["hl"]) - 0.22 * h
		elif float(p["w"]) > 0.3:
			p["hl"] = minf(1.0, float(p["hl"]) + 0.08 * h)
		if winter and not c["cold"]:
			rate *= 0.35
			p["hl"] = float(p["hl"]) - 0.06 * h
		if float(p["fz"]) > 0.0:
			rate *= 1.3
			p["fz"] = float(p["fz"]) - h
		if float(p["dis"]) > 0.0:
			p["dis"] = minf(1.0, float(p["dis"]) + 0.12 * h)
			p["hl"] = float(p["hl"]) - float(p["dis"]) * 0.25 * h
			rate *= 1.0 - 0.5 * float(p["dis"])
		elif float(p["w"]) > 0.92 and (G.hash2(int(now) + i, int(p["p"].z), 9) % 100) < 6:
			p["dis"] = 0.1
		p["g"] = float(p["g"]) + rate * h * clampf(float(p["hl"]) + 0.3, 0.3, 1.0)
		if float(p["g"]) > 2.4:
			p["hl"] = 0.0


static func _spawn_plot(ch: Dictionary, p: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	ch["node"].add_child(mi)
	mi.position = p["p"]
	p["node"] = mi
	ch["plots"].append(p)
	_refresh_plot(ch, p)


static func _refresh_plot(_ch: Dictionary, p: Dictionary) -> void:
	if not p.has("node") or not is_instance_valid(p["node"]):
		return
	var m := MB.new()
	var wet := float(p["w"])
	m.box(Vector3(0, 0.06, 0), Vector3(0.92, 0.12, 0.92), Color(0.34, 0.25, 0.17).lerp(Color(0.2, 0.15, 0.11), wet))
	var stg := plot_stage(p)
	if stg >= 1 and stg <= 6:
		var c: Dictionary = CROPS[p["crop"]]
		var leaf := Color(0.26, 0.5, 0.2)
		if stg == 5:
			leaf = Color(0.5, 0.45, 0.2)
		elif stg == 6:
			leaf = Color(0.35, 0.28, 0.18)
		if float(p["dis"]) > 0.3:
			leaf = leaf.lerp(Color(0.55, 0.5, 0.25), 0.5)
		var h: float = [0.0, 0.06, 0.2, 0.42, 0.6, 0.55, 0.3][stg]
		if p["crop"] == "milho":
			h *= 2.6
		for off in [Vector3(-0.22, 0, -0.22), Vector3(0.22, 0, -0.22), Vector3(-0.22, 0, 0.22), Vector3(0.22, 0, 0.22)]:
			m.box(off + Vector3(0, 0.12 + h * 0.5, 0), Vector3(0.16 + h * 0.2, h, 0.16 + h * 0.2), leaf)
			if stg == 4:
				m.box(off + Vector3(0.06, 0.12 + h * 0.75, 0.06), Vector3(0.1, 0.1, 0.1), c["col"])
	p["node"].mesh = m.to_mesh(Mats.world)


# =====================================================================================
#  ALVOS DE INTERACAO
# =====================================================================================
static func targets_near(_w: Node3D, k: Vector2i, ch: Dictionary, p: Vector3, out: Array) -> void:
	for s in ch["structs"]:
		if s["p"].distance_to(p) < 2.0:
			var d: Dictionary = STRUCTS[s["t"]]
			var lab := "Usar"
			match s["t"]:
				"porta_madeira":
					lab = "Fechar" if s.get("open", false) else "Abrir"
				"caixote", "bolsa_acampamento":
					lab = "Vasculhar"
				"fogueira":
					lab = "Fogo"
				"cama_simples", "saco_dormir", "barraca":
					lab = "Dormir"
				"coletor_chuva":
					lab = "Água"
				"bancada":
					lab = "Bancada"
				"parede_madeira", "cerca_madeira", "piso_madeira", "parede_pedra", "parede_metal", "telhado_madeira", "escada_madeira":
					lab = "Desmontar"
			out.append({"kind": "estrutura", "key": k, "s": s, "pos": s["p"] + Vector3(0, 0.8, 0), "name": d["n"], "label": lab})
	for pl in ch["plots"]:
		if pl["p"].distance_to(p) < 1.7:
			var stg := plot_stage(pl)
			var nm := "Canteiro vazio"
			var lab2 := "Semear"
			if stg > 0:
				var c: Dictionary = CROPS[pl["crop"]]
				nm = "%s — %s" % [c["n"], ["", "semeado", "broto", "crescendo", "pronto para colher", "passando do ponto", "morto"][stg]]
				lab2 = "Colher" if (stg == 4 or stg == 5) else ("Remover" if stg == 6 else "Regar")
			out.append({"kind": "canteiro", "key": k, "pl": pl, "pos": pl["p"] + Vector3(0, 0.3, 0), "name": nm, "label": lab2,
				"hint": "água %d%%%s%s" % [int(float(pl["w"]) * 100.0), "  •  adubado" if float(pl["fz"]) > 0.0 else "", "  •  doente" if float(pl["dis"]) > 0.2 else ""]})
