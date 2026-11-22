class_name FurnDetail
extends RefCounted
## Moveis detalhados gerados por codigo: estofados com almofadas arredondadas, estantes com
## livros individuais, armarios e gavetas com portas almofadadas, puxadores e rodapes.
## Usa apenas arrays (seguro em threads). As dimensoes de colisao continuam as de BPlan.FURN.

const IDS := {"sofa": 1, "poltrona": 1, "estante": 1, "guarda_roupa": 1, "armario_cozinha": 1, "comoda": 1, "criado_mudo": 1}
const BOOKS := [Color(0.52, 0.16, 0.14), Color(0.16, 0.26, 0.46), Color(0.20, 0.40, 0.26), Color(0.74, 0.62, 0.26), Color(0.36, 0.20, 0.42),
	Color(0.62, 0.34, 0.14), Color(0.84, 0.80, 0.68), Color(0.14, 0.15, 0.18), Color(0.56, 0.22, 0.30), Color(0.22, 0.44, 0.50),
	Color(0.44, 0.30, 0.20), Color(0.70, 0.70, 0.72), Color(0.30, 0.34, 0.20), Color(0.78, 0.40, 0.22)]
const GOLD := Color(0.86, 0.74, 0.40)
const BRASS := Color(0.74, 0.62, 0.34)


static func has(id: String) -> bool:
	return IDS.has(id)


static func _b(m: MB, t: Transform3D, x: float, y: float, z: float, sx: float, sy: float, sz: float, col: Color, faces: int = 63) -> void:
	m.box_t(t * Transform3D(Basis.IDENTITY, Vector3(x, y, z)), Vector3(sx, sy, sz), col, faces)


static func _r(m: MB, t: Transform3D, x: float, y: float, z: float, sx: float, sy: float, sz: float, col: Color, e: float = 0.4, rx: float = 0.0) -> Transform3D:
	var tt := t * Transform3D(Basis(Vector3.RIGHT, rx), Vector3(x, y, z))
	m.rbox(tt, Vector3(sx, sy, sz), col, e)
	return tt


static func _cyl(m: MB, t: Transform3D, x: float, z: float, y0: float, y1: float, r0: float, r1: float, col: Color, sides: int = 8) -> void:
	var p := t * Vector3(x, 0, z)
	m.tube(p.x, p.z, p.y + y0, p.y + y1, Vector2(r0, r0), Vector2(r1, r1), col, sides, false, true)


static func _wood(c: Color) -> Color:
	return MB.wm(c, MB.M_WOOD)


static func _metal(c: Color) -> Color:
	return MB.wm(c, MB.M_METAL)


## Frente de porta ou gaveta com moldura (montantes e travessas) e almofadas em relevo.
## rails: fracoes da altura (0..1) onde ha travessas intermediarias.
static func _panel(m: MB, t: Transform3D, cx: float, cy: float, z: float, w: float, h: float, frame: Color, field: Color, rails: Array = [], st: float = 0.055) -> void:
	_b(m, t, cx, cy, z, w, h, 0.018, field, 61)
	var zf := z + 0.014
	_b(m, t, cx - w * 0.5 + st * 0.5, cy, zf, st, h, 0.012, frame, 61)
	_b(m, t, cx + w * 0.5 - st * 0.5, cy, zf, st, h, 0.012, frame, 61)
	var iw := w - st * 2.0
	var ys := [0.0]
	for r in rails:
		ys.append(float(r))
	ys.append(1.0)
	for i in ys.size():
		var yy: float = cy - h * 0.5 + float(ys[i]) * h
		if i == 0:
			yy += st * 0.5
		elif i == ys.size() - 1:
			yy -= st * 0.5
		_b(m, t, cx, yy, zf, iw, st, 0.012, frame, 61)
	for i in ys.size() - 1:
		var ya: float = cy - h * 0.5 + float(ys[i]) * h + (st if i == 0 else st * 0.5)
		var yb: float = cy - h * 0.5 + float(ys[i + 1]) * h - (st if i == ys.size() - 2 else st * 0.5)
		var fh := yb - ya - 0.045
		if fh > 0.04 and iw > 0.1:
			_b(m, t, cx, (ya + yb) * 0.5, z + 0.012, iw - 0.045, fh, 0.008, field.lightened(0.07), 61)


