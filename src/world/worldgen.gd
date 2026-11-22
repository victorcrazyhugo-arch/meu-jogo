class_name WorldGen
extends RefCounted
## Leiaute fixo do mapa (dados puros, seguro para threads): exatamente duas cidades,
## rodovia, estradas de terra, rio, fazendas de producao vegetal, florestas e cabanas.
## O mapa nao contem animais de nenhuma especie.

const CH := 40
const X0 := -1600.0
const X1 := 1600.0
const Z0 := -1000.0
const Z1 := 1000.0
const Z_MEADOW := 0
const Z_FOREST := 1
const Z_FARM := 2
const Z_CITY := 3
const Z_RIVER := 4
const SA := Rect2(-1180, -166, 468, 332)      # Santa Aurora
const PB := Rect2(560, -249, 702, 434)        # Porto Bruma
const HWY_Z := -32.0
const RIVER_HALF := 13.0
const CITY_NAMES := ["Zona rural", "Santa Aurora", "Porto Bruma"]

## tipo: n nome, lay leiaute, mat material, roof telhado, zp perfil de zumbi, zd densidade de zumbis, sign cor da fachada
const TYPES := {
	"casa": {"n": "Casa", "lay": "bsp", "mat": "reboco", "roof": "gable", "zp": "civil", "zd": 1.0},
	"apto": {"n": "Prédio de apartamentos", "lay": "corr", "mat": "reboco", "roof": "flat", "zp": "civil", "zd": 1.4},
	"mercado": {"n": "Mercado", "lay": "shop", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 1.5, "sign": Color(0.75, 0.2, 0.15)},
	"supermercado": {"n": "Supermercado", "lay": "shop", "mat": "concreto", "roof": "flat", "zp": "civil", "zd": 1.6, "sign": Color(0.15, 0.4, 0.7)},
	"padaria": {"n": "Padaria", "lay": "shop", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 1.2, "sign": Color(0.8, 0.6, 0.2)},
	"loja_roupas": {"n": "Loja de roupas", "lay": "shop", "mat": "reboco", "roof": "flat", "zp": "civil", "zd": 1.2, "sign": Color(0.7, 0.3, 0.55)},
	"loja_ferramentas": {"n": "Loja de ferramentas", "lay": "shop", "mat": "tijolo", "roof": "flat", "zp": "obra", "zd": 1.2, "sign": Color(0.85, 0.5, 0.1)},
	"loja_armas": {"n": "Loja de armas", "lay": "shop", "mat": "concreto", "roof": "flat", "zp": "civil", "zd": 1.0, "sign": Color(0.25, 0.3, 0.2)},
	"farmacia": {"n": "Farmácia", "lay": "shop", "mat": "reboco", "roof": "flat", "zp": "saude", "zd": 1.2, "sign": Color(0.15, 0.6, 0.35)},
	"livraria": {"n": "Livraria", "lay": "shop", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 1.0, "sign": Color(0.4, 0.25, 0.5)},
	"bar": {"n": "Bar", "lay": "shop", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 1.5, "sign": Color(0.5, 0.15, 0.15)},
	"restaurante": {"n": "Restaurante", "lay": "shop", "mat": "reboco", "roof": "flat", "zp": "civil", "zd": 1.5, "sign": Color(0.65, 0.35, 0.15)},
	"posto": {"n": "Posto de gasolina", "lay": "shop", "mat": "concreto", "roof": "flat", "zp": "civil", "zd": 0.8, "sign": Color(0.8, 0.15, 0.1)},
	"escola": {"n": "Escola", "lay": "corr", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 1.2},
	"delegacia": {"n": "Delegacia", "lay": "corr", "mat": "concreto", "roof": "flat", "zp": "policia", "zd": 1.3},
	"bombeiros": {"n": "Corpo de bombeiros", "lay": "hall", "mat": "tijolo", "roof": "flat", "zp": "bombeiro", "zd": 1.0},
	"hospital": {"n": "Hospital", "lay": "corr", "mat": "concreto", "roof": "flat", "zp": "saude", "zd": 1.8},
	"centro_saude": {"n": "Centro de saúde", "lay": "corr", "mat": "reboco", "roof": "flat", "zp": "saude", "zd": 1.4},
	"biblioteca": {"n": "Biblioteca", "lay": "hall", "mat": "tijolo", "roof": "flat", "zp": "civil", "zd": 0.9},
	"hotel": {"n": "Hotel", "lay": "corr", "mat": "reboco", "roof": "flat", "zp": "civil", "zd": 1.3},
	"escritorio": {"n": "Edifício comercial", "lay": "corr", "mat": "concreto", "roof": "flat", "zp": "escritorio", "zd": 1.4},
	"fabrica": {"n": "Fábrica", "lay": "hall", "mat": "metal", "roof": "flat", "zp": "obra", "zd": 1.0},
	"deposito": {"n": "Depósito", "lay": "hall", "mat": "metal", "roof": "flat", "zp": "obra", "zd": 0.7},
	"oficina": {"n": "Oficina mecânica", "lay": "hall", "mat": "tijolo", "roof": "flat", "zp": "obra", "zd": 0.9},
	"transportadora": {"n": "Transportadora", "lay": "hall", "mat": "metal", "roof": "flat", "zp": "obra", "zd": 0.9},
	"cabana": {"n": "Cabana", "lay": "bsp", "mat": "madeira", "roof": "gable", "zp": "civil", "zd": 0.5},
	"casa_fazenda": {"n": "Casa de fazenda", "lay": "bsp", "mat": "madeira", "roof": "gable", "zp": "fazenda", "zd": 0.8},
	"celeiro": {"n": "Celeiro", "lay": "hall", "mat": "madeira", "roof": "gable", "zp": "fazenda", "zd": 0.5},
	"galpao": {"n": "Galpão", "lay": "hall", "mat": "metal", "roof": "gable", "zp": "fazenda", "zd": 0.4},
	"posto_florestal": {"n": "Posto florestal", "lay": "bsp", "mat": "madeira", "roof": "gable", "zp": "civil", "zd": 0.4},
	"casa_abandonada": {"n": "Casa abandonada", "lay": "bsp", "mat": "madeira", "roof": "gable", "zp": "civil", "zd": 0.9},
	"praca": {"n": "Praça", "lay": "none", "mat": "", "roof": "", "zp": "civil", "zd": 0.6},
}

