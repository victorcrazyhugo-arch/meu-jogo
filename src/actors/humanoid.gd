class_name Humanoid
extends Node3D
## Personagem articulado gerado por codigo: esqueleto + malha unica com skinning rigido
## e animacao procedural (locomocao, agachar, mira, golpes, quedas, zumbis).
## Modelos proprios do projeto, sem recursos externos.

signal step(foot: int)

const B_HIPS := 0
const B_SPINE := 1
const B_HEAD := 2
const B_ARM_L := 3
const B_FARM_L := 4
const B_ARM_R := 5
const B_FARM_R := 6
const B_LEG_L := 7
const B_SHIN_L := 8
const B_LEG_R := 9
const B_SHIN_R := 10
const NB := 11
const BONE_NAMES := ["quadril", "tronco", "cabeca", "braco_e", "antebraco_e", "braco_d", "antebraco_d", "coxa_e", "canela_e", "coxa_d", "canela_d"]
const BONE_PARENT := [-1, 0, 1, 1, 3, 1, 5, 0, 7, 0, 9]
const REST := [
	Vector3(0, 0.94, 0), Vector3(0, 0.10, 0), Vector3(0, 0.50, 0),
	Vector3(-0.215, 0.42, 0), Vector3(0, -0.29, 0), Vector3(0.215, 0.42, 0), Vector3(0, -0.29, 0),
	Vector3(-0.095, -0.02, 0), Vector3(0, -0.45, 0), Vector3(0.095, -0.02, 0), Vector3(0, -0.45, 0)]

var skel: Skeleton3D
var mesh_i: MeshInstance3D
var pivot: Node3D
var hand_r: BoneAttachment3D
var back_att: BoneAttachment3D
var grip: Node3D
var weapon_node: MeshInstance3D
var back_node: MeshInstance3D
var look: Dictionary = {}

# ---- entradas de animacao (definidas pelo dono a cada quadro)
var speed := 0.0
var crouch := 0.0
var aim := 0             # 0 nenhum, 1 arma curta, 2 arma longa
var aim_pitch := 0.0
var hold := 0            # 0 nada, 1 uma mao, 2 duas maos, 3 pistola baixa, 4 arma longa baixa
var zombie := false
var reach := 0.0         # bracos de zumbi estendidos 0..1
var act := ""            # animacao de acao atual
var act_t := 0.0         # progresso 0..1
var down := 0.0          # 0 de pe .. 1 deitado
var down_back := true
var sit := 0.0
var flinch := 0.0
var limp := 0.0
var tired := 0.0
var lod_skip := 0

var phase := 0.0
var _ang: Array[Vector3] = []
var _tgt: Array[Vector3] = []
var _hip := Vector3.ZERO
var _t := 0.0
var _seed := 0.0
var _frame := 0


func _init() -> void:
	for i in NB:
		_ang.append(Vector3.ZERO)
		_tgt.append(Vector3.ZERO)
	_seed = randf() * 100.0
	pivot = Node3D.new()
	add_child(pivot)
	skel = Skeleton3D.new()
	pivot.add_child(skel)
	for i in NB:
		skel.add_bone(BONE_NAMES[i])
	for i in NB:
		if BONE_PARENT[i] >= 0:
			skel.set_bone_parent(i, BONE_PARENT[i])
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, REST[i]))
	skel.reset_bone_poses()
	mesh_i = MeshInstance3D.new()
	skel.add_child(mesh_i)
	hand_r = BoneAttachment3D.new()
	skel.add_child(hand_r)
	hand_r.bone_idx = B_FARM_R
	grip = Node3D.new()
	grip.position = Vector3(0, -0.325, -0.02)
	hand_r.add_child(grip)
	weapon_node = MeshInstance3D.new()
	grip.add_child(weapon_node)
	back_att = BoneAttachment3D.new()
	skel.add_child(back_att)
	back_att.bone_idx = B_SPINE
	back_node = MeshInstance3D.new()
	back_node.position = Vector3(0.05, 0.28, 0.17)
	back_node.rotation = Vector3(0.0, 0.0, 0.5)
	back_att.add_child(back_node)


func set_look(l: Dictionary) -> void:
	look = l
	zombie = l.get("zombie", false)
	Mats.init()
	var mb := build_arrays(l)
	mesh_i.mesh = mb.to_mesh(Mats.chara)
	mesh_i.skin = skel.create_skin_from_rest_transforms()
	var hs: float = l.get("height", 1.0)
	pivot.scale = Vector3(hs, hs, hs)


func set_weapon(kind: String) -> void:
	weapon_node.mesh = weapon_mesh(kind) if kind != "" else null
	weapon_node.rotation = Vector3(0.35, 0, 0) if not kind.begins_with("gun") else Vector3.ZERO


func set_back_item(kind: String) -> void:
	back_node.mesh = weapon_mesh(kind) if kind != "" else null


# =====================================================================================
#  MALHA
# =====================================================================================
static func _soil(col: Color, dirt: float, blood: float, k: float) -> Color:
	var o := col.lerp(Color(0.33, 0.27, 0.2), dirt * 0.45 * k)
	return o.lerp(Color(0.36, 0.05, 0.04), blood * 0.5 * k)