static func build(m: MB, t: Transform3D, id: String, plan: BPlan, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	match id:
		"sofa":
			_sofa(m, t, 2, plan.c_fab, plan.c_fab2, rng)
		"poltrona":
			_sofa(m, t, 1, plan.c_fab, plan.c_fab2, rng)
		"estante":
			_bookcase(m, t, rng)
		"guarda_roupa":
			_wardrobe(m, t, plan.c_fab2, rng)
		"armario_cozinha":
			_kitchen(m, t, rng)
		"comoda":
			_dresser(m, t, plan.c_fab2, rng)
		"criado_mudo":
			_nightstand(m, t, rng)


static func _sofa(m: MB, t: Transform3D, seats: int, fab: Color, fab2: Color, rng: RandomNumberGenerator) -> void:
	var ww := 1.9 if seats == 2 else 0.94
	var hw := ww * 0.5
	var f := MB.wm(fab, MB.M_FABRIC)
	var fl := MB.wm(fab.lightened(0.13), MB.M_FABRIC)
	var fd := MB.wm(fab.darkened(0.32), MB.M_FABRIC)
	var wood := _wood(BPlan.DWOOD)
	# pes torneados e estrado de madeira
	for sx in [-1.0, 1.0]:
		for z in [-0.32, 0.38]:
			_cyl(m, t, sx * (hw - 0.09), z, 0.0, 0.1, 0.024, 0.04, wood, 7)
	_b(m, t, 0, 0.115, 0.03, ww - 0.08, 0.04, 0.8, wood, 61)
	# base, encosto e bracos estofados
	_r(m, t, 0, 0.25, 0.03, ww, 0.25, 0.88, f, 0.3)
	_r(m, t, 0, 0.60, -0.34, ww, 0.60, 0.2, f, 0.38, -0.06)
	for sx in [-1.0, 1.0]:
		_r(m, t, sx * (hw - 0.095), 0.43, 0.04, 0.2, 0.46, 0.88, f, 0.45)
		_r(m, t, sx * (hw - 0.095), 0.655, 0.04, 0.25, 0.14, 0.92, f, 0.85)
	# almofadas de assento e de encosto, com vivo e botoes
	var cw := (ww - 0.42) / seats
	for i in seats:
		var cx := (i - (seats - 1) * 0.5) * (cw + 0.012)
		_r(m, t, cx, 0.425, 0.11, cw, 0.17, 0.68, fl, 0.42)
		_b(m, t, cx, 0.40, 0.45, cw * 0.9, 0.014, 0.01, fd, 4 | 1)
		var ct := _r(m, t, cx, 0.71, -0.185, cw - 0.02, 0.42, 0.17, fl, 0.5, -0.2)
		for bx in [-0.26, 0.0, 0.26]:
			for by in [-0.09, 0.09]:
				m.box_t(ct * Transform3D(Basis.IDENTITY, Vector3(bx * cw, by, 0.082)), Vector3(0.024, 0.024, 0.012), fd, 4 | 1 | 2 | 16 | 32)
	# almofadas soltas e manta
	var p1 := MB.wm(fab2, MB.M_FABRIC)
	m.rbox(t * Transform3D(Basis(Vector3.UP, 0.45) * Basis(Vector3.RIGHT, -0.38), Vector3(-hw + 0.33, 0.63, 0.02)), Vector3(0.34, 0.34, 0.13), p1, 0.6, 10, 6)
	if seats == 2:
		var p2 := MB.wm(fab2.darkened(0.25).lerp(Color(0.85, 0.8, 0.7), 0.25), MB.M_FABRIC)
		m.rbox(t * Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, -0.34), Vector3(hw - 0.36, 0.62, 0.03)), Vector3(0.3, 0.3, 0.12), p2, 0.6, 10, 6)
		if rng.randf() < 0.6:
			var bl := MB.wm(fab2.lerp(Color(0.86, 0.82, 0.72), 0.5), MB.M_FABRIC)
			_r(m, t, hw - 0.095, 0.735, 0.12, 0.3, 0.035, 0.46, bl, 0.5)
			_b(m, t, hw + 0.012, 0.56, 0.12, 0.012, 0.34, 0.44, bl, 16 | 4 | 8 | 2)


