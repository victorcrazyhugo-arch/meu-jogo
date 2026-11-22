class_name MB
extends RefCounted
## Construtor de malhas com cor por vertice (caixas, tubos, elipsoides).
## Seguro para uso em threads: so manipula arrays.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var ix := PackedInt32Array()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var use_bones := false
var bone := 0
var use_uv := false          # grava a posicao de repouso em UV/UV2 (padroes fixos em malhas com esqueleto)
var mat_a := -1.0            # tipo de superficie gravado no alfa da cor (-1 = manter o alfa da cor)

# tipos de superficie reconhecidos pelo shader do cenario (alfa = id / 20)
const M_GRASS := 0.05
const M_ASPHALT := 0.10
const M_CONCRETE := 0.15
const M_BRICK := 0.20
const M_PLASTER := 0.25
const M_SIDING := 0.30
const M_CORR := 0.35
const M_FLOORWOOD := 0.40
const M_TILE := 0.45
const M_ROOF := 0.50
const M_DIRT := 0.55
const M_FABRIC := 0.60
const M_SOIL := 0.65
const M_STONE := 0.70
const M_WOOD := 0.75
const M_METAL := 0.90
const M_PAINT := 0.95           # parede interna pintada, com rodape


func _mc(col: Color) -> Color:
	if mat_a < 0.0:
		return col
	return Color(col.r, col.g, col.b, mat_a)


static func wm(col: Color, mat: float) -> Color:
	return Color(col.r, col.g, col.b, mat)


func _skin(count: int) -> void:
	for i in count:
		bones.append(bone); bones.append(0); bones.append(0); bones.append(0)
		weights.append(1.0); weights.append(0.0); weights.append(0.0); weights.append(0.0)


func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nor: Vector3, col: Color) -> void:
	var i := v.size()
	v.append(a); v.append(b); v.append(cc); v.append(d)
	n.append(nor); n.append(nor); n.append(nor); n.append(nor)
	c.append(_mc(col)); c.append(_mc(col)); c.append(_mc(col)); c.append(_mc(col))
	ix.append(i); ix.append(i + 1); ix.append(i + 2); ix.append(i); ix.append(i + 2); ix.append(i + 3)
	if use_bones:
		_skin(4)


## Quadrilatero com ordem corrigida automaticamente para a normal dada.
func quad_auto(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nor: Vector3, col: Color) -> void:
	if (b - a).cross(cc - a).dot(nor) > 0.0:
		quad(a, d, cc, b, nor, col)
	else:
		quad(a, b, cc, d, nor, col)


## Caixa alinhada aos eixos. faces: bits 1=+Y 2=-Y 4=+Z 8=-Z 16=+X 32=-X
func box(ct: Vector3, size: Vector3, col: Color, faces: int = 63) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var x0 := ct.x - hx; var x1 := ct.x + hx
	var y0 := ct.y - hy; var y1 := ct.y + hy
	var z0 := ct.z - hz; var z1 := ct.z + hz
	if faces & 1:
		quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col)
	if faces & 2:
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3.DOWN, col)
	if faces & 4:
		quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.BACK, col)
	if faces & 8:
		quad(Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3.FORWARD, col)
	if faces & 16:
		quad(Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3.RIGHT, col)
	if faces & 32:
		quad(Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3.LEFT, col)


## Caixa com cores por face: [+Y, -Y, +Z, -Z, +X, -X]
func box6(ct: Vector3, size: Vector3, cols: Array, faces: int = 63) -> void:
	for i in 6:
		var bit := 1 << i
		if faces & bit:
			box(ct, size, cols[i], bit)


