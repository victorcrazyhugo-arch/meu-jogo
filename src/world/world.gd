extends Node3D
## Mundo: carregamento por regioes (chunks de 40 m) com geracao em threads, terreno,
## vegetacao instanciada, edificios, itens no chao, cadaveres, navegacao dos zumbis
## e estado persistente (nada e restaurado ao descarregar uma regiao).

const CH := WorldGen.CH
const NAV_N := 224
const TREE_NAMES := ["Pinheiro", "Árvore", "Árvore seca", "Arbusto", "Pedra"]

var gen: WorldGen
var chunks := {}
var buildings := {}
var bstate := {}
var cstate := {}
var radius := 4
var astar := AStarGrid2D.new()
var nav_rect := Rect2i(0, 0, 0, 0)
var nav_special := {}          # celula -> ["porta"/"janela", Building, indice]
var _pending := {}
var _results: Array = []
var _mutex := Mutex.new()
var _build_queue: Array = []
var _center := Vector2i(99999, 99999)
var _nav_dirty := false
var _nav_t := 0.0
var _tree_meshes: Array = []
var _tree_shape: CylinderShape3D
var _item_meshes := {}
var _stump_mesh: ArrayMesh
var lit_building: Building = null
var fires: Array = []          # posicoes de fontes de calor acesas


func _ready() -> void:
	Mats.init()
	gen = WorldGen.new()
	var gb := StaticBody3D.new()
	gb.collision_layer = G.L_WORLD
	gb.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	gb.add_child(cs)
	add_child(gb)
	_tree_shape = CylinderShape3D.new()
	_tree_shape.radius = 0.3
	_tree_shape.height = 7.0
	_make_tree_meshes()
	astar.cell_size = Vector2(1, 1)
	astar.offset = Vector2(0.5, 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	apply_graphics()
	G.settings_changed.connect(apply_graphics)


func apply_graphics() -> void:
	radius = [3, 4, 5][clampi(int(G.settings["graphics"]), 0, 2)]
	_center = Vector2i(99999, 99999)


# =====================================================================================
#  MALHAS COMPARTILHADAS
# =====================================================================================
func _make_tree_meshes() -> void:
	var bark := Color(0.32, 0.23, 0.15)
	# 0 conifera
	var t := MB.new()
	var f := MB.new()
	t.tube(0, 0, 0.0, 2.2, Vector2(0.2, 0.2), Vector2(0.13, 0.13), bark, 6, false, false)
	var g := Color(0.13, 0.30, 0.17)
	f.tube(0, 0, 1.3, 3.4, Vector2(1.7, 1.7), Vector2(0.25, 0.25), g, 8, true, false)
	f.tube(0, 0, 2.8, 4.8, Vector2(1.3, 1.3), Vector2(0.15, 0.15), g.lightened(0.06), 8, true, false)
	f.tube(0, 0, 4.2, 6.2, Vector2(0.9, 0.9), Vector2(0.02, 0.02), g.lightened(0.12), 8, true, false)
	_tree_meshes.append(_two(t, f))
	# 1 folhosa
	t = MB.new()
	f = MB.new()
	t.tube(0, 0, 0.0, 2.8, Vector2(0.24, 0.24), Vector2(0.16, 0.16), bark.lightened(0.06), 6, false, false)
	var g2 := Color(0.22, 0.40, 0.16)
	f.ellipsoid(Vector3(0, 3.9, 0), Vector3(2.1, 1.6, 2.1), g2, 8, 5)
	f.ellipsoid(Vector3(0.9, 3.2, 0.5), Vector3(1.3, 1.0, 1.3), g2.darkened(0.1), 7, 4)
	f.ellipsoid(Vector3(-0.8, 3.4, -0.6), Vector3(1.2, 1.0, 1.2), g2.lightened(0.08), 7, 4)
	_tree_meshes.append(_two(t, f))
	# 2 seca
	t = MB.new()
	f = MB.new()
	var dead := Color(0.36, 0.31, 0.26)
	t.tube(0, 0, 0.0, 3.6, Vector2(0.2, 0.2), Vector2(0.07, 0.07), dead, 6, false, true)
	t.box_t(Transform3D(Basis(Vector3.BACK, 0.9), Vector3(0.5, 2.6, 0)), Vector3(0.09, 1.4, 0.09), dead)
	t.box_t(Transform3D(Basis(Vector3.BACK, -0.8), Vector3(-0.45, 2.2, 0.1)), Vector3(0.08, 1.2, 0.08), dead)
	t.box_t(Transform3D(Basis(Vector3.RIGHT, 0.8), Vector3(0, 3.0, 0.4)), Vector3(0.07, 1.0, 0.07), dead)
	_tree_meshes.append(_two(t, f))
	# 3 arbusto
	t = MB.new()
	f = MB.new()
	f.ellipsoid(Vector3(0, 0.45, 0), Vector3(0.85, 0.6, 0.85), Color(0.2, 0.36, 0.17), 7, 4)
	f.ellipsoid(Vector3(0.4, 0.35, 0.3), Vector3(0.5, 0.42, 0.5), Color(0.24, 0.42, 0.18), 6, 3)
	_tree_meshes.append(_two(t, f))
	# 4 pedra
	t = MB.new()
	f = MB.new()
	t.ellipsoid(Vector3(0, 0.25, 0), Vector3(0.7, 0.45, 0.55), Color(0.46, 0.46, 0.45), 7, 4)
	t.ellipsoid(Vector3(0.4, 0.15, 0.3), Vector3(0.35, 0.25, 0.3), Color(0.40, 0.40, 0.40), 6, 3)
	_tree_meshes.append(_two(t, f))
	var s := MB.new()
	s.tube(0, 0, 0.0, 0.35, Vector2(0.24, 0.24), Vector2(0.22, 0.22), bark, 6, false, true)
	_stump_mesh = s.to_mesh(Mats.world)


func _two(trunk: MB, leaf: MB) -> ArrayMesh:
	var m := ArrayMesh.new()
	trunk.add_to(m, Mats.world)
	leaf.add_to(m, Mats.foliage)
	return m


func item_mesh(it: Dictionary) -> ArrayMesh:
	var d := Items.def(it["id"])
	var cat: String = d.get("cat", "Diversos")
	var key: String = cat
	if d.has("mdl"):
		return Humanoid.weapon_mesh(d["mdl"])
	if _item_meshes.has(key):
		return _item_meshes[key]
	var m := MB.new()
	match cat:
		"Comida":
			m.box(Vector3(0, 0.07, 0), Vector3(0.18, 0.14, 0.18), Color(0.75, 0.3, 0.2))
		"Bebida", "Recipiente":
			m.tube(0, 0, 0.0, 0.26, Vector2(0.05, 0.05), Vector2(0.04, 0.04), Color(0.3, 0.5, 0.7), 6)
		"Médico":
			m.box(Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.14), Color(0.9, 0.9, 0.9))
			m.box(Vector3(0, 0.101, 0), Vector3(0.1, 0.004, 0.03), Color(0.8, 0.1, 0.1))
		"Roupa":
			m.box(Vector3(0, 0.04, 0), Vector3(0.34, 0.08, 0.28), Color(0.4, 0.45, 0.6))
		"Munição":
			m.box(Vector3(0, 0.04, 0), Vector3(0.12, 0.08, 0.08), Color(0.6, 0.5, 0.2))
		"Literatura":
			m.box(Vector3(0, 0.025, 0), Vector3(0.2, 0.05, 0.28), Color(0.5, 0.25, 0.2))
		"Material":
			m.box(Vector3(0, 0.05, 0), Vector3(0.3, 0.1, 0.2), Color(0.5, 0.4, 0.28))
		_:
			m.box(Vector3(0, 0.06, 0), Vector3(0.22, 0.12, 0.18), Color(0.5, 0.5, 0.45))
	var mesh := m.to_mesh(Mats.flat)
	_item_meshes[key] = mesh
	return mesh


