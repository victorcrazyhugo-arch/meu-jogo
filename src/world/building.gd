class_name Building
extends Node3D
## Edificio carregado: malha unica, colisores, portas articuladas, janelas com vidro,
## barricadas, recipientes e estado persistente.

const W_CLOSED := 0
const W_OPEN := 1
const W_BROKEN := 2      # cacos remanescentes: perigoso atravessar
const W_CLEARED := 3

static var _shape_cache := {}
static var _door_mesh: BoxMesh
static var _door_mats := {}

var plan: BPlan
var state: Dictionary = {}
var body: StaticBody3D
var glass_body: StaticBody3D
var glass_mi: MeshInstance3D
var extra_mi: MeshInstance3D
var main_mi: MeshInstance3D
var inner_mi: MeshInstance3D
var door_nodes: Array = []
var label: Label3D
var alarm_t := 0.0
var _alarm_beat := 0.0
var _lights: Array = []
var lit := false


static func box_shape(size: Vector3) -> BoxShape3D:
	var k := Vector3i(roundi(size.x * 50.0), roundi(size.y * 50.0), roundi(size.z * 50.0))
	if _shape_cache.has(k):
		return _shape_cache[k]
	var s := BoxShape3D.new()
	s.size = size
	_shape_cache[k] = s
	return s


func setup(p: BPlan, mb: MB, st: Dictionary, inner: MB = null) -> void:
	plan = p
	state = st
	if not state.has("doors"):
		state["doors"] = {}
		state["wins"] = {}
		state["cont"] = {}
		state["gone"] = []
		state["alarm"] = (G.hash2(plan.id, 3, G.world_seed) % 100) < (9 if plan.tdef["lay"] != "hall" else 3)
	transform = plan.xform()
	main_mi = MeshInstance3D.new()
	main_mi.mesh = mb.to_mesh(Mats.world)
	add_child(main_mi)
	# moveis e decoracao: so desenhados de perto (o estado e a colisao nao dependem disso)
	inner_mi = MeshInstance3D.new()
	if inner == null:
		inner = plan.build_interior()
	inner_mi.mesh = inner.to_mesh(Mats.world)
	inner_mi.visibility_range_end = maxf(42.0, Vector2(plan.w, plan.d).length() * 0.5 + 26.0)
	inner_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner_mi)
	body = StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	add_child(body)
	_add_colliders()
	glass_body = StaticBody3D.new()
	glass_body.collision_layer = G.L_GLASS
	glass_body.collision_mask = 0
	glass_body.set_meta("building", self)
	add_child(glass_body)
	for wn in plan.windows:
		var sz := Vector3(1.0, 1.2, 0.06) if wn["h"] else Vector3(0.06, 1.2, 1.0)
		var sh := box_shape(sz)
		PhysicsServer3D.body_add_shape(glass_body.get_rid(), sh.get_rid(), Transform3D(Basis.IDENTITY, Vector3(wn["x"] + 0.5, wn["f"] * BPlan.FH + 1.5, wn["z"] + 0.5)))
	glass_mi = MeshInstance3D.new()
	glass_mi.visibility_range_end = 80.0
	add_child(glass_mi)
	extra_mi = MeshInstance3D.new()
	add_child(extra_mi)
	_make_doors()
	refresh_dynamic()
	if plan.tdef.has("sign") or plan.type in ["hospital", "escola", "delegacia", "bombeiros", "hotel", "biblioteca", "centro_saude"]:
		label = Label3D.new()
		label.text = plan.name.to_upper()
		label.font_size = 96
		label.pixel_size = 0.006
		label.outline_size = 14
		label.modulate = Color(0.96, 0.95, 0.9)
		label.position = Vector3(plan.w * 0.5, 2.56 if plan.tdef.has("sign") else 3.4, plan.d - 0.24)
		label.visibility_range_end = 55.0
		add_child(label)


func _add_colliders() -> void:
	var rid := body.get_rid()
	PhysicsServer3D.body_clear_shapes(rid)
	for c in plan.colliders:
		var sh := box_shape(c[1])
		PhysicsServer3D.body_add_shape(rid, sh.get_rid(), c[0])