static func build_arrays(L: Dictionary) -> MB:
	var m := MB.new()
	m.use_bones = true
	m.use_uv = true
	var rs := RandomNumberGenerator.new()
	rs.seed = int(L.get("seed", 1))
	var is_z: bool = L.get("zombie", false)
	var skin: Color = L.get("skin", Color(0.84, 0.65, 0.52))
	if is_z:
		skin = skin.lerp(Color(0.50, 0.57, 0.46), 0.62)
	var hairc: Color = L.get("hair", Color(0.2, 0.14, 0.1))
	# o alfa informa o tipo de superficie ao shader dos personagens
	skin.a = 0.2
	hairc.a = 0.4
	var bw: float = L.get("build", 1.0)
	var fem: bool = L.get("female", false)
	var dirt: float = L.get("dirt", 0.0)
	var bld: float = L.get("blood", 0.0)
	var top: Dictionary = L.get("top", {})
	var over: Dictionary = L.get("over", {})
	var bot: Dictionary = L.get("bottom", {})
	var shoes: Dictionary = L.get("shoes", {"style": 0})
	var hat: Dictionary = L.get("hat", {})
	var bag: Dictionary = L.get("bag", {})
	var has_top := top.has("col")
	var sl: int = top.get("sl", 0)
	var os: int = over.get("style", 0)
	var bs: int = bot.get("style", 0)
	var tc: Color = _soil(top.get("col", Color(0.5, 0.5, 0.5)), dirt, bld, 1.0)
	var tc2: Color = _soil(top.get("col2", tc.darkened(0.3)), dirt, bld, 1.0)
	var oc: Color = _soil(over.get("col", Color(0.3, 0.3, 0.35)), dirt, bld, 0.8)
	var oc2: Color = _soil(over.get("col2", oc.darkened(0.3)), dirt, bld, 0.8)
	var bc: Color = _soil(bot.get("col", Color(0.2, 0.25, 0.4)), dirt, bld, 0.7)
	var bc2: Color = _soil(bot.get("col2", bc.darkened(0.25)), dirt, bld, 0.7)
	var sc: Color = _soil(shoes.get("col", Color(0.15, 0.13, 0.12)), dirt, 0.0, 1.0)
	var refl := Color(0.86, 0.92, 0.35)
	var tpat: int = top.get("pat", 0)
	var opat: int = over.get("pat", 0)

	var sh := (0.168 if fem else 0.186) * bw
	var hp := (0.170 if fem else 0.160) * bw
	var dp := 0.108 * (0.94 + (bw - 1.0) * 1.6)

	# ---------------- cores por camada
	var jacket := os == 1 or os == 2 or os == 4
	var up_arm := skin
	var lo_arm := skin
	if has_top:
		if sl >= 1:
			up_arm = tc
		if sl >= 2:
			lo_arm = tc
	var bulk := 0.0
	if has_top and top.get("thick", false):
		bulk = 0.008
	if jacket:
		bulk = 0.014
		if over.get("puffy", false):
			bulk = 0.032
		elif over.get("wide", false):
			bulk = 0.02
		up_arm = oc2 if opat == 1 else oc
		lo_arm = up_arm
	elif os == 3:
		bulk += 0.012

	# ---------------- quadril e pernas
	var legc := bc if bs >= 1 else skin
	var lbulk := 0.0
	if bot.get("loose", false):
		lbulk = 0.008
	elif bot.get("tight", false):
		lbulk = -0.004
	m.bone = B_HIPS
	m.tube(0, 0, 0.86, 1.04, Vector2(hp, dp) + Vector2(0.006, 0.006), Vector2(hp, dp), legc if (bs == 1 or bs == 2) else Color(0.28, 0.28, 0.32), 14, true, false)
	if bs == 3:
		var sk_y: float = bot.get("len", 0.5)
		var flare := 0.04 + (0.98 - sk_y) * 0.12
		m.tube(0, 0, sk_y, 0.99, Vector2(hp + flare, dp + flare), Vector2(hp + 0.012, dp + 0.012), bc, 14, true, false, 5 if bot.get("pat", 0) in [1, 3] else 1, bc2)
		if bot.get("pat", 0) == 2:
			m.tube(0, 0, sk_y, sk_y + 0.05, Vector2(hp + flare + 0.004, dp + flare + 0.004), Vector2(hp + flare - 0.002, dp + flare - 0.002), bc2, 14, false, false)
	if L.has("belt"):
		m.tube(0, 0, 1.00, 1.045, Vector2(hp + 0.012, dp + 0.012), Vector2(hp + 0.012, dp + 0.012), L["belt"], 14, false, false)
		m.box(Vector3(0, 1.022, -(dp + 0.016)), Vector3(0.04, 0.04, 0.012), Color(0.7, 0.66, 0.5))
	for side in 2:
		var sx := -0.095 if side == 0 else 0.095
		var osx := -1.0 if side == 0 else 1.0
		var thigh := legc
		var shin := legc
		if bs == 2:
			shin = skin
			thigh = skin
		elif bs == 3 or bs == 0:
			thigh = skin
			shin = skin
		m.bone = B_LEG_L if side == 0 else B_LEG_R
		var tr := 0.083 * (0.92 + (bw - 1.0) * 1.2) + lbulk
		m.tube(sx, 0, 0.47, 0.93, Vector2(0.060 + lbulk, 0.062 + lbulk), Vector2(tr, tr + 0.004), thigh, 12, false, true)
		if bs == 2:
			var sy: float = bot.get("len", 0.66)
			m.tube(sx, 0, sy, 0.93, Vector2(tr + 0.004, tr + 0.008), Vector2(tr + 0.006, tr + 0.01), bc, 12, true, false)
			if bot.get("pat", 0) == 2:
				m.tube(sx, 0, sy, sy + 0.04, Vector2(tr + 0.007, tr + 0.011), Vector2(tr + 0.007, tr + 0.011), bc2, 12, false, false)
			if bot.get("pat", 0) == 1:
				m.box(Vector3(sx + osx * (tr + 0.006), (sy + 0.93) * 0.5, 0), Vector3(0.012, 0.93 - sy, 0.03), bc2)
		if bs == 1 and bot.get("pat", 0) == 1:
			m.box(Vector3(sx + osx * (tr - 0.004), 0.70, 0), Vector3(0.012, 0.44, 0.03), bc2)
		if bot.get("cargo", false) and bs >= 1:
			m.box(Vector3(sx + osx * (tr + 0.004), 0.68, 0.0), Vector3(0.03, 0.12, 0.10), bc.darkened(0.14))
		m.bone = B_SHIN_L if side == 0 else B_SHIN_R
		m.ellipsoid(Vector3(sx, 0.47, -0.004), Vector3(0.060 + lbulk, 0.058, 0.064 + lbulk), legc if bs == 1 else skin, 12, 6)
		m.tube(sx, 0, 0.09, 0.47, Vector2(0.043 + lbulk, 0.046 + lbulk), Vector2(0.058 + lbulk, 0.060 + lbulk), shin, 12, false, false)
		if bs == 1:
			if bot.get("pat", 0) == 1:
				m.box(Vector3(sx + osx * 0.052, 0.28, 0), Vector3(0.012, 0.38, 0.03), bc2)
			elif bot.get("pat", 0) == 2:
				m.tube(sx, 0, 0.09, 0.16, Vector2(0.048 + lbulk, 0.051 + lbulk), Vector2(0.05 + lbulk, 0.053 + lbulk), bc2, 12, false, false)
			if bot.get("knee", false):
				m.box(Vector3(sx, 0.46, -0.058), Vector3(0.08, 0.1, 0.03), bc.darkened(0.3))
		var sst: int = shoes.get("style", 0)
		if sst == 0:
			m.box(Vector3(sx, 0.045, -0.045), Vector3(0.085, 0.08, 0.23), skin)
		elif sst == 4:
			m.box(Vector3(sx, 0.05, -0.045), Vector3(0.082, 0.07, 0.22), skin)
			m.box(Vector3(sx, 0.012, -0.05), Vector3(0.10, 0.024, 0.26), sc)
			m.box(Vector3(sx, 0.07, -0.09), Vector3(0.092, 0.035, 0.03), sc)
		else:
			var sole := sc.darkened(0.45)
			if shoes.get("sole", false):
				sole = Color(0.88, 0.87, 0.84)
			if sst == 3:
				m.box(Vector3(sx, 0.042, -0.055), Vector3(0.09, 0.075, 0.27), sc)
				m.box(Vector3(sx, 0.01, -0.055), Vector3(0.094, 0.02, 0.275), sole)
			else:
				m.box(Vector3(sx, 0.05, -0.05), Vector3(0.098, 0.10, 0.26), sc)
				m.box(Vector3(sx, 0.012, -0.05), Vector3(0.104, 0.026, 0.27), sole)
			if sst == 2:
				var shaft := 0.40 if shoes.get("tall", false) else 0.28
				m.tube(sx, 0, 0.09, shaft, Vector2(0.052, 0.055), Vector2(0.058 + lbulk, 0.060 + lbulk), sc, 12, false, true)

	# ---------------- tronco
	m.bone = B_SPINE
	var wst := Vector2(hp * 0.94 + bulk, dp + bulk)
	var chs := Vector2(sh + bulk, dp + 0.012 + bulk)
	var shd := Vector2(sh * 0.80 + bulk, dp * 0.86 + bulk)
	if fem:
		wst.x -= 0.012
	var body_c := skin
	var body_c2 := skin
	var bands := 1
	var checker := false
	var split := false
	if os > 0:
		body_c = oc
		body_c2 = oc.darkened(0.07)
		if over.get("puffy", false):
			bands = 5
	elif has_top:
		body_c = tc
		body_c2 = tc2
		if tpat == 1:
			bands = 6
		elif tpat == 2:
			split = true
		elif tpat == 3:
			bands = 7
			checker = true
	if split:
		m.tube(0, 0, 1.03, 1.30, wst, chs, body_c, 14, false, false)
		m.tube(0, 0, 1.30, 1.485, chs, shd, body_c2, 14, false, true)
	else:
		m.tube(0, 0, 1.03, 1.30, wst, chs, body_c, 14, false, false, bands, body_c2, checker)
		m.tube(0, 0, 1.30, 1.485, chs, shd, body_c if bands % 2 == 1 else body_c2, 14, false, true, 1 if not checker else 4, body_c2 if bands % 2 == 1 else body_c, checker)
	var front := -(dp + bulk + 0.006)
	if os == 0 and has_top:
		if tpat == 4:
			m.box(Vector3(0, 1.30, front - 0.004), Vector3(0.13, 0.12, 0.008), tc2)
		elif tpat == 5:
			m.tube(0, 0, 1.27, 1.33, chs + Vector2(0.004, 0.004), chs + Vector2(0.004, 0.004), tc2, 14, false, false)
		elif tpat == 6:
			m.tube(0, 0, 1.12, 1.15, wst.lerp(chs, 0.35) + Vector2(0.004, 0.004), wst.lerp(chs, 0.45) + Vector2(0.004, 0.004), refl, 14, false, false)
			m.tube(0, 0, 1.33, 1.36, chs + Vector2(0.003, 0.003), chs + Vector2(0.001, 0.001), refl, 14, false, false)
		if sl == 0:
			m.ellipsoid(Vector3(-sh * 0.86, 1.455, 0), Vector3(0.06, 0.045, 0.07), skin, 10, 5)
			m.ellipsoid(Vector3(sh * 0.86, 1.455, 0), Vector3(0.06, 0.045, 0.07), skin, 10, 5)
		if top.get("buttons", false):
			m.box(Vector3(0, 1.27, front), Vector3(0.022, 0.40, 0.008), tc.lightened(0.25) if tc.get_luminance() < 0.6 else tc.darkened(0.2))
		if top.get("collar", false):
			m.tube(0, 0, 1.47, 1.512, Vector2(0.07, 0.07), Vector2(0.084, 0.084), tc.lightened(0.14) if tc.get_luminance() < 0.6 else tc.darkened(0.12), 12, false, false)
		if top.get("turtle", false):
			m.tube(0, 0, 1.47, 1.565, Vector2(0.06, 0.062), Vector2(0.056, 0.058), tc, 12, false, false)
		if top.get("vneck", false):
			m.box(Vector3(0, 1.44, front + 0.002), Vector3(0.06, 0.07, 0.008), skin)
		if top.get("badge", false):
			m.box(Vector3(-0.085, 1.36, front), Vector3(0.05, 0.05, 0.008), Color(0.85, 0.75, 0.3))
	if jacket:
		if over.get("open", false):
			m.box(Vector3(0, 1.27, front), Vector3(0.065, 0.42, 0.012), tc if has_top else skin)
		else:
			m.box(Vector3(0, 1.27, front), Vector3(0.012, 0.42, 0.008), oc.darkened(0.3))
		m.tube(0, 0, 1.47, 1.515, Vector2(0.075, 0.075), Vector2(0.088, 0.088), oc.darkened(0.15), 12, false, false)
		if over.get("hood", false):
			m.ellipsoid(Vector3(0, 1.50, 0.105), Vector3(0.115, 0.095, 0.075), oc, 10, 5)
		if over.get("long", false):
			m.tube(0, 0, 0.66, 1.04, Vector2(hp + 0.055, dp + 0.055), Vector2(hp + 0.02 + bulk, dp + 0.02 + bulk), oc, 14, false, false)
		if over.get("pockets", false):
			m.box(Vector3(-0.085, 1.36, front - 0.002), Vector3(0.075, 0.07, 0.014), oc.darkened(0.16))
			m.box(Vector3(0.085, 1.36, front - 0.002), Vector3(0.075, 0.07, 0.014), oc.darkened(0.16))
		if opat == 2:
			m.tube(0, 0, 1.12, 1.15, wst.lerp(chs, 0.35) + Vector2(0.004, 0.004), wst.lerp(chs, 0.45) + Vector2(0.004, 0.004), refl, 14, false, false)
			m.tube(0, 0, 1.33, 1.36, chs + Vector2(0.003, 0.003), chs + Vector2(0.001, 0.001), refl, 14, false, false)
	elif os == 3:
		m.box(Vector3(0, 1.27, front), Vector3(0.05, 0.40, 0.01), tc if has_top else skin)
		if over.get("plate", false):
			m.box(Vector3(0, 1.27, front - 0.012), Vector3(0.27, 0.30, 0.03), oc.darkened(0.12))
			m.box(Vector3(0, 1.27, dp + bulk + 0.014), Vector3(0.27, 0.30, 0.03), oc.darkened(0.12))
		if over.get("pockets", false):
			m.box(Vector3(-0.085, 1.15, front - 0.014), Vector3(0.09, 0.09, 0.03), oc.darkened(0.2))
			m.box(Vector3(0.085, 1.15, front - 0.014), Vector3(0.09, 0.09, 0.03), oc.darkened(0.2))
		if opat == 2 or over.get("pname", "") == "faixas refletivas":
			m.tube(0, 0, 1.20, 1.23, wst.lerp(chs, 0.6) + Vector2(0.004, 0.004), wst.lerp(chs, 0.7) + Vector2(0.004, 0.004), refl, 14, false, false)
	# mochilas e bolsas
	var bgs: int = bag.get("style", 0)
	if bgs > 0:
		var bgc: Color = _soil(bag.get("col", Color(0.3, 0.33, 0.22)), dirt, 0.0, 0.6)
		var bgc2: Color = bag.get("col2", bgc.darkened(0.2)) if bag.get("trim", false) else bgc.darkened(0.2)
		var back := dp + bulk
		if bgs == 3:
			m.box(Vector3(-(hp + 0.07), 0.98, 0.02), Vector3(0.09, 0.2, 0.26), bgc)
			m.box_t(Transform3D(Basis(Vector3.BACK, 0.62), Vector3(0.0, 1.27, front - 0.006)), Vector3(0.035, 0.62, 0.012), bgc.darkened(0.3))
			m.box_t(Transform3D(Basis(Vector3.BACK, 0.62), Vector3(0.0, 1.27, back + 0.012)), Vector3(0.035, 0.62, 0.012), bgc.darkened(0.3))
		elif bgs == 4:
			m.box(Vector3(0.03, 1.0, front - 0.04), Vector3(0.17, 0.085, 0.07), bgc)
			m.tube(0, 0, 0.99, 1.02, Vector2(hp + 0.016, dp + 0.016), Vector2(hp + 0.016, dp + 0.016), bgc.darkened(0.3), 14, false, false)
		else:
			var big: bool = bag.get("big", false)
			var bh := 0.34 if bgs == 1 else (0.52 if big else 0.46)
			var bd := 0.13 if bgs == 1 else (0.21 if big else 0.18)
			var bwid := 0.27 if bgs == 1 else (0.35 if big else 0.32)
			m.box(Vector3(0, 1.30 - (0.03 if bgs == 2 else 0.0), back + bd * 0.5), Vector3(bwid, bh, bd), bgc)
			m.box(Vector3(0, 1.20, back + bd + 0.02), Vector3(bwid * 0.7, 0.16, 0.04), bgc2)
			if bgs == 2:
				m.box(Vector3(0, 1.30 + bh * 0.5 + 0.035, back + bd * 0.5), Vector3(bwid * 0.9, 0.07, bd * 0.8), bgc.darkened(0.12))
			for sx2 in [-0.105, 0.105]:
				m.box(Vector3(sx2, 1.34, front - 0.004), Vector3(0.04, 0.30, 0.014), bgc.darkened(0.3))
				m.box(Vector3(sx2, 1.495 + bulk, 0.0), Vector3(0.04, 0.014, dp * 2.0 + bulk * 2.0 + 0.02), bgc.darkened(0.3))

	# ---------------- bracos
	var gl = L.get("gloves", null)
	var sleeve_bands := 1
	if not jacket and has_top and (tpat == 1 or tpat == 3):
		sleeve_bands = 4
	for side in 2:
		var sx := -0.215 if side == 0 else 0.215
		var ar := 0.052 * (0.93 + (bw - 1.0) * 1.3) + bulk * 0.6
		m.bone = B_ARM_L if side == 0 else B_ARM_R
		m.ellipsoid(Vector3(sx, 1.452, 0), Vector3(ar + 0.007, ar + 0.006, ar + 0.008), up_arm, 12, 6)
		if sl == 1 and not jacket and has_top:
			m.tube(sx, 0, 1.17, 1.46, Vector2(ar - 0.007, ar - 0.005), Vector2(ar, ar), skin, 12, false, false)
			m.tube(sx, 0, 1.31, 1.46, Vector2(ar + 0.006, ar + 0.006), Vector2(ar + 0.004, ar + 0.004), tc, 12, true, false, 2 if sleeve_bands > 1 else 1, tc2)
		else:
			m.tube(sx, 0, 1.17, 1.46, Vector2(ar - 0.006, ar - 0.004), Vector2(ar, ar), up_arm, 12, false, false, sleeve_bands if up_arm != skin else 1, tc2)
		if jacket and opat == 2:
			m.tube(sx, 0, 1.24, 1.27, Vector2(ar + 0.002, ar + 0.003), Vector2(ar + 0.002, ar + 0.003), refl, 12, false, false)
		m.bone = B_FARM_L if side == 0 else B_FARM_R
		m.ellipsoid(Vector3(sx, 1.17, 0), Vector3(ar - 0.004, ar - 0.002, ar - 0.002), lo_arm, 10, 5)
		m.tube(sx, 0, 0.91, 1.17, Vector2(ar - 0.016, ar - 0.014), Vector2(ar - 0.006, ar - 0.004), lo_arm, 12, false, false, sleeve_bands if lo_arm != skin else 1, tc2)
		var hc: Color = gl if gl != null else skin
		m.ellipsoid(Vector3(sx, 0.905, -0.004), Vector3(0.034, 0.03, 0.04), hc, 8, 4)
		m.box(Vector3(sx, 0.862, -0.004), Vector3(0.04, 0.07, 0.076), hc)
		for fg in 4:
			m.box(Vector3(sx, 0.806, -0.033 + fg * 0.02), Vector3(0.034, 0.05, 0.017), hc.darkened(0.03 * (fg % 2)))
		m.box(Vector3(sx + (0.014 if side == 0 else -0.014), 0.858, -0.052), Vector3(0.024, 0.055, 0.026), hc)

	# ---------------- pescoco e cabeca
	m.bone = B_HEAD
	m.tube(0, 0, 1.47, 1.57, Vector2(0.052, 0.054), Vector2(0.048, 0.05), skin, 12, false, false)
	var hc0 := Vector3(0, 1.665, -0.004)
	var hr := Vector3(0.094, 0.122, 0.104)
	m.ellipsoid(hc0, hr, skin, 16, 10)
	var eye := Color(0.08, 0.07, 0.07) if not is_z else Color(0.82, 0.8, 0.7)
	var sclera := Color(0.93, 0.92, 0.88) if not is_z else Color(0.80, 0.76, 0.55)
	var iris: Color = L.get("eyes", Color(0.22, 0.16, 0.1)) if not is_z else Color(0.62, 0.6, 0.55)
	for ex in [-0.036, 0.036]:
		m.box(Vector3(ex, 1.686, -0.092), Vector3(0.034, 0.022, 0.012), skin.darkened(0.22))
		m.box(Vector3(ex, 1.686, -0.096), Vector3(0.028, 0.014, 0.012), sclera)
		m.box(Vector3(ex, 1.686, -0.099), Vector3(0.012, 0.013, 0.01), iris)
		m.box(Vector3(ex, 1.686, -0.1005), Vector3(0.006, 0.007, 0.01), Color(0.04, 0.04, 0.04))
		m.box_t(Transform3D(Basis(Vector3.BACK, 0.12 * signf(ex)), Vector3(ex, 1.706, -0.097)), Vector3(0.036, 0.007, 0.014), hairc.darkened(0.2))
	m.ellipsoid(Vector3(0, 1.652, -0.102), Vector3(0.013, 0.022, 0.02), skin.darkened(0.05), 6, 4)
	m.box(Vector3(0, 1.636, -0.104), Vector3(0.024, 0.008, 0.012), skin.darkened(0.14))
	m.box(Vector3(0, 1.607, -0.094), Vector3(0.042, 0.007, 0.012), skin.darkened(0.45) if not is_z else Color(0.3, 0.05, 0.05))
	m.box(Vector3(0, 1.600, -0.093), Vector3(0.034, 0.008, 0.012), skin.lerp(Color(0.7, 0.35, 0.33), 0.45) if not is_z else Color(0.4, 0.3, 0.28))
	m.ellipsoid(Vector3(0, 1.575, -0.07), Vector3(0.05, 0.03, 0.04), skin, 8, 4)
	m.box(Vector3(-0.097, 1.665, 0.0), Vector3(0.012, 0.04, 0.026), skin.darkened(0.08))
	m.box(Vector3(0.097, 1.665, 0.0), Vector3(0.012, 0.04, 0.026), skin.darkened(0.08))
	var hst: int = L.get("hair_style", 1)
	var hats: int = hat.get("style", 0)
	if hst >= 1:
		var hh := Vector3(hr.x + 0.012, hr.y + 0.012, hr.z + 0.014)
		if hats == 0:
			m.ellipsoid(hc0 + Vector3(0, 0.008, 0.012), hh, hairc, 16, 6, 0.0, 1.32)
		if hst >= 2 and hats != 3:
			m.ellipsoid(hc0 + Vector3(0, 0.0, 0.03), Vector3(hr.x + 0.012, hr.y + 0.004, hr.z + 0.006), hairc, 16, 6, 0.9, 2.3)
		if hst == 3:
			m.tube(0, 0.075, 1.40, 1.62, Vector2(0.088, 0.035), Vector2(0.1, 0.05), hairc, 12, true, false)
		elif hst == 4:
			m.tube(0, 0.135, 1.46, 1.70, Vector2(0.022, 0.022), Vector2(0.038, 0.038), hairc, 6, true, true)
		elif hst == 5 and hats == 0:
			m.box(Vector3(0, 1.795, 0.0), Vector3(0.035, 0.05, 0.19), hairc)
	var brd: int = L.get("beard", 0)
	if brd == 1:
		m.box(Vector3(0, 1.582, -0.082), Vector3(0.075, 0.045, 0.03), hairc)
	elif brd >= 2:
		m.ellipsoid(Vector3(0, 1.60, -0.03), Vector3(0.092, 0.075, 0.09), hairc, 12, 6, 1.45, PI)
	if hats > 0:
		var hcol: Color = _soil(hat.get("col", Color(0.2, 0.25, 0.4)), dirt, 0.0, 0.6)
		var hcol2: Color = hat.get("col2", hcol.darkened(0.2)) if hat.get("trim", false) else hcol.darkened(0.16)
		if hats == 1:
			var crown := 0.02 if hat.get("flat", false) else 0.0
			m.ellipsoid(hc0 + Vector3(0, 0.03 + crown, 0.006), Vector3(hr.x + 0.016, hr.y - 0.012 + crown, hr.z + 0.018), hcol, 16, 6, 0.0, 1.5)
			m.box(Vector3(0, 1.715, -0.15), Vector3(0.14, 0.012, 0.11), hcol2)
			if hat.get("flat", false):
				m.box(Vector3(0, 1.77, -0.112), Vector3(0.04, 0.04, 0.012), Color(0.85, 0.75, 0.3))
		elif hats == 2:
			m.ellipsoid(hc0 + Vector3(0, 0.022, 0.004), Vector3(hr.x + 0.018, hr.y + 0.012, hr.z + 0.02), hcol, 16, 7, 0.0, 1.62)
			m.tube(0, -0.004, 1.672, 1.715, Vector2(hr.x + 0.023, hr.z + 0.025), Vector2(hr.x + 0.023, hr.z + 0.025), hcol2, 14, false, false)
		elif hats == 3:
			m.ellipsoid(hc0 + Vector3(0, 0.026, 0.004), Vector3(hr.x + 0.03, hr.y + 0.022, hr.z + 0.034), hcol, 16, 7, 0.0, 2.2 if hat.get("full", false) else 1.66)
			if hat.get("full", false):
				m.box(Vector3(0, 1.68, -0.125), Vector3(0.17, 0.07, 0.03), Color(0.08, 0.09, 0.11))
			else:
				m.box(Vector3(0, 1.69, -0.125), Vector3(0.17, 0.016, 0.05), hcol.darkened(0.2))
			if hat.get("crest", false):
				m.box(Vector3(0, 1.815, 0.02), Vector3(0.03, 0.035, 0.24), hcol.darkened(0.15))
				m.box(Vector3(0, 1.69, 0.14), Vector3(0.2, 0.014, 0.1), hcol.darkened(0.2))
		elif hats == 4:
			m.tube(0, 0, 1.728, 1.742, Vector2(0.21, 0.21), Vector2(0.21, 0.21), hcol, 16, true, true)
			m.tube(0, 0, 1.74, 1.83, Vector2(0.105, 0.115), Vector2(0.09, 0.1), hcol, 14, false, true)
			if hat.get("trim", false):
				m.tube(0, 0, 1.742, 1.765, Vector2(0.108, 0.118), Vector2(0.105, 0.115), hcol2, 14, false, false)
	if L.has("mask"):
		m.box(Vector3(0, 1.618, -0.088), Vector3(0.115, 0.06, 0.04), L["mask"])
	if L.has("glasses"):
		if L.get("glasses_dark", false):
			m.box(Vector3(0, 1.686, -0.102), Vector3(0.15, 0.03, 0.012), L["glasses"])
		else:
			m.box(Vector3(0, 1.70, -0.102), Vector3(0.15, 0.007, 0.012), L["glasses"])
			m.box(Vector3(0, 1.672, -0.102), Vector3(0.15, 0.007, 0.012), L["glasses"])
			m.box(Vector3(-0.073, 1.686, -0.102), Vector3(0.007, 0.03, 0.012), L["glasses"])
			m.box(Vector3(0.073, 1.686, -0.102), Vector3(0.007, 0.03, 0.012), L["glasses"])
			m.box(Vector3(0, 1.686, -0.102), Vector3(0.012, 0.03, 0.012), L["glasses"])

	# ---------------- marcas de zumbi (feridas e sangue)
	if is_z:
		var bc0 := Color(0.33, 0.04, 0.04)
		m.bone = B_SPINE
		for i in 2 + rs.randi() % 3:
			var a := rs.randf() * TAU
			var y := rs.randf_range(1.08, 1.42)
			m.box(Vector3(cos(a) * (sh + bulk - 0.01), y, sin(a) * (dp + bulk + 0.004)), Vector3(rs.randf_range(0.05, 0.11), rs.randf_range(0.04, 0.1), 0.03), bc0)
		m.bone = B_HEAD
		if rs.randf() < 0.6:
			m.box(Vector3(rs.randf_range(-0.05, 0.05), rs.randf_range(1.60, 1.72), -0.09), Vector3(0.05, 0.04, 0.03), bc0)
		m.box(Vector3(0, 1.585, -0.092), Vector3(0.06, 0.03, 0.02), bc0)
	return m