const PLAN_SA := ["R R C R R R", "R C M E R R", "R P D F C R", "R C B R A R", "R R R R R R"]
const PLAN_PB := ["I I W W T O R R", "I W G C C A R R", "C C H K K A A R", "C S K P L A R R", "R C X Y C A R R", "R R R C R R R R"]
const COM_SA := ["mercado", "padaria", "loja_roupas", "livraria", "loja_ferramentas", "bar", "restaurante", "mercado", "loja_roupas", "padaria"]
const COM_PB := ["loja_roupas", "mercado", "loja_ferramentas", "loja_armas", "restaurante", "padaria", "bar", "farmacia", "livraria", "loja_roupas", "mercado", "restaurante", "bar", "loja_ferramentas"]
const CAR_TYPES := ["sedan", "sedan", "hatch", "hatch", "picape", "van", "utilitario"]

var noise: FastNoiseLite
var roads: Array = []        # {r: Rect2, kind 0 rua / 1 rodovia / 2 terra, horiz, bridge}
var lots: Array = []
var fields: Array = []       # {r: Rect2, crop}
var pois: Array = []         # {n, p: Vector2, k}
var cars: Array = []         # {id, p: Vector2, rot, type}
var camps: Array = []        # {p: Vector2}
var clearings: Array = []    # Vector3(x, z, raio)
var chunk_lots := {}
var chunk_lot_refs := {}
var chunk_roads := {}
var chunk_fields := {}
var chunk_clear := {}
var chunk_cars := {}
var chunk_camps := {}
var _com_i := [0, 0, 0]
var _r := RandomNumberGenerator.new()