# =====================================================================================
#  CARREGAMENTO POR REGIOES
# =====================================================================================
static func key_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CH), floori(p.z / CH))


func _in_map(k: Vector2i) -> bool:
	return k.x >= floori(WorldGen.X0 / CH) and k.x < ceili(WorldGen.X1 / CH) and k.y >= floori(WorldGen.Z0 / CH) and k.y < ceili(WorldGen.Z1 / CH)


func focus(p: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	# antecipa o carregamento na direcao do deslocamento
	var ahead := p + vel * 1.6
	var c := key_of(ahead)
	if c == _center:
		return
	_center = c
	var want: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _in_map(k) and not chunks.has(k) and not _pending.has(k):
				want.append(k)
	want.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())
	for k in want:
		_request(k)
	for k in chunks.keys():
		if absi(k.x - c.x) > radius + 1 or absi(k.y - c.y) > radius + 1:
			_unload(k)
	var pc := Vector2i(floori(p.x), floori(p.z))
	if nav_rect.size.x == 0 or absi(pc.x - (nav_rect.position.x + NAV_N / 2)) > 44 or absi(pc.y - (nav_rect.position.y + NAV_N / 2)) > 44:
		_nav_shift(pc)


func ready_around(p: Vector3, r: int) -> bool:
	var c := key_of(p)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _in_map(k) and not chunks.has(k):
				return false
	return _build_queue.is_empty()


func _request(k: Vector2i) -> void:
	_pending[k] = true
	var gone := {}
	for lid in gen.chunk_lots.get(k, []):
		if bstate.has(lid):
			gone[lid] = bstate[lid].get("gone", []).duplicate()
	WorkerThreadPool.add_task(_gen_chunk.bind(k, gone))


func _unload(k: Vector2i) -> void:
	var ch: Dictionary = chunks[k]
	if G.vehicles != null:
		G.vehicles.chunk_unloaded(k)
	for lid in ch["bids"]:
		var b: Building = buildings.get(lid, null)
		if b != null:
			if b == lit_building:
				lit_building = null
			for c in b.get_meta("navsp", []):
				nav_special.erase(c)
		buildings.erase(lid)
	Base.unload_chunk(self, k, ch)
	ch["node"].queue_free()
	chunks.erase(k)


func _process(dt: float) -> void:
	# resultados das threads: no maximo um chunk-base por quadro
	var res = null
	_mutex.lock()
	if not _results.is_empty():
		res = _results.pop_front()
	_mutex.unlock()
	if res != null:
		_finish_chunk(res)
	var t0 := Time.get_ticks_usec()
	while not _build_queue.is_empty() and Time.get_ticks_usec() - t0 < 5000:
		var e: Array = _build_queue.pop_front()
		if chunks.has(e[0]):
			_make_building(e[0], e[1], e[2], e[3])
	if _nav_dirty:
		_nav_t -= dt
		if _nav_t <= 0.0:
			_nav_dirty = false
			_nav_shift(Vector2i(nav_rect.position.x + NAV_N / 2, nav_rect.position.y + NAV_N / 2))
	Base.process(self, dt)
	# luzes internas apenas no edificio onde o jogador esta
	var p: Node3D = G.player
	if p != null and is_instance_valid(p):
		var b = p.cur_building
		var want = b if (b != null and G.power_on() and G.daylight() < 0.75) else null
		if want != lit_building:
			if lit_building != null and is_instance_valid(lit_building):
				lit_building.set_lit(false)
			lit_building = want
			if want != null:
				want.set_lit(true)