func rebuild_static() -> void:
	var mb := plan.build_mesh()
	main_mi.mesh = mb.to_mesh(Mats.world)
	inner_mi.mesh = plan.build_interior().to_mesh(Mats.world)
	_add_colliders()


# =====================================================================================
#  PORTAS
# =====================================================================================
func door_state(i: int) -> Dictionary:
	var ds: Dictionary = state["doors"]
	if not ds.has(i):
		var d: Dictionary = plan.doors[i]
		ds[i] = {"o": false, "l": d["lock"], "hp": 170.0 if d["ext"] else 100.0, "bar": 0, "gone": false}
	return ds[i]


## Folha de porta detalhada: montantes, travessas, almofadas em relevo, dobradicas, espelho e
## macaneta dos dois lados. A externa tem vidros no alto, chapa de protecao e fenda de cartas.
static func _door_mesh_for(col: Color, ext: bool, lod: bool) -> ArrayMesh:
	var dm := MB.new()
	var dc := MB.wm(col, MB.M_WOOD)
	var fr := MB.wm(col.lightened(0.05), MB.M_WOOD)
	var fld := MB.wm(col.darkened(0.10), MB.M_WOOD)
	var brass := MB.wm(Color(0.74, 0.64, 0.38), MB.M_METAL)
	var steel := MB.wm(Color(0.52, 0.52, 0.54), MB.M_METAL)
	if lod:
		dm.box(Vector3.ZERO, Vector3(0.92, 2.06, 0.05), dc)
		for side in [-1.0, 1.0]:
			var fz: int = 4 if side > 0.0 else 8
			dm.box(Vector3(0, 0.5, 0.027 * side), Vector3(0.64, 0.8, 0.004), fld, fz)
			dm.box(Vector3(0, -0.52, 0.027 * side), Vector3(0.64, 0.84, 0.004), fld, fz)
		return dm.to_mesh(Mats.world)
	dm.box(Vector3.ZERO, Vector3(0.92, 2.06, 0.036), fld)
	# linhas de travessas (do alto para baixo) e colunas de almofadas
	var rails := [1.03, 0.52, -0.10, -1.03]
	var rh := [0.13, 0.11, 0.16, 0.22]
	for side in [-1.0, 1.0]:
		var fz2: int = (4 if side > 0.0 else 8) | 1 | 2 | 16 | 32
		var z: float = 0.024 * side
		dm.box(Vector3(-0.405, 0, z), Vector3(0.11, 2.06, 0.014), fr, fz2)
		dm.box(Vector3(0.405, 0, z), Vector3(0.11, 2.06, 0.014), fr, fz2)
		for i in rails.size():
			var ry: float = rails[i]
			var hh: float = rh[i]
			if i == 0:
				ry -= hh * 0.5
			elif i == rails.size() - 1:
				ry += hh * 0.5
			dm.box(Vector3(0, ry, z), Vector3(0.70, hh, 0.014), fr, fz2)
		dm.box(Vector3(0, -0.02, z), Vector3(0.09, 1.8, 0.014), fr, fz2)
		# almofadas (ou vidros, no alto da porta externa)
		var rows := [[0.90, 0.575], [0.465, -0.02], [-0.18, -0.81]]
		for ri in rows.size():
			var ya: float = rows[ri][0]
			var yb: float = rows[ri][1]
			for cx in [-0.2, 0.2]:
				if ext and ri == 0:
					dm.box(Vector3(cx, (ya + yb) * 0.5, 0.019 * side), Vector3(0.3, ya - yb, 0.004), MB.wm(Color(0.20, 0.30, 0.36), MB.M_METAL), fz2 & 12)
				else:
					dm.box(Vector3(cx, (ya + yb) * 0.5, 0.021 * side), Vector3(0.24, ya - yb - 0.07, 0.008), dc, fz2)
					dm.box(Vector3(cx, (ya + yb) * 0.5, 0.026 * side), Vector3(0.19, ya - yb - 0.13, 0.006), fr, fz2)
		# espelho, macaneta e fechadura
		dm.box(Vector3(0.375, -0.06, 0.033 * side), Vector3(0.05, 0.2, 0.006), brass, fz2)
		dm.box(Vector3(0.375, -0.02, 0.05 * side), Vector3(0.022, 0.022, 0.034), brass, fz2)
		dm.ellipsoid(Vector3(0.375, -0.02, 0.075 * side), Vector3(0.034, 0.034, 0.024), brass, 8, 5)
		dm.box(Vector3(0.375, -0.12, 0.037 * side), Vector3(0.012, 0.03, 0.004), Color(0.05, 0.05, 0.05), fz2 & 12)
		if ext:
			dm.box(Vector3(0, -0.93, z + 0.008 * side), Vector3(0.9, 0.2, 0.006), steel, fz2)
			dm.box(Vector3(0, -0.36, 0.033 * side), Vector3(0.26, 0.05, 0.006), brass, fz2)
			dm.box(Vector3(0.375, 0.2, 0.036 * side), Vector3(0.05, 0.05, 0.012), steel, fz2)
	# dobradicas no lado do eixo
	for hy in [0.78, 0.0, -0.78]:
		dm.box(Vector3(-0.462, hy, 0), Vector3(0.012, 0.11, 0.07), steel)
	return dm.to_mesh(Mats.world)