## Caixa com transformacao arbitraria. faces: mesmos bits de box(), nos eixos locais.
func box_t(t: Transform3D, size: Vector3, col: Color, faces: int = 63) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var p := [
		t * Vector3(-hx, -hy, -hz), t * Vector3(hx, -hy, -hz), t * Vector3(hx, -hy, hz), t * Vector3(-hx, -hy, hz),
		t * Vector3(-hx, hy, -hz), t * Vector3(hx, hy, -hz), t * Vector3(hx, hy, hz), t * Vector3(-hx, hy, hz)]
	var b := t.basis
	if faces & 1:
		quad(p[4], p[5], p[6], p[7], (b * Vector3.UP).normalized(), col)
	if faces & 2:
		quad(p[3], p[2], p[1], p[0], (b * Vector3.DOWN).normalized(), col)
	if faces & 4:
		quad(p[7], p[6], p[2], p[3], (b * Vector3.BACK).normalized(), col)
	if faces & 8:
		quad(p[5], p[4], p[0], p[1], (b * Vector3.FORWARD).normalized(), col)
	if faces & 16:
		quad(p[6], p[5], p[1], p[2], (b * Vector3.RIGHT).normalized(), col)
	if faces & 32:
		quad(p[4], p[7], p[3], p[0], (b * Vector3.LEFT).normalized(), col)


## Caixa arredondada (superelipsoide) com normais suaves: almofadas, estofados, travesseiros.
## e: 0.2 = quase caixa, 1.0 = elipsoide.
func rbox(t: Transform3D, size: Vector3, col: Color, e: float = 0.4, segs: int = 12, rings: int = 6) -> void:
	var base := v.size()
	var h := size * 0.5
	var nb := t.basis
	for j in rings + 1:
		var ph := PI * 0.5 - PI * float(j) / rings
		var cp := cos(ph)
		var sp := sin(ph)
		if j == 0 or j == rings:
			cp = 0.0
		var cpe := pow(absf(cp), e)
		var spe := signf(sp) * pow(absf(sp), e)
		var cpn := pow(absf(cp), 2.0 - e)
		var spn := signf(sp) * pow(absf(sp), 2.0 - e)
		for i in segs:
			var th := TAU * float(i) / segs
			var ct := cos(th)
			var st := sin(th)
			if absf(ct) < 0.0001:
				ct = 0.0
			if absf(st) < 0.0001:
				st = 0.0
			var cte := signf(ct) * pow(absf(ct), e)
			var ste := signf(st) * pow(absf(st), e)
			var ctn := signf(ct) * pow(absf(ct), 2.0 - e)
			var stn := signf(st) * pow(absf(st), 2.0 - e)
			v.append(t * Vector3(h.x * cpe * cte, h.y * spe, h.z * cpe * ste))
			var nn := Vector3(cpn * ctn / h.x, spn / h.y, cpn * stn / h.z)
			if nn.length_squared() < 0.000001:
				nn = Vector3(0, signf(sp), 0)
			n.append((nb * nn).normalized())
			c.append(_mc(col))
	if use_bones:
		_skin((rings + 1) * segs)
	for j in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var t0 := base + j * segs + i
			var t1 := base + j * segs + i2
			var b0 := base + (j + 1) * segs + i
			var b1 := base + (j + 1) * segs + i2
			ix.append(t0); ix.append(b0); ix.append(b1)
			ix.append(t0); ix.append(b1); ix.append(t1)


static func _ring_at(rings: Array, f: float) -> Array:
	var last := rings.size() - 1
	var i := clampi(int(floor(f)), 0, last - 1)
	var w := clampf(f - i, 0.0, 1.0)
	var a: Array = rings[i]
	var b: Array = rings[i + 1]
	var p0: Array = rings[maxi(i - 1, 0)]
	var p1: Array = rings[mini(i + 2, last)]
	var o := [lerpf(a[0], b[0], w)]
	for k in [1, 2, 3, 4]:
		o.append(cubic_interpolate(float(a[k]), float(b[k]), float(p0[k]), float(p1[k]), w))
	o.append(lerpf(a[5], b[5], w))
	return o