# =====================================================================================
#  GERACAO EM THREAD (somente dados)
# =====================================================================================
func _flat(m: MB, r: Rect2, y: float, col: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	m.quad(Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), Vector3.UP, col)


func _zone_col(x: float, z: float) -> Color:
	var zn := gen.zone_at(x, z)
	var n := gen.noise.get_noise_2d(x * 3.1, z * 3.1) * 0.05
	var c := Color(0.37, 0.47, 0.24)
	match zn:
		WorldGen.Z_FOREST:
			c = Color(0.25, 0.34, 0.18)
		WorldGen.Z_FARM:
			c = Color(0.44, 0.47, 0.25)
		WorldGen.Z_CITY:
			c = Color(0.36, 0.43, 0.27)
		WorldGen.Z_RIVER:
			c = Color(0.24, 0.28, 0.22)
	return Color(c.r + n, c.g + n, c.b + n * 0.5)


func _other_road(i: int, x: float, z: float, list: Array) -> bool:
	for j in list:
		if j != i and gen.roads[j]["r"].has_point(Vector2(x, z)):
			return true
	return false


func _gen_chunk(k: Vector2i, gone: Dictionary) -> void:
	var x0 := float(k.x * CH)
	var z0 := float(k.y * CH)
	var crect := Rect2(x0, z0, CH, CH)
	var m := MB.new()
	var wm := MB.new()
	var wcols: Array = []
	var gcols: Array = []
	var nav := PackedVector2Array()
	# ---- terreno: grade 11x11 com cor por vertice
	var base := m.v.size()
	for gz in 11:
		for gx in 11:
			var px := x0 + gx * 4.0
			var pz := z0 + gz * 4.0
			m.v.append(Vector3(px, 0.0, pz))
			m.n.append(Vector3.UP)
			m.c.append(_zone_col(px, pz))
	for gz in 10:
		for gx in 10:
			var a := base + gz * 11 + gx
			m.ix.append(a); m.ix.append(a + 1); m.ix.append(a + 12)
			m.ix.append(a); m.ix.append(a + 12); m.ix.append(a + 11)
	# ---- lotes
	for lid in gen.chunk_lot_refs.get(k, []):
		var lot: Dictionary = gen.lots[lid]
		var lr := Rect2(lot["lot"]).intersection(crect)
		var lc := Color(0.33, 0.46, 0.25)
		var tp: String = lot["type"]
		if lot["city"] == 0:
			lc = Color(0.42, 0.38, 0.27)
		elif tp == "praca":
			lc = Color(0.34, 0.50, 0.26)
		elif tp != "casa":
			lc = Color(0.47, 0.47, 0.45) if WorldGen.TYPES[tp]["mat"] != "metal" else Color(0.40, 0.40, 0.40)
		_flat(m, lr, 0.015, lc)
		if tp == "praca":
			var lt: Rect2i = lot["lot"]
			_flat(m, Rect2(lt.position.x, lt.position.y + lt.size.y * 0.5 - 1.5, lt.size.x, 3.0).intersection(crect), 0.03, Color(0.62, 0.58, 0.48))
			_flat(m, Rect2(lt.position.x + lt.size.x * 0.5 - 1.5, lt.position.y, 3.0, lt.size.y).intersection(crect), 0.03, Color(0.62, 0.58, 0.48))
	# ---- plantacoes
	for fi in gen.chunk_fields.get(k, []):
		var fd: Dictionary = gen.fields[fi]
		var fr: Rect2 = fd["r"]
		_flat(m, fr.intersection(crect), 0.02, Color(0.36, 0.27, 0.18))
		var cc := Color(0.30, 0.50, 0.20)
		var chh := 0.3
		match fd["crop"]:
			"milho":
				cc = Color(0.50, 0.56, 0.22)
				chh = 1.5
			"repolho", "alface":
				cc = Color(0.42, 0.60, 0.34)
				chh = 0.22
			"abobora":
				cc = Color(0.34, 0.48, 0.2)
				chh = 0.25
			"tomate", "feijao_verde":
				chh = 0.7
		var rz := fr.position.y + 1.0
		while rz < fr.end.y - 0.5:
			if rz >= z0 and rz < z0 + CH:
				var xa := maxf(fr.position.x + 1.0, x0)
				var xb := minf(fr.end.x - 1.0, x0 + CH)
				if xb > xa:
					m.box(Vector3((xa + xb) * 0.5, chh * 0.5 + 0.02, rz), Vector3(xb - xa, chh, 0.45), cc, 1 | 4 | 8 | 16 | 32)
			rz += 1.6
	# ---- estradas
	var rlist: Array = gen.chunk_roads.get(k, [])
	for ri in rlist:
		var rd: Dictionary = gen.roads[ri]
		var rr: Rect2 = rd["r"]
		var cr := rr.intersection(crect)
		if cr.size.x <= 0.0 or cr.size.y <= 0.0:
			continue
		var kind: int = rd["kind"]
		if kind == 2:
			_flat(m, cr, 0.03, Color(0.44, 0.36, 0.25))
			continue
		_flat(m, cr, 0.04, Color(0.21, 0.21, 0.22))
		var hz: bool = rd["horiz"]
		# calcadas (ruas) em trechos de 2 m, omitidas nos cruzamentos
		if kind == 0:
			for side in 2:
				var a0 := cr.position.x if hz else cr.position.y
				var a1 := cr.end.x if hz else cr.end.y
				var q := floorf(a0 / 2.0) * 2.0
				var run_s := -1.0e9
				while q <= a1:
					var mid := q + 1.0
					var sx := mid if hz else ((rr.position.x + 1.0) if side == 0 else (rr.end.x - 1.0))
					var sz := ((rr.position.y + 1.0) if side == 0 else (rr.end.y - 1.0)) if hz else mid
					var ok := q < a1 and q >= a0 - 0.01 and not _other_road(ri, sx, sz, rlist)
					if ok and run_s < -1.0e8:
						run_s = q
					if not ok and run_s > -1.0e8:
						var e := minf(q, a1)
						if hz:
							_flat(m, Rect2(run_s, (rr.position.y if side == 0 else rr.end.y - 2.0), e - run_s, 2.0), 0.09, Color(0.56, 0.56, 0.54))
						else:
							_flat(m, Rect2((rr.position.x if side == 0 else rr.end.x - 2.0), run_s, 2.0, e - run_s), 0.09, Color(0.56, 0.56, 0.54))
						run_s = -1.0e9
					q += 2.0
		# faixa central tracejada
		var b0 := cr.position.x if hz else cr.position.y
		var b1 := cr.end.x if hz else cr.end.y
		var dq := ceilf(b0 / 8.0) * 8.0
		while dq + 3.0 <= b1:
			var dx := dq + 1.5 if hz else rr.position.x + rr.size.x * 0.5
			var dz := rr.position.y + rr.size.y * 0.5 if hz else dq + 1.5
			if not _other_road(ri, dx, dz, rlist):
				if hz:
					_flat(m, Rect2(dq, dz - 0.09, 3.0, 0.18), 0.05, Color(0.80, 0.74, 0.42))
				else:
					_flat(m, Rect2(dx - 0.09, dq, 0.18, 3.0), 0.05, Color(0.80, 0.74, 0.42))
			dq += 8.0
	# ---- rio: agua, bloqueio de travessia e guarda-corpos das pontes
	var zs := z0
	while zs < z0 + CH:
		var zc := zs + 1.0
		var rx := WorldGen.river_x(zc)
		var ra := rx - WorldGen.RIVER_HALF
		var rb := rx + WorldGen.RIVER_HALF
		if rb > x0 and ra < x0 + CH:
			var ca := maxf(ra, x0)
			var cb := minf(rb, x0 + CH)
			var ri2 := gen.road_at(rx, zs + 0.1)
			var ri3 := gen.road_at(rx, zs + 1.9)
			var bridged := ri2 >= 0 and ri3 >= 0 and gen.roads[ri2]["bridge"]
			if not bridged:
				_flat(wm, Rect2(ca, zs, cb - ca, 2.0), 0.06, Color.WHITE)
				gcols.append([Transform3D(Basis.IDENTITY, Vector3((ca + cb) * 0.5, 1.0, zc)), Vector3(cb - ca, 2.0, 2.0)])
				for xi in range(floori(ca), ceili(cb)):
					nav.append(Vector2(xi, floorf(zs)))
					nav.append(Vector2(xi, floorf(zs) + 1.0))
				if ri2 >= 0 or ri3 >= 0:
					m.box(Vector3((ca + cb) * 0.5, 0.55, zc), Vector3(cb - ca, 1.1, 0.25), Color(0.5, 0.5, 0.5))
		zs += 2.0
	# ---- cercas dos quintais (lotes residenciais pertencentes a este chunk)
	var plans: Array = []
	for lid in gen.chunk_lots.get(k, []):
		var lot2: Dictionary = gen.lots[lid]
		var tp2: String = lot2["type"]
		if tp2 == "praca":
			continue
		if tp2 == "casa":
			var lt2: Rect2i = lot2["lot"]
			var south: bool = lot2["face"] == 0
			var fz0 := float(lt2.position.y) if south else float(lt2.position.y + 7)
			var fz1 := float(lt2.end.y - 7) if south else float(lt2.end.y)
			_fence(m, gcols, nav, Vector2(lt2.position.x, fz0), Vector2(lt2.position.x, fz1))
			if south:
				_fence(m, gcols, nav, Vector2(lt2.position.x, lt2.position.y), Vector2(lt2.end.x, lt2.position.y))
		var plan := BPlan.generate(lot2)
		if gone.has(lid):
			plan.apply_gone(gone[lid])
		var mb := plan.build_mesh()
		var cells := PackedVector2Array()
		for c in plan.solid_cells[0]:
			cells.append(Vector2(plan.ltw(int(c.x), int(c.y))))
		plans.append([plan, mb, cells])
	# ---- acampamentos
	for ci in gen.chunk_camps.get(k, []):
		var cp: Vector2 = gen.camps[ci]["p"]
		var tc := [Color(0.3, 0.42, 0.3), Color(0.55, 0.4, 0.2), Color(0.25, 0.35, 0.5)][ci % 3]
		m.gable(cp.x - 1.3, cp.x + 1.3, cp.y - 1.6, cp.y + 1.6, 0.0, 1.5, tc, tc.darkened(0.3), true)
		wcols.append([Transform3D(Basis.IDENTITY, Vector3(cp.x, 0.7, cp.y)), Vector3(2.2, 1.4, 3.0)])
		for s in 7:
			var an := TAU * s / 7.0
			m.box(Vector3(cp.x + 3.5 + cos(an) * 0.55, 0.1, cp.y + sin(an) * 0.55), Vector3(0.24, 0.2, 0.24), Color(0.45, 0.45, 0.44))
		m.box(Vector3(cp.x + 3.5, 0.2, cp.y + 1.7), Vector3(1.6, 0.36, 0.36), Color(0.36, 0.26, 0.17))
	# ---- arvores
	var trees := gen.trees_for(k.x, k.y)
	for t in trees:
		if t["k"] != 3:
			nav.append(Vector2(floorf(t["x"]), floorf(t["z"])))
	var res := {"key": k, "ground": m, "water": wm, "wcols": wcols, "gcols": gcols, "trees": trees, "nav": nav, "plans": plans}
	_mutex.lock()
	_results.append(res)
	_mutex.unlock()