func _make_doors() -> void:
	for ext_v in [false, true]:
		var key0 := plan.c_door.to_html() + ("e" if ext_v else "i")
		if not _door_mats.has(key0):
			_door_mats[key0] = _door_mesh_for(plan.c_door, ext_v, false)
			_door_mats[key0 + "L"] = _door_mesh_for(plan.c_door, ext_v, true)
	for i in plan.doors.size():
		var d: Dictionary = plan.doors[i]
		var piv := Node3D.new()
		var y0: float = d["f"] * BPlan.FH
		if d["h"]:
			piv.position = Vector3(d["x"] + 0.04, y0, d["z"] + 0.5)
		else:
			piv.position = Vector3(d["x"] + 0.5, y0, d["z"] + 0.04)
			piv.rotation.y = -PI * 0.5
		add_child(piv)
		var key: String = plan.c_door.to_html() + ("e" if d["ext"] else "i")
		var mi := MeshInstance3D.new()
		mi.mesh = _door_mats[key]
		mi.position = Vector3(0.46, 1.06, 0)
		mi.visibility_range_end = 24.0
		piv.add_child(mi)
		var mi_far := MeshInstance3D.new()
		mi_far.mesh = _door_mats[key + "L"]
		mi_far.position = Vector3(0.46, 1.06, 0)
		mi_far.visibility_range_begin = 24.0
		mi_far.visibility_range_end = 70.0
		piv.add_child(mi_far)
		var sb := StaticBody3D.new()
		sb.collision_layer = G.L_WORLD
		sb.collision_mask = 0
		sb.position = Vector3(0.46, 1.06, 0)
		var cs := CollisionShape3D.new()
		cs.shape = box_shape(Vector3(0.92, 2.06, 0.1))
		sb.add_child(cs)
		sb.set_meta("door", [self, i])
		piv.add_child(sb)
		door_nodes.append({"piv": piv, "body": sb, "cs": cs, "mi": mi, "base": piv.rotation.y})
		var st := door_state(i)
		if st["gone"]:
			piv.visible = false
			cs.disabled = true
		elif st["o"]:
			piv.rotation.y = float(door_nodes[i]["base"]) + PI * 0.52


func door_world_pos(i: int) -> Vector3:
	var d: Dictionary = plan.doors[i]
	return to_global(Vector3(d["x"] + 0.5, d["f"] * BPlan.FH + 1.0, d["z"] + 0.5))