## Perfil organico: varias secoes elipticas ao longo de Y com normais suaves (tronco e membros).
## rings, de baixo para cima: [y, rx, rz, ox, oz, w2]; ox/oz deslocam a secao e w2 e o peso do
## osso bone2 naquela altura (articulacoes que dobram sem abrir frestas).
func prof(cx: float, cz: float, rings: Array, col: Color, sides: int = 12, cap_bottom: bool = false, cap_top: bool = false,
		bands: int = 1, col2: Color = Color.WHITE, checker: bool = false, bone2: int = -1) -> void:
	var last := rings.size() - 1
	var smp: Array = []
	var nseg := last * 2
	if bands > 1:
		nseg = bands * 2
		var ya: float = rings[0][0]
		var yb: float = rings[last][0]
		for i in nseg + 1:
			var y := lerpf(ya, yb, float(i) / nseg)
			var f := float(last)
			for k in last:
				if y <= float(rings[k + 1][0]) + 0.00001:
					f = k + clampf((y - float(rings[k][0])) / maxf(float(rings[k + 1][0]) - float(rings[k][0]), 0.0001), 0.0, 1.0)
					break
			var r := _ring_at(rings, f)
			r[0] = y
			smp.append(r)
	else:
		for i in nseg + 1:
			smp.append(_ring_at(rings, float(i) * 0.5))
	var slope := PackedFloat32Array()
	for i in nseg + 1:
		var a: Array = smp[maxi(i - 1, 0)]
		var b: Array = smp[mini(i + 1, nseg)]
		slope.append(((float(b[1]) + float(b[2])) - (float(a[1]) + float(a[2]))) * 0.5 / maxf(float(b[0]) - float(a[0]), 0.0001))
	for sg in nseg:
		var band := (sg * bands) / nseg if bands > 1 else 0
		var base := v.size()
		var reps := 2 if checker else 1      # no xadrez cada face tem vertices proprios
		for e in 2:
			var si := sg + 1 - e          # primeiro o anel de cima
			var r: Array = smp[si]
			for i in sides:
				for q in reps:
					var th := TAU * float(i + q) / sides
					var ct := cos(th)
					var st := sin(th)
					v.append(Vector3(cx + float(r[3]) + float(r[1]) * ct, r[0], cz + float(r[4]) + float(r[2]) * st))
					var nx := Vector2(ct / maxf(float(r[1]), 0.001), st / maxf(float(r[2]), 0.001)).normalized()
					n.append(Vector3(nx.x, -slope[si], nx.y).normalized())
					var cc := col if band % 2 == 0 else col2
					if checker and (band + i) % 2 == 1:
						cc = col2 if band % 2 == 0 else col
					c.append(_mc(cc))
					if use_bones:
						var w: float = float(r[5]) if bone2 >= 0 else 0.0
						bones.append(bone); bones.append(bone2 if w > 0.0 else 0); bones.append(0); bones.append(0)
						weights.append(1.0 - w); weights.append(w); weights.append(0.0); weights.append(0.0)
		var per := sides * reps
		for i in sides:
			var t0 := base + i * reps
			var t1 := base + (i * reps + 1 if checker else ((i + 1) % sides))
			var b0 := t0 + per
			var b1 := t1 + per
			ix.append(t0); ix.append(b0); ix.append(b1)
			ix.append(t0); ix.append(b1); ix.append(t1)
	if cap_bottom:
		var r0: Array = smp[0]
		_cap(cx + float(r0[3]), cz + float(r0[4]), r0[0], Vector2(r0[1], r0[2]), col, sides, false)
	if cap_top:
		var r1: Array = smp[nseg]
		_cap(cx + float(r1[3]), cz + float(r1[4]), r1[0], Vector2(r1[1], r1[2]), col if ((bands - 1) % 2 == 0 or bands <= 1) else col2, sides, true)


