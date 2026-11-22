class_name BPlan
extends RefCounted
## Planta de um edificio gerada de forma deterministica (dados puros, segura para threads):
## grade de 1 m com paredes, portas, janelas, escadas e moveis; e a malha correspondente.

const T_VOID := 0
const T_FLOOR := 1
const T_WALL := 2
const T_DOOR := 3
const T_WIN := 4
const T_STAIR := 5
const T_FURN := 6
const T_HOLE := 7
const FH := 3.0
const WH := 2.8

const WOOD := Color(0.50, 0.35, 0.22)
const DWOOD := Color(0.33, 0.22, 0.14)
const WHITE := Color(0.90, 0.90, 0.88)
const METAL := Color(0.52, 0.54, 0.57)
const DARK := Color(0.14, 0.14, 0.16)
const FAB := Color(1, 0, 1)        # substituida pela cor de tecido do edificio

## movel: n nome, w largura ao longo da parede, h altura de colisao, cont recipiente, use funcao, b caixas [x,y,z, sx,sy,sz, cor]
const FURN := {
	"sofa": {"n": "Sofá", "w": 2, "h": 0.8, "use": "sofa", "b": [[0, 0.25, 0.05, 1.9, 0.5, 0.8, FAB], [0, 0.65, -0.32, 1.9, 0.5, 0.2, FAB], [-0.9, 0.45, 0.05, 0.14, 0.5, 0.8, FAB], [0.9, 0.45, 0.05, 0.14, 0.5, 0.8, FAB]]},
	"poltrona": {"n": "Poltrona", "w": 1, "h": 0.8, "use": "sofa", "b": [[0, 0.25, 0.05, 0.85, 0.5, 0.8, FAB], [0, 0.65, -0.32, 0.85, 0.5, 0.2, FAB]]},
	"estante": {"n": "Estante", "w": 1, "h": 1.9, "cont": "estante", "b": [[0, 0.95, -0.25, 0.95, 1.9, 0.4, WOOD], [0, 0.5, -0.06, 0.8, 0.22, 0.05, Color(0.5, 0.2, 0.2)], [0, 0.95, -0.06, 0.8, 0.22, 0.05, Color(0.2, 0.35, 0.5)], [0, 1.4, -0.06, 0.8, 0.22, 0.05, Color(0.3, 0.45, 0.25)]]},
	"tv": {"n": "Televisão", "w": 1, "h": 0.9, "use": "tv", "b": [[0, 0.25, -0.2, 0.9, 0.5, 0.45, DWOOD], [0, 0.82, -0.25, 0.85, 0.5, 0.06, DARK]]},
	"mesa": {"n": "Mesa", "w": 1, "h": 0.8, "b": [[0, 0.76, 0, 0.95, 0.06, 0.95, WOOD], [-0.4, 0.37, -0.4, 0.07, 0.74, 0.07, DWOOD], [0.4, 0.37, -0.4, 0.07, 0.74, 0.07, DWOOD], [-0.4, 0.37, 0.4, 0.07, 0.74, 0.07, DWOOD], [0.4, 0.37, 0.4, 0.07, 0.74, 0.07, DWOOD]]},
	"geladeira": {"n": "Geladeira", "w": 1, "h": 1.8, "cont": "geladeira", "use": "fridge", "b": [[0, 0.9, -0.12, 0.75, 1.8, 0.7, WHITE], [0.28, 1.2, 0.25, 0.04, 0.4, 0.04, METAL], [0, 1.28, 0.235, 0.74, 0.02, 0.01, Color(0.6, 0.6, 0.6)]]},
	"fogao": {"n": "Fogão", "w": 1, "h": 0.9, "cont": "fogao", "use": "stove", "b": [[0, 0.44, -0.15, 0.75, 0.88, 0.65, WHITE], [0, 0.89, -0.15, 0.75, 0.03, 0.65, DARK], [0, 0.55, 0.18, 0.6, 0.4, 0.02, DARK]]},
	"pia_cozinha": {"n": "Pia da cozinha", "w": 1, "h": 0.9, "use": "sink", "b": [[0, 0.44, -0.18, 0.98, 0.88, 0.62, WOOD], [0, 0.9, -0.18, 0.98, 0.04, 0.62, METAL], [0, 0.92, -0.18, 0.5, 0.02, 0.36, DARK], [0, 1.02, -0.42, 0.04, 0.2, 0.04, METAL]]},
	"armario_cozinha": {"n": "Armário de cozinha", "w": 1, "h": 0.9, "cont": "armario_cozinha", "b": [[0, 0.44, -0.18, 0.98, 0.88, 0.62, WOOD], [0, 0.9, -0.18, 0.98, 0.04, 0.62, Color(0.75, 0.73, 0.68)], [0, 1.85, -0.31, 0.98, 0.6, 0.36, WOOD]]},
	"microondas": {"n": "Balcão com micro-ondas", "w": 1, "h": 0.9, "use": "microwave", "b": [[0, 0.44, -0.18, 0.98, 0.88, 0.62, WOOD], [0, 0.9, -0.18, 0.98, 0.04, 0.62, Color(0.75, 0.73, 0.68)], [0, 1.06, -0.2, 0.5, 0.28, 0.36, WHITE], [-0.05, 1.06, -0.015, 0.3, 0.2, 0.01, DARK]]},
	"cama": {"n": "Cama", "w": 2, "h": 0.6, "use": "bed", "b": [[0, 0.15, 0, 1.95, 0.3, 0.98, DWOOD], [0, 0.42, 0, 1.9, 0.26, 0.92, FAB], [-0.7, 0.6, 0, 0.4, 0.12, 0.6, WHITE], [-0.96, 0.5, 0, 0.06, 0.9, 0.98, DWOOD]]},
	"colchao": {"n": "Colchão velho", "w": 2, "h": 0.3, "use": "bed_bad", "b": [[0, 0.11, 0, 1.9, 0.22, 0.9, Color(0.62, 0.6, 0.52)]]},
	"guarda_roupa": {"n": "Guarda-roupa", "w": 1, "h": 2.0, "cont": "guarda_roupa", "b": [[0, 1.0, -0.18, 0.96, 2.0, 0.62, DWOOD], [0, 1.0, 0.135, 0.02, 1.9, 0.01, DARK], [0.08, 1.0, 0.14, 0.03, 0.2, 0.02, METAL]]},
	"comoda": {"n": "Cômoda", "w": 1, "h": 0.85, "cont": "comoda", "b": [[0, 0.42, -0.22, 0.92, 0.85, 0.5, WOOD], [0, 0.6, 0.035, 0.8, 0.02, 0.01, DARK], [0, 0.32, 0.035, 0.8, 0.02, 0.01, DARK]]},
	"criado_mudo": {"n": "Criado-mudo", "w": 1, "h": 0.55, "cont": "criado_mudo", "b": [[0, 0.28, -0.22, 0.5, 0.55, 0.45, WOOD]]},
	"vaso": {"n": "Vaso sanitário", "w": 1, "h": 0.5, "use": "toilet", "b": [[0, 0.2, 0.0, 0.4, 0.4, 0.5, WHITE], [0, 0.55, -0.36, 0.42, 0.4, 0.2, WHITE]]},
	"pia": {"n": "Pia", "w": 1, "h": 0.85, "use": "sink", "b": [[0, 0.4, -0.25, 0.3, 0.8, 0.3, WHITE], [0, 0.82, -0.2, 0.6, 0.12, 0.45, WHITE], [0, 0.95, -0.38, 0.04, 0.16, 0.04, METAL]]},
	"armario_banheiro": {"n": "Armário de remédios", "w": 1, "h": 0.9, "cont": "armario_banheiro", "b": [[0, 0.45, -0.3, 0.6, 0.9, 0.35, WHITE], [0, 1.5, -0.4, 0.5, 0.6, 0.14, Color(0.7, 0.8, 0.85)]]},
	"banheira": {"n": "Banheira", "w": 2, "h": 0.55, "use": "bath", "b": [[0, 0.28, -0.1, 1.75, 0.55, 0.78, WHITE], [0, 0.5, -0.1, 1.55, 0.12, 0.58, Color(0.72, 0.8, 0.84)]]},
	"caixote": {"n": "Caixote", "w": 1, "h": 0.8, "cont": "caixote", "b": [[0, 0.4, 0, 0.86, 0.8, 0.86, Color(0.55, 0.42, 0.26)], [0, 0.4, 0.435, 0.86, 0.1, 0.01, DWOOD], [0, 0.7, 0.435, 0.86, 0.06, 0.01, DWOOD]]},
	"prateleira": {"n": "Prateleira", "w": 1, "h": 1.8, "cont": "caixote", "b": [[-0.46, 0.9, 0, 0.05, 1.8, 0.55, METAL], [0.46, 0.9, 0, 0.05, 1.8, 0.55, METAL], [0, 0.3, 0, 0.92, 0.04, 0.55, METAL], [0, 0.8, 0, 0.92, 0.04, 0.55, METAL], [0, 1.3, 0, 0.92, 0.04, 0.55, METAL], [0, 1.78, 0, 0.92, 0.04, 0.55, METAL], [-0.15, 0.46, 0, 0.5, 0.28, 0.4, Color(0.7, 0.45, 0.2)], [0.18, 0.95, 0, 0.45, 0.26, 0.4, Color(0.3, 0.5, 0.6)], [-0.1, 1.44, 0, 0.6, 0.24, 0.4, Color(0.6, 0.6, 0.35)]]},
	"balcao": {"n": "Balcão", "w": 2, "h": 1.0, "cont": "balcao", "b": [[0, 0.5, -0.1, 1.95, 1.0, 0.6, WOOD], [0, 1.02, -0.1, 1.98, 0.05, 0.66, DWOOD], [0.5, 1.16, -0.1, 0.35, 0.24, 0.35, DARK]]},
	"balcao_bar": {"n": "Balcão do bar", "w": 2, "h": 1.1, "cont": "balcao_bar", "b": [[0, 0.55, -0.1, 1.98, 1.1, 0.6, DWOOD], [0, 1.12, -0.1, 2.0, 0.05, 0.7, Color(0.2, 0.14, 0.1)], [-0.5, 1.28, -0.2, 0.08, 0.28, 0.08, Color(0.2, 0.4, 0.25)], [-0.3, 1.26, -0.2, 0.08, 0.24, 0.08, Color(0.5, 0.35, 0.15)]]},
	"mesa_escritorio": {"n": "Mesa de escritório", "w": 2, "h": 0.8, "cont": "mesa_escritorio", "b": [[0, 0.74, -0.1, 1.7, 0.05, 0.75, WOOD], [-0.7, 0.36, -0.1, 0.3, 0.72, 0.7, METAL], [0.8, 0.36, -0.1, 0.05, 0.72, 0.7, METAL], [0.2, 0.98, -0.3, 0.5, 0.36, 0.05, DARK], [0.2, 0.8, -0.3, 0.2, 0.06, 0.16, DARK]]},
	"arquivo": {"n": "Arquivo", "w": 1, "h": 1.3, "cont": "arquivo", "b": [[0, 0.65, -0.18, 0.5, 1.3, 0.62, METAL], [0, 1.0, 0.135, 0.3, 0.03, 0.01, DARK], [0, 0.6, 0.135, 0.3, 0.03, 0.01, DARK], [0, 0.2, 0.135, 0.3, 0.03, 0.01, DARK]]},
	"carteira": {"n": "Carteira escolar", "w": 1, "h": 0.75, "b": [[0, 0.7, 0, 0.6, 0.04, 0.45, Color(0.7, 0.6, 0.4)], [0, 0.35, 0, 0.5, 0.7, 0.04, METAL], [0, 0.4, 0.45, 0.4, 0.04, 0.38, Color(0.25, 0.4, 0.3)]]},
	"armario": {"n": "Armário de aço", "w": 1, "h": 1.9, "cont": "armario_escola", "b": [[0, 0.95, -0.25, 0.92, 1.9, 0.45, Color(0.42, 0.5, 0.56)], [0, 0.95, -0.02, 0.02, 1.8, 0.01, DARK], [-0.2, 1.4, -0.02, 0.2, 0.05, 0.01, DARK]]},
	"cama_hospital": {"n": "Leito", "w": 2, "h": 0.7, "use": "bed", "b": [[0, 0.35, 0, 1.95, 0.08, 0.9, METAL], [0, 0.5, 0, 1.9, 0.2, 0.85, WHITE], [-0.94, 0.6, 0, 0.05, 0.6, 0.9, METAL], [0.94, 0.5, 0, 0.05, 0.4, 0.9, METAL], [-0.8, 0.18, -0.38, 0.05, 0.36, 0.05, METAL], [0.8, 0.18, 0.38, 0.05, 0.36, 0.05, METAL]]},
	"bancada": {"n": "Bancada de trabalho", "w": 2, "h": 0.9, "use": "workbench", "b": [[0, 0.86, -0.08, 1.95, 0.08, 0.75, WOOD], [-0.85, 0.42, -0.08, 0.1, 0.84, 0.7, METAL], [0.85, 0.42, -0.08, 0.1, 0.84, 0.7, METAL], [0.6, 1.0, -0.2, 0.2, 0.2, 0.2, Color(0.3, 0.32, 0.4)], [0, 0.3, -0.08, 1.6, 0.04, 0.7, WOOD]]},
	"maquina": {"n": "Máquina industrial", "w": 2, "h": 1.6, "b": [[0, 0.8, 0, 1.8, 1.6, 0.9, Color(0.28, 0.4, 0.34)], [0.4, 1.7, 0, 0.5, 0.2, 0.5, METAL], [-0.5, 1.0, 0.46, 0.5, 0.4, 0.02, DARK]]},
	"fardo": {"n": "Fardo de feno", "w": 1, "h": 0.8, "b": [[0, 0.4, 0, 0.95, 0.8, 0.95, Color(0.78, 0.66, 0.3)]]},
	"lareira": {"n": "Lareira", "w": 1, "h": 1.6, "use": "fire", "b": [[0, 0.8, -0.2, 1.0, 1.6, 0.6, Color(0.42, 0.4, 0.38)], [0, 0.4, 0.1, 0.6, 0.6, 0.06, Color(0.08, 0.07, 0.07)], [0, 2.2, -0.25, 0.5, 1.4, 0.45, Color(0.42, 0.4, 0.38)]]},
	"fogao_lenha": {"n": "Fogão a lenha", "w": 1, "h": 0.9, "use": "fire", "cont": "fogao", "b": [[0, 0.44, -0.12, 0.85, 0.88, 0.7, Color(0.2, 0.2, 0.22)], [0.25, 1.6, -0.3, 0.16, 1.5, 0.16, Color(0.2, 0.2, 0.22)]]},
	"lixeira": {"n": "Lixeira", "w": 1, "h": 0.7, "cont": "lixeira", "b": [[0, 0.35, -0.2, 0.45, 0.7, 0.45, Color(0.25, 0.35, 0.3)]]},
	"cela_grade": {"n": "Grade", "w": 1, "h": 2.4, "b": [[-0.4, 1.2, 0, 0.05, 2.4, 0.05, METAL], [-0.2, 1.2, 0, 0.05, 2.4, 0.05, METAL], [0, 1.2, 0, 0.05, 2.4, 0.05, METAL], [0.2, 1.2, 0, 0.05, 2.4, 0.05, METAL], [0.4, 1.2, 0, 0.05, 2.4, 0.05, METAL], [0, 2.38, 0, 1.0, 0.05, 0.05, METAL]]},
}