func set_door(i: int, open: bool, from_pos: Vector3 = Vector3.ZERO, silent: bool = false) -> void:
	var st := door_state(i)
	if st["gone"] or st["o"] == open:
		return
	st["o"] = open
	var dn: Dictionary = door_nodes[i]
	var piv: Node3D = dn["piv"]
	var tgt: float = dn["base"]
	if open:
		# abre para o lado oposto de quem empurra
		var lp := to_local(from_pos)
		var d: Dictionary = plan.doors[i]
		var side := 1.0
		if d["h"]:
			side = 1.0 if lp.z > d["z"] + 0.5 else -1.0
		else:
			side = -1.0 if lp.x > d["x"] + 0.5 else 1.0
		tgt += PI * 0.52 * side
	var tw := piv.create_tween()
	tw.tween_property(piv, "rotation:y", tgt, 0.22)
	if not silent:
		Sfx.play3d("door_open" if open else "door_close", door_world_pos(i), -4.0)
		Sfx.noise(door_world_pos(i), 5.0)
	G.world.nav_door(self, i)


func damage_door(i: int, dmg: float, by_player: bool = false) -> bool:
	var st := door_state(i)
	if st["gone"] or st["o"]:
		return false
	if int(st["bar"]) > 0:
		st["bhp"] = float(st.get("bhp", 60.0)) - dmg
		if float(st["bhp"]) <= 0.0:
			st["bar"] = int(st["bar"]) - 1
			st["bhp"] = 60.0
			refresh_dynamic()
			Sfx.play3d("door_break", door_world_pos(i), -6.0)
		return true
	st["hp"] = float(st["hp"]) - dmg
	if float(st["hp"]) <= 0.0:
		st["gone"] = true
		door_nodes[i]["piv"].visible = false
		door_nodes[i]["cs"].disabled = true
		Sfx.play3d("door_break", door_world_pos(i), 2.0, 1.0, 70.0)
		Sfx.noise(door_world_pos(i), 22.0)
		G.world.nav_door(self, i)
		trigger_alarm(by_player)
		G.world.drop_item(door_world_pos(i) - Vector3(0, 0.9, 0), Items.make("tabua", 1))
	return true


func door_blocks(i: int) -> bool:
	var st := door_state(i)
	return not st["gone"] and not st["o"]


# =====================================================================================
#  JANELAS
# =====================================================================================
func win_state(i: int) -> Dictionary:
	var ws: Dictionary = state["wins"]
	if not ws.has(i):
		ws[i] = {"s": W_CLOSED, "bar": 0, "l": (G.hash2(plan.id, i, 17) % 100) < 55}
	return ws[i]


func win_world_pos(i: int) -> Vector3:
	var wn: Dictionary = plan.windows[i]
	return to_global(Vector3(wn["x"] + 0.5, wn["f"] * BPlan.FH + 1.3, wn["z"] + 0.5))


func win_passable(i: int) -> bool:
	var st := win_state(i)
	return int(st["s"]) != W_CLOSED and int(st["bar"]) == 0


func set_window(i: int, s: int) -> void:
	var st := win_state(i)
	st["s"] = s
	refresh_dynamic()
	G.world.nav_window(self, i)


func break_window(i: int, by_player: bool = false) -> void:
	var st := win_state(i)
	if int(st["s"]) != W_CLOSED:
		return
	st["s"] = W_BROKEN
	Sfx.play3d("glass_break", win_world_pos(i), 2.0, 1.0, 70.0)
	Sfx.noise(win_world_pos(i), 16.0)
	refresh_dynamic()
	G.world.nav_window(self, i)
	trigger_alarm(by_player)


func damage_window(i: int, dmg: float) -> bool:
	var st := win_state(i)
	if int(st["bar"]) > 0:
		st["bhp"] = float(st.get("bhp", 60.0)) - dmg
		if float(st["bhp"]) <= 0.0:
			st["bar"] = int(st["bar"]) - 1
			st["bhp"] = 60.0
			Sfx.play3d("door_break", win_world_pos(i), -6.0)
			refresh_dynamic()
			G.world.nav_window(self, i)
		return true
	if int(st["s"]) == W_CLOSED:
		break_window(i)
		return true
	return false


