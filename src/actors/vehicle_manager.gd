extends Node3D
## Gerenciador de veiculos: guarda o estado persistente de todos os carros do mundo e mantem
## nos (Vehicle) apenas nas regioes carregadas. Os carros podem ser levados para outros lugares,
## por isso existe um indice pela regiao ATUAL de cada um, alem das posicoes originais do mapa.

const REACH := 3.2            # alcance de interacao, medido do centro do veiculo
const SWEEP := 1.5            # intervalo (s) da varredura de manutencao

var cars: Dictionary = {}     # id -> estado persistente (Dictionary simples, gravavel com store_var)
var index: Dictionary = {}    # chave do chunk -> Array de ids que estao nele agora
var nodes: Dictionary = {}    # id -> Vehicle ativo
var _where: Dictionary = {}   # id -> chave do chunk em que o id esta indexado
var _reseat := -1             # id do carro em que o jogador estava ao salvar
var _reseat_t := 0.0
var _t := 0.0


static func key_of(p: Vector3) -> Vector2i:
	return WorldGen.ck(p.x, p.z)


## Um carro do mapa existe neste mundo? (sorteio fixo por id e semente; viaturas e ambulancias sempre)
func exists(id: int, type: String) -> bool:
	if type == "policia" or type == "ambulancia":
		return true
	return float(G.hash2(id, 31, G.world_seed) % 1000) / 1000.0 < 0.75 * float(G.sandbox.get("car_spawn", 1.0))


# =====================================================================================
#  REGIOES
# =====================================================================================
func chunk_loaded(k: Vector2i) -> void:
	if G.world == null or not is_instance_valid(G.world):
		return
	var gen = G.world.gen
	# carros do mapa vistos pela primeira vez: cria o estado deterministico
	for cid in gen.chunk_cars.get(k, []):
		var id: int = cid
		if cars.has(id):
			continue
		var c: Dictionary = gen.cars[id]
		var type: String = c["type"]
		if not exists(id, type):
			continue
		var p: Vector2 = c["p"]
		cars[id] = Vehicle.new_state(id, type, Vector3(p.x, 0.0, p.y), float(c["rot"]), G.hash2(id, 977, G.world_seed))
		_index_set(id, k)
	# todos os carros cuja posicao atual fica nesta regiao
	for cid2 in index.get(k, []).duplicate():
		_spawn(int(cid2))


func chunk_unloaded(k: Vector2i) -> void:
	for id in nodes.keys():
		var v := _node(id)
		if v == null:
			nodes.erase(id)
			continue
		if key_of(v.global_position) != k:
			continue
		if v.driver != null:
			continue              # nunca remove o veiculo em que o jogador esta
		_despawn(int(id))


## No ativo de um id, ou null (tambem se o no ja tiver sido liberado).
func _node(id) -> Vehicle:
	var o = nodes.get(id, null)
	if o == null or not is_instance_valid(o):
		return null
	return o


func _spawn(id: int) -> void:
	if _node(id) != null:
		return
	if not cars.has(id):
		return
	var st: Dictionary = cars[id]
	var v := Vehicle.new()
	v.setup(st)
	add_child(v)
	nodes[id] = v
	if id == _reseat:
		_try_reseat()


func _despawn(id: int) -> void:
	var v := _node(id)
	nodes.erase(id)
	if v != null:
		_store(v)
		v.queue_free()


## Grava o estado do no no dicionario persistente e atualiza o indice por regiao.
func _store(v: Vehicle) -> void:
	v.save_state()
	cars[v.id] = v.state
	var pos: Vector3 = v.state["pos"]
	_index_set(v.id, key_of(pos))


func _index_set(id: int, k: Vector2i) -> void:
	if _where.has(id):
		var old: Vector2i = _where[id]
		if old == k:
			return
		if index.has(old):
			var l: Array = index[old]
			l.erase(id)
			if l.is_empty():
				index.erase(old)
	_where[id] = k
	if not index.has(k):
		index[k] = []
	var l2: Array = index[k]
	if not l2.has(id):
		l2.append(id)


func _rebuild_index() -> void:
	index.clear()
	_where.clear()
	for id in cars:
		var st: Dictionary = cars[id]
		var pos: Vector3 = st.get("pos", Vector3.ZERO)
		_index_set(int(id), key_of(pos))