## comodo -> lista de [movel, chance, recipiente opcional]; "c:" indica movel de centro
const ROOM_FURN := {
	"sala": [["sofa", 1.0], ["tv", 0.9], ["estante", 0.8], ["poltrona", 0.6], ["c:mesa", 0.5], ["estante", 0.3]],
	"cozinha": [["geladeira", 1.0], ["fogao", 1.0], ["pia_cozinha", 1.0], ["armario_cozinha", 1.0], ["armario_cozinha", 0.8], ["microondas", 0.6], ["c:mesa", 0.6], ["lixeira", 0.5]],
	"quarto": [["cama", 1.0], ["guarda_roupa", 1.0], ["criado_mudo", 0.9], ["comoda", 0.6], ["estante", 0.25]],
	"banheiro": [["vaso", 1.0], ["pia", 1.0], ["armario_banheiro", 0.9], ["banheira", 0.5]],
	"despensa": [["caixote", 1.0], ["prateleira", 0.9, "armario_cozinha"], ["caixote", 0.6], ["prateleira", 0.5, "caixa_ferramentas"]],
	"escritorio": [["mesa_escritorio", 1.0], ["arquivo", 0.9], ["estante", 0.6], ["mesa_escritorio", 0.5], ["arquivo", 0.4], ["lixeira", 0.4]],
	"deposito": [["caixote", 1.0], ["caixote", 0.9], ["prateleira", 0.9], ["prateleira", 0.7], ["caixote", 0.6], ["caixote", 0.5], ["prateleira", 0.5]],
	"sala_aula": [["mesa_escritorio", 1.0], ["armario", 0.9], ["estante", 0.6]],
	"enfermaria": [["cama_hospital", 1.0], ["armario", 0.9, "armario_medico"], ["cama_hospital", 0.7], ["pia", 0.6], ["criado_mudo", 0.5]],
	"consultorio": [["mesa_escritorio", 1.0], ["cama_hospital", 0.8], ["armario", 1.0, "armario_medico"], ["pia", 0.6], ["arquivo", 0.5]],
	"farmacia_int": [["armario", 1.0, "armario_medico"], ["armario", 1.0, "armario_medico"], ["prateleira", 0.9, "prateleira_farmacia"], ["geladeira", 0.5]],
	"cela": [["colchao", 1.0], ["vaso", 0.9]],
	"arsenal": [["armario", 1.0, "armario_policia"], ["armario", 1.0, "armario_policia"], ["armario", 0.8, "armario_policia"], ["caixote", 0.6, "prateleira_armas"]],
	"quarto_hotel": [["cama", 1.0], ["criado_mudo", 0.9], ["guarda_roupa", 0.8], ["tv", 0.6], ["poltrona", 0.4]],
	"apartamento": [["cama", 1.0], ["guarda_roupa", 0.9], ["geladeira", 0.9], ["fogao", 0.8], ["armario_cozinha", 0.8], ["sofa", 0.7], ["pia_cozinha", 0.7], ["tv", 0.6], ["criado_mudo", 0.5]],
	"recepcao": [["balcao", 1.0], ["sofa", 0.8], ["poltrona", 0.5], ["arquivo", 0.5], ["lixeira", 0.5]],
	"cozinha_ind": [["geladeira", 1.0], ["geladeira", 0.8], ["fogao", 1.0], ["fogao", 0.7], ["pia_cozinha", 1.0], ["armario_cozinha", 1.0], ["armario_cozinha", 0.9], ["prateleira", 0.7, "armario_cozinha"]],
	"cabana": [["lareira", 1.0], ["colchao", 0.3], ["cama", 0.9], ["armario_cozinha", 1.0, "armario_cabana"], ["c:mesa", 0.7], ["caixote", 0.8, "armario_cabana"], ["estante", 0.4], ["pia_cozinha", 0.5]],
	"vestiario": [["armario", 1.0, "armario_bombeiro"], ["armario", 1.0, "armario_bombeiro"], ["armario", 0.7, "armario_bombeiro"], ["pia", 0.5]],
	"corredor": [["lixeira", 0.3]],
	"": [],
}