static func _bookcase(m: MB, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := _wood(BPlan.WOOD)
	var dw := _wood(BPlan.DWOOD)
	# caixa, fundo, rodape e cornija
	_b(m, t, -0.455, 0.98, -0.25, 0.045, 1.84, 0.4, wood, 61)
	_b(m, t, 0.455, 0.98, -0.25, 0.045, 1.84, 0.4, wood, 61)
	_b(m, t, 0, 0.98, -0.44, 0.9, 1.84, 0.02, _wood(BPlan.DWOOD.darkened(0.2)), 4)
	_b(m, t, 0, 0.045, -0.24, 0.95, 0.09, 0.42, dw, 61)
	_b(m, t, 0, 1.915, -0.25, 0.97, 0.035, 0.43, wood)
	_b(m, t, 0, 1.95, -0.24, 1.0, 0.035, 0.47, dw)
	_b(m, t, -0.455, 0.98, -0.043, 0.06, 1.84, 0.014, dw, 61)
	_b(m, t, 0.455, 0.98, -0.043, 0.06, 1.84, 0.014, dw, 61)
	var tops := [0.105, 0.475, 0.835, 1.195, 1.555]
	for i in tops.size():
		var sy: float = tops[i]
		_b(m, t, 0, sy - 0.015, -0.25, 0.87, 0.03, 0.39, wood, 1 | 2 | 4)
		var room: float = (float(tops[i + 1]) if i + 1 < tops.size() else 1.9) - sy - 0.05
		var x := -0.425
		while x < 0.40:
			var roll := rng.randf()
			if roll < 0.08:
				x += rng.randf_range(0.04, 0.12)
			elif roll < 0.18 and x < 0.2:
				# pilha de livros deitados
				var ln := rng.randf_range(0.19, 0.24)
				var yy := sy
				for k in rng.randi_range(2, 4):
					var th := rng.randf_range(0.03, 0.05)
					var bc: Color = BOOKS[rng.randi() % BOOKS.size()]
					_b(m, t, x + ln * 0.5 + rng.randf_range(-0.01, 0.01), yy + th * 0.5, -0.17 + rng.randf_range(-0.015, 0.015), ln, th, 0.17, bc, 61)
					_b(m, t, x + ln * 0.5, yy + th * 0.5, -0.083, ln * 0.5, th * 0.4, 0.002, GOLD.lerp(bc, 0.3), 4)
					yy += th
				x += ln + 0.02
			elif roll < 0.27 and x < 0.24:
				# enfeite: vaso, caixa, porta-retrato ou globo
				var k2 := rng.randi() % 4
				if k2 == 0:
					var vc: Color = [Color(0.3, 0.45, 0.6), Color(0.8, 0.78, 0.7), Color(0.65, 0.3, 0.22)][rng.randi() % 3]
					_cyl(m, t, x + 0.07, -0.2, sy, sy + 0.13, 0.035, 0.055, vc, 8)
					_cyl(m, t, x + 0.07, -0.2, sy + 0.13, sy + 0.2, 0.055, 0.03, vc, 8)
				elif k2 == 1:
					_b(m, t, x + 0.08, sy + 0.05, -0.2, 0.15, 0.1, 0.13, _wood(Color(0.42, 0.26, 0.15)), 61)
					_b(m, t, x + 0.08, sy + 0.105, -0.2, 0.16, 0.012, 0.14, _wood(Color(0.33, 0.2, 0.12)))
					_b(m, t, x + 0.08, sy + 0.07, -0.133, 0.03, 0.03, 0.006, BRASS, 4)
				elif k2 == 2:
					m.box_t(t * Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(x + 0.08, sy + 0.095, -0.2)), Vector3(0.15, 0.19, 0.014), Color(0.12, 0.11, 0.1))
					m.box_t(t * Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(x + 0.08, sy + 0.097, -0.192)), Vector3(0.115, 0.15, 0.004), Color(0.74, 0.70, 0.60), 4)
				else:
					_cyl(m, t, x + 0.08, -0.2, sy, sy + 0.03, 0.05, 0.03, Color(0.2, 0.16, 0.12), 8)
					m.ellipsoid(t * Vector3(x + 0.08, sy + 0.11, -0.2), Vector3(0.075, 0.075, 0.075), Color(0.24, 0.42, 0.58), 10, 6)
				x += 0.18
			else:
				var bw := rng.randf_range(0.026, 0.058)
				if x + bw > 0.43:
					break
				var bh := minf(rng.randf_range(0.2, 0.31), room)
				var bd := rng.randf_range(0.17, 0.23)
				var fz := -0.075 - rng.randf() * 0.03
				var bc2: Color = BOOKS[rng.randi() % BOOKS.size()]
				bc2 = bc2.lerp(Color(0.5, 0.45, 0.4), rng.randf() * 0.25)
				if roll > 0.93 and x < 0.3:
					# livro inclinado, apoiado nos vizinhos
					var tl := t * Transform3D(Basis(Vector3.BACK, -0.22), Vector3(x + bw * 0.5 + bh * 0.11, sy + bh * 0.49, fz - bd * 0.5))
					m.box_t(tl, Vector3(bw, bh, bd), bc2)
					x += bw + bh * 0.22 + 0.004
					continue
				_b(m, t, x + bw * 0.5, sy + bh * 0.5, fz - bd * 0.5, bw, bh, bd, bc2, 1 | 4 | 16 | 32)
				# paginas no topo e faixas na lombada
				_b(m, t, x + bw * 0.5, sy + bh + 0.0006, fz - bd * 0.5, bw * 0.72, 0.001, bd * 0.94, Color(0.9, 0.87, 0.78), 1)
				var band := GOLD if rng.randf() < 0.5 else bc2.lightened(0.45)
				if rng.randf() < 0.75:
					_b(m, t, x + bw * 0.5, sy + bh * rng.randf_range(0.68, 0.8), fz + 0.001, bw, bh * 0.1, 0.001, band, 4)
				if rng.randf() < 0.45:
					_b(m, t, x + bw * 0.5, sy + bh * 0.14, fz + 0.001, bw, 0.012, 0.001, band, 4)
					_b(m, t, x + bw * 0.5, sy + bh * 0.2, fz + 0.001, bw, 0.006, 0.001, band, 4)
				x += bw + 0.002