func add_barricade(kind: String, i: int) -> void:
	var st := win_state(i) if kind == "janela" else door_state(i)
	st["bar"] = mini(4, int(st["bar"]) + 1)
	st["bhp"] = 60.0 + G.player.sv.level("carpintaria") * 12.0
	refresh_dynamic()
	if kind == "janela":
		G.world.nav_window(self, i)


func remove_barricade(kind: String, i: int) -> void:
	var st := win_state(i) if kind == "janela" else door_state(i)
	st["bar"] = maxi(0, int(st["bar"]) - 1)
	refresh_dynamic()
	if kind == "janela":
		G.world.nav_window(self, i)


## Reconstroi vidros, cacos e tabuas de barricada.
func refresh_dynamic() -> void:
	var g := MB.new()
	var e := MB.new()
	var rid := glass_body.get_rid()
	var plank := Color(0.56, 0.42, 0.27)
	for i in plan.windows.size():
		var wn: Dictionary = plan.windows[i]
		var st := win_state(i)
		var c := Vector3(wn["x"] + 0.5, wn["f"] * BPlan.FH + 1.5, wn["z"] + 0.5)
		var s: int = st["s"]
		PhysicsServer3D.body_set_shape_disabled(rid, i, s != W_CLOSED and int(st["bar"]) == 0)
		var thin := Vector3(0.96, 1.16, 0.02) if wn["h"] else Vector3(0.02, 1.16, 0.96)
		if s == W_CLOSED:
			g.box(c, thin, Color.WHITE, 4 | 8 if wn["h"] else 16 | 32)
		elif s == W_BROKEN:
			# cacos presos na moldura
			var sh := Vector3(0.22, 0.3, 0.02) if wn["h"] else Vector3(0.02, 0.3, 0.22)
			for k in 3:
				var off := (k - 1) * 0.34
				var p := c + (Vector3(off, -0.44, 0) if wn["h"] else Vector3(0, -0.44, off))
				g.box(p, sh, Color.WHITE, 4 | 8 if wn["h"] else 16 | 32)
		elif s == W_OPEN:
			var up := Vector3(0.96, 0.5, 0.03) if wn["h"] else Vector3(0.03, 0.5, 0.96)
			g.box(c + Vector3(0, 0.34, 0), up, Color.WHITE, 4 | 8 if wn["h"] else 16 | 32)
		# moldura, peitoril e travessas
		var fr := BPlan.WHITE
		var fr2 := Color(0.80, 0.80, 0.77)
		if wn["h"]:
			e.box(c + Vector3(0, -0.615, 0), Vector3(1.10, 0.06, 0.34), fr2)
			if s == W_CLOSED:
				e.box(c, Vector3(0.035, 1.16, 0.045), fr)
				e.box(c + Vector3(0, 0.05, 0), Vector3(0.96, 0.035, 0.045), fr)
		else:
			e.box(c + Vector3(0, -0.615, 0), Vector3(0.34, 0.06, 1.10), fr2)
			if s == W_CLOSED:
				e.box(c, Vector3(0.045, 1.16, 0.035), fr)
				e.box(c + Vector3(0, 0.05, 0), Vector3(0.045, 0.035, 0.96), fr)
		if wn["h"]:
			e.box(c + Vector3(0, 0.6, 0), Vector3(1.0, 0.05, 0.24), fr)
			e.box(c + Vector3(-0.48, 0, 0), Vector3(0.05, 1.2, 0.24), fr)
			e.box(c + Vector3(0.48, 0, 0), Vector3(0.05, 1.2, 0.24), fr)
		else:
			e.box(c + Vector3(0, 0.6, 0), Vector3(0.24, 0.05, 1.0), fr)
			e.box(c + Vector3(0, 0, -0.48), Vector3(0.24, 1.2, 0.05), fr)
			e.box(c + Vector3(0, 0, 0.48), Vector3(0.24, 1.2, 0.05), fr)
		for b in int(st["bar"]):
			var y := -0.42 + b * 0.28
			var out := -0.14 if (wn["z"] == 0 or wn["x"] == 0) else 0.14
			if wn["h"]:
				e.box(c + Vector3(0, y, -out), Vector3(1.3, 0.2, 0.05), plank.darkened(0.06 * (b % 2)))
			else:
				e.box(c + Vector3(-out, y, 0), Vector3(0.05, 0.2, 1.3), plank.darkened(0.06 * (b % 2)))
	for i in plan.doors.size():
		var d: Dictionary = plan.doors[i]
		var st2 := door_state(i)
		var c2 := Vector3(d["x"] + 0.5, d["f"] * BPlan.FH + 1.0, d["z"] + 0.5)
		for b in int(st2["bar"]):
			var y2 := -0.55 + b * 0.42
			if d["h"]:
				e.box(c2 + Vector3(0, y2, -0.1), Vector3(1.35, 0.22, 0.05), plank)
			else:
				e.box(c2 + Vector3(-0.1, y2, 0), Vector3(0.05, 0.22, 1.35), plank)
	glass_mi.mesh = g.to_mesh(Mats.glass)
	extra_mi.mesh = e.to_mesh(Mats.world)