var id := 0
var type := ""
var tdef: Dictionary = {}
var name := ""
var w := 0
var d := 0
var floors := 1
var face := 0
var bx := 0
var bz := 0
var bw := 0
var bd := 0
var tiles: Array = []
var rooms: Array = []
var doors: Array = []
var windows: Array = []
var furn: Array = []
var stairs: Array = []
var pumps: Array = []        # posicoes locais de bombas de combustivel
var has_well := false
var zb := 0
var cz := 0
var rng := RandomNumberGenerator.new()
var c_ext := Color.WHITE
var c_int := Color.WHITE
var c_floor := Color.WHITE
var c_roof := Color.WHITE
var c_fab := Color.WHITE
var c_door := Color.WHITE
var colliders: Array = []    # [Transform3D, Vector3 tamanho]
var solid_cells: Array = []  # por andar: PackedVector2Array de celulas locais solidas


static func generate(lot: Dictionary) -> BPlan:
	var p := BPlan.new()
	p._gen(lot)
	return p


func _gen(lot: Dictionary) -> void:
	id = lot["id"]
	type = lot["type"]
	name = lot["name"]
	tdef = WorldGen.TYPES[type]
	floors = lot["floors"]
	face = lot["face"]
	var b: Rect2i = lot["b"]
	bx = b.position.x
	bz = b.position.y
	bw = b.size.x
	bd = b.size.y
	if face == 0 or face == 2:
		w = bw
		d = bd
	else:
		w = bd
		d = bw
	rng.seed = G.hash2(id, 911, 5)
	_palette()
	has_well = floors > 1
	var lay: String = tdef["lay"]
	cz = d / 2 - 1
	zb = clampi(d / 2 + 2, 6, d - 3)
	if lay == "corr":
		zb = clampi(cz + 6, 6, d - 3)
	for f in floors:
		var t := PackedByteArray()
		t.resize(w * d)
		t.fill(T_FLOOR)
		tiles.append(t)
		rooms.append([])
		for x in w:
			ts(f, x, 0, T_WALL)
			ts(f, x, d - 1, T_WALL)
		for z in d:
			ts(f, 0, z, T_WALL)
			ts(f, w - 1, z, T_WALL)
	var mx := 1
	if has_well:
		mx = 4
		for f in floors:
			for z in d:
				ts(f, 3, z, T_WALL)
			rooms[f].append({"r": Rect2i(1, 1, 2, d - 2), "k": "corredor"})
		for f in floors - 1:
			var col := 1 if f % 2 == 0 else 2
			stairs.append({"f": f, "col": col, "dir": -1 if f % 2 == 0 else 1})
			for z in range(zb - 4, zb + 1):
				ts(f, col, z, T_STAIR)
				ts(f + 1, col, z, T_HOLE)
	var main := Rect2i(mx, 1, w - 1 - mx, d - 2)
	for f in floors:
		match lay:
			"bsp":
				_lay_bsp(f, main)
			"shop":
				_lay_shop(f, main)
			"corr":
				_lay_corr(f, main)
			"hall":
				_lay_hall(f, main)
		if has_well:
			_well_door(f, lay)
	_ext_doors(lay)
	for f in floors:
		_windows(f, lay)
	for f in floors:
		_furnish(f)
		_connect(f)
	if type == "posto":
		pumps = [Vector2(w * 0.5 - 3.0, d + 5.5), Vector2(w * 0.5 + 3.0, d + 5.5)]
	_calc_solid()