func _init() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 4217
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0045
	noise.fractal_octaves = 3
	_r.seed = 90210
	_city(1, int(SA.position.x), int(SA.position.y), PLAN_SA, 64, 52, 12)
	_city(2, int(PB.position.x), int(PB.position.y), PLAN_PB, 72, 56, 14)
	_roads_rural()
	_rural()
	_index()


# ---------------------------------------------------------------- rio
static func river_x(z: float) -> float:
	return -70.0 + 55.0 * sin(z / 160.0) + 25.0 * sin(z / 61.0 + 1.3)


func river_dist(x: float, z: float) -> float:
	return absf(x - river_x(z)) - RIVER_HALF


# ---------------------------------------------------------------- zonas
func zone_at(x: float, z: float) -> int:
	if absf(x - river_x(z)) < RIVER_HALF:
		return Z_RIVER
	if SA.grow(14.0).has_point(Vector2(x, z)) or PB.grow(14.0).has_point(Vector2(x, z)):
		return Z_CITY
	if z > -215.0 and z < 150.0 and ((x > -700.0 and x < -110.0) or (x > -20.0 and x < 548.0)):
		return Z_FARM
	var n := noise.get_noise_2d(x, z)
	var dsa := _rect_dist(SA, x, z)
	var dpb := _rect_dist(PB, x, z)
	var dc := minf(dsa, dpb)
	if dc < 60.0:
		return Z_MEADOW
	if n > -0.28 + clampf((140.0 - dc) / 400.0, 0.0, 0.3):
		return Z_FOREST
	return Z_MEADOW


func forest_density(x: float, z: float) -> float:
	var zn := zone_at(x, z)
	if zn == Z_FOREST:
		return clampf(0.55 + noise.get_noise_2d(x * 2.3 + 500.0, z * 2.3) * 0.9, 0.18, 1.0)
	if zn == Z_MEADOW:
		return 0.05
	if zn == Z_FARM:
		return 0.012
	return 0.0