func _fence(m: MB, gcols: Array, nav: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var wood := Color(0.52, 0.42, 0.30)
	var len := a.distance_to(b)
	if len < 1.0:
		return
	var mid := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var sz := Vector3(len, 0.09, 0.05) if along_x else Vector3(0.05, 0.09, len)
	m.box(Vector3(mid.x, 0.45, mid.y), sz, wood)
	m.box(Vector3(mid.x, 0.85, mid.y), sz, wood)
	var n := int(len / 2.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, n))
		m.box(Vector3(p.x, 0.5, p.y), Vector3(0.1, 1.0, 0.1), wood.darkened(0.12))
	gcols.append([Transform3D(Basis.IDENTITY, Vector3(mid.x, 0.5, mid.y)), Vector3(len, 1.0, 0.16) if along_x else Vector3(0.16, 1.0, len)])
	for i in int(len) + 1:
		var p2 := a.lerp(b, float(i) / maxf(1.0, len))
		nav.append(Vector2(floorf(p2.x - (0.0 if along_x else 0.01)), floorf(p2.y - (0.01 if along_x else 0.0))))


# =====================================================================================
#  FINALIZACAO NA THREAD PRINCIPAL
# =====================================================================================
func _finish_chunk(res: Dictionary) -> void:
	var k: Vector2i = res["key"]
	_pending.erase(k)
	if chunks.has(k):
		return
	if absi(k.x - _center.x) > radius + 1 or absi(k.y - _center.y) > radius + 1:
		return
	var node := Node3D.new()
	add_child(node)
	var gmi := MeshInstance3D.new()
	gmi.mesh = res["ground"].to_mesh(Mats.world)
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(gmi)
	if not res["water"].is_empty():
		var wmi := MeshInstance3D.new()
		wmi.mesh = res["water"].to_mesh(Mats.water)
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(wmi)
	var sb := StaticBody3D.new()
	sb.collision_layer = G.L_WORLD
	sb.collision_mask = 0
	node.add_child(sb)
	var lb := StaticBody3D.new()
	lb.collision_layer = G.L_GLASS
	lb.collision_mask = 0
	lb.set_meta("low", true)
	node.add_child(lb)
	var trees: Array = res["trees"]
	var st: Dictionary = cstate.get(k, {})
	var cut: Dictionary = st.get("cut", {})
	# arvores cortadas ha mais de 40 dias voltam a crescer
	for ti in cut.keys():
		if G.time_min - float(cut[ti]) > 40.0 * 1440.0:
			cut.erase(ti)
	var counts := [0, 0, 0, 0, 0]
	for t in trees:
		counts[t["k"]] += 1
	var mms: Array = []
	for kind in 5:
		var mmi: MultiMeshInstance3D = null
		if counts[kind] > 0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _tree_meshes[kind]
			mm.instance_count = counts[kind]
			mmi = MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if kind >= 3:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mmi)
		mms.append(mmi)
	var idx := [0, 0, 0, 0, 0]
	var shape_i := 0
	var rid := sb.get_rid()
	for i in trees.size():
		var t: Dictionary = trees[i]
		var kind: int = t["k"]
		var s: float = t["s"]
		var tf := Transform3D(Basis(Vector3.UP, t["r"]).scaled(Vector3(s, s, s)), Vector3(t["x"], 0, t["z"]))
		t["mi"] = idx[kind]
		t["si"] = -1
		if cut.has(i):
			tf = Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), Vector3(t["x"], -5.0, t["z"]))
		mms[kind].multimesh.set_instance_transform(idx[kind], tf)
		idx[kind] += 1
		if kind != 3:
			if kind == 4:
				PhysicsServer3D.body_add_shape(rid, Building.box_shape(Vector3(1.2 * s, 0.9, 1.0 * s)).get_rid(), Transform3D(Basis.IDENTITY, Vector3(t["x"], 0.4, t["z"])))
			else:
				PhysicsServer3D.body_add_shape(rid, _tree_shape.get_rid(), Transform3D(Basis.IDENTITY, Vector3(t["x"], 3.5, t["z"])))
			t["si"] = shape_i
			if cut.has(i):
				PhysicsServer3D.body_set_shape_disabled(rid, shape_i, true)
			shape_i += 1
	for c in res["wcols"]:
		PhysicsServer3D.body_add_shape(rid, Building.box_shape(c[1]).get_rid(), c[0])
	var lrid := lb.get_rid()
	for c in res["gcols"]:
		PhysicsServer3D.body_add_shape(lrid, Building.box_shape(c[1]).get_rid(), c[0])
	var ch := {"node": node, "trees": trees, "mm": mms, "body": sb, "nav": res["nav"], "bids": [], "items": [], "corpses": [], "structs": [], "plots": [], "hp": {}}
	chunks[k] = ch
	if not cstate.has(k):
		cstate[k] = {}
	for p in res["plans"]:
		_build_queue.append([k, p[0], p[1], p[2]])
	# itens no chao e cadaveres persistidos
	for e in cstate[k].get("items", []):
		_spawn_item_node(ch, e)
	for e in cstate[k].get("corpses", []):
		_spawn_corpse_node(ch, e)
	for i in trees.size():
		if cut.has(i):
			_spawn_stump(ch, trees[i])
	_nav_add_cells(res["nav"], cut, trees)
	Base.load_chunk(self, k, ch)
	if G.vehicles != null:
		G.vehicles.chunk_loaded(k)