func _calc_solid() -> void:
	solid_cells = []
	for f in floors:
		var sc := PackedVector2Array()
		var t2: PackedByteArray = tiles[f]
		for z in d:
			for x in w:
				var v := t2[z * w + x]
				if v == T_WALL or v == T_FURN or v == T_WIN or v == T_HOLE:
					sc.append(Vector2(x, z))
		solid_cells.append(sc)


## Aplica moveis ja desmontados (indices) antes de gerar a malha.
func apply_gone(list: Array) -> void:
	for fi in list:
		if fi < 0 or fi >= furn.size():
			continue
		var fu: Dictionary = furn[fi]
		fu["gone"] = true
		for t in fu["tiles"]:
			ts(fu["f"], t.x, t.y, T_FLOOR)
	_calc_solid()


func _palette() -> void:
	var mat: String = tdef["mat"]
	match mat:
		"tijolo":
			c_ext = [Color(0.60, 0.32, 0.24), Color(0.66, 0.38, 0.27), Color(0.52, 0.30, 0.24), Color(0.70, 0.46, 0.34)][rng.randi() % 4]
		"concreto":
			c_ext = [Color(0.62, 0.62, 0.60), Color(0.55, 0.56, 0.58), Color(0.70, 0.68, 0.63)][rng.randi() % 3]
		"metal":
			c_ext = [Color(0.48, 0.55, 0.60), Color(0.56, 0.52, 0.44), Color(0.42, 0.50, 0.44), Color(0.60, 0.36, 0.28)][rng.randi() % 4]
		"madeira":
			c_ext = [Color(0.44, 0.31, 0.20), Color(0.52, 0.38, 0.25), Color(0.36, 0.27, 0.20), Color(0.56, 0.20, 0.16)][rng.randi() % 4]
		_:
			c_ext = [Color(0.86, 0.80, 0.66), Color(0.74, 0.80, 0.84), Color(0.84, 0.72, 0.62), Color(0.80, 0.84, 0.72), Color(0.88, 0.86, 0.80),
				Color(0.70, 0.62, 0.52), Color(0.82, 0.66, 0.66), Color(0.62, 0.70, 0.74)][rng.randi() % 8]
	c_int = [Color(0.86, 0.84, 0.78), Color(0.80, 0.84, 0.82), Color(0.86, 0.80, 0.72), Color(0.78, 0.80, 0.86)][rng.randi() % 4]
	if mat == "madeira":
		c_int = c_ext.lightened(0.18)
	elif mat == "metal":
		c_int = Color(0.66, 0.67, 0.68)
	var lay: String = tdef["lay"]
	if lay == "bsp":
		c_floor = [Color(0.50, 0.36, 0.23), Color(0.58, 0.44, 0.30), Color(0.42, 0.30, 0.20)][rng.randi() % 3]
	elif mat == "metal" or type == "oficina" or type == "bombeiros":
		c_floor = Color(0.46, 0.46, 0.46)
	else:
		c_floor = [Color(0.72, 0.72, 0.70), Color(0.66, 0.68, 0.70), Color(0.74, 0.70, 0.64)][rng.randi() % 3]
	c_roof = [Color(0.48, 0.22, 0.16), Color(0.26, 0.27, 0.30), Color(0.38, 0.30, 0.24), Color(0.22, 0.30, 0.26)][rng.randi() % 4]
	if tdef["roof"] == "flat":
		c_roof = Color(0.34, 0.35, 0.36)
	c_fab = [Color(0.45, 0.25, 0.22), Color(0.25, 0.35, 0.5), Color(0.3, 0.45, 0.32), Color(0.55, 0.5, 0.4), Color(0.4, 0.3, 0.45), Color(0.6, 0.45, 0.25)][rng.randi() % 6]
	c_door = [Color(0.40, 0.26, 0.16), Color(0.86, 0.86, 0.82), Color(0.30, 0.20, 0.14), Color(0.25, 0.35, 0.3), Color(0.5, 0.2, 0.16)][rng.randi() % 5]


func tg(f: int, x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= w or z >= d:
		return T_VOID
	return tiles[f][z * w + x]


func ts(f: int, x: int, z: int, v: int) -> void:
	if x < 0 or z < 0 or x >= w or z >= d:
		return
	tiles[f][z * w + x] = v


## celula local -> celula do mundo
func ltw(lx: int, lz: int) -> Vector2i:
	match face:
		0:
			return Vector2i(bx + lx, bz + lz)
		2:
			return Vector2i(bx + bw - 1 - lx, bz + bd - 1 - lz)
		1:
			return Vector2i(bx + lz, bz + w - 1 - lx)
		_:
			return Vector2i(bx + d - 1 - lz, bz + lx)


func xform() -> Transform3D:
	match face:
		0:
			return Transform3D(Basis.IDENTITY, Vector3(bx, 0, bz))
		2:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(bx + bw, 0, bz + bd))
		1:
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(bx, 0, bz + w))
		_:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(bx + d, 0, bz))


# =====================================================================================
#  LEIAUTES
# =====================================================================================
func _bsp(f: int, r: Rect2i, min_s: int, max_area: int, out: Array, splits: Array) -> void:
	var can_x := r.size.x >= min_s * 2 + 1
	var can_z := r.size.y >= min_s * 2 + 1
	if (not can_x and not can_z) or (r.size.x * r.size.y <= max_area and rng.randf() < 0.8):
		out.append({"r": r, "k": ""})
		return
	var vx := can_x and (not can_z or r.size.x > r.size.y or (r.size.x == r.size.y and rng.randf() < 0.5))
	if vx:
		var s := rng.randi_range(r.position.x + min_s, r.end.x - min_s - 1)
		for z in range(r.position.y, r.end.y):
			ts(f, s, z, T_WALL)
		splits.append([true, s, r.position.y, r.end.y - 1])
		_bsp(f, Rect2i(r.position.x, r.position.y, s - r.position.x, r.size.y), min_s, max_area, out, splits)
		_bsp(f, Rect2i(s + 1, r.position.y, r.end.x - s - 1, r.size.y), min_s, max_area, out, splits)
	else:
		var s2 := rng.randi_range(r.position.y + min_s, r.end.y - min_s - 1)
		for x in range(r.position.x, r.end.x):
			ts(f, x, s2, T_WALL)
		splits.append([false, s2, r.position.x, r.end.x - 1])
		_bsp(f, Rect2i(r.position.x, r.position.y, r.size.x, s2 - r.position.y), min_s, max_area, out, splits)
		_bsp(f, Rect2i(r.position.x, s2 + 1, r.size.x, r.end.y - s2 - 1), min_s, max_area, out, splits)


func _split_doors(f: int, splits: Array) -> void:
	for sp in splits:
		var cand: Array = []
		if sp[0]:
			for z in range(sp[2], sp[3] + 1):
				if tg(f, sp[1] - 1, z) == T_FLOOR and tg(f, sp[1] + 1, z) == T_FLOOR:
					cand.append(z)
			if cand.is_empty():
				var zz: int = (sp[2] + sp[3]) / 2
				ts(f, sp[1] - 1, zz, T_FLOOR)
				ts(f, sp[1] + 1, zz, T_FLOOR)
				cand.append(zz)
			_door(f, sp[1], cand[rng.randi() % cand.size()], false, false)
		else:
			for x in range(sp[2], sp[3] + 1):
				if tg(f, x, sp[1] - 1) == T_FLOOR and tg(f, x, sp[1] + 1) == T_FLOOR:
					cand.append(x)
			if cand.is_empty():
				var xx: int = (sp[2] + sp[3]) / 2
				ts(f, xx, sp[1] - 1, T_FLOOR)
				ts(f, xx, sp[1] + 1, T_FLOOR)
				cand.append(xx)
			_door(f, cand[rng.randi() % cand.size()], sp[1], true, false)