# =====================================================================================
#  MODELOS DE ARMAS E FERRAMENTAS (empunhadura na origem, comprimento ao longo de -Z)
# =====================================================================================
static var _wcache := {}


static func weapon_mesh(kind: String) -> ArrayMesh:
	if _wcache.has(kind):
		return _wcache[kind]
	Mats.init()
	var m := MB.new()
	var wood := Color(0.48, 0.33, 0.2)
	var steel := Color(0.62, 0.64, 0.66)
	var dark := Color(0.13, 0.13, 0.14)
	match kind:
		"bat":
			m.box(Vector3(0, 0, -0.30), Vector3(0.04, 0.04, 0.75), wood)
			m.box(Vector3(0, 0, -0.55), Vector3(0.06, 0.06, 0.32), wood.lightened(0.08))
		"bat_nails":
			m.box(Vector3(0, 0, -0.30), Vector3(0.04, 0.04, 0.75), wood)
			m.box(Vector3(0, 0, -0.55), Vector3(0.06, 0.06, 0.32), wood.lightened(0.08))
			for i in 4:
				m.box(Vector3(0, 0, -0.45 - i * 0.07), Vector3(0.13, 0.012, 0.012), steel)
				m.box(Vector3(0, 0, -0.48 - i * 0.07), Vector3(0.012, 0.13, 0.012), steel)
		"plank":
			m.box(Vector3(0, 0, -0.35), Vector3(0.10, 0.03, 0.9), wood.lightened(0.15))
		"axe":
			m.box(Vector3(0, 0, -0.30), Vector3(0.035, 0.045, 0.82), wood)
			m.box(Vector3(0, -0.07, -0.66), Vector3(0.03, 0.2, 0.11), steel)
			m.box(Vector3(0, -0.15, -0.66), Vector3(0.012, 0.06, 0.15), steel.lightened(0.2))
		"hatchet":
			m.box(Vector3(0, 0, -0.14), Vector3(0.03, 0.04, 0.40), wood)
			m.box(Vector3(0, -0.05, -0.31), Vector3(0.025, 0.13, 0.08), steel)
		"stone_axe":
			m.box(Vector3(0, 0, -0.16), Vector3(0.03, 0.035, 0.44), wood.darkened(0.1))
			m.box(Vector3(0, -0.04, -0.34), Vector3(0.04, 0.12, 0.08), Color(0.45, 0.45, 0.44))
		"hammer":
			m.box(Vector3(0, 0, -0.10), Vector3(0.028, 0.035, 0.30), wood)
			m.box(Vector3(0, 0, -0.26), Vector3(0.04, 0.12, 0.045), steel.darkened(0.2))
		"sledge":
			m.box(Vector3(0, 0, -0.32), Vector3(0.04, 0.04, 0.85), wood)
			m.box(Vector3(0, 0, -0.74), Vector3(0.09, 0.2, 0.09), steel.darkened(0.3))
		"crowbar":
			m.box(Vector3(0, 0, -0.26), Vector3(0.025, 0.025, 0.62), Color(0.55, 0.12, 0.1))
			m.box(Vector3(0, -0.035, -0.57), Vector3(0.025, 0.07, 0.03), Color(0.55, 0.12, 0.1))
		"pipe":
			m.box(Vector3(0, 0, -0.26), Vector3(0.035, 0.035, 0.62), steel.darkened(0.25))
		"wrench":
			m.box(Vector3(0, 0, -0.1), Vector3(0.022, 0.03, 0.28), steel)
			m.box(Vector3(0, 0, -0.26), Vector3(0.022, 0.06, 0.05), steel)
		"knife":
			m.box(Vector3(0, 0, 0.0), Vector3(0.026, 0.032, 0.11), dark)
			m.box(Vector3(0, 0.004, -0.15), Vector3(0.008, 0.034, 0.2), steel.lightened(0.15))
		"machete":
			m.box(Vector3(0, 0, 0.0), Vector3(0.028, 0.036, 0.13), dark)
			m.box(Vector3(0, 0.008, -0.33), Vector3(0.008, 0.06, 0.52), steel)
		"screwdriver":
			m.box(Vector3(0, 0, 0.0), Vector3(0.03, 0.03, 0.1), Color(0.8, 0.5, 0.1))
			m.box(Vector3(0, 0, -0.13), Vector3(0.01, 0.01, 0.16), steel)
		"spear":
			m.box(Vector3(0, 0, -0.45), Vector3(0.03, 0.03, 1.5), wood.darkened(0.1))
			m.box(Vector3(0, 0, -1.25), Vector3(0.012, 0.035, 0.16), steel)
		"shovel":
			m.box(Vector3(0, 0, -0.3), Vector3(0.03, 0.03, 0.9), wood)
			m.box(Vector3(0, 0, -0.84), Vector3(0.17, 0.015, 0.24), steel.darkened(0.2))
		"hoe":
			m.box(Vector3(0, 0, -0.3), Vector3(0.03, 0.03, 0.95), wood)
			m.box(Vector3(0, -0.06, -0.77), Vector3(0.14, 0.12, 0.015), steel.darkened(0.2))
		"pan":
			m.box(Vector3(0, 0, -0.06), Vector3(0.025, 0.02, 0.2), dark)
			m.tube(0, -0.28, -0.012, 0.012, Vector2(0.12, 0.12), Vector2(0.12, 0.12), dark.lightened(0.1), 10)
		"saw":
			m.box(Vector3(0, 0, 0.0), Vector3(0.03, 0.09, 0.1), wood)
			m.box(Vector3(0, -0.02, -0.26), Vector3(0.006, 0.1, 0.42), steel)
		"flashlight":
			m.box(Vector3(0, 0, -0.03), Vector3(0.035, 0.035, 0.15), dark)
			m.box(Vector3(0, 0, -0.12), Vector3(0.05, 0.05, 0.04), steel)
		"gun_pistol":
			m.box(Vector3(0, -0.035, 0.01), Vector3(0.028, 0.10, 0.04), dark)
			m.box(Vector3(0, 0.03, -0.055), Vector3(0.03, 0.04, 0.19), dark.lightened(0.08))
		"gun_revolver":
			m.box(Vector3(0, -0.035, 0.015), Vector3(0.028, 0.10, 0.04), wood.darkened(0.2))
			m.box(Vector3(0, 0.028, -0.02), Vector3(0.045, 0.05, 0.06), steel.darkened(0.3))
			m.box(Vector3(0, 0.035, -0.12), Vector3(0.02, 0.022, 0.16), steel.darkened(0.3))
		"gun_shotgun":
			m.box(Vector3(0, -0.02, 0.16), Vector3(0.035, 0.09, 0.3), wood)
			m.box(Vector3(0, 0.02, -0.05), Vector3(0.04, 0.055, 0.2), dark)
			m.box(Vector3(0, 0.03, -0.45), Vector3(0.026, 0.026, 0.62), dark.lightened(0.1))
			m.box(Vector3(0, -0.005, -0.3), Vector3(0.04, 0.04, 0.2), wood.darkened(0.1))
		"gun_rifle":
			m.box(Vector3(0, -0.02, 0.17), Vector3(0.035, 0.085, 0.3), wood.darkened(0.15))
			m.box(Vector3(0, 0.02, -0.08), Vector3(0.04, 0.055, 0.28), wood.darkened(0.15))
			m.box(Vector3(0, 0.035, -0.52), Vector3(0.02, 0.02, 0.66), dark.lightened(0.1))
			m.box(Vector3(0, 0.075, -0.08), Vector3(0.026, 0.026, 0.2), dark)
		"gun_carbine":
			m.box(Vector3(0, -0.01, 0.15), Vector3(0.035, 0.07, 0.24), dark)
			m.box(Vector3(0, 0.02, -0.08), Vector3(0.04, 0.06, 0.3), dark.lightened(0.06))
			m.box(Vector3(0, 0.03, -0.38), Vector3(0.022, 0.022, 0.34), dark.lightened(0.1))
			m.box(Vector3(0, -0.08, -0.06), Vector3(0.026, 0.13, 0.05), dark)
		"log":
			m.tube(0, 0, -0.5, 0.5, Vector2(0.12, 0.12), Vector2(0.12, 0.12), wood.darkened(0.2), 8)
		_:
			m.box(Vector3(0, 0, -0.08), Vector3(0.05, 0.05, 0.2), Color(0.5, 0.5, 0.5))
	var mesh := m.to_mesh(Mats.flat)
	_wcache[kind] = mesh
	return mesh