static func _rect_dist(r: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dz := maxf(maxf(r.position.y - z, 0.0), z - r.end.y)
	return sqrt(dx * dx + dz * dz)


func city_at(x: float, z: float) -> int:
	if SA.grow(30.0).has_point(Vector2(x, z)):
		return 1
	if PB.grow(30.0).has_point(Vector2(x, z)):
		return 2
	return 0


# ---------------------------------------------------------------- cidades
func _add_lot(type: String, lot: Rect2i, b: Rect2i, face: int, floors: int, city: int, nm: String = "") -> Dictionary:
	var l := {"id": lots.size(), "type": type, "lot": lot, "b": b, "face": face, "floors": floors, "city": city,
		"name": nm if nm != "" else String(TYPES[type]["n"])}
	lots.append(l)
	return l


func _city(city: int, x0: int, z0: int, plan: Array, bw: int, bd: int, rw: int) -> void:
	var rows := plan.size()
	var cols: int = String(plan[0]).split(" ").size()
	var tw := cols * (bw + rw) + rw
	var td := rows * (bd + rw) + rw
	for i in cols + 1:
		roads.append({"r": Rect2(x0 + i * (bw + rw), z0, rw, td), "kind": 0, "horiz": false, "bridge": false})
	for j in rows + 1:
		roads.append({"r": Rect2(x0, z0 + j * (bd + rw), tw, rw), "kind": 0, "horiz": true, "bridge": false})
	for j in rows:
		var codes := String(plan[j]).split(" ")
		for i in cols:
			var bx := x0 + rw + i * (bw + rw)
			var bz := z0 + rw + j * (bd + rw)
			_block(city, codes[i], bx, bz, bw, bd)
	pois.append({"n": CITY_NAMES[city], "p": Vector2(x0 + tw * 0.5, z0 + td * 0.5), "k": "cidade"})
	# carros estacionados junto ao meio-fio
	for j in rows + 1:
		for i in cols:
			if _r.randf() < 0.5:
				var px := x0 + rw + i * (bw + rw) + _r.randi_range(8, bw - 8)
				var pz := z0 + j * (bd + rw) + (3.2 if _r.randf() < 0.5 else rw - 3.2)
				_add_car(Vector2(px, pz), PI * 0.5 if _r.randf() < 0.5 else -PI * 0.5, "")


func _add_car(p: Vector2, rot: float, type: String) -> void:
	var t := type
	if t == "":
		t = CAR_TYPES[_r.randi() % CAR_TYPES.size()]
	cars.append({"id": cars.size(), "p": p, "rot": rot, "type": t})


func _next_com(city: int) -> String:
	var list: Array = COM_SA if city == 1 else COM_PB
	var t: String = list[_com_i[city] % list.size()]
	_com_i[city] += 1
	return t


func _block(city: int, code: String, bx: int, bz: int, bw: int, bd: int) -> void:
	var hd := bd / 2
	var whole := Rect2i(bx, bz, bw, bd)
	match code:
		"R":
			var n := bw / 16
			var lw := bw / n
			for row in 2:
				for i in n:
					var lot := Rect2i(bx + i * lw, bz + row * hd, lw, hd)
					var w := _r.randi_range(9, mini(13, lw - 4))
					var d := _r.randi_range(8, 11)
					var floors := 2 if (_r.randf() < 0.2 and d >= 10) else 1
					var px := lot.position.x + (lw - w) / 2
					var sb := _r.randi_range(4, 6)
					var pz := (lot.position.y + sb) if row == 0 else (lot.end.y - sb - d)
					_add_lot("casa", lot, Rect2i(px, pz, w, d), 2 if row == 0 else 0, floors, city)
					if _r.randf() < 0.28:
						var cz := float(lot.position.y + 2) if row == 0 else float(lot.end.y - 2)
						_add_car(Vector2(lot.position.x + 2.2, cz + (2.0 if row == 0 else -2.0)), 0.0 if row == 0 else PI, "")
		"C", "B":
			var n2 := 4 if bw < 70 else 4
			var lw2 := bw / n2
			for row in 2:
				for i in n2:
					var lot2 := Rect2i(bx + i * lw2, bz + row * hd, lw2, hd)
					var w2 := lw2 - 2
					var d2 := hd - 6
					var pz2 := (lot2.position.y + 2) if row == 0 else (lot2.end.y - 2 - d2)
					var t := _next_com(city)
					if code == "B":
						t = ["bar", "restaurante", "bar", "padaria"][(i + row) % 4]
					_add_lot(t, lot2, Rect2i(lot2.position.x + 1, pz2, w2, d2), 2 if row == 0 else 0, 1, city)
		"A":
			var fl := 2 if city == 1 else 3
			for row in 2:
				for i in 2:
					var lw3 := bw / 2
					var lot3 := Rect2i(bx + i * lw3, bz + row * hd, lw3, hd)
					var w3 := lw3 - 6
					var d3 := hd - 7
					var pz3 := (lot3.position.y + 3) if row == 0 else (lot3.end.y - 3 - d3)
					_add_lot("apto", lot3, Rect2i(lot3.position.x + 3, pz3, w3, d3), 2 if row == 0 else 0, fl, city)
		"M", "S":
			_add_lot("supermercado", whole, Rect2i(bx + 6, bz + 3, bw - 12, bd - 24), 0, 1, city, "Supermercado " + ("Aurora" if city == 1 else "Bruma"))
			_parking(bx + 8, bz + bd - 17, bw - 16, 12, 6)
		"E":
			_add_lot("escola", whole, Rect2i(bx + 5, bz + 4, bw - 10, 26), 0, 2, city, "Escola Municipal")
		"D", "Y":
			var half := bw / 2
			_add_lot("delegacia", Rect2i(bx, bz, half, bd), Rect2i(bx + 3, bz + 4, half - 6, 22), 0, 1, city)
			_add_lot("bombeiros", Rect2i(bx + half, bz, half, bd), Rect2i(bx + half + 3, bz + 4, half - 6, 22), 0, 1, city)
			_add_car(Vector2(bx + 8, bz + bd - 8), PI * 0.5, "policia")
			_add_car(Vector2(bx + 16, bz + bd - 8), PI * 0.5, "policia")
		"F":
			_add_lot("farmacia", Rect2i(bx, bz, 20, bd), Rect2i(bx + 2, bz + 4, 16, 18), 0, 1, city)
			_add_lot("centro_saude", Rect2i(bx + 20, bz, bw - 20, bd), Rect2i(bx + 24, bz + 4, bw - 28, 24), 0, 1, city)
			_add_car(Vector2(bx + 30, bz + bd - 8), PI * 0.5, "ambulancia")
		"P":
			_add_lot("praca", whole, Rect2i(bx, bz, 0, 0), 0, 0, city, "Praça " + ("da Matriz" if city == 1 else "do Porto"))
		"H":
			_add_lot("hospital", whole, Rect2i(bx + 6, bz + 3, bw - 12, bd - 20), 0, 3, city, "Hospital de Porto Bruma")
			_parking(bx + 8, bz + bd - 14, bw - 16, 10, 5)
			_add_car(Vector2(bx + 12, bz + bd - 9), PI * 0.5, "ambulancia")
		"K":
			for row in 2:
				var pzk := (bz + 3) if row == 0 else (bz + hd + 5)
				_add_lot("escritorio", Rect2i(bx, bz + row * hd, bw, hd), Rect2i(bx + 10, pzk, bw - 20, hd - 8), 2 if row == 0 else 0, 3, city)
		"L":
			_add_lot("biblioteca", Rect2i(bx, bz, bw, hd), Rect2i(bx + 12, bz + 3, bw - 24, hd - 7), 2, 1, city, "Biblioteca Pública")
			_add_lot("livraria", Rect2i(bx, bz + hd, bw / 2, hd), Rect2i(bx + 4, bz + hd + 5, bw / 2 - 8, hd - 8), 0, 1, city)
			_add_lot("loja_roupas", Rect2i(bx + bw / 2, bz + hd, bw / 2, hd), Rect2i(bx + bw / 2 + 4, bz + hd + 5, bw / 2 - 8, hd - 8), 0, 1, city)
		"X":
			_add_lot("hotel", whole, Rect2i(bx + 8, bz + 4, bw - 16, 24), 0, 3, city, "Hotel Bruma")
			_parking(bx + 10, bz + bd - 16, bw - 20, 10, 4)
		"I":
			_add_lot("fabrica", whole, Rect2i(bx + 5, bz + 5, bw - 10, bd - 14), 0, 1, city)
		"W":
			for row in 2:
				var pzw := (bz + 3) if row == 0 else (bz + hd + 3)
				_add_lot("deposito", Rect2i(bx, bz + row * hd, bw, hd), Rect2i(bx + 6, pzw, bw - 12, hd - 6), 2 if row == 0 else 0, 1, city)
		"T":
			_add_lot("transportadora", whole, Rect2i(bx + 6, bz + 4, 44, 24), 0, 1, city)
			for k in 4:
				_add_car(Vector2(bx + 12 + k * 12, bz + bd - 10), 0.0, "van" if k % 2 == 0 else "utilitario")
		"O":
			for row in 2:
				for i in 2:
					var lw4 := bw / 2
					var pzo := (bz + 3) if row == 0 else (bz + hd + 5)
					_add_lot("oficina", Rect2i(bx + i * lw4, bz + row * hd, lw4, hd), Rect2i(bx + i * lw4 + 4, pzo, lw4 - 8, hd - 8), 2 if row == 0 else 0, 1, city)
					_add_car(Vector2(bx + i * lw4 + lw4 * 0.5, (bz + hd - 3) if row == 0 else (bz + hd + 3)), PI * 0.5, "")
		"G":
			_add_lot("posto", Rect2i(bx, bz, bw, hd), Rect2i(bx + 6, bz + 3, 16, 10), 0, 1, city)
			_add_lot("loja_ferramentas", Rect2i(bx, bz + hd, bw, hd), Rect2i(bx + 8, bz + hd + 5, bw - 16, hd - 8), 0, 1, city, "Casa das Ferramentas")
		_:
			pass


func _parking(x: int, z: int, w: int, _d: int, n: int) -> void:
	for i in n:
		if _r.randf() < 0.7:
			_add_car(Vector2(x + 3 + i * (float(w - 6) / maxi(1, n - 1)), z + 4), 0.0 if _r.randf() < 0.5 else PI, "")


# ---------------------------------------------------------------- estradas e zona rural
func _roads_rural() -> void:
	var hx0 := SA.end.x
	var hx1 := PB.position.x
	roads.append({"r": Rect2(hx0, HWY_Z - 5.0, hx1 - hx0, 10.0), "kind": 1, "horiz": true, "bridge": true})
	pois.append({"n": "Rodovia da Bruma", "p": Vector2(120, HWY_Z - 24), "k": "estrada"})
	# estradas de terra pela floresta
	roads.append({"r": Rect2(-946, -520, 1870, 5), "kind": 2, "horiz": true, "bridge": true})
	roads.append({"r": Rect2(-946, -520, 5, 354), "kind": 2, "horiz": false, "bridge": false})
	roads.append({"r": Rect2(919, -520, 5, 271), "kind": 2, "horiz": false, "bridge": false})
	roads.append({"r": Rect2(-880, 470, 1790, 5), "kind": 2, "horiz": true, "bridge": true})
	roads.append({"r": Rect2(-880, 166, 5, 309), "kind": 2, "horiz": false, "bridge": false})
	roads.append({"r": Rect2(905, 185, 5, 290), "kind": 2, "horiz": false, "bridge": false})
	roads.append({"r": Rect2(-420, -820, 5, 300), "kind": 2, "horiz": false, "bridge": false})
	roads.append({"r": Rect2(300, 475, 5, 330), "kind": 2, "horiz": false, "bridge": false})
	pois.append({"n": "Estrada do Mirante", "p": Vector2(0, -540), "k": "estrada"})
	pois.append({"n": "Estrada da Mata", "p": Vector2(0, 492), "k": "estrada"})
	pois.append({"n": "Rio Cinzento", "p": Vector2(river_x(250.0) + 40.0, 250.0), "k": "rio"})
	pois.append({"n": "Floresta do Norte", "p": Vector2(250, -720), "k": "floresta"})
	pois.append({"n": "Mata do Sul", "p": Vector2(-300, 700), "k": "floresta"})


func _rural_lot(type: String, cx: int, cz: int, w: int, d: int, face: int, nm: String = "", clear_r: float = 0.0) -> void:
	var b := Rect2i(cx - w / 2, cz - d / 2, w, d)
	_add_lot(type, b.grow(4), b, face, 1, 0, nm)
	clearings.append(Vector3(cx, cz, clear_r if clear_r > 0.0 else maxf(w, d) * 0.5 + 8.0))


func _farm(cx: int, cz: int, south: bool, nm: String) -> void:
	var face := 2 if south else 0
	var s := 1 if south else -1
	_rural_lot("casa_fazenda", cx, cz, 12, 10, face, nm)
	_rural_lot("celeiro", cx + 30, cz - s * 14, 14, 18, 3, "")
	_rural_lot("galpao", cx - 24, cz - s * 12, 10, 12, 1, "")
	var crops := ["batata", "milho", "tomate", "repolho", "cenoura", "abobora", "alface", "feijao_verde"]
	for i in 3:
		for j in 2:
			var fx := cx - 62 + i * 46
			var fz := cz + s * (26 + j * 40)
			var r := Rect2(fx, fz - 17, 40, 34)
			fields.append({"r": r, "crop": crops[_r.randi() % crops.size()]})
	roads.append({"r": Rect2(cx + 9, minf(HWY_Z, cz), 4, absf(cz - HWY_Z)), "kind": 2, "horiz": false, "bridge": false})
	pois.append({"n": nm, "p": Vector2(cx, cz), "k": "fazenda"})
	_add_car(Vector2(cx + 11, cz + s * -3), 0.0, "picape")


func _rural() -> void:
	# postos na rodovia
	_rural_lot("posto", -660, int(HWY_Z) + 22, 16, 10, 2, "Posto Saída Leste", 22.0)
	_rural_lot("posto", 250, int(HWY_Z) - 22, 16, 10, 0, "Posto Meio do Caminho", 22.0)
	_add_car(Vector2(262, HWY_Z - 9), PI * 0.5, "")
	# fazendas de producao vegetal, alternando os lados da rodovia
	_farm(-560, 60, true, "Fazenda Boa Colheita")
	_farm(-330, -110, false, "Sítio das Hortas")
	_farm(170, 62, true, "Fazenda Três Irmãos")
	_farm(400, -112, false, "Sítio Recanto Verde")
	# cabanas, postos florestais e casas isoladas
	var cab := [[-700, -560, 0], [-520, -470, 0], [-300, -566, 0], [-420, -700, 3], [-120, -470, 0], [140, -566, 0], [420, -470, 0], [640, -566, 0],
		[-640, 430, 2], [-380, 520, 2], [-90, 430, 2], [120, 520, 2], [300, 640, 3], [520, 430, 2], [760, 520, 2], [300, 790, 3], [-420, -810, 1]]
	var i := 0
	for c in cab:
		var t := "cabana"
		var nm := "Cabana %d" % (i + 1)
		if i == 3 or i == 12:
			t = "posto_florestal"
			nm = "Posto Florestal " + ("Norte" if i == 3 else "Sul")
		elif i == 6 or i == 10 or i == 15:
			t = "casa_abandonada"
			nm = "Casa abandonada"
		var w := 8 + (i * 7) % 4
		var d := 7 + (i * 5) % 3
		_rural_lot(t, c[0], c[1], w, d, c[2], nm)
		pois.append({"n": nm, "p": Vector2(c[0], c[1]), "k": "cabana"})
		i += 1
	# acampamentos
	for c2 in [[-760, -700], [-200, -760], [520, -700], [-560, 660], [60, 700], [700, 700], [1180, -620], [-1300, 520]]:
		camps.append({"p": Vector2(c2[0], c2[1])})
		clearings.append(Vector3(c2[0], c2[1], 9.0))
		pois.append({"n": "Acampamento", "p": Vector2(c2[0], c2[1]), "k": "acampamento"})
	# acidente na rodovia
	_add_car(Vector2(-180, HWY_Z + 1.5), 0.4, "sedan")
	_add_car(Vector2(-172, HWY_Z - 2.0), -1.1, "van")
	_add_car(Vector2(40, HWY_Z + 2.5), PI * 0.5, "picape")


# ---------------------------------------------------------------- indices espaciais
static func ck(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CH), floori(z / CH))