func _door(f: int, x: int, z: int, h: bool, ext: bool) -> void:
	ts(f, x, z, T_DOOR)
	var lock := false
	if ext:
		lock = rng.randf() < (0.55 if tdef["lay"] == "bsp" else 0.3)
	doors.append({"f": f, "x": x, "z": z, "h": h, "ext": ext, "lock": lock})


func _lay_bsp(f: int, main: Rect2i) -> void:
	var rs: Array = []
	var sp: Array = []
	_bsp(f, main, 3 if main.size.x * main.size.y > 40 else 2, 22, rs, sp)
	_split_doors(f, sp)
	# tipos de comodo
	var kinds: Array = []
	if type == "cabana" or type == "posto_florestal":
		kinds = ["cabana", "quarto", "despensa", "banheiro", "quarto"]
	elif f == 0:
		kinds = ["sala", "cozinha", "banheiro", "quarto", "quarto", "despensa", "escritorio", "quarto"]
	else:
		kinds = ["quarto", "banheiro", "quarto", "escritorio", "quarto", "despensa"]
	# sala = comodo junto a fachada; banheiro = o menor
	rs.sort_custom(func(a, b): return a["r"].size.x * a["r"].size.y > b["r"].size.x * b["r"].size.y)
	var front := -1
	for i in rs.size():
		if rs[i]["r"].end.y == d - 1 and (front < 0 or rs[i]["r"].size.x > rs[front]["r"].size.x):
			front = i
	var ki := 0
	if front >= 0:
		rs[front]["k"] = kinds[0]
		ki = 1
	var small := rs.size() - 1
	if small >= 0 and rs[small]["k"] == "" and rs.size() >= 3:
		rs[small]["k"] = "banheiro"
	for r in rs:
		if r["k"] == "":
			while ki < kinds.size() and kinds[ki] == "banheiro" and rs.size() >= 3:
				ki += 1
			r["k"] = kinds[ki % kinds.size()]
			ki += 1
		rooms[f].append(r)


func _lay_shop(f: int, main: Rect2i) -> void:
	var back := clampi(main.size.y / 4, 3, 6)
	var wz := main.position.y + back
	for x in range(main.position.x, main.end.x):
		ts(f, x, wz, T_WALL)
	var store := Rect2i(main.position.x, wz + 1, main.size.x, main.end.y - wz - 1)
	rooms[f].append({"r": store, "k": "loja"})
	# fundos: deposito, escritorio, banheiro
	var bk := Rect2i(main.position.x, main.position.y, main.size.x, back)
	var names := ["deposito", "escritorio", "banheiro"]
	if type == "restaurante" or type == "bar" or type == "padaria":
		names = ["cozinha_ind", "deposito", "banheiro"]
	elif type == "farmacia":
		names = ["farmacia_int", "escritorio", "banheiro"]
	var n := clampi(bk.size.x / 5, 1, 3)
	var x0 := bk.position.x
	for i in n:
		var rw := (bk.end.x - x0) if i == n - 1 else maxi(3, (bk.size.x - (n - 1)) / n)
		if i < n - 1:
			for z in range(bk.position.y, bk.end.y):
				ts(f, x0 + rw, z, T_WALL)
		var rr := Rect2i(x0, bk.position.y, rw, back)
		rooms[f].append({"r": rr, "k": names[i] if n > 1 else names[0]})
		_door(f, x0 + rw / 2, wz, true, false)
		x0 += rw + 1


func _lay_hall(f: int, main: Rect2i) -> void:
	var kinds := ["escritorio", "banheiro"]
	if type == "bombeiros":
		kinds = ["vestiario", "escritorio"]
	elif type == "biblioteca":
		kinds = ["escritorio", "banheiro"]
	elif type == "celeiro" or type == "galpao":
		kinds = []
	var x0 := main.position.x
	var rd := 4
	for k in kinds:
		if x0 + 4 >= main.end.x - 4 or main.size.y < 9:
			break
		var rr := Rect2i(x0, main.position.y, 4, rd)
		for x in range(x0, x0 + 5):
			ts(f, x, main.position.y + rd, T_WALL)
		for z in range(main.position.y, main.position.y + rd + 1):
			ts(f, x0 + 4, z, T_WALL)
		rooms[f].append({"r": rr, "k": k})
		_door(f, x0 + 2, main.position.y + rd, true, false)
		x0 += 5
	rooms[f].append({"r": main, "k": "galpao", "hall": true})


func _lay_corr(f: int, main: Rect2i) -> void:
	# corredor central de 2 m ao longo de X, salas dos dois lados
	var c0 := cz
	for x in range(main.position.x, main.end.x):
		ts(f, x, c0 - 1, T_WALL)
		ts(f, x, c0 + 2, T_WALL)
	rooms[f].append({"r": Rect2i(main.position.x, c0, main.size.x, 2), "k": "corredor"})
	var kn := "escritorio"
	var kn2 := "escritorio"
	match type:
		"escola":
			kn = "sala_aula"
			kn2 = "sala_aula"
		"hospital", "centro_saude":
			kn = "enfermaria"
			kn2 = "consultorio"
		"hotel":
			kn = "quarto_hotel"
			kn2 = "quarto_hotel"
		"apto":
			kn = "apartamento"
			kn2 = "apartamento"
		"delegacia":
			kn = "cela"
			kn2 = "escritorio"
	var rwid := 6 if (type == "escola" or type == "apto") else (3 if kn == "cela" else 5)
	for side in 2:
		var z0 := main.position.y if side == 0 else c0 + 3
		var z1 := (c0 - 2) if side == 0 else (main.end.y - 1)
		if z1 < z0:
			continue
		var x := main.position.x
		var idx := 0
		var lobby_x := main.position.x + main.size.x / 2 - 3
		while x < main.end.x:
			var rw := rwid if side == 0 else (rwid if kn2 != "escritorio" else 5)
			var kind := kn if side == 0 else kn2
			if side == 1 and f == 0 and x <= lobby_x and x + rw >= lobby_x:
				rw = 7
				kind = "recepcao"
			if main.end.x - (x + rw) < 3:
				rw = main.end.x - x
			if x + rw < main.end.x:
				for z in range(z0, z1 + 1):
					ts(f, x + rw, z, T_WALL)
			var rr := Rect2i(x, z0, rw, z1 - z0 + 1)
			if type == "delegacia" and side == 1 and idx == 0 and f == 0:
				kind = "arsenal"
			if type == "hospital" and idx % 5 == 4:
				kind = "farmacia_int" if f == 0 else "banheiro"
			if (type == "escola" or type == "escritorio") and idx % 6 == 5:
				kind = "banheiro"
			rooms[f].append({"r": rr, "k": kind})
			_door(f, x + rw / 2, (c0 - 1) if side == 0 else (c0 + 2), true, false)
			x += rw + 1
			idx += 1


func _well_door(f: int, lay: String) -> void:
	var cand: Array = []
	if lay == "corr":
		cand = [cz]
	else:
		var top := f == floors - 1
		for z in range(1, d - 1):
			if tg(f, 2, z) != T_FLOOR or tg(f, 4, z) != T_FLOOR:
				continue
			if f % 2 == 1 and not top and z > zb - 5:
				continue
			cand.append(z)
	if cand.is_empty():
		var zz := clampi(zb - 5, 1, d - 2)
		ts(f, 4, zz, T_FLOOR)
		cand = [zz]
	_door(f, 3, cand[rng.randi() % cand.size()], false, false)