# =====================================================================================
#  ALARME E LUZES
# =====================================================================================
func trigger_alarm(by_player: bool) -> void:
	if by_player and state.get("alarm", false) and G.power_on():
		state["alarm"] = false
		alarm_t = 150.0
		G.say("Um alarme disparou!")


func _process(dt: float) -> void:
	if alarm_t > 0.0:
		alarm_t -= dt
		_alarm_beat -= dt
		if _alarm_beat <= 0.0:
			_alarm_beat = 1.6
			var p := to_global(Vector3(plan.w * 0.5, 2.0, plan.d * 0.5))
			Sfx.play3d("alarm_loop", p, 6.0, 1.0, 160.0)
			Sfx.noise(p, 95.0)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	for l in _lights:
		l.queue_free()
	_lights.clear()
	if not on:
		return
	var n := 0
	for f in plan.floors:
		for room in plan.rooms[f]:
			if n >= 7:
				break
			var r: Rect2i = room["r"]
			if r.size.x * r.size.y < 6:
				continue
			var l := OmniLight3D.new()
			l.position = Vector3(r.position.x + r.size.x * 0.5, f * BPlan.FH + 2.5, r.position.y + r.size.y * 0.5)
			l.omni_range = maxf(r.size.x, r.size.y) * 0.9 + 2.0
			l.light_energy = 1.1
			l.light_color = Color(1.0, 0.93, 0.8)
			l.shadow_enabled = false
			add_child(l)
			_lights.append(l)
			n += 1


# =====================================================================================
#  CONSULTAS
# =====================================================================================
func floor_of(y: float) -> int:
	return clampi(int(floor((y + 0.6) / BPlan.FH)), 0, plan.floors - 1)


func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return l.x > 0.3 and l.z > 0.3 and l.x < plan.w - 0.3 and l.z < plan.d - 0.3 and l.y > -0.5 and l.y < plan.floors * BPlan.FH


func container(fi: int) -> Array:
	var cs: Dictionary = state["cont"]
	if not cs.has(fi):
		var fu: Dictionary = plan.furn[fi]
		cs[fi] = Items.roll_loot(fu["cont"], G.hash2(plan.id * 131 + fi, G.world_seed, 23))
	return cs[fi]


func furn_world_pos(fi: int) -> Vector3:
	var fu: Dictionary = plan.furn[fi]
	return to_global(Vector3(fu["x"], fu["f"] * BPlan.FH + 0.8, fu["z"]))