func _reg(dict: Dictionary, r: Rect2, val) -> void:
	var a := ck(r.position.x, r.position.y)
	var b := ck(r.end.x - 0.01, r.end.y - 0.01)
	for cx in range(a.x, b.x + 1):
		for cz in range(a.y, b.y + 1):
			var k := Vector2i(cx, cz)
			if not dict.has(k):
				dict[k] = []
			dict[k].append(val)


func _index() -> void:
	for l in lots:
		var lot: Rect2i = l["lot"]
		var c := ck(lot.position.x + lot.size.x * 0.5, lot.position.y + lot.size.y * 0.5)
		if not chunk_lots.has(c):
			chunk_lots[c] = []
		chunk_lots[c].append(l["id"])
		_reg(chunk_lot_refs, Rect2(lot), l["id"])
	for i in roads.size():
		_reg(chunk_roads, roads[i]["r"], i)
	for i in fields.size():
		_reg(chunk_fields, fields[i]["r"], i)
	for c3 in clearings:
		_reg(chunk_clear, Rect2(c3.x - c3.z, c3.y - c3.z, c3.z * 2.0, c3.z * 2.0), c3)
	for c4 in cars:
		var k := ck(c4["p"].x, c4["p"].y)
		if not chunk_cars.has(k):
			chunk_cars[k] = []
		chunk_cars[k].append(c4["id"])
	for i in camps.size():
		var k2 := ck(camps[i]["p"].x, camps[i]["p"].y)
		if not chunk_camps.has(k2):
			chunk_camps[k2] = []
		chunk_camps[k2].append(i)