## Tubo eliptico afunilado ao longo de Y, de y0 (base) a y1 (topo), com faixas opcionais de cor.
func tube(cx: float, cz: float, y0: float, y1: float, r0: Vector2, r1: Vector2, col: Color, sides: int = 8,
		cap_bottom: bool = true, cap_top: bool = true, bands: int = 1, col2: Color = Color.WHITE, checker: bool = false) -> void:
	if checker:
		_tube_checker(cx, cz, y0, y1, r0, r1, col, col2, sides, bands)
		return
	for bi in bands:
		var ta := float(bi) / bands
		var tb := float(bi + 1) / bands
		var ya := lerpf(y0, y1, ta)
		var yb := lerpf(y0, y1, tb)
		var ra := r0.lerp(r1, ta)
		var rb := r0.lerp(r1, tb)
		var bc := col if (bi % 2 == 0) else col2
		var base := v.size()
		for i in sides:
			var th := TAU * float(i) / sides
			var cs := cos(th)
			var sn := sin(th)
			v.append(Vector3(cx + ra.x * cs, ya, cz + ra.y * sn))
			n.append(Vector3(cs * ra.y, 0.0, sn * ra.x).normalized())
			c.append(_mc(bc))
		for i in sides:
			var th := TAU * float(i) / sides
			var cs := cos(th)
			var sn := sin(th)
			v.append(Vector3(cx + rb.x * cs, yb, cz + rb.y * sn))
			n.append(Vector3(cs * rb.y, 0.0, sn * rb.x).normalized())
			c.append(_mc(bc))
		if use_bones:
			_skin(sides * 2)
		for i in sides:
			var j := (i + 1) % sides
			var b0 := base + i
			var b1 := base + j
			var t0 := base + sides + i
			var t1 := base + sides + j
			ix.append(t0); ix.append(b0); ix.append(b1)
			ix.append(t0); ix.append(b1); ix.append(t1)
	if cap_top:
		_cap(cx, cz, y1, r1, col if ((bands - 1) % 2 == 0) else col2, sides, true)
	if cap_bottom:
		_cap(cx, cz, y0, r0, col, sides, false)


func _tube_checker(cx: float, cz: float, y0: float, y1: float, r0: Vector2, r1: Vector2, col: Color, col2: Color, sides: int, bands: int) -> void:
	for bi in bands:
		var ta := float(bi) / bands
		var tb := float(bi + 1) / bands
		var ya := lerpf(y0, y1, ta)
		var yb := lerpf(y0, y1, tb)
		var ra := r0.lerp(r1, ta)
		var rb := r0.lerp(r1, tb)
		for i in sides:
			var th0 := TAU * float(i) / sides
			var th1 := TAU * float(i + 1) / sides
			var bc := col if ((bi + i) % 2 == 0) else col2
			var base := v.size()
			var n0 := Vector3(cos(th0) * ra.y, 0.0, sin(th0) * ra.x).normalized()
			var n1 := Vector3(cos(th1) * ra.y, 0.0, sin(th1) * ra.x).normalized()
			v.append(Vector3(cx + ra.x * cos(th0), ya, cz + ra.y * sin(th0))); n.append(n0); c.append(_mc(bc))
			v.append(Vector3(cx + ra.x * cos(th1), ya, cz + ra.y * sin(th1))); n.append(n1); c.append(_mc(bc))
			v.append(Vector3(cx + rb.x * cos(th0), yb, cz + rb.y * sin(th0))); n.append(n0); c.append(_mc(bc))
			v.append(Vector3(cx + rb.x * cos(th1), yb, cz + rb.y * sin(th1))); n.append(n1); c.append(_mc(bc))
			if use_bones:
				_skin(4)
			ix.append(base + 2); ix.append(base); ix.append(base + 1)
			ix.append(base + 2); ix.append(base + 1); ix.append(base + 3)


func _cap(cx: float, cz: float, y: float, r: Vector2, col: Color, sides: int, top: bool) -> void:
	var base := v.size()
	var nor := Vector3.UP if top else Vector3.DOWN
	v.append(Vector3(cx, y, cz)); n.append(nor); c.append(_mc(col))
	for i in sides:
		var th := TAU * float(i) / sides
		v.append(Vector3(cx + r.x * cos(th), y, cz + r.y * sin(th)))
		n.append(nor); c.append(_mc(col))
	if use_bones:
		_skin(sides + 1)
	for i in sides:
		var j := (i + 1) % sides
		if top:
			ix.append(base); ix.append(base + 1 + i); ix.append(base + 1 + j)
		else:
			ix.append(base); ix.append(base + 1 + j); ix.append(base + 1 + i)