func _ext_doors(lay: String) -> void:
	# porta principal na fachada (z = d-1)
	var cand: Array = []
	for x in range(1, w - 1):
		if tg(0, x, d - 2) == T_FLOOR and (not has_well or x >= 4):
			cand.append(x)
	if cand.is_empty():
		for x in range(1, w - 1):
			if tg(0, x, d - 2) == T_FLOOR:
				cand.append(x)
	if not cand.is_empty():
		var mid := w / 2
		cand.sort_custom(func(a, b): return absi(a - mid) < absi(b - mid))
		var x1: int = cand[mini(rng.randi() % 3, cand.size() - 1)]
		_door(0, x1, d - 1, true, true)
	# porta dos fundos
	if lay == "bsp" or lay == "hall" or lay == "shop":
		if rng.randf() < 0.6:
			var c2: Array = []
			for x in range(1, w - 1):
				if tg(0, x, 1) == T_FLOOR and (not has_well or x >= 4):
					c2.append(x)
			if not c2.is_empty():
				_door(0, c2[rng.randi() % c2.size()], 0, true, true)
	if lay == "hall" and w > 14:
		var c3: Array = []
		for z in range(2, d - 2):
			if tg(0, w - 2, z) == T_FLOOR:
				c3.append(z)
		if not c3.is_empty():
			_door(0, w - 1, c3[rng.randi() % c3.size()], false, true)


func _windows(f: int, lay: String) -> void:
	var step := 3
	if lay == "hall":
		step = 4
	for x in range(1, w - 1):
		for zz in [0, d - 1]:
			if tg(f, x, zz) != T_WALL:
				continue
			var inner: int = 1 if zz == 0 else d - 2
			if tg(f, x, inner) != T_FLOOR or tg(f, x - 1, zz) != T_WALL or tg(f, x + 1, zz) != T_WALL:
				continue
			var shopfront: bool = lay == "shop" and zz == d - 1 and f == 0
			if (shopfront and x % 2 == 0) or (not shopfront and x % step == 1 and rng.randf() < 0.85):
				ts(f, x, zz, T_WIN)
				windows.append({"f": f, "x": x, "z": zz, "h": true})
	for z in range(1, d - 1):
		for xx in [0, w - 1]:
			if tg(f, xx, z) != T_WALL:
				continue
			var inner2: int = 1 if xx == 0 else w - 2
			if tg(f, inner2, z) != T_FLOOR or tg(f, xx, z - 1) != T_WALL or tg(f, xx, z + 1) != T_WALL:
				continue
			if z % step == 1 and rng.randf() < 0.8:
				ts(f, xx, z, T_WIN)
				windows.append({"f": f, "x": xx, "z": z, "h": false})


# =====================================================================================
#  MOBILIA
# =====================================================================================
func _reserved(f: int, x: int, z: int) -> bool:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var v := tg(f, x + o.x, z + o.y)
		if v == T_DOOR or v == T_WIN or v == T_STAIR:
			return true
		# dois passos livres a frente de portas
		if tg(f, x + o.x * 2, z + o.y * 2) == T_DOOR and v == T_FLOOR:
			return true
	return false


func _free(f: int, x: int, z: int) -> bool:
	return tg(f, x, z) == T_FLOOR and not _reserved(f, x, z)


func _add_furn(f: int, fid: String, x: float, z: float, rot: int, tiles_used: Array, cont: String) -> void:
	var fd: Dictionary = FURN[fid]
	for t in tiles_used:
		ts(f, t.x, t.y, T_FURN)
	var c: String = cont if cont != "" else String(fd.get("cont", ""))
	furn.append({"f": f, "id": fid, "x": x, "z": z, "rot": rot, "cont": c, "use": fd.get("use", ""), "tiles": tiles_used})


func _place_wall(f: int, r: Rect2i, fid: String, cont: String = "") -> bool:
	var fw: int = FURN[fid]["w"]
	var cand: Array = []
	# parede norte (rot 0) e sul (rot 2): movel ao longo de X
	for x in range(r.position.x, r.end.x - fw + 1):
		for side in 2:
			var z := r.position.y if side == 0 else r.end.y - 1
			var wz := z - 1 if side == 0 else z + 1
			var ok := true
			for k in fw:
				if not _free(f, x + k, z) or tg(f, x + k, wz) != T_WALL:
					ok = false
					break
			if ok:
				cand.append([x, z, 0 if side == 0 else 2])
	# parede oeste (rot 1) e leste (rot 3): movel ao longo de Z
	for z in range(r.position.y, r.end.y - fw + 1):
		for side in 2:
			var x2 := r.position.x if side == 0 else r.end.x - 1
			var wx := x2 - 1 if side == 0 else x2 + 1
			var ok2 := true
			for k in fw:
				if not _free(f, x2, z + k) or tg(f, wx, z + k) != T_WALL:
					ok2 = false
					break
			if ok2:
				cand.append([x2, z, 1 if side == 0 else 3])
	if cand.is_empty():
		return false
	var c: Array = cand[rng.randi() % cand.size()]
	var used: Array = []
	var px := float(c[0]) + 0.5
	var pz := float(c[1]) + 0.5
	if c[2] == 0 or c[2] == 2:
		for k in fw:
			used.append(Vector2i(c[0] + k, c[1]))
		px += (fw - 1) * 0.5
	else:
		for k in fw:
			used.append(Vector2i(c[0], c[1] + k))
		pz += (fw - 1) * 0.5
	_add_furn(f, fid, px, pz, c[2], used, cont)
	return true


func _place_center(f: int, r: Rect2i, fid: String, cont: String = "") -> bool:
	var cand: Array = []
	for x in range(r.position.x + 1, r.end.x - 1):
		for z in range(r.position.y + 1, r.end.y - 1):
			if not _free(f, x, z):
				continue
			var ok := true
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if tg(f, x + dx, z + dz) != T_FLOOR:
						ok = false
			if ok:
				cand.append(Vector2i(x, z))
	if cand.is_empty():
		return false
	var c: Vector2i = cand[rng.randi() % cand.size()]
	_add_furn(f, fid, c.x + 0.5, c.y + 0.5, 0, [c], cont)
	return true


func _rows(f: int, r: Rect2i, fid: String, conts: Array, zstep: int, margin: int) -> void:
	var row := 0
	var z := r.position.y + margin
	while z < r.end.y - margin:
		var cont: String = conts[row % conts.size()]
		var aisle := r.position.x + r.size.x / 2
		for x in range(r.position.x + margin, r.end.x - margin):
			if x == aisle or (r.size.x > 16 and (x == aisle - 6 or x == aisle + 6)):
				continue
			if _free(f, x, z) and tg(f, x, z - 1) == T_FLOOR and tg(f, x, z + 1) != T_WALL:
				_add_furn(f, fid, x + 0.5, z + 0.5, 0, [Vector2i(x, z)], cont)
		z += zstep
		row += 1


func _furnish(f: int) -> void:
	for room in rooms[f]:
		var r: Rect2i = room["r"]
		var k: String = room["k"]
		if k == "loja":
			_furnish_shop(f, r)
			continue
		if k == "galpao":
			_furnish_hall(f, r)
			continue
		if k == "sala_aula":
			var z := r.position.y + 2
			while z < r.end.y - 1:
				for x in range(r.position.x + 1, r.end.x - 1, 2):
					if _free(f, x, z):
						_add_furn(f, "carteira", x + 0.5, z + 0.5, 0, [Vector2i(x, z)], "")
				z += 2
		if k == "cela":
			pass
		for e in ROOM_FURN.get(k, []):
			if rng.randf() > float(e[1]):
				continue
			var fid: String = e[0]
			var cont: String = e[2] if e.size() > 2 else ""
			if fid.begins_with("c:"):
				_place_center(f, r, fid.substr(2), cont)
			else:
				_place_wall(f, r, fid, cont)