func _make_building(k: Vector2i, plan: BPlan, mb: MB, cells: PackedVector2Array) -> void:
	var b := Building.new()
	chunks[k]["node"].add_child(b)
	if not bstate.has(plan.id):
		bstate[plan.id] = {}
	b.setup(plan, mb, bstate[plan.id])
	b.set_meta("nav", cells)
	buildings[plan.id] = b
	chunks[k]["bids"].append(plan.id)
	_nav_add_building(b)


# =====================================================================================
#  NAVEGACAO
# =====================================================================================
func _nav_shift(c: Vector2i) -> void:
	nav_rect = Rect2i(c.x - NAV_N / 2, c.y - NAV_N / 2, NAV_N, NAV_N)
	astar.region = nav_rect
	astar.update()
	for k in chunks:
		var ch: Dictionary = chunks[k]
		_nav_add_cells(ch["nav"], cstate.get(k, {}).get("cut", {}), ch["trees"])
		Base.nav_chunk(self, k, ch)
	for lid in buildings:
		_nav_add_building(buildings[lid])


func _nav_add_cells(cells: PackedVector2Array, _cut: Dictionary, _trees: Array) -> void:
	if nav_rect.size.x == 0:
		return
	for c in cells:
		var p := Vector2i(c)
		if nav_rect.has_point(p):
			astar.set_point_solid(p, true)