## Elipsoide. phi0..phi1 limitam a faixa vertical (0 = topo, PI = base).
func ellipsoid(ct: Vector3, r: Vector3, col: Color, segs: int = 8, rings: int = 6, phi0: float = 0.0, phi1: float = PI) -> void:
	var base := v.size()
	for j in rings + 1:
		var ph := lerpf(phi0, phi1, float(j) / rings)
		var sp := sin(ph)
		var cp := cos(ph)
		for i in segs:
			var th := TAU * float(i) / segs
			var d := Vector3(sp * cos(th), cp, sp * sin(th))
			v.append(ct + Vector3(d.x * r.x, d.y * r.y, d.z * r.z))
			n.append(Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized())
			c.append(_mc(col))
	if use_bones:
		_skin((rings + 1) * segs)
	for j in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var t0 := base + j * segs + i
			var t1 := base + j * segs + i2
			var b0 := base + (j + 1) * segs + i
			var b1 := base + (j + 1) * segs + i2
			ix.append(t0); ix.append(b0); ix.append(b1)
			ix.append(t0); ix.append(b1); ix.append(t1)


## Prisma triangular (telhado de duas aguas) sobre o retangulo x0..x1, z0..z1; cumeeira ao longo de X.
func gable(x0: float, x1: float, z0: float, z1: float, y: float, h: float, col: Color, col_end: Color, along_z: bool = false) -> void:
	if along_z:
		var xm := (x0 + x1) * 0.5
		var a2 := Vector3(x0, y, z0); var b2 := Vector3(x0, y, z1)
		var c2 := Vector3(x1, y, z1); var d2 := Vector3(x1, y, z0)
		var e2 := Vector3(xm, y + h, z0); var f2 := Vector3(xm, y + h, z1)
		quad_auto(a2, b2, f2, e2, Vector3(-h, xm - x0, 0).normalized(), col)
		quad_auto(d2, c2, f2, e2, Vector3(h, x1 - xm, 0).normalized(), col)
		tri_auto(a2, d2, e2, Vector3.FORWARD, col_end)
		tri_auto(b2, c2, f2, Vector3.BACK, col_end)
		return
	var zm := (z0 + z1) * 0.5
	var a := Vector3(x0, y, z0); var b := Vector3(x1, y, z0)
	var cc := Vector3(x1, y, z1); var d := Vector3(x0, y, z1)
	var e := Vector3(x0, y + h, zm); var f := Vector3(x1, y + h, zm)
	var n1 := Vector3(0, zm - z0, -h).normalized()
	var n2 := Vector3(0, z1 - zm, h).normalized()
	quad_auto(a, b, f, e, n1, col)
	quad_auto(d, cc, f, e, n2, col)
	tri_auto(a, d, e, Vector3.LEFT, col_end)
	tri_auto(b, cc, f, Vector3.RIGHT, col_end)


func tri_auto(a: Vector3, b: Vector3, cc: Vector3, nor: Vector3, col: Color) -> void:
	var i := v.size()
	v.append(a); v.append(b); v.append(cc)
	n.append(nor); n.append(nor); n.append(nor)
	c.append(_mc(col)); c.append(_mc(col)); c.append(_mc(col))
	if (b - a).cross(cc - a).dot(nor) > 0.0:
		ix.append(i); ix.append(i + 2); ix.append(i + 1)
	else:
		ix.append(i); ix.append(i + 1); ix.append(i + 2)
	if use_bones:
		_skin(3)


func is_empty() -> bool:
	return v.is_empty()


func arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = ix
	if use_bones:
		a[Mesh.ARRAY_BONES] = bones
		a[Mesh.ARRAY_WEIGHTS] = weights
	if use_uv:
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		uv.resize(v.size())
		uv2.resize(v.size())
		for i in v.size():
			uv[i] = Vector2(v[i].x, v[i].y)
			uv2[i] = Vector2(v[i].z, 0.0)
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
	return a


func add_to(mesh: ArrayMesh, mat: Material) -> void:
	if v.is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func to_mesh(mat: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	add_to(m, mat)
	return m