func _furnish_shop(f: int, r: Rect2i) -> void:
	var conts: Array = ["prateleira_comida"]
	match type:
		"supermercado":
			conts = ["prateleira_comida", "prateleira_comida", "prateleira_hortifruti", "prateleira_padaria", "prateleira_comida", "prateleira_farmacia"]
		"padaria":
			conts = ["prateleira_padaria"]
		"loja_roupas":
			conts = ["prateleira_roupas"]
		"loja_ferramentas":
			conts = ["prateleira_ferramentas"]
		"loja_armas":
			conts = ["prateleira_armas", "prateleira_ferramentas"]
		"farmacia":
			conts = ["prateleira_farmacia"]
		"livraria":
			conts = ["estante_livraria"]
		"posto":
			conts = ["prateleira_comida", "prateleira_oficina"]
		"bar", "restaurante":
			conts = []
	if type == "bar":
		_place_wall(f, r, "balcao_bar")
		_place_wall(f, r, "balcao_bar")
	else:
		_place_wall(f, r, "balcao")
	if conts.is_empty():
		for i in maxi(2, r.size.x * r.size.y / 14):
			_place_center(f, r, "mesa")
	else:
		_rows(f, r, "prateleira", conts, 3, 2)
	if type == "loja_armas":
		_place_wall(f, r, "armario", "prateleira_armas")
		_place_wall(f, r, "armario", "prateleira_armas")


func _furnish_hall(f: int, r: Rect2i) -> void:
	match type:
		"biblioteca":
			_rows(f, r, "estante", ["estante_livraria"], 3, 2)
			_place_wall(f, r, "balcao")
		"oficina":
			for i in 3:
				_place_wall(f, r, "prateleira", "prateleira_oficina")
			_place_wall(f, r, "bancada")
			_place_wall(f, r, "prateleira", "caixa_ferramentas")
			_place_wall(f, r, "caixote")
		"bombeiros":
			_place_wall(f, r, "armario", "armario_bombeiro")
			_place_wall(f, r, "armario", "armario_bombeiro")
			_place_wall(f, r, "bancada")
		"fabrica":
			_rows(f, r, "maquina", [""], 5, 4)
			for i in 4:
				_place_wall(f, r, "caixote")
			_place_wall(f, r, "bancada")
			_place_wall(f, r, "prateleira", "caixa_ferramentas")
		"celeiro":
			for i in 5:
				_place_wall(f, r, "fardo")
			for i in 3:
				_place_wall(f, r, "caixote", "caixote_fazenda")
			_place_wall(f, r, "bancada")
		"galpao":
			for i in 2:
				_place_wall(f, r, "caixote", "caixote_fazenda")
			_place_wall(f, r, "prateleira", "caixa_ferramentas")
			_place_wall(f, r, "bancada")
		_:
			_rows(f, r, "caixote", ["caixote"], 4, 3)
			for i in 4:
				_place_wall(f, r, "prateleira")
			_place_wall(f, r, "bancada")


## Garante que todas as portas e o piso livre sejam alcancaveis; remove moveis que bloqueiem.
func _connect(f: int) -> void:
	for attempt in 5:
		var seen := PackedByteArray()
		seen.resize(w * d)
		var start := Vector2i(-1, -1)
		for dr in doors:
			if dr["f"] == f:
				start = Vector2i(dr["x"], dr["z"])
				break
		if start.x < 0:
			return
		var stack: Array = [start]
		seen[start.y * w + start.x] = 1
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + o
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= d or seen[n.y * w + n.x] == 1:
					continue
				var v := tg(f, n.x, n.y)
				if v == T_FLOOR or v == T_DOOR or v == T_STAIR:
					seen[n.y * w + n.x] = 1
					stack.append(n)
		var bad := false
		var i := furn.size() - 1
		while i >= 0:
			var fu: Dictionary = furn[i]
			if fu["f"] == f:
				var near_unseen := false
				for t in fu["tiles"]:
					for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n2: Vector2i = t + o
						var v2 := tg(f, n2.x, n2.y)
						if (v2 == T_FLOOR or v2 == T_DOOR) and seen[n2.y * w + n2.x] == 0:
							near_unseen = true
				if near_unseen:
					for t in fu["tiles"]:
						ts(f, t.x, t.y, T_FLOOR)
					furn.remove_at(i)
					bad = true
			i -= 1
		if not bad:
			return


# =====================================================================================
#  MALHA E COLISORES (coordenadas locais do edificio)
# =====================================================================================
func _wl(f: int, x: int, z: int) -> bool:
	var v := tg(f, x, z)
	return v == T_WALL or v == T_DOOR or v == T_WIN


func _col(center: Vector3, size: Vector3) -> void:
	colliders.append([Transform3D(Basis.IDENTITY, center), size])