static func _wardrobe(m: MB, t: Transform3D, fab2: Color, rng: RandomNumberGenerator) -> void:
	var tone := rng.randf()
	var base := BPlan.DWOOD.lerp(BPlan.WOOD, tone * 0.6)
	var wood := _wood(base)
	var dw := _wood(base.darkened(0.25))
	var lw := _wood(base.lightened(0.1))
	var chrome := _metal(BRASS if tone > 0.5 else BPlan.CHROME)
	# corpo, rodape com pes e cornija em degraus
	_b(m, t, 0, 1.02, -0.18, 0.94, 1.84, 0.6, wood, 61)
	_b(m, t, 0, 0.06, -0.17, 0.9, 0.08, 0.56, dw, 61)
	for sx in [-1.0, 1.0]:
		_b(m, t, sx * 0.42, 0.05, 0.1, 0.1, 0.1, 0.06, dw, 61)
	_b(m, t, 0, 1.955, -0.17, 0.99, 0.035, 0.65, lw)
	_b(m, t, 0, 1.988, -0.17, 1.03, 0.03, 0.69, dw)
	# duas portas almofadadas
	for sx in [-1.0, 1.0]:
		_panel(m, t, sx * 0.2325, 1.21, 0.13, 0.455, 1.38, lw, wood, [0.36], 0.06)
		_b(m, t, sx * 0.045, 1.2, 0.166, 0.014, 0.2, 0.014, chrome, 61)
		_b(m, t, sx * 0.045, 1.28, 0.154, 0.014, 0.014, 0.02, chrome, 61)
		_b(m, t, sx * 0.045, 1.12, 0.154, 0.014, 0.014, 0.02, chrome, 61)
		for hy in [0.68, 1.2, 1.76]:
			_b(m, t, sx * 0.466, hy, 0.128, 0.012, 0.07, 0.022, chrome, 61)
		# gavetas
		_panel(m, t, sx * 0.2325, 0.31, 0.13, 0.455, 0.38, lw, wood, [], 0.05)
		_b(m, t, sx * 0.2325, 0.31, 0.162, 0.13, 0.016, 0.016, chrome, 61)
	_b(m, t, 0, 1.0, 0.122, 0.006, 1.78, 0.004, Color(0.06, 0.05, 0.04), 4)
	_b(m, t, 0, 0.505, 0.122, 0.92, 0.008, 0.004, Color(0.06, 0.05, 0.04), 4)
	# em cima: mala e cobertores dobrados
	if rng.randf() < 0.75:
		var lc := Color(0.40, 0.25, 0.14)
		_b(m, t, -0.17, 2.09, -0.2, 0.52, 0.17, 0.36, lc, 61)
		_b(m, t, -0.17, 2.09, -0.018, 0.5, 0.012, 0.004, lc.darkened(0.4), 4)
		_b(m, t, -0.17, 2.105, -0.012, 0.12, 0.03, 0.02, lc.darkened(0.5), 61)
		for bx in [-0.36, 0.02]:
			_b(m, t, bx, 2.07, -0.017, 0.03, 0.05, 0.006, _metal(BRASS), 4)
	if rng.randf() < 0.7:
		_r(m, t, 0.27, 2.045, -0.19, 0.3, 0.09, 0.36, MB.wm(fab2, MB.M_FABRIC), 0.45)
		_r(m, t, 0.27, 2.125, -0.19, 0.28, 0.08, 0.34, MB.wm(fab2.lerp(Color(0.85, 0.82, 0.74), 0.6), MB.M_FABRIC), 0.45)