# =====================================================================================
#  ANIMACAO PROCEDURAL
# =====================================================================================
func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func animate(dt: float) -> void:
	_frame += 1
	if lod_skip > 0 and (_frame + int(_seed)) % (lod_skip + 1) != 0:
		return
	if lod_skip > 0:
		dt *= float(lod_skip + 1)
	_t += dt
	var T := _tgt
	for i in NB:
		T[i] = Vector3.ZERO
	var sp := absf(speed)
	var run := clampf((sp - 1.7) / 3.4, 0.0, 1.0)
	var moving := clampf(sp / 0.7, 0.0, 1.0)
	var cr := crouch
	var stride := lerpf(1.35, 2.5, run) * (0.78 if cr > 0.5 else 1.0)
	if zombie:
		stride = lerpf(1.0, 2.2, run)
	if sp > 0.05:
		var prev := int(phase / PI)
		phase += dt * (sp / stride) * TAU
		if int(phase / PI) != prev:
			step.emit(int(phase / PI) % 2)
		if phase > TAU * 64.0:
			phase -= TAU * 64.0
	var s := sin(phase)
	var c := cos(phase)
	var A := lerpf(0.44, 0.86, run) * moving
	var hip := Vector3.ZERO

	# ---- locomocao
	var la := 1.0
	var ra := 1.0 - 0.45 * limp
	T[B_LEG_L].x = A * s * la
	T[B_LEG_R].x = -A * s * ra
	T[B_SHIN_L].x = -(0.06 + lerpf(0.6, 1.3, run) * maxf(0.0, c)) * moving
	T[B_SHIN_R].x = -(0.06 + lerpf(0.6, 1.3, run) * maxf(0.0, -c)) * moving * ra
	hip.y = -(0.018 + 0.03 * run) * absf(s) * moving
	T[B_SPINE].x = -(0.05 + 0.24 * run) * moving - 0.08 * tired
	T[B_SPINE].y = 0.10 * s * moving * (1.0 + run * 0.6)
	T[B_SPINE].z = 0.03 * s * moving + 0.10 * limp * s
	T[B_HEAD].y = -T[B_SPINE].y * 0.8
	T[B_HEAD].x = -T[B_SPINE].x * 0.65 - 0.1 * tired
	var arm_a := A * lerpf(0.75, 1.05, run)
	T[B_ARM_L].x = -arm_a * s
	T[B_ARM_R].x = arm_a * s
	T[B_ARM_L].z = -0.07
	T[B_ARM_R].z = 0.07
	var elb := lerpf(0.16, 1.2, run) * maxf(moving, 0.4)
	T[B_FARM_L].x = elb + 0.12 * maxf(0.0, -s) * moving
	T[B_FARM_R].x = elb + 0.12 * maxf(0.0, s) * moving
	# respiracao em repouso
	var br := sin(_t * (1.5 + tired * 2.0) + _seed)
	T[B_SPINE].x += br * (0.012 + 0.02 * tired) * (1.0 - moving)
	T[B_ARM_L].z -= br * 0.012
	T[B_ARM_R].z += br * 0.012
	T[B_HEAD].y += sin(_t * 0.31 + _seed) * 0.06 * (1.0 - moving)

	# ---- agachado / furtivo
	if cr > 0.01:
		hip.y -= 0.27 * cr
		T[B_LEG_L].x += 0.9 * cr
		T[B_LEG_R].x += 0.9 * cr
		T[B_SHIN_L].x -= 1.5 * cr
		T[B_SHIN_R].x -= 1.5 * cr
		T[B_SPINE].x -= 0.42 * cr
		T[B_HEAD].x += 0.34 * cr
		T[B_FARM_L].x += 0.5 * cr
		T[B_FARM_R].x += 0.5 * cr

	# ---- sentado (dirigindo)
	if sit > 0.01:
		hip.y -= 0.40 * sit
		T[B_LEG_L].x = 1.42 * sit
		T[B_LEG_R].x = 1.42 * sit
		T[B_SHIN_L].x = -1.25 * sit
		T[B_SHIN_R].x = -1.25 * sit
		T[B_ARM_L].x = 1.0 * sit
		T[B_ARM_R].x = 1.0 * sit
		T[B_ARM_L].z = 0.12
		T[B_ARM_R].z = -0.12
		T[B_FARM_L].x = 0.5
		T[B_FARM_R].x = 0.5
		T[B_SPINE].x = 0.06

	# ---- zumbi
	if zombie:
		T[B_SPINE].x -= 0.16 + 0.08 * sin(_t * 0.7 + _seed)
		T[B_SPINE].z += 0.09 * s * moving + 0.05 * sin(_seed)
		T[B_HEAD].z = 0.22 * sin(_seed * 3.1) + 0.05 * sin(_t * 0.9 + _seed)
		T[B_HEAD].x += 0.12
		var rc := maxf(reach, 0.12)
		T[B_ARM_L].x = lerpf(T[B_ARM_L].x * 0.4 + 0.15, 1.25 + 0.12 * sin(_t * 2.1 + _seed), rc)
		T[B_ARM_R].x = lerpf(T[B_ARM_R].x * 0.4 + 0.15, 1.38 + 0.12 * sin(_t * 1.7 + _seed * 2.0), rc)
		T[B_ARM_L].z = lerpf(-0.1, 0.16, rc)
		T[B_ARM_R].z = lerpf(0.1, -0.16, rc)
		T[B_FARM_L].x = lerpf(0.2, 0.42, rc)
		T[B_FARM_R].x = lerpf(0.25, 0.3, rc)

	# ---- empunhadura e mira
	if aim == 1:
		T[B_ARM_R] = Vector3(1.47 + aim_pitch, 0.0, -0.13)
		T[B_FARM_R].x = 0.08
		T[B_ARM_L] = Vector3(1.36 + aim_pitch, 0.0, 0.40)
		T[B_FARM_L].x = 0.28
		T[B_SPINE].x += aim_pitch * 0.25
		T[B_HEAD].x += aim_pitch * 0.5
	elif aim == 2:
		T[B_ARM_R] = Vector3(0.82 + aim_pitch, 0.0, 0.34)
		T[B_FARM_R].x = 1.62
		T[B_ARM_L] = Vector3(1.26 + aim_pitch, 0.0, 0.42)
		T[B_FARM_L].x = 0.42
		T[B_SPINE].y = -0.32
		T[B_SPINE].x += aim_pitch * 0.3
		T[B_HEAD].y = 0.30
		T[B_HEAD].x += aim_pitch * 0.5
	elif not zombie:
		match hold:
			1:
				T[B_ARM_R].x = T[B_ARM_R].x * 0.4 + 0.22
				T[B_FARM_R].x = 0.62
			2:
				T[B_ARM_R] = Vector3(0.42, 0.0, -0.10)
				T[B_FARM_R].x = 1.05
				T[B_ARM_L] = Vector3(0.62, 0.0, 0.48)
				T[B_FARM_L].x = 1.0
			3:
				T[B_ARM_R].x = T[B_ARM_R].x * 0.3 + 0.2
				T[B_FARM_R].x = 0.45
			4:
				T[B_ARM_R] = Vector3(0.25, 0.0, 0.05)
				T[B_FARM_R].x = 1.25
				T[B_ARM_L] = Vector3(0.72, 0.0, 0.52)
				T[B_FARM_L].x = 0.9

	# ---- acoes
	var k_rate := 12.0
	if act != "":
		k_rate = 26.0
		var t := act_t
		match act:
			"swing_side":
				var two := hold == 2
				if t < 0.34:
					var w := _ease(t / 0.34)
					T[B_ARM_R] = Vector3(1.15, 0.0, lerpf(0.2, 1.15, w))
					T[B_FARM_R].x = 0.9
					T[B_SPINE].y = -0.55 * w
					if two:
						T[B_ARM_L] = Vector3(1.25, 0.0, 0.2 + 0.5 * w)
						T[B_FARM_L].x = 1.2
				elif t < 0.6:
					var w2 := _ease((t - 0.34) / 0.26)
					T[B_ARM_R] = Vector3(1.3, 0.0, lerpf(1.15, -0.75, w2))
					T[B_FARM_R].x = 0.25
					T[B_SPINE].y = lerpf(-0.55, 0.6, w2)
					T[B_SPINE].x -= 0.15
					if two:
						T[B_ARM_L] = Vector3(1.35, 0.0, lerpf(0.7, 0.1, w2))
						T[B_FARM_L].x = 0.6
				else:
					T[B_ARM_R] = Vector3(0.9, 0.0, -0.5)
					T[B_FARM_R].x = 0.6
					T[B_SPINE].y = 0.3
			"swing_over", "chop":
				var two2 := hold == 2
				if t < 0.4:
					var w3 := _ease(t / 0.4)
					T[B_ARM_R] = Vector3(lerpf(0.6, 2.75, w3), 0.0, 0.1)
					T[B_FARM_R].x = 1.1
					T[B_SPINE].x += 0.16 * w3
					if two2:
						T[B_ARM_L] = Vector3(lerpf(0.6, 2.6, w3), 0.0, 0.3)
						T[B_FARM_L].x = 1.2
				elif t < 0.62:
					var w4 := _ease((t - 0.4) / 0.22)
					T[B_ARM_R] = Vector3(lerpf(2.75, 0.55, w4), 0.0, 0.0)
					T[B_FARM_R].x = lerpf(1.1, 0.15, w4)
					T[B_SPINE].x -= 0.5 * w4
					if two2:
						T[B_ARM_L] = Vector3(lerpf(2.6, 0.7, w4), 0.0, 0.42)
						T[B_FARM_L].x = lerpf(1.2, 0.5, w4)
				else:
					T[B_ARM_R] = Vector3(0.5, 0.0, 0.0)
					T[B_FARM_R].x = 0.4
					T[B_SPINE].x -= 0.3
					if two2:
						T[B_ARM_L] = Vector3(0.7, 0.0, 0.42)
						T[B_FARM_L].x = 0.6
			"stab":
				if t < 0.35:
					T[B_ARM_R] = Vector3(-0.35, 0.0, 0.15)
					T[B_FARM_R].x = 1.7
					T[B_SPINE].y = -0.3
				elif t < 0.6:
					T[B_ARM_R] = Vector3(1.42, 0.0, -0.1)
					T[B_FARM_R].x = 0.05
					T[B_SPINE].y = 0.3
					T[B_SPINE].x -= 0.2
				else:
					T[B_ARM_R] = Vector3(0.8, 0.0, 0.0)
					T[B_FARM_R].x = 0.7
			"push":
				if t < 0.3:
					T[B_ARM_L] = Vector3(0.7, 0.0, 0.1)
					T[B_ARM_R] = Vector3(0.7, 0.0, -0.1)
					T[B_FARM_L].x = 1.7
					T[B_FARM_R].x = 1.7
				elif t < 0.65:
					T[B_ARM_L] = Vector3(1.45, 0.0, 0.1)
					T[B_ARM_R] = Vector3(1.45, 0.0, -0.1)
					T[B_FARM_L].x = 0.15
					T[B_FARM_R].x = 0.15
					T[B_SPINE].x -= 0.28
			"stomp":
				if t < 0.45:
					T[B_LEG_R].x = 1.25
					T[B_SHIN_R].x = -1.5
					T[B_SPINE].x += 0.1
				elif t < 0.7:
					T[B_LEG_R].x = 0.25
					T[B_SHIN_R].x = -0.1
					T[B_SPINE].x -= 0.3
					hip.y -= 0.06
			"lunge":
				var w5 := sin(clampf(t, 0.0, 1.0) * PI)
				T[B_ARM_L].x = 1.5
				T[B_ARM_R].x = 1.6
				T[B_FARM_L].x = 0.5 * (1.0 - w5)
				T[B_FARM_R].x = 0.5 * (1.0 - w5)
				T[B_SPINE].x -= 0.5 * w5
				T[B_HEAD].x -= 0.25 * w5
			"use":
				T[B_ARM_R] = Vector3(0.75, 0.0, -0.25)
				T[B_FARM_R].x = 2.0 + 0.15 * sin(_t * 9.0)
				T[B_HEAD].x += 0.08
			"work":
				T[B_ARM_L] = Vector3(0.75, 0.0, 0.2)
				T[B_ARM_R] = Vector3(0.75, 0.0, -0.2)
				T[B_FARM_L].x = 1.1 + 0.25 * sin(_t * 7.0)
				T[B_FARM_R].x = 1.1 + 0.25 * sin(_t * 7.0 + 2.0)
				T[B_SPINE].x -= 0.22
				T[B_HEAD].x -= 0.2
			"reload":
				T[B_ARM_R] = Vector3(0.75, 0.0, -0.05)
				T[B_FARM_R].x = 1.25
				T[B_ARM_L] = Vector3(0.6 + 0.3 * sin(t * TAU * 1.5), 0.0, 0.5)
				T[B_FARM_L].x = 1.45
				T[B_HEAD].x -= 0.22
			"vault":
				var w6 := sin(clampf(t, 0.0, 1.0) * PI)
				hip.y += 0.25 * w6
				T[B_LEG_L].x = 1.3 * w6
				T[B_SHIN_L].x = -1.5 * w6
				T[B_LEG_R].x = 0.9 * w6
				T[B_SHIN_R].x = -1.4 * w6
				T[B_ARM_L].x = 1.2 * w6
				T[B_ARM_R].x = 1.2 * w6
				T[B_SPINE].x -= 0.5 * w6

	if flinch > 0.01:
		T[B_SPINE].x += 0.35 * flinch
		T[B_HEAD].x += 0.3 * flinch
		T[B_ARM_L].z -= 0.4 * flinch
		T[B_ARM_R].z += 0.4 * flinch
		flinch = maxf(0.0, flinch - dt * 3.5)

	# ---- deitado / caido
	if down > 0.01:
		var dn := _ease(down)
		var sgn := 1.0 if down_back else -1.0
		pivot.rotation.x = sgn * dn * 1.5
		pivot.position.y = dn * 0.16
		pivot.position.z = sgn * dn * -0.5
		T[B_ARM_L].z -= 0.7 * dn
		T[B_ARM_R].z += 0.5 * dn
		T[B_LEG_L].z = -0.12 * dn
		T[B_LEG_R].z = 0.16 * dn
		T[B_SHIN_R].x -= 0.5 * dn
	elif pivot.rotation.x != 0.0:
		pivot.rotation.x = 0.0
		pivot.position = Vector3.ZERO

	var k := 1.0 - exp(-k_rate * dt)
	for i in NB:
		_ang[i] = _ang[i].lerp(T[i], k)
		skel.set_bone_pose_rotation(i, Quaternion.from_euler(_ang[i]))
	_hip = _hip.lerp(hip, 1.0 - exp(-14.0 * dt))
	skel.set_bone_pose_position(B_HIPS, REST[B_HIPS] + _hip)


## Posicao global aproximada da cabeca (olhos).
func head_pos() -> Vector3:
	return global_position + Vector3(0, (1.62 - 0.27 * crouch) * pivot.scale.y, 0)