func _nav_add_building(b: Building) -> void:
	if nav_rect.size.x == 0:
		return
	var cells: PackedVector2Array = b.get_meta("nav")
	for c in cells:
		var p := Vector2i(c)
		if nav_rect.has_point(p):
			astar.set_point_solid(p, true)
	var sp: Array = []
	for i in b.plan.doors.size():
		if b.plan.doors[i]["f"] == 0:
			var cell := b.plan.ltw(b.plan.doors[i]["x"], b.plan.doors[i]["z"])
			nav_special[cell] = ["porta", b, i]
			sp.append(cell)
			nav_door(b, i)
	for i in b.plan.windows.size():
		if b.plan.windows[i]["f"] == 0:
			var cell2 := b.plan.ltw(b.plan.windows[i]["x"], b.plan.windows[i]["z"])
			nav_special[cell2] = ["janela", b, i]
			sp.append(cell2)
			nav_window(b, i)
	b.set_meta("navsp", sp)


func nav_door(b: Building, i: int) -> void:
	var d: Dictionary = b.plan.doors[i]
	if d["f"] != 0:
		return
	var cell := b.plan.ltw(d["x"], d["z"])
	if not nav_rect.has_point(cell):
		return
	astar.set_point_solid(cell, false)
	var st := b.door_state(i)
	astar.set_point_weight_scale(cell, (14.0 + 10.0 * int(st["bar"])) if b.door_blocks(i) else 1.0)


func nav_window(b: Building, i: int) -> void:
	var wn: Dictionary = b.plan.windows[i]
	if wn["f"] != 0:
		return
	var cell := b.plan.ltw(wn["x"], wn["z"])
	if not nav_rect.has_point(cell):
		return
	astar.set_point_solid(cell, false)
	var st := b.win_state(i)
	astar.set_point_weight_scale(cell, 7.0 if b.win_passable(i) else 24.0 + 14.0 * int(st["bar"]))


func nav_rebuild_soon() -> void:
	_nav_dirty = true
	_nav_t = 0.4


func nav_set(cell: Vector2i, solid: bool) -> void:
	if nav_rect.has_point(cell):
		astar.set_point_solid(cell, solid)