func road_at(x: float, z: float) -> int:
	var k := ck(x, z)
	if not chunk_roads.has(k):
		return -1
	var p := Vector2(x, z)
	for i in chunk_roads[k]:
		if roads[i]["r"].has_point(p):
			return i
	return -1


func lot_at(x: float, z: float) -> int:
	var k := ck(x, z)
	if not chunk_lot_refs.has(k):
		return -1
	var p := Vector2i(floori(x), floori(z))
	for i in chunk_lot_refs[k]:
		if lots[i]["lot"].has_point(p):
			return i
	return -1


func field_at(x: float, z: float) -> int:
	var k := ck(x, z)
	if not chunk_fields.has(k):
		return -1
	var p := Vector2(x, z)
	for i in chunk_fields[k]:
		if fields[i]["r"].has_point(p):
			return i
	return -1


func in_clearing(x: float, z: float) -> bool:
	var k := ck(x, z)
	if not chunk_clear.has(k):
		return false
	for c in chunk_clear[k]:
		if Vector2(x - c.x, z - c.y).length() < c.z:
			return true
	return false


## Arvores, arbustos e pedras de um chunk (deterministico). kind: 0 conifera, 1 folhosa, 2 seca, 3 arbusto, 4 pedra
func trees_for(cx: int, cz: int) -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = G.hash2(cx, cz, 77)
	var x0 := float(cx * CH)
	var z0 := float(cz * CH)
	for i in 150:
		var x := x0 + r.randf() * CH
		var z := z0 + r.randf() * CH
		var roll := r.randf()
		var kroll := r.randf()
		var sc := r.randf_range(0.8, 1.45)
		var rot := r.randf() * TAU
		var d := forest_density(x, z)
		var zn := zone_at(x, z)
		if zn == Z_RIVER or zn == Z_CITY:
			var li := lot_at(x, z)
			if li < 0 or lots[li]["type"] != "praca" or roll > 0.16:
				continue
			d = 1.0
		if roll > d:
			continue
		if absf(x - river_x(z)) < RIVER_HALF + 2.0:
			continue
		if road_at(x, z) >= 0 or road_at(x + 1.5, z) >= 0 or road_at(x - 1.5, z) >= 0 or road_at(x, z + 1.5) >= 0 or road_at(x, z - 1.5) >= 0:
			continue
		if field_at(x, z) >= 0 or in_clearing(x, z):
			continue
		var li2 := lot_at(x, z)
		if li2 >= 0 and lots[li2]["type"] != "praca":
			continue
		var kind := 0
		if kroll < 0.14:
			kind = 3
		elif kroll < 0.19:
			kind = 4
		elif kroll < 0.24:
			kind = 2
		elif kroll < 0.62:
			kind = 1
		out.append({"x": x, "z": z, "k": kind, "s": sc, "r": rot})
	return out