func build_mesh() -> MB:
	var m := MB.new()
	colliders = []
	var trim := c_ext.darkened(0.25)
	var ceil_c := Color(0.88, 0.88, 0.86)
	# piso terreo
	m.box(Vector3(w * 0.5, 0.03, d * 0.5), Vector3(w, 0.06, d), c_floor, 1 | 4 | 8 | 16 | 32)
	for f in floors:
		var y0 := f * FH
		# lajes dos andares superiores, com abertura da escada
		if f >= 1:
			var hx := -1
			for st in stairs:
				if st["f"] == f - 1:
					hx = st["col"]
			var fc := c_floor
			if hx < 0:
				_slab(m, 0, 0, w, d, y0, fc, ceil_c, trim)
			else:
				_slab(m, 0, 0, hx, d, y0, fc, ceil_c, trim)
				_slab(m, hx + 1, 0, w - hx - 1, d, y0, fc, ceil_c, trim)
				_slab(m, hx, 0, 1, zb - 4, y0, fc, ceil_c, trim)
				_slab(m, hx, zb + 1, 1, d - zb - 1, y0, fc, ceil_c, trim)
		_walls(m, f, y0)
		# portas: verga; janelas: peitoril e verga
		for dr in doors:
			if dr["f"] != f:
				continue
			var c := Vector3(dr["x"] + 0.5, y0 + 2.45, dr["z"] + 0.5)
			var sz := Vector3(1.0, 0.7, 0.2) if dr["h"] else Vector3(0.2, 0.7, 1.0)
			m.box6(c, sz, _wall_cols(dr["x"], dr["z"], dr["h"]), 2 | 4 | 8 | 16 | 32)
		for wn in windows:
			if wn["f"] != f:
				continue
			var wx: float = wn["x"] + 0.5
			var wz: float = wn["z"] + 0.5
			var sz2 := Vector3(1.0, 0.9, 0.2) if wn["h"] else Vector3(0.2, 0.9, 1.0)
			var cols := _wall_cols(wn["x"], wn["z"], wn["h"])
			m.box6(Vector3(wx, y0 + 0.45, wz), sz2, cols)
			_col(Vector3(wx, y0 + 0.45, wz), sz2)
			var sz3 := Vector3(1.0, 0.7, 0.2) if wn["h"] else Vector3(0.2, 0.7, 1.0)
			m.box6(Vector3(wx, y0 + 2.45, wz), sz3, cols, 2 | 4 | 8 | 16 | 32)
			var sill := Vector3(1.0, 0.05, 0.3) if wn["h"] else Vector3(0.3, 0.05, 1.0)
			m.box(Vector3(wx, y0 + 0.92, wz), sill, WHITE)
		# escadas
		for st in stairs:
			if st["f"] != f:
				continue
			var sx: float = st["col"] + 0.5
			var up: int = st["dir"]
			for i in 10:
				var t := (i + 0.5) / 10.0
				var zc := (zb + 1.0 - t * 5.0) if up < 0 else (zb - 4.0 + t * 5.0)
				m.box(Vector3(sx, y0 + (i + 1) * 0.3 - 0.15, zc), Vector3(0.98, 0.3, 0.5), c_floor.darkened(0.15 + 0.05 * (i % 2)))
			var ang := atan2(FH, 5.0)
			var mid := Vector3(sx, y0 + FH * 0.5 - 0.08, zb - 1.5)
			colliders.append([Transform3D(Basis(Vector3.RIGHT, ang if up < 0 else -ang), mid), Vector3(1.0, 0.16, sqrt(FH * FH + 25.0))])
		# moveis
		for fu in furn:
			if fu["f"] != f or fu.get("gone", false):
				continue
			_furn_mesh(m, fu, y0)
	# cobertura
	var top := floors * FH
	_slab(m, 0, 0, w, d, top, c_roof, ceil_c, trim)
	if tdef["roof"] == "gable":
		var rh := minf(w, d) * 0.28
		m.gable(-0.5, w + 0.5, -0.5, d + 0.5, top, rh, c_roof, c_ext, d > w)
	else:
		var pc := c_ext.darkened(0.12)
		m.box(Vector3(w * 0.5, top + 0.25, 0.1), Vector3(w, 0.5, 0.2), pc)
		m.box(Vector3(w * 0.5, top + 0.25, d - 0.1), Vector3(w, 0.5, 0.2), pc)
		m.box(Vector3(0.1, top + 0.25, d * 0.5), Vector3(0.2, 0.5, d), pc)
		m.box(Vector3(w - 0.1, top + 0.25, d * 0.5), Vector3(0.2, 0.5, d), pc)
	# fachada com faixa de cor do estabelecimento
	if tdef.has("sign"):
		var sw := minf(w - 2.0, 10.0)
		m.box(Vector3(w * 0.5, 2.55, d - 0.33), Vector3(sw, 0.62, 0.14), tdef["sign"])
		m.box(Vector3(w * 0.5, 2.92, d + 0.25), Vector3(sw + 0.6, 0.08, 1.3), Color(tdef["sign"]).darkened(0.3))
	# posto: cobertura e bombas
	if not pumps.is_empty():
		var cy := 4.2
		m.box(Vector3(w * 0.5, cy, d + 5.5), Vector3(13.0, 0.4, 7.0), Color(0.85, 0.85, 0.83))
		m.box(Vector3(w * 0.5, cy - 0.3, d + 5.5), Vector3(13.2, 0.2, 7.2), Color(tdef.get("sign", Color.RED)))
		for px in [w * 0.5 - 5.5, w * 0.5 + 5.5]:
			m.box(Vector3(px, cy * 0.5, d + 5.5), Vector3(0.35, cy, 0.35), METAL)
			_col(Vector3(px, cy * 0.5, d + 5.5), Vector3(0.35, cy, 0.35))
		for p in pumps:
			m.box(Vector3(p.x, 0.1, p.y), Vector3(1.4, 0.2, 2.6), Color(0.6, 0.6, 0.58))
			m.box(Vector3(p.x, 0.95, p.y), Vector3(0.7, 1.5, 0.9), Color(0.82, 0.2, 0.16))
			m.box(Vector3(p.x, 1.25, p.y + 0.46), Vector3(0.5, 0.4, 0.02), DARK)
			m.box(Vector3(p.x, 1.25, p.y - 0.46), Vector3(0.5, 0.4, 0.02), DARK)
			_col(Vector3(p.x, 0.85, p.y), Vector3(0.8, 1.7, 1.0))
	return m


func _slab(m: MB, x: int, z: int, sw: int, sd: int, y: float, top_c: Color, bot_c: Color, side_c: Color) -> void:
	if sw <= 0 or sd <= 0:
		return
	var c := Vector3(x + sw * 0.5, y - 0.1, z + sd * 0.5)
	var s := Vector3(sw, 0.2, sd)
	m.box6(c, s, [top_c, bot_c, side_c, side_c, side_c, side_c])
	_col(c, s)


## cores por face de uma parede: [+Y, -Y, +Z, -Z, +X, -X]; faces externas usam a cor da fachada
func _wall_cols(x: int, z: int, horiz: bool) -> Array:
	var a := c_int
	var cols := [a, a, a, a, a, a]
	if horiz:
		if z == 0:
			cols[3] = c_ext
		elif z == d - 1:
			cols[2] = c_ext
	else:
		if x == 0:
			cols[5] = c_ext
		elif x == w - 1:
			cols[4] = c_ext
	return cols


func _walls(m: MB, f: int, y0: float) -> void:
	var hy := y0 + WH * 0.5
	# trechos horizontais (ao longo de X)
	for z in d:
		var x := 0
		while x < w:
			if tg(f, x, z) != T_WALL or not (_wl(f, x - 1, z) or _wl(f, x + 1, z)):
				x += 1
				continue
			var xa := x
			while x + 1 < w and tg(f, x + 1, z) == T_WALL:
				x += 1
			var xb := x
			var s := float(xa) if (tg(f, xa - 1, z) == T_DOOR or tg(f, xa - 1, z) == T_WIN) else xa + 0.4
			var e := float(xb + 1) if (tg(f, xb + 1, z) == T_DOOR or tg(f, xb + 1, z) == T_WIN) else xb + 0.6
			var c := Vector3((s + e) * 0.5, hy, z + 0.5)
			var sz := Vector3(e - s, WH, 0.2)
			m.box6(c, sz, _wall_cols(xa, z, true), 4 | 8 | 16 | 32)
			_col(c, sz)
			x += 1
	# trechos verticais (ao longo de Z)
	for x2 in w:
		var z2 := 0
		while z2 < d:
			if tg(f, x2, z2) != T_WALL or not (_wl(f, x2, z2 - 1) or _wl(f, x2, z2 + 1)):
				z2 += 1
				continue
			var za := z2
			while z2 + 1 < d and tg(f, x2, z2 + 1) == T_WALL:
				z2 += 1
			var zb2 := z2
			var s2 := float(za) if (tg(f, x2, za - 1) == T_DOOR or tg(f, x2, za - 1) == T_WIN) else za + 0.4
			var e2 := float(zb2 + 1) if (tg(f, x2, zb2 + 1) == T_DOOR or tg(f, x2, zb2 + 1) == T_WIN) else zb2 + 0.6
			var c2 := Vector3(x2 + 0.5, hy, (s2 + e2) * 0.5)
			var sz2 := Vector3(0.2, WH, e2 - s2)
			m.box6(c2, sz2, _wall_cols(x2, za, false), 4 | 8 | 16 | 32)
			_col(c2, sz2)
			z2 += 1


func furn_basis(rot: int) -> Basis:
	return Basis(Vector3.UP, [0.0, PI * 0.5, PI, -PI * 0.5][rot])


func _furn_mesh(m: MB, fu: Dictionary, y0: float) -> void:
	var fd: Dictionary = FURN[fu["id"]]
	var t := Transform3D(furn_basis(fu["rot"]), Vector3(fu["x"], y0 + 0.06, fu["z"]))
	for b in fd["b"]:
		var col: Color = b[6]
		if col == FAB:
			col = c_fab
		if fu["rot"] == 0 and true:
			m.box(t.origin + Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), col)
		else:
			m.box_t(t * Transform3D(Basis.IDENTITY, Vector3(b[0], b[1], b[2])), Vector3(b[3], b[4], b[5]), col)
	var fw: float = float(fd["w"])
	var h: float = fd["h"]
	var sz := Vector3(fw * 0.94, h, 0.9)
	if fu["rot"] == 1 or fu["rot"] == 3:
		sz = Vector3(0.9, h, fw * 0.94)
	if fu["id"] != "cela_grade":
		_col(Vector3(fu["x"], y0 + h * 0.5, fu["z"]), sz)