func _free_cell(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var n := Vector2i(c.x + dx, c.y + dz)
				if nav_rect.has_point(n) and not astar.is_point_solid(n):
					return n
	return c


## Caminho em celulas (centros no plano XZ). Vazio se fora da area de navegacao.
func find_path(a: Vector3, b: Vector3) -> PackedVector2Array:
	var ia := Vector2i(floori(a.x), floori(a.z))
	var ib := Vector2i(floori(b.x), floori(b.z))
	if not nav_rect.has_point(ia) or not nav_rect.has_point(ib):
		return PackedVector2Array()
	ia = _free_cell(ia)
	ib = _free_cell(ib)
	return astar.get_point_path(ia, ib, true)


func cell_blocked(x: float, z: float) -> bool:
	var c := Vector2i(floori(x), floori(z))
	return nav_rect.has_point(c) and astar.is_point_solid(c)


# =====================================================================================
#  CONSULTAS
# =====================================================================================
func zone_at(x: float, z: float) -> int:
	return gen.zone_at(x, z)


func river_dist(x: float, z: float) -> float:
	return gen.river_dist(x, z)


func building_at(p: Vector3):
	var li := gen.lot_at(p.x, p.z)
	if li < 0:
		return null
	var b: Building = buildings.get(li, null)
	if b != null and b.contains(p):
		return b
	return null


func surface_at(p: Vector3) -> String:
	var b = building_at(p)
	if b != null:
		return "wood" if b.plan.tdef["lay"] == "bsp" else "tile"
	var ri := gen.road_at(p.x, p.z)
	if ri >= 0 and gen.roads[ri]["kind"] != 2:
		return "asphalt"
	return "grass"


func heat_near(p: Vector3) -> bool:
	for f in fires:
		if f.distance_to(p) < 4.5:
			return true
	var b = building_at(p)
	if b != null:
		var fr: Dictionary = b.state.get("fire", {})
		for fi in fr:
			if G.time_min < float(fr[fi]) and b.furn_world_pos(fi).distance_to(p) < 6.5:
				return true
	return false


func chunk_at(p: Vector3):
	return chunks.get(key_of(p), null)


## Posicao livre aleatoria perto de um ponto (para zumbis e itens).
func free_spot(p: Vector3, r: float, rng: RandomNumberGenerator) -> Vector3:
	for i in 8:
		var q := p + Vector3(rng.randf_range(-r, r), 0, rng.randf_range(-r, r))
		if not cell_blocked(q.x, q.z):
			return q
	return p


func targets_near(p: Vector3, out: Array) -> void:
	var k := key_of(p)
	var seen := {}
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var kk := Vector2i(k.x + dx, k.y + dz)
			for lid in gen.chunk_lot_refs.get(kk, []):
				if seen.has(lid):
					continue
				seen[lid] = true
				var b: Building = buildings.get(lid, null)
				if b != null:
					b.targets_near(p, out)
			var ch = chunks.get(kk, null)
			if ch == null:
				continue
			var cut: Dictionary = cstate[kk].get("cut", {})
			var trees: Array = ch["trees"]
			for i in trees.size():
				var t: Dictionary = trees[i]
				var ddx: float = t["x"] - p.x
				var ddz: float = t["z"] - p.z
				if ddx * ddx + ddz * ddz < 4.4 and not cut.has(i) and absf(p.y) < 1.0:
					var kind: int = t["k"]
					out.append({"kind": "arvore", "key": kk, "i": i, "tk": kind, "pos": Vector3(t["x"], 1.0, t["z"]), "name": TREE_NAMES[kind],
						"label": "Coletar" if kind >= 3 else "Cortar"})
			for e in ch["items"]:
				if e["p"].distance_to(p) < 1.9:
					out.append({"kind": "chao", "key": kk, "pos": e["p"] + Vector3(0, 0.3, 0), "name": Items.name_of(e["it"]), "label": "Pegar", "e": e})
			for e in ch["corpses"]:
				if e["p"].distance_to(p) < 1.9:
					out.append({"kind": "corpo", "key": kk, "pos": e["p"] + Vector3(0, 0.4, 0), "name": "Cadáver", "label": "Revistar", "e": e})
			Base.targets_near(self, kk, ch, p, out)
	if absf(p.y) < 1.0 and gen.river_dist(p.x, p.z) < 2.2:
		out.append({"kind": "rio", "pos": Vector3(WorldGen.river_x(p.z) + (WorldGen.RIVER_HALF if p.x > WorldGen.river_x(p.z) else -WorldGen.RIVER_HALF), 0.5, p.z),
			"name": "Rio Cinzento", "label": "Água"})
	if G.vehicles != null:
		G.vehicles.targets_near(p, out)


# =====================================================================================
#  ARVORES
# =====================================================================================
func tree_hit(k: Vector2i, i: int, dmg: float) -> bool:
	var ch: Dictionary = chunks[k]
	var t: Dictionary = ch["trees"][i]
	var hp: float = ch["hp"].get(i, 100.0 * float(t["s"]) * (1.25 if t["k"] == 1 else 1.0))
	hp -= dmg
	ch["hp"][i] = hp
	if hp > 0.0:
		return false
	_fell_tree(k, i)
	return true


func _fell_tree(k: Vector2i, i: int) -> void:
	var ch: Dictionary = chunks[k]
	var t: Dictionary = ch["trees"][i]
	var st: Dictionary = cstate[k]
	if not st.has("cut"):
		st["cut"] = {}
	st["cut"][i] = G.time_min
	var kind: int = t["k"]
	var mm: MultiMesh = ch["mm"][kind].multimesh
	mm.set_instance_transform(t["mi"], Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), Vector3(t["x"], -5.0, t["z"])))
	if t["si"] >= 0:
		PhysicsServer3D.body_set_shape_disabled(ch["body"].get_rid(), t["si"], true)
	nav_set(Vector2i(floori(t["x"]), floori(t["z"])), false)
	var pos := Vector3(t["x"], 0, t["z"])
	# animacao de queda respeitando a direcao oposta ao jogador
	var fall := MeshInstance3D.new()
	fall.mesh = _tree_meshes[kind]
	var s: float = t["s"]
	fall.scale = Vector3(s, s, s)
	ch["node"].add_child(fall)
	fall.global_position = pos
	var away := (pos - G.player.global_position)
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var tilt := func(a: float):
		fall.basis = Basis(axis, a).scaled(Vector3(s, s, s))
	var landed := func():
		Sfx.noise(pos, 30.0)
		fall.queue_free()
	var tw := fall.create_tween()
	tw.tween_method(tilt, 0.0, PI * 0.5, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(landed)
	Sfx.play3d("tree_fall", pos, 2.0, 1.0, 90.0)
	_spawn_stump(ch, t)
	var logs := 2 if s < 1.1 else 3
	if kind == 2:
		logs = 1
	for n in logs:
		drop_item(pos + away * (1.5 + n * 1.2) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), Items.make("tronco", 1))
	drop_item(pos + away * 2.0 + Vector3(0.6, 0, 0.3), Items.make("galho", randi_range(1, 3)))
	drop_item(pos + away * 3.0 + Vector3(-0.5, 0, 0.2), Items.make("graveto", randi_range(2, 5)))


func _spawn_stump(ch: Dictionary, t: Dictionary) -> void:
	if t["k"] >= 3:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _stump_mesh
	ch["node"].add_child(mi)
	mi.position = Vector3(t["x"], 0, t["z"])


# =====================================================================================
#  ITENS NO CHAO E CADAVERES
# =====================================================================================
func drop_item(p: Vector3, it: Dictionary) -> void:
	var k := key_of(p)
	if not cstate.has(k):
		cstate[k] = {}
	if not cstate[k].has("items"):
		cstate[k]["items"] = []
	var b = building_at(p)
	var y := 0.07
	if b != null:
		y = b.floor_of(b.to_local(p).y) * BPlan.FH + 0.07
	var e := {"p": Vector3(p.x, y, p.z), "it": it}
	cstate[k]["items"].append(e)
	if chunks.has(k):
		_spawn_item_node(chunks[k], e)