static func _kitchen(m: MB, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := _wood(BPlan.WOOD)
	var lw := _wood(BPlan.WOOD.lightened(0.1))
	var dw := _wood(BPlan.DWOOD)
	var chrome := _metal(BPlan.CHROME)
	var top := _metal(Color(0.80, 0.78, 0.73))
	# balcao: rodape recuado, corpo, tampo com borda e frontao de azulejo
	_b(m, t, 0, 0.045, -0.2, 0.98, 0.09, 0.54, Color(0.1, 0.1, 0.11), 4 | 16 | 32)
	_b(m, t, 0, 0.47, -0.18, 0.98, 0.76, 0.62, wood, 60)
	_b(m, t, 0, 0.875, -0.17, 1.0, 0.045, 0.66, top)
	_b(m, t, 0, 0.93, -0.485, 1.0, 0.07, 0.02, top, 1 | 4)
	_b(m, t, 0, 1.26, -0.492, 1.0, 0.58, 0.012, MB.wm(Color(0.84, 0.87, 0.86), MB.M_TILE), 4)
	for sx in [-1.0, 1.0]:
		_panel(m, t, sx * 0.243, 0.765, 0.132, 0.47, 0.14, lw, wood, [], 0.03)
		_b(m, t, sx * 0.243, 0.765, 0.163, 0.14, 0.014, 0.014, chrome, 61)
		_panel(m, t, sx * 0.243, 0.395, 0.132, 0.47, 0.57, lw, wood, [], 0.055)
		_b(m, t, sx * 0.05, 0.58, 0.163, 0.014, 0.12, 0.014, chrome, 61)
	# armario suspenso com portas, cornija e sombra por baixo
	_b(m, t, 0, 1.86, -0.31, 0.98, 0.62, 0.36, wood, 62)
	_b(m, t, 0, 2.185, -0.3, 1.0, 0.03, 0.4, dw)
	for sx in [-1.0, 1.0]:
		_panel(m, t, sx * 0.243, 1.86, -0.128, 0.47, 0.58, lw, wood, [], 0.055)
		_b(m, t, sx * 0.05, 1.66, -0.097, 0.014, 0.1, 0.014, chrome, 61)
	_b(m, t, 0, 1.548, -0.31, 0.96, 0.004, 0.34, Color(0.05, 0.05, 0.05), 2)
	# utensilios sobre o tampo
	var k := rng.randi() % 3
	_cyl(m, t, -0.32, -0.32, 0.9, 1.07, 0.058, 0.058, Color(0.80, 0.30, 0.25), 9)
	_cyl(m, t, -0.32, -0.32, 1.07, 1.085, 0.062, 0.062, Color(0.75, 0.75, 0.74), 9)
	_cyl(m, t, -0.17, -0.34, 0.9, 1.03, 0.048, 0.048, Color(0.90, 0.85, 0.60), 9)
	_cyl(m, t, -0.17, -0.34, 1.03, 1.045, 0.052, 0.052, Color(0.75, 0.75, 0.74), 9)
	if k == 0:
		m.box_t(t * Transform3D(Basis(Vector3.UP, 0.2), Vector3(0.26, 0.908, -0.14)), Vector3(0.3, 0.018, 0.2), _wood(Color(0.62, 0.45, 0.28)), 61)
		m.box_t(t * Transform3D(Basis(Vector3.UP, 0.7), Vector3(0.26, 0.922, -0.14)), Vector3(0.2, 0.006, 0.025), _metal(BPlan.CHROME), 61)
	elif k == 1:
		_r(m, t, 0.27, 0.955, -0.26, 0.3, 0.12, 0.2, _wood(Color(0.58, 0.42, 0.26)), 0.5)
	else:
		_cyl(m, t, 0.28, -0.22, 0.9, 0.96, 0.09, 0.12, Color(0.86, 0.86, 0.84), 10)
		m.ellipsoid(t * Vector3(0.25, 0.975, -0.22), Vector3(0.035, 0.035, 0.035), Color(0.75, 0.2, 0.15), 6, 4)
		m.ellipsoid(t * Vector3(0.31, 0.975, -0.2), Vector3(0.035, 0.035, 0.035), Color(0.85, 0.6, 0.15), 6, 4)


static func _dresser(m: MB, t: Transform3D, fab2: Color, rng: RandomNumberGenerator) -> void:
	var wood := _wood(BPlan.WOOD)
	var lw := _wood(BPlan.WOOD.lightened(0.1))
	var dw := _wood(BPlan.DWOOD)
	var knob := _metal(BRASS)
	for sx in [-1.0, 1.0]:
		for z in [-0.42, -0.02]:
			_cyl(m, t, sx * 0.4, z, 0.0, 0.1, 0.02, 0.034, dw, 6)
	_b(m, t, 0, 0.46, -0.22, 0.92, 0.72, 0.5, wood, 62)
	_b(m, t, 0, 0.84, -0.22, 0.97, 0.04, 0.55, dw)
	for i in 3:
		var y := 0.215 + i * 0.235
		_panel(m, t, 0, y, 0.032, 0.86, 0.215, lw, wood, [], 0.035)
		for sx in [-1.0, 1.0]:
			m.ellipsoid(t * Vector3(sx * 0.22, y, 0.066), Vector3(0.02, 0.02, 0.02), knob, 6, 4)
	# porta-retrato, pano dobrado e caixinha
	m.box_t(t * Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0.25, 0.98, -0.3)), Vector3(0.22, 0.26, 0.016), Color(0.12, 0.11, 0.1))
	m.box_t(t * Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0.25, 0.982, -0.291)), Vector3(0.17, 0.2, 0.004), Color(0.72, 0.64, 0.5), 4)
	_r(m, t, -0.22, 0.895, -0.2, 0.26, 0.07, 0.2, MB.wm(fab2, MB.M_FABRIC), 0.45)
	if rng.randf() < 0.6:
		_b(m, t, -0.02, 0.89, -0.34, 0.12, 0.06, 0.09, _wood(Color(0.36, 0.2, 0.12)), 61)