# =====================================================================================
#  MANUTENCAO
# =====================================================================================
func _process(dt: float) -> void:
	if not G.in_game or G.paused:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = SWEEP
	var w = G.world
	var has_world: bool = w != null and is_instance_valid(w)
	for id in nodes.keys():
		var v := _node(id)
		if v == null:
			nodes.erase(id)
			continue
		var k := key_of(v.global_position)
		_index_set(int(id), k)
		if v.driver != null:
			continue
		if has_world and not w.chunks.has(k):
			_despawn(int(id))         # rolou para fora da area carregada
		elif v.lights_on:
			v.idle_update()           # farois acesos gastam a bateria mesmo com o carro parado
	if _reseat >= 0:
		_reseat_t += SWEEP
		_try_reseat()
		if _reseat_t > 30.0:
			_reseat = -1


## Recoloca o jogador no veiculo que ele dirigia quando o jogo foi salvo.
func _try_reseat() -> void:
	if _reseat < 0:
		return
	var v := _node(_reseat)
	var p: Node3D = G.player
	if v == null or p == null or not is_instance_valid(p):
		return
	_reseat = -1
	if p.vehicle == null and not p.sv.dead and p.global_position.distance_to(v.global_position) < 4.5:
		v.enter_player(p, true)


# =====================================================================================
#  CONSULTAS
# =====================================================================================
func targets_near(p: Vector3, out: Array) -> void:
	for id in nodes:
		var v := _node(id)
		if v == null:
			continue
		var d := v.global_position - p
		if absf(d.y) > 2.0:
			continue
		d.y = 0.0
		var hl: float = float(v.spec["len"]) * 0.5
		var hw: float = float(v.spec["wid"]) * 0.5
		if d.length() > REACH + maxf(0.0, hl - 2.2):
			continue
		# distancia ate a lataria (veiculos compridos sao alcancados pelas pontas)
		var l: Vector3 = v.to_local(p)
		var ex := maxf(absf(l.x) - hw, 0.0)
		var ez := maxf(absf(l.z) - hl, 0.0)
		if ex * ex + ez * ez > 1.7 * 1.7:
			continue
		var zone := "porta"
		if l.z > hl - 0.5 and absf(l.x) < hw + 0.3:
			zone = "porta_malas"
		elif l.z < -hl + 0.5 and absf(l.x) < hw + 0.3:
			zone = "capo"
		var t := {"kind": "veiculo", "obj": v, "pos": v.global_position + Vector3(0, 1.0, 0), "name": v.display_name, "label": "Entrar", "zone": zone}
		if v.locked:
			t["hint"] = "Trancado"
		elif v.has_key:
			t["hint"] = "Chave na ignição"
		out.append(t)


## Veiculo mais proximo de p dentro do raio r (ou null).
func nearest(p: Vector3, r: float) -> Variant:
	var best: Vehicle = null
	var best_d := r
	for id in nodes:
		var v := _node(id)
		if v == null:
			continue
		var d := v.global_position.distance_to(p)
		if d <= best_d:
			best_d = d
			best = v
	return best


## Estado persistente de um carro ja visto ({} se desconhecido).
func state_of(id: int) -> Dictionary:
	return cars.get(id, {})


# =====================================================================================
#  SALVAMENTO
# =====================================================================================
func to_dict() -> Dictionary:
	var drv := -1
	for id in nodes:
		var v := _node(id)
		if v == null:
			continue
		_store(v)
		if v.driver != null:
			drv = int(id)
	return {"v": 1, "cars": cars.duplicate(true), "driver": drv}


func from_dict(d: Dictionary) -> void:
	for id in nodes:
		var v := _node(id)
		if v != null:
			if v.driver != null and is_instance_valid(v.driver):
				v.exit_player(v.driver, true)
			v.queue_free()
	nodes.clear()
	cars = {}
	var src: Dictionary = d.get("cars", {})
	for id2 in src:
		var st = src[id2]
		if typeof(st) != TYPE_DICTIONARY:
			continue
		Vehicle.fill_defaults(st)
		st["id"] = int(id2)
		cars[int(id2)] = st
	_rebuild_index()
	_reseat = int(d.get("driver", -1))
	_reseat_t = 0.0
	# regioes ja carregadas antes da leitura do arquivo
	if G.world != null and is_instance_valid(G.world):
		for k in G.world.chunks.keys():
			chunk_loaded(k)