func _spawn_item_node(ch: Dictionary, e: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = item_mesh(e["it"])
	mi.visibility_range_end = 40.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ch["node"].add_child(mi)
	mi.position = e["p"]
	mi.rotation = Vector3(0, randf() * TAU, PI * 0.5 if Items.def(e["it"]["id"]).has("mdl") else 0.0)
	if Items.def(e["it"]["id"]).has("mdl"):
		mi.position.y += 0.03
	e["node"] = mi
	ch["items"].append(e)


func take_item(k: Vector2i, e: Dictionary) -> void:
	if e.has("node") and is_instance_valid(e["node"]):
		e["node"].queue_free()
	e.erase("node")
	if chunks.has(k):
		chunks[k]["items"].erase(e)
	if cstate.has(k):
		cstate[k].get("items", []).erase(e)


## Itens no chao proximos (para a tela de recipiente "Chão").
func ground_items(p: Vector3, r: float = 2.2) -> Array:
	var out: Array = []
	var k := key_of(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var ch = chunks.get(Vector2i(k.x + dx, k.y + dz), null)
			if ch == null:
				continue
			for e in ch["items"]:
				if e["p"].distance_to(p) < r:
					out.append([Vector2i(k.x + dx, k.y + dz), e])
	return out


func add_corpse(p: Vector3, rot: float, look: Dictionary, items: Array, is_player: bool = false, reanimate_at: float = -1.0) -> void:
	var k := key_of(p)
	if not cstate.has(k):
		cstate[k] = {}
	if not cstate[k].has("corpses"):
		cstate[k]["corpses"] = []
	var list: Array = cstate[k]["corpses"]
	if list.size() >= 14:
		var old: Dictionary = list.pop_front()
		if old.has("node") and is_instance_valid(old["node"]):
			old["node"].queue_free()
		if chunks.has(k):
			chunks[k]["corpses"].erase(old)
	var e := {"p": p, "r": rot, "look": look, "items": items, "t": G.time_min, "pl": is_player, "re": reanimate_at}
	list.append(e)
	if chunks.has(k):
		_spawn_corpse_node(chunks[k], e)


func _spawn_corpse_node(ch: Dictionary, e: Dictionary) -> void:
	# cadaveres se decompoem e somem apos alguns dias
	if G.time_min - float(e["t"]) > 6.0 * 1440.0 and not e.get("pl", false):
		return
	var h := Humanoid.new()
	ch["node"].add_child(h)
	h.position = e["p"]
	h.rotation.y = e["r"]
	var lk: Dictionary = e["look"].duplicate()
	var age := clampf((G.time_min - float(e["t"])) / (4.0 * 1440.0), 0.0, 1.0)
	lk["dirt"] = maxf(float(lk.get("dirt", 0.0)), age)
	h.set_look(lk)
	h.down = 1.0
	h.down_back = (hash(e["p"]) % 2) == 0
	h.animate(0.016)
	for i in 12:
		h.animate(0.1)
	h.set_process(false)
	e["node"] = h
	ch["corpses"].append(e)


func remove_corpse(k: Vector2i, e: Dictionary) -> void:
	if e.has("node") and is_instance_valid(e["node"]):
		e["node"].queue_free()
	e.erase("node")
	if chunks.has(k):
		chunks[k]["corpses"].erase(e)
	if cstate.has(k):
		cstate[k].get("corpses", []).erase(e)


# =====================================================================================
#  IMPACTOS NO CENARIO
# =====================================================================================
func melee_hit_world(hit: Dictionary, wdef: Dictionary, _player: Node) -> void:
	var col = hit["collider"]
	if col == null:
		return
	var dmg: float = (float(wdef["dmg"][0]) + float(wdef["dmg"][1])) * 0.35
	if col.has_meta("door"):
		var d: Array = col.get_meta("door")
		d[0].damage_door(d[1], dmg, true)
	elif col.has_meta("building"):
		var b: Building = col.get_meta("building")
		b.damage_window(int(hit["shape"]), dmg)
		b.trigger_alarm(true)
	elif col.has_meta("struct"):
		Base.damage_struct(self, col.get_meta("struct"), dmg)


## Retorna true quando o projetil atravessa (vidro quebrado).
func bullet_hit_world(hit: Dictionary) -> bool:
	var col = hit["collider"]
	if col == null:
		return false
	if col.has_meta("building"):
		var b: Building = col.get_meta("building")
		var st := b.win_state(int(hit["shape"]))
		if int(st["bar"]) > 0:
			return false
		b.break_window(int(hit["shape"]), true)
		return true
	if col.has_meta("door"):
		var d: Array = col.get_meta("door")
		d[0].damage_door(d[1], 12.0, true)
	return false


# =====================================================================================
#  SALVAMENTO
# =====================================================================================
func to_dict() -> Dictionary:
	# remove referencias de nos antes de gravar
	var cs := {}
	for k in cstate:
		var src: Dictionary = cstate[k]
		if src.is_empty():
			continue
		var d := {}
		for key in src:
			if key == "items" or key == "corpses" or key == "structs" or key == "plots":
				var arr: Array = []
				for e in src[key]:
					var c: Dictionary = e.duplicate()
					c.erase("node")
					arr.append(c)
				if not arr.is_empty():
					d[key] = arr
			else:
				d[key] = src[key]
		if not d.is_empty():
			cs[k] = d
	var bs := {}
	for lid in bstate:
		var s: Dictionary = bstate[lid]
		if s.get("doors", {}).is_empty() and s.get("wins", {}).is_empty() and s.get("cont", {}).is_empty() and s.get("gone", []).is_empty():
			continue
		bs[lid] = s
	return {"b": bs, "c": cs}


func from_dict(d: Dictionary) -> void:
	bstate = d.get("b", {})
	cstate = d.get("c", {})