static func _nightstand(m: MB, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := _wood(BPlan.WOOD)
	var lw := _wood(BPlan.WOOD.lightened(0.1))
	var dw := _wood(BPlan.DWOOD)
	for sx in [-1.0, 1.0]:
		for z in [-0.4, -0.04]:
			_cyl(m, t, sx * 0.21, z, 0.0, 0.1, 0.016, 0.028, dw, 6)
	_b(m, t, 0, 0.32, -0.22, 0.5, 0.44, 0.45, wood, 62)
	_b(m, t, 0, 0.555, -0.22, 0.55, 0.03, 0.49, dw)
	_panel(m, t, 0, 0.44, 0.012, 0.44, 0.17, lw, wood, [], 0.03)
	m.ellipsoid(t * Vector3(0, 0.44, 0.045), Vector3(0.02, 0.02, 0.02), _metal(BRASS), 6, 4)
	_b(m, t, 0, 0.22, 0.008, 0.42, 0.2, 0.004, Color(0.07, 0.05, 0.04), 4)
	_b(m, t, 0, 0.135, -0.2, 0.44, 0.02, 0.38, lw, 1)
	# abajur com cupula e livro
	_cyl(m, t, 0.08, -0.26, 0.57, 0.6, 0.055, 0.045, Color(0.14, 0.14, 0.16), 9)
	_cyl(m, t, 0.08, -0.26, 0.6, 0.8, 0.014, 0.014, _metal(BRASS), 6)
	_cyl(m, t, 0.08, -0.26, 0.78, 0.97, 0.13, 0.085, BPlan.CREAM, 10)
	var bc: Color = BOOKS[rng.randi() % BOOKS.size()]
	m.box_t(t * Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.13, 0.59, -0.14)), Vector3(0.14, 0.035, 0.2), bc, 61)
	m.box_t(t * Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.13, 0.59, -0.14)), Vector3(0.145, 0.025, 0.19), Color(0.9, 0.87, 0.78), 4 | 16)