## Lista alvos de interacao proximos.
func targets_near(p: Vector3, out: Array) -> void:
	var l := to_local(p)
	if l.x < -2.5 or l.z < -2.5 or l.x > plan.w + 2.5 or l.z > plan.d + 9.0:
		return
	var f := floor_of(l.y)
	for i in plan.doors.size():
		var d: Dictionary = plan.doors[i]
		if d["f"] != f:
			continue
		var c := Vector2(d["x"] + 0.5, d["z"] + 0.5)
		if c.distance_to(Vector2(l.x, l.z)) < 1.7:
			var st := door_state(i)
			if st["gone"]:
				continue
			out.append({"kind": "porta", "b": self, "i": i, "pos": door_world_pos(i), "name": "Porta" + (" (barricada)" if int(st["bar"]) > 0 else ""),
				"label": "Fechar" if st["o"] else "Abrir"})
	for i in plan.windows.size():
		var wn: Dictionary = plan.windows[i]
		if wn["f"] != f:
			continue
		var c2 := Vector2(wn["x"] + 0.5, wn["z"] + 0.5)
		if c2.distance_to(Vector2(l.x, l.z)) < 1.5:
			var st2 := win_state(i)
			var s: int = st2["s"]
			var nm: String = ["Janela", "Janela aberta", "Janela quebrada (cacos)", "Janela sem vidro"][s]
			if int(st2["bar"]) > 0:
				nm += " (barricada)"
			out.append({"kind": "janela", "b": self, "i": i, "pos": win_world_pos(i), "name": nm,
				"label": "Abrir" if s == W_CLOSED else "Pular"})
	for i in plan.furn.size():
		var fu: Dictionary = plan.furn[i]
		if fu["f"] != f or fu.get("gone", false):
			continue
		var reach := 1.55 if BPlan.FURN[fu["id"]]["w"] == 1 else 1.95
		if Vector2(fu["x"], fu["z"]).distance_to(Vector2(l.x, l.z)) < reach:
			var fd: Dictionary = BPlan.FURN[fu["id"]]
			var lab := "Vasculhar" if fu["cont"] != "" else "Usar"
			match fu["use"]:
				"bed", "bed_bad":
					lab = "Dormir"
				"sink", "toilet", "bath":
					lab = "Água"
				"stove", "microwave", "fire":
					lab = "Cozinhar"
				"workbench":
					lab = "Bancada"
				"sofa":
					lab = "Descansar"
				"tv":
					lab = "Assistir"
				"":
					if fu["cont"] == "":
						lab = "Desmontar"
			out.append({"kind": "movel", "b": self, "i": i, "pos": furn_world_pos(i), "name": fd["n"], "label": lab})
	for i in plan.pumps.size():
		var pp: Vector2 = plan.pumps[i]
		if pp.distance_to(Vector2(l.x, l.z)) < 2.2:
			out.append({"kind": "bomba", "b": self, "i": i, "pos": to_global(Vector3(pp.x, 1.0, pp.y)), "name": "Bomba de combustível", "label": "Abastecer"})


## Zumbi pressiona o obstaculo mais proximo. Retorna true se havia algo para bater.
func zombie_thump(p: Vector3, dmg: float) -> bool:
	var l := to_local(p)
	var f := floor_of(l.y)
	var pl := Vector2(l.x, l.z)
	for i in plan.doors.size():
		var d: Dictionary = plan.doors[i]
		if d["f"] == f and Vector2(d["x"] + 0.5, d["z"] + 0.5).distance_to(pl) < 1.25 and door_blocks(i):
			damage_door(i, dmg)
			Sfx.play3d("zombie_thump", door_world_pos(i), -2.0, 1.0, 40.0)
			Sfx.noise(door_world_pos(i), 9.0)
			return true
	for i in plan.windows.size():
		var wn: Dictionary = plan.windows[i]
		if wn["f"] == f and Vector2(wn["x"] + 0.5, wn["z"] + 0.5).distance_to(pl) < 1.25:
			if damage_window(i, dmg):
				Sfx.play3d("zombie_thump", win_world_pos(i), -4.0, 1.2, 40.0)
				return true
	return false


## Remove um movel (desmontagem) e reconstroi a malha.
func remove_furniture(fi: int) -> void:
	var fu: Dictionary = plan.furn[fi]
	fu["gone"] = true
	if not state["gone"].has(fi):
		state["gone"].append(fi)
	plan.apply_gone([fi])
	rebuild_static()
	G.world.nav_rebuild_soon()
