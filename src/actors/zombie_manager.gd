extends Node
## Populacao persistente de zumbis: cada regiao guarda seus zumbis "virtuais"; os proximos
## do jogador viram entidades completas e os distantes voltam ao resumo preservando posicao
## e dano. O limite de entidades ativas e uma regra de simulacao, nao uma opcao grafica.

const ACT_R := 78.0
const DEACT_R := 98.0
const CAP := 64

var active: Array = []
var pop := {}            # chave do chunk -> Array de zumbis virtuais
var orig := {}           # chave do chunk -> populacao inicial
var _t := 0.0
var _spawn_queue: Array = []
var _path_n := 0
var _hour := -1
var holder: Node3D
var total_killed := 0


func _ready() -> void:
	holder = Node3D.new()
	add_child(holder)


func active_count() -> int:
	return active.size()


func path_budget() -> bool:
	if _path_n >= 5:
		return false
	_path_n += 1
	return true


func query(p: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for z in active:
		if z.global_position.distance_squared_to(p) <= r2:
			out.append(z)
	return out


func threat_count(p: Vector3) -> int:
	var n := 0
	for z in active:
		if z.dead:
			continue
		var d: float = z.global_position.distance_to(p)
		if d < 4.5 or (d < 11.0 and z.sees):
			n += 1
	return n


func danger_near(p: Vector3, r: float) -> bool:
	for z in active:
		if not z.dead and z.global_position.distance_to(p) < r:
			return true
	return false


## Evento sonoro: afeta zumbis ativos e desloca os virtuais na direcao do som.
func hear(pos: Vector3, radius: float) -> void:
	var hm: float = [0.6, 1.0, 1.5][clampi(int(G.sandbox["zombie_hearing"]), 0, 2)]
	var r := radius * hm
	for z in active:
		var d: float = z.global_position.distance_to(pos)
		if d < r:
			z.hear(pos, 1.0 - d / r)
	if r > 30.0:
		var k0 := WorldGen.ck(pos.x, pos.z)
		var cr := int(ceil(r / WorldGen.CH))
		for dx in range(-cr, cr + 1):
			for dz in range(-cr, cr + 1):
				var k := Vector2i(k0.x + dx, k0.y + dz)
				if not pop.has(k):
					continue
				for v in pop[k]:
					var d2: float = v["p"].distance_to(pos)
					if d2 < r and d2 > 12.0 and randf() < 0.5:
						var step := minf(d2 - 10.0, r * 0.3)
						var np: Vector3 = v["p"] + (pos - v["p"]).normalized() * step
						v["p"] = Vector3(np.x, 0.0, np.z)
						v["mig"] = true


func alert_group(src: Node3D) -> void:
	for z in active:
		if z != src and not z.dead and z.global_position.distance_to(src.global_position) < 9.0:
			z.alert(src.target_pos)


func on_death(z: Node3D) -> void:
	active.erase(z)
	total_killed += 1


# =====================================================================================
#  POPULACAO INICIAL POR REGIAO
# =====================================================================================
func _init_chunk(k: Vector2i) -> bool:
	var w: Node3D = G.world
	var gen: WorldGen = w.gen
	# edificios desta regiao precisam estar carregados para posicionar zumbis dentro deles
	for lid in gen.chunk_lots.get(k, []):
		if gen.lots[lid]["type"] != "praca" and not w.buildings.has(lid):
			return false
	var r := RandomNumberGenerator.new()
	r.seed = G.hash2(k.x, k.y, G.world_seed + 5)
	var mult: float = float(G.sandbox["zombie_pop"])
	var list: Array = []
	var cx := (k.x + 0.5) * WorldGen.CH
	var cz := (k.y + 0.5) * WorldGen.CH
	var zn := gen.zone_at(cx, cz)
	var city := gen.city_at(cx, cz)
	var base := 0.35
	match zn:
		WorldGen.Z_CITY:
			base = 3.4 if city == 1 else 5.6
		WorldGen.Z_FARM:
			base = 0.5
		WorldGen.Z_FOREST:
			base = 0.32
		WorldGen.Z_RIVER:
			base = 0.0
	if gen.road_at(cx, cz) >= 0 and zn != WorldGen.Z_CITY:
		base += 0.5
	var n := _count(base * mult, r)
	for i in n:
		var p := Vector3(k.x * WorldGen.CH + r.randf() * WorldGen.CH, 0, k.y * WorldGen.CH + r.randf() * WorldGen.CH)
		if gen.zone_at(p.x, p.z) == WorldGen.Z_RIVER or w.building_at(p) != null or w.cell_blocked(p.x, p.z):
			continue
		var pf := "civil"
		if zn == WorldGen.Z_FARM and r.randf() < 0.5:
			pf = "fazenda"
		list.append({"p": p, "s": r.randi(), "pf": pf})
	for lid in gen.chunk_lots.get(k, []):
		var lot: Dictionary = gen.lots[lid]
		if lot["type"] == "praca":
			continue
		var b: Building = w.buildings[lid]
		var td: Dictionary = WorldGen.TYPES[lot["type"]]
		var area := float(b.plan.w * b.plan.d * b.plan.floors)
		var nb := _count(area / 105.0 * float(td["zd"]) * mult, r)
		for i in nb:
			var f := r.randi() % b.plan.floors
			for attempt in 8:
				var lx := r.randi_range(1, b.plan.w - 2)
				var lz := r.randi_range(1, b.plan.d - 2)
				if b.plan.tg(f, lx, lz) == BPlan.T_FLOOR:
					var wp := b.to_global(Vector3(lx + 0.5, f * BPlan.FH + 0.1, lz + 0.5))
					var pf2: String = td["zp"]
					if pf2 != "civil" and r.randf() < 0.35:
						pf2 = "civil"
					list.append({"p": wp, "s": r.randi(), "pf": pf2})
					break
	pop[k] = list
	orig[k] = list.size()
	return true


func _count(x: float, r: RandomNumberGenerator) -> int:
	var n := int(floor(x))
	if r.randf() < x - n:
		n += 1
	return n


# =====================================================================================
#  ATIVACAO E DESATIVACAO
# =====================================================================================
func _physics_process(dt: float) -> void:
	if G.paused or not G.in_game or G.player == null or not is_instance_valid(G.player):
		return
	_path_n = 0
	# no maximo dois zumbis novos por quadro (evita picos ao entrar em areas cheias)
	var made := 0
	while not _spawn_queue.is_empty() and made < 2 and active.size() < CAP:
		var v: Dictionary = _spawn_queue.pop_front()
		_spawn(v)
		made += 1
	_separate()
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var pp: Vector3 = G.player.global_position
	var k0 := WorldGen.ck(pp.x, pp.z)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var k := Vector2i(k0.x + dx, k0.y + dz)
			if not G.world.chunks.has(k):
				continue
			if not pop.has(k):
				if not _init_chunk(k):
					continue
			var list: Array = pop[k]
			var i := list.size() - 1
			while i >= 0:
				var v: Dictionary = list[i]
				if v["p"].distance_to(pp) < ACT_R and active.size() + _spawn_queue.size() < CAP:
					# nao materializa zumbis a vista e muito perto do jogador
					list.remove_at(i)
					_spawn_queue.append(v)
				i -= 1
	var j := active.size() - 1
	while j >= 0:
		var z: Zombie = active[j]
		if not is_instance_valid(z):
			active.remove_at(j)
		elif not z.dead and z.global_position.distance_to(pp) > DEACT_R:
			var kk := WorldGen.ck(z.global_position.x, z.global_position.z)
			if not pop.has(kk):
				pop[kk] = []
				orig[kk] = 0
			pop[kk].append(z.to_virtual())
			active.remove_at(j)
			z.queue_free()
		j -= 1
	var h := int(G.hours_total())
	if h != _hour:
		_hour = h
		_respawn()
		_check_reanimation()


func _spawn(v: Dictionary) -> void:
	var z := Zombie.new()
	z.setup(v)
	holder.add_child(z)
	z.global_position = v["p"]
	z.rotation.y = randf() * TAU
	active.append(z)


var _sep_i := 0


## Separacao suave entre zumbis (evita que ocupem o mesmo lugar). Posicoes copiadas uma vez
## para vetores locais; executa em quadros alternados.
func _separate() -> void:
	_sep_i += 1
	if _sep_i % 2 != 0:
		return
	var n := active.size()
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var pz := PackedFloat32Array()
	var ok := PackedByteArray()
	px.resize(n)
	py.resize(n)
	pz.resize(n)
	ok.resize(n)
	for i in n:
		var z: Zombie = active[i]
		var gp := z.global_position
		px[i] = gp.x
		py[i] = gp.y
		pz[i] = gp.z
		ok[i] = 0 if (z.dead or z.state == Zombie.CLIMB) else 1
	for i in n:
		if ok[i] == 0:
			continue
		var ax := px[i]
		var az := pz[i]
		var ay := py[i]
		for j in range(i + 1, n):
			var dx := ax - px[j]
			if dx > 0.65 or dx < -0.65:
				continue
			var dz := az - pz[j]
			if dz > 0.65 or dz < -0.65 or ok[j] == 0 or absf(ay - py[j]) > 1.5:
				continue
			var l2 := dx * dx + dz * dz
			if l2 < 0.42 and l2 > 0.0001:
				var l := sqrt(l2)
				var f := (0.65 - l) * 3.0 / l
				var push := Vector3(dx * f, 0, dz * f)
				active[i].sep += push
				active[j].sep -= push


## Reaparecimento lento em regioes ja visitadas e longe do jogador (configuravel).
func _respawn() -> void:
	var rh := int(G.sandbox.get("respawn_hours", 72))
	if rh <= 0 or _hour % maxi(1, rh / 6) != 0:
		return
	var pp: Vector3 = G.player.global_position
	var k0 := WorldGen.ck(pp.x, pp.z)
	var r := RandomNumberGenerator.new()
	r.seed = G.hash2(_hour, 4, G.world_seed)
	for k in pop.keys():
		if absi(k.x - k0.x) <= 3 and absi(k.y - k0.y) <= 3:
			continue
		var want: int = int(orig.get(k, 0))
		var have: int = pop[k].size()
		if have < want and r.randf() < 0.35:
			var p := Vector3((k.x + r.randf()) * WorldGen.CH, 0, (k.y + r.randf()) * WorldGen.CH)
			if G.world.gen.zone_at(p.x, p.z) != WorldGen.Z_RIVER and G.world.gen.lot_at(p.x, p.z) < 0:
				pop[k].append({"p": p, "s": r.randi(), "pf": "civil"})


## Cadaver de sobrevivente infectado levanta como zumbi.
func _check_reanimation() -> void:
	var w: Node3D = G.world
	for k in w.chunks.keys():
		var list: Array = w.cstate.get(k, {}).get("corpses", [])
		for e in list.duplicate():
			if float(e.get("re", -1.0)) > 0.0 and G.time_min >= float(e["re"]):
				var lk: Dictionary = e["look"].duplicate()
				w.remove_corpse(k, e)
				var z := Zombie.new()
				z.setup({"s": randi(), "pf": "civil"})
				lk["zombie"] = true
				z.look = lk
				holder.add_child(z)
				z.global_position = e["p"]
				active.append(z)


func clear_all() -> void:
	for z in active:
		if is_instance_valid(z):
			z.queue_free()
	active.clear()
	_spawn_queue.clear()


func to_dict() -> Dictionary:
	# zumbis ativos voltam para o resumo de sua regiao no arquivo salvo
	var out := {}
	for k in pop:
		out[k] = pop[k].duplicate(true)
	for v in _spawn_queue:
		var k2 := WorldGen.ck(v["p"].x, v["p"].z)
		if not out.has(k2):
			out[k2] = []
		out[k2].append(v)
	for z in active:
		if is_instance_valid(z) and not z.dead:
			var k3 := WorldGen.ck(z.global_position.x, z.global_position.z)
			if not out.has(k3):
				out[k3] = []
			out[k3].append(z.to_virtual())
	return {"pop": out, "orig": orig, "killed": total_killed}


func from_dict(d: Dictionary) -> void:
	clear_all()
	pop = d.get("pop", {})
	orig = d.get("orig", {})
	total_killed = d.get("killed", 0)
