class_name Items
extends RefCounted
## Catalogo de itens (dados proprios do projeto). Sem itens de caca, pesca ou manejo animal.
## Chaves: n nome, w peso, cat categoria, st pilha maxima.

const D := {
	# ------------------------------------------------------------ comida pereciveis (fresh/rot em dias)
	"maca": {"n": "Maçã", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.10, "thi": 0.04, "cal": 95, "pro": 0, "fresh": 5, "rot": 8, "unh": -0.02},
	"banana": {"n": "Banana", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.10, "thi": 0.02, "cal": 105, "pro": 1, "fresh": 4, "rot": 7, "unh": -0.02},
	"laranja": {"n": "Laranja", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.08, "thi": 0.08, "cal": 62, "pro": 1, "fresh": 6, "rot": 10, "unh": -0.02},
	"tomate": {"n": "Tomate", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.08, "thi": 0.05, "cal": 22, "pro": 1, "fresh": 5, "rot": 8, "veg": 1},
	"alface": {"n": "Alface", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.07, "thi": 0.04, "cal": 15, "pro": 1, "fresh": 4, "rot": 6, "veg": 1},
	"batata": {"n": "Batata", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.12, "cal": 160, "pro": 4, "fresh": 14, "rot": 28, "veg": 1, "cook": 1},
	"cenoura": {"n": "Cenoura", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.08, "thi": 0.02, "cal": 30, "pro": 1, "fresh": 10, "rot": 18, "veg": 1},
	"repolho": {"n": "Repolho", "w": 0.6, "cat": "Comida", "st": 5, "hun": 0.22, "thi": 0.05, "cal": 110, "pro": 5, "fresh": 6, "rot": 10, "veg": 1},
	"milho": {"n": "Espiga de milho", "w": 0.3, "cat": "Comida", "st": 10, "hun": 0.12, "cal": 125, "pro": 4, "fresh": 6, "rot": 10, "veg": 1, "cook": 1},
	"morango": {"n": "Morangos", "w": 0.1, "cat": "Comida", "st": 20, "hun": 0.05, "thi": 0.03, "cal": 12, "pro": 0, "fresh": 3, "rot": 5, "unh": -0.03},
	"abobora": {"n": "Abóbora", "w": 1.2, "cat": "Comida", "st": 3, "hun": 0.30, "thi": 0.04, "cal": 180, "pro": 6, "fresh": 20, "rot": 40, "veg": 1, "cook": 1},
	"feijao_verde": {"n": "Vagem", "w": 0.1, "cat": "Comida", "st": 20, "hun": 0.05, "cal": 20, "pro": 2, "fresh": 5, "rot": 9, "veg": 1},
	"pao": {"n": "Pão", "w": 0.4, "cat": "Comida", "st": 4, "hun": 0.20, "cal": 340, "pro": 12, "fresh": 3, "rot": 6},
	"queijo": {"n": "Queijo", "w": 0.3, "cat": "Comida", "st": 4, "hun": 0.15, "cal": 330, "pro": 20, "fresh": 8, "rot": 14},
	"presunto": {"n": "Presunto fatiado", "w": 0.3, "cat": "Comida", "st": 4, "hun": 0.15, "cal": 180, "pro": 22, "fresh": 5, "rot": 8},
	"ovos": {"n": "Caixa de ovos", "w": 0.4, "cat": "Comida", "st": 2, "hun": 0.18, "cal": 430, "pro": 36, "fresh": 10, "rot": 18, "raw": 1, "cook": 1},
	"leite": {"n": "Caixa de leite", "w": 1.0, "cat": "Bebida", "st": 2, "hun": 0.08, "thi": 0.30, "cal": 600, "pro": 32, "fresh": 5, "rot": 8},
	"bife": {"n": "Bife embalado", "w": 0.4, "cat": "Comida", "st": 4, "hun": 0.30, "cal": 460, "pro": 50, "fresh": 3, "rot": 5, "raw": 1, "cook": 1},
	"frango": {"n": "Frango embalado", "w": 0.5, "cat": "Comida", "st": 4, "hun": 0.32, "cal": 390, "pro": 55, "fresh": 3, "rot": 5, "raw": 1, "cook": 1},
	"manteiga": {"n": "Manteiga", "w": 0.2, "cat": "Comida", "st": 4, "hun": 0.06, "cal": 720, "pro": 1, "fresh": 20, "rot": 40, "unh": 0.03},
	# ------------------------------------------------------------ comida nao perecivel
	"feijao_lata": {"n": "Feijão em lata", "w": 0.5, "cat": "Comida", "st": 6, "hun": 0.28, "cal": 380, "pro": 22, "can": 1, "unh": 0.02},
	"milho_lata": {"n": "Milho em lata", "w": 0.4, "cat": "Comida", "st": 6, "hun": 0.20, "cal": 240, "pro": 7, "can": 1},
	"atum_lata": {"n": "Atum em lata", "w": 0.3, "cat": "Comida", "st": 6, "hun": 0.18, "cal": 220, "pro": 40, "can": 1},
	"sardinha_lata": {"n": "Sardinha em lata", "w": 0.2, "cat": "Comida", "st": 6, "hun": 0.14, "cal": 190, "pro": 24},
	"sopa_lata": {"n": "Sopa em lata", "w": 0.5, "cat": "Comida", "st": 6, "hun": 0.24, "thi": 0.06, "cal": 210, "pro": 8, "can": 1, "unh": -0.01},
	"ervilha_lata": {"n": "Ervilha em lata", "w": 0.4, "cat": "Comida", "st": 6, "hun": 0.18, "cal": 200, "pro": 12, "can": 1},
	"pessego_lata": {"n": "Pêssego em calda", "w": 0.5, "cat": "Comida", "st": 6, "hun": 0.18, "thi": 0.06, "cal": 300, "pro": 2, "can": 1, "unh": -0.05},
	"macarrao": {"n": "Macarrão cru", "w": 0.5, "cat": "Comida", "st": 4, "hun": 0.10, "cal": 1750, "pro": 60, "unh": 0.08, "dry": 1},
	"arroz": {"n": "Arroz cru", "w": 1.0, "cat": "Comida", "st": 3, "hun": 0.10, "cal": 3600, "pro": 70, "unh": 0.10, "dry": 1},
	"feijao_seco": {"n": "Feijão seco", "w": 1.0, "cat": "Comida", "st": 3, "hun": 0.10, "cal": 3300, "pro": 210, "unh": 0.10, "dry": 1},
	"cereal": {"n": "Cereal matinal", "w": 0.3, "cat": "Comida", "st": 4, "hun": 0.20, "cal": 1100, "pro": 20, "unh": -0.02},
	"biscoito": {"n": "Biscoitos", "w": 0.2, "cat": "Comida", "st": 6, "hun": 0.12, "cal": 480, "pro": 6, "unh": -0.04},
	"chips": {"n": "Batata chips", "w": 0.15, "cat": "Comida", "st": 6, "hun": 0.10, "thi": -0.04, "cal": 540, "pro": 6, "unh": -0.05},
	"chocolate": {"n": "Chocolate", "w": 0.1, "cat": "Comida", "st": 10, "hun": 0.08, "cal": 530, "pro": 7, "unh": -0.10},
	"barra_cereal": {"n": "Barra de cereal", "w": 0.1, "cat": "Comida", "st": 10, "hun": 0.08, "cal": 190, "pro": 4, "unh": -0.02},
	"amendoim": {"n": "Amendoim", "w": 0.2, "cat": "Comida", "st": 6, "hun": 0.12, "thi": -0.03, "cal": 830, "pro": 35},
	"miojo": {"n": "Macarrão instantâneo", "w": 0.1, "cat": "Comida", "st": 10, "hun": 0.14, "thi": -0.04, "cal": 380, "pro": 8, "unh": 0.02},
	"pasta_amendoim": {"n": "Pasta de amendoim", "w": 0.4, "cat": "Comida", "st": 4, "hun": 0.22, "cal": 2200, "pro": 90},
	"farinha": {"n": "Farinha de trigo", "w": 1.0, "cat": "Comida", "st": 3, "hun": 0.05, "cal": 3600, "pro": 100, "unh": 0.15, "dry": 1},
	"acucar": {"n": "Açúcar", "w": 1.0, "cat": "Comida", "st": 3, "hun": 0.04, "cal": 3900, "pro": 0, "unh": 0.05, "dry": 1},
	"sal": {"n": "Sal", "w": 0.5, "cat": "Comida", "st": 3, "hun": 0.0, "thi": -0.2, "cal": 0, "pro": 0, "unh": 0.2, "dry": 1},
	"vinagre": {"n": "Vinagre", "w": 0.8, "cat": "Comida", "st": 3, "hun": 0.0, "thi": 0.05, "cal": 20, "pro": 0, "unh": 0.25},
	"cafe": {"n": "Café solúvel", "w": 0.2, "cat": "Comida", "st": 4, "hun": 0.0, "cal": 5, "pro": 0, "fat": -0.12, "unh": 0.05},
	"frutas_silvestres": {"n": "Frutas silvestres", "w": 0.1, "cat": "Comida", "st": 20, "hun": 0.06, "thi": 0.03, "cal": 45, "pro": 0, "fresh": 3, "rot": 5},
	"cogumelo": {"n": "Cogumelos do mato", "w": 0.1, "cat": "Comida", "st": 20, "hun": 0.06, "cal": 20, "pro": 2, "fresh": 3, "rot": 5, "poison": 0.25, "veg": 1},
	"raiz": {"n": "Raiz comestível", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.09, "cal": 90, "pro": 1, "fresh": 10, "rot": 20, "veg": 1, "unh": 0.03},
	"nozes": {"n": "Castanhas", "w": 0.1, "cat": "Comida", "st": 20, "hun": 0.07, "cal": 180, "pro": 4},
	# ------------------------------------------------------------ pratos preparados
	"ensopado": {"n": "Ensopado", "w": 1.0, "cat": "Comida", "st": 1, "hun": 0.55, "thi": 0.15, "cal": 700, "pro": 30, "fresh": 3, "rot": 5, "unh": -0.12, "bor": -0.1},
	"sopa": {"n": "Sopa de legumes", "w": 1.0, "cat": "Comida", "st": 1, "hun": 0.42, "thi": 0.25, "cal": 420, "pro": 14, "fresh": 3, "rot": 5, "unh": -0.10},
	"salada": {"n": "Salada", "w": 0.5, "cat": "Comida", "st": 1, "hun": 0.28, "thi": 0.10, "cal": 160, "pro": 5, "fresh": 2, "rot": 3, "unh": -0.08},
	"arroz_cozido": {"n": "Arroz cozido", "w": 0.8, "cat": "Comida", "st": 2, "hun": 0.40, "cal": 900, "pro": 18, "fresh": 3, "rot": 5},
	"feijao_cozido": {"n": "Feijão cozido", "w": 0.8, "cat": "Comida", "st": 2, "hun": 0.42, "cal": 820, "pro": 52, "fresh": 3, "rot": 5, "unh": -0.04},
	"macarrao_cozido": {"n": "Macarrão cozido", "w": 0.8, "cat": "Comida", "st": 2, "hun": 0.42, "cal": 870, "pro": 30, "fresh": 3, "rot": 5, "unh": -0.04},
	"carne_assada": {"n": "Carne assada", "w": 0.4, "cat": "Comida", "st": 2, "hun": 0.40, "cal": 520, "pro": 55, "fresh": 3, "rot": 5, "unh": -0.10},
	"legumes_assados": {"n": "Legumes assados", "w": 0.5, "cat": "Comida", "st": 2, "hun": 0.34, "cal": 330, "pro": 9, "fresh": 3, "rot": 5, "unh": -0.06},
	"pao_caseiro": {"n": "Pão caseiro", "w": 0.5, "cat": "Comida", "st": 2, "hun": 0.30, "cal": 900, "pro": 26, "fresh": 4, "rot": 7, "unh": -0.08},
	"conserva": {"n": "Pote de conserva", "w": 0.8, "cat": "Comida", "st": 4, "hun": 0.26, "thi": 0.04, "cal": 260, "pro": 6, "unh": -0.02},
	"legumes_secos": {"n": "Legumes desidratados", "w": 0.2, "cat": "Comida", "st": 10, "hun": 0.14, "thi": -0.05, "cal": 190, "pro": 5},
	# ------------------------------------------------------------ bebidas e recipientes de liquido
	"garrafa_agua": {"n": "Garrafa d'água", "w": 0.1, "cat": "Recipiente", "cap": 1.0, "fill": "agua"},
	"garrafa_vazia": {"n": "Garrafa vazia", "w": 0.1, "cat": "Recipiente", "cap": 1.0},
	"cantil": {"n": "Cantil", "w": 0.2, "cat": "Recipiente", "cap": 1.5},
	"panela": {"n": "Panela", "w": 1.0, "cat": "Recipiente", "cap": 3.0, "tags": ["panela"]},
	"balde": {"n": "Balde", "w": 0.8, "cat": "Recipiente", "cap": 10.0},
	"regador": {"n": "Regador", "w": 0.6, "cat": "Recipiente", "cap": 5.0, "tags": ["regador"]},
	"galao": {"n": "Galão de combustível", "w": 1.0, "cat": "Recipiente", "cap": 10.0, "fuel": 1},
	"pote_vidro": {"n": "Pote de vidro com tampa", "w": 0.2, "cat": "Recipiente", "st": 6},
	"refrigerante": {"n": "Refrigerante", "w": 0.4, "cat": "Bebida", "st": 6, "thi": 0.22, "cal": 150, "pro": 0, "unh": -0.05, "hun": 0.03},
	"suco": {"n": "Suco de caixinha", "w": 0.3, "cat": "Bebida", "st": 6, "thi": 0.22, "cal": 110, "pro": 1, "unh": -0.03, "hun": 0.03},
	"cerveja": {"n": "Cerveja", "w": 0.4, "cat": "Bebida", "st": 6, "thi": 0.12, "cal": 150, "pro": 1, "alc": 0.2, "unh": -0.06, "hun": 0.02},
	"uisque": {"n": "Garrafa de uísque", "w": 0.7, "cat": "Bebida", "st": 1, "thi": 0.05, "cal": 240, "pro": 0, "alc": 0.45, "unh": -0.10, "hun": 0.0, "uses": 6, "med": "desinfetar"},
	# ------------------------------------------------------------ medico
	"atadura": {"n": "Atadura", "w": 0.05, "cat": "Médico", "st": 10, "med": "atadura"},
	"atadura_suja": {"n": "Atadura suja", "w": 0.05, "cat": "Médico", "st": 10, "med": "atadura", "dirty": 1},
	"pano": {"n": "Pano rasgado", "w": 0.05, "cat": "Médico", "st": 20, "med": "atadura", "weak": 1},
	"pano_sujo": {"n": "Pano sujo", "w": 0.05, "cat": "Médico", "st": 20, "med": "atadura", "weak": 1, "dirty": 1},
	"alcool": {"n": "Álcool antisséptico", "w": 0.3, "cat": "Médico", "st": 1, "med": "desinfetar", "uses": 8},
	"analgesico": {"n": "Analgésico", "w": 0.1, "cat": "Médico", "st": 1, "med": "analgesico", "uses": 10},
	"antibiotico": {"n": "Antibiótico", "w": 0.1, "cat": "Médico", "st": 1, "med": "antibiotico", "uses": 6},
	"antidepressivo": {"n": "Antidepressivo", "w": 0.1, "cat": "Médico", "st": 1, "med": "antidepressivo", "uses": 10},
	"betabloqueador": {"n": "Betabloqueador", "w": 0.1, "cat": "Médico", "st": 1, "med": "betabloqueador", "uses": 10},
	"sonifero": {"n": "Sonífero", "w": 0.1, "cat": "Médico", "st": 1, "med": "sonifero", "uses": 10},
	"vitaminas": {"n": "Vitaminas", "w": 0.1, "cat": "Médico", "st": 1, "med": "vitaminas", "uses": 10},
	"kit_sutura": {"n": "Agulha de sutura", "w": 0.05, "cat": "Médico", "st": 5, "med": "sutura"},
	"pinca": {"n": "Pinça", "w": 0.05, "cat": "Médico", "st": 1, "tags": ["pinca"]},
	"tala": {"n": "Tala", "w": 0.4, "cat": "Médico", "st": 2, "med": "tala"},
	"cataplasma": {"n": "Cataplasma de ervas", "w": 0.1, "cat": "Médico", "st": 5, "med": "cataplasma"},
	"ervas": {"n": "Ervas medicinais", "w": 0.05, "cat": "Médico", "st": 20},
	"cigarros": {"n": "Cigarros", "w": 0.05, "cat": "Diversos", "st": 1, "med": "cigarro", "uses": 20},
	# ------------------------------------------------------------ armas brancas
	"taco": {"n": "Taco de beisebol", "w": 1.5, "cat": "Arma", "wt": "contundente_longo", "dmg": [44, 62], "rng": 1.35, "spd": 0.78, "sta": 0.055, "brk": 22, "hits": 2, "kb": 1.0, "two": 1, "anim": "swing_side", "mdl": "bat"},
	"taco_pregos": {"n": "Taco com pregos", "w": 1.6, "cat": "Arma", "wt": "contundente_longo", "dmg": [55, 80], "rng": 1.35, "spd": 0.80, "sta": 0.058, "brk": 14, "hits": 2, "kb": 0.9, "two": 1, "anim": "swing_side", "mdl": "bat_nails"},
	"tabua": {"n": "Tábua", "w": 1.5, "cat": "Material", "st": 4, "wt": "contundente_longo", "dmg": [26, 40], "rng": 1.3, "spd": 0.82, "sta": 0.06, "brk": 5, "hits": 1, "kb": 0.8, "two": 1, "anim": "swing_side", "mdl": "plank"},
	"pe_de_cabra": {"n": "Pé de cabra", "w": 2.0, "cat": "Arma", "wt": "contundente_longo", "dmg": [34, 64], "rng": 1.25, "spd": 0.84, "sta": 0.06, "brk": 70, "hits": 1, "kb": 1.0, "two": 1, "anim": "swing_side", "mdl": "crowbar", "tags": ["pe_de_cabra"]},
	"cano": {"n": "Cano de metal", "w": 1.5, "cat": "Arma", "wt": "contundente_curto", "dmg": [30, 52], "rng": 1.15, "spd": 0.70, "sta": 0.045, "brk": 30, "hits": 1, "kb": 0.8, "anim": "swing_side", "mdl": "pipe"},
	"martelo": {"n": "Martelo", "w": 1.0, "cat": "Ferramenta", "wt": "contundente_curto", "dmg": [28, 55], "rng": 1.0, "spd": 0.66, "sta": 0.04, "brk": 40, "hits": 1, "kb": 0.6, "anim": "swing_over", "mdl": "hammer", "tags": ["martelo"]},
	"marreta": {"n": "Marreta", "w": 6.0, "cat": "Ferramenta", "wt": "contundente_longo", "dmg": [110, 190], "rng": 1.35, "spd": 1.35, "sta": 0.12, "brk": 60, "hits": 2, "kb": 2.0, "two": 1, "anim": "swing_over", "mdl": "sledge", "tags": ["marreta"]},
	"chave_inglesa": {"n": "Chave inglesa", "w": 1.0, "cat": "Ferramenta", "wt": "contundente_curto", "dmg": [24, 46], "rng": 0.95, "spd": 0.64, "sta": 0.04, "brk": 50, "hits": 1, "kb": 0.6, "anim": "swing_side", "mdl": "wrench", "tags": ["chave_inglesa"]},
	"frigideira": {"n": "Frigideira", "w": 1.0, "cat": "Ferramenta", "wt": "contundente_curto", "dmg": [22, 44], "rng": 0.95, "spd": 0.66, "sta": 0.04, "brk": 25, "hits": 1, "kb": 0.7, "anim": "swing_side", "mdl": "pan", "tags": ["frigideira"]},
	"machado": {"n": "Machado", "w": 3.0, "cat": "Arma", "wt": "machado", "dmg": [48, 115], "rng": 1.3, "spd": 0.95, "sta": 0.075, "brk": 35, "hits": 2, "kb": 1.1, "two": 1, "anim": "swing_over", "mdl": "axe", "tags": ["machado"], "sharp": 1},
	"machadinha": {"n": "Machadinha", "w": 1.2, "cat": "Arma", "wt": "machado", "dmg": [36, 70], "rng": 1.0, "spd": 0.68, "sta": 0.045, "brk": 30, "hits": 1, "kb": 0.7, "anim": "swing_over", "mdl": "hatchet", "tags": ["machado"], "sharp": 1},
	"machado_pedra": {"n": "Machado de pedra", "w": 1.4, "cat": "Arma", "wt": "machado", "dmg": [24, 50], "rng": 1.0, "spd": 0.74, "sta": 0.05, "brk": 9, "hits": 1, "kb": 0.7, "anim": "swing_over", "mdl": "stone_axe", "tags": ["machado"]},
	"faca_cozinha": {"n": "Faca de cozinha", "w": 0.3, "cat": "Arma", "wt": "lamina_curta", "dmg": [14, 40], "rng": 0.85, "spd": 0.52, "sta": 0.025, "brk": 6, "hits": 1, "kb": 0.2, "anim": "stab", "mdl": "knife", "tags": ["faca"], "sharp": 1, "crit": 0.25},
	"faca_caca": {"n": "Faca de combate", "w": 0.4, "cat": "Arma", "wt": "lamina_curta", "dmg": [20, 58], "rng": 0.9, "spd": 0.50, "sta": 0.025, "brk": 18, "hits": 1, "kb": 0.2, "anim": "stab", "mdl": "knife", "tags": ["faca"], "sharp": 1, "crit": 0.35},
	"facao": {"n": "Facão", "w": 1.2, "cat": "Arma", "wt": "lamina_longa", "dmg": [62, 120], "rng": 1.2, "spd": 0.66, "sta": 0.045, "brk": 28, "hits": 2, "kb": 0.5, "anim": "swing_side", "mdl": "machete", "tags": ["faca"], "sharp": 1, "crit": 0.2},
	"chave_fenda": {"n": "Chave de fenda", "w": 0.3, "cat": "Ferramenta", "wt": "lamina_curta", "dmg": [12, 30], "rng": 0.85, "spd": 0.52, "sta": 0.025, "brk": 12, "hits": 1, "kb": 0.2, "anim": "stab", "mdl": "screwdriver", "tags": ["chave_fenda"], "crit": 0.2},
	"lanca": {"n": "Lança de madeira", "w": 1.5, "cat": "Arma", "wt": "lanca", "dmg": [34, 66], "rng": 1.95, "spd": 0.72, "sta": 0.05, "brk": 5, "hits": 1, "kb": 0.6, "two": 1, "anim": "stab", "mdl": "spear", "crit": 0.3},
	"lanca_faca": {"n": "Lança com faca", "w": 1.8, "cat": "Arma", "wt": "lanca", "dmg": [48, 90], "rng": 1.95, "spd": 0.72, "sta": 0.05, "brk": 7, "hits": 1, "kb": 0.6, "two": 1, "anim": "stab", "mdl": "spear", "crit": 0.35},
	"pa": {"n": "Pá", "w": 2.5, "cat": "Ferramenta", "wt": "contundente_longo", "dmg": [32, 62], "rng": 1.35, "spd": 0.92, "sta": 0.065, "brk": 40, "hits": 1, "kb": 1.0, "two": 1, "anim": "swing_side", "mdl": "shovel", "tags": ["pa"]},
	"enxada": {"n": "Enxada", "w": 2.0, "cat": "Ferramenta", "wt": "contundente_longo", "dmg": [30, 58], "rng": 1.35, "spd": 0.9, "sta": 0.06, "brk": 30, "hits": 1, "kb": 0.8, "two": 1, "anim": "swing_over", "mdl": "hoe", "tags": ["enxada"]},
	# ------------------------------------------------------------ armas de fogo e municao
	"pistola": {"n": "Pistola 9 mm", "w": 1.2, "cat": "Arma", "gun": 1, "ammo": "mun_9mm", "mag": 15, "dmg": [58, 98], "rng": 28.0, "spr": 2.2, "noise": 55.0, "rof": 0.32, "rl": "mag", "mdl": "gun_pistol", "snd": "gun_pistol", "brk": 90},
	"revolver": {"n": "Revólver .38", "w": 1.3, "cat": "Arma", "gun": 1, "ammo": "mun_38", "mag": 6, "dmg": [70, 112], "rng": 26.0, "spr": 2.6, "noise": 60.0, "rof": 0.5, "rl": "cyl", "mdl": "gun_revolver", "snd": "gun_revolver", "brk": 140},
	"espingarda": {"n": "Espingarda calibre 12", "w": 3.5, "cat": "Arma", "gun": 1, "two": 1, "ammo": "cartucho_12", "mag": 6, "dmg": [95, 170], "rng": 16.0, "spr": 7.5, "pellets": 5, "noise": 95.0, "rof": 0.95, "rl": "shell", "mdl": "gun_shotgun", "snd": "gun_shotgun", "brk": 110},
	"rifle": {"n": "Rifle de ferrolho .308", "w": 4.0, "cat": "Arma", "gun": 1, "two": 1, "ammo": "mun_308", "mag": 5, "dmg": [150, 260], "rng": 70.0, "spr": 0.9, "noise": 105.0, "rof": 1.5, "rl": "bolt", "mdl": "gun_rifle", "snd": "gun_rifle", "brk": 130},
	"carabina": {"n": "Carabina semiautomática", "w": 3.2, "cat": "Arma", "gun": 1, "two": 1, "ammo": "mun_9mm", "mag": 20, "dmg": [66, 108], "rng": 45.0, "spr": 1.4, "noise": 70.0, "rof": 0.24, "rl": "mag", "mdl": "gun_carbine", "snd": "gun_pistol", "brk": 100},
	"mun_9mm": {"n": "Munição 9 mm", "w": 0.012, "cat": "Munição", "st": 60},
	"mun_38": {"n": "Munição .38", "w": 0.015, "cat": "Munição", "st": 60},
	"cartucho_12": {"n": "Cartucho calibre 12", "w": 0.05, "cat": "Munição", "st": 24},
	"mun_308": {"n": "Munição .308", "w": 0.025, "cat": "Munição", "st": 40},
	"kit_limpeza": {"n": "Kit de limpeza de armas", "w": 0.5, "cat": "Ferramenta", "uses": 5, "tags": ["limpeza_arma"]},
	"molotov": {"n": "Coquetel incendiário", "w": 0.8, "cat": "Arma", "st": 3, "throw": "fogo"},
	"chamariz": {"n": "Despertador de distração", "w": 0.4, "cat": "Arma", "st": 3, "throw": "ruido"},
	# ------------------------------------------------------------ ferramentas
	"serrote": {"n": "Serrote", "w": 0.8, "cat": "Ferramenta", "tags": ["serrote"], "mdl": "saw"},
	"macaco": {"n": "Macaco hidráulico", "w": 3.0, "cat": "Ferramenta", "tags": ["macaco"]},
	"chave_roda": {"n": "Chave de roda", "w": 1.0, "cat": "Ferramenta", "tags": ["chave_roda"]},
	"abridor": {"n": "Abridor de latas", "w": 0.1, "cat": "Ferramenta", "tags": ["abridor"]},
	"isqueiro": {"n": "Isqueiro", "w": 0.05, "cat": "Ferramenta", "tags": ["fogo"], "uses": 60},
	"fosforos": {"n": "Fósforos", "w": 0.05, "cat": "Ferramenta", "tags": ["fogo"], "uses": 20},
	"lanterna": {"n": "Lanterna", "w": 0.4, "cat": "Ferramenta", "tags": ["lanterna"], "mdl": "flashlight", "light": 1},
	"pazinha": {"n": "Pazinha de jardim", "w": 0.3, "cat": "Ferramenta", "tags": ["pa"]},
	"tesoura": {"n": "Tesoura", "w": 0.2, "cat": "Ferramenta", "tags": ["tesoura"]},
	"agulha": {"n": "Agulha de costura", "w": 0.02, "cat": "Ferramenta", "tags": ["agulha"]},
	"alicate": {"n": "Alicate", "w": 0.3, "cat": "Ferramenta", "tags": ["alicate"]},
	"mangueira": {"n": "Mangueira de borracha", "w": 0.5, "cat": "Ferramenta", "tags": ["mangueira"]},
	"pedra_amolar": {"n": "Pedra de amolar", "w": 0.4, "cat": "Ferramenta", "tags": ["amolar"], "uses": 12},
	"macarico": {"n": "Maçarico", "w": 1.5, "cat": "Ferramenta", "tags": ["macarico"], "uses": 20},
	"mascara_solda": {"n": "Máscara de solda", "w": 1.0, "cat": "Ferramenta", "tags": ["mascara_solda"]},
	"colher_pedreiro": {"n": "Colher de pedreiro", "w": 0.3, "cat": "Ferramenta", "tags": ["colher_pedreiro"]},
	"formao": {"n": "Formão de entalhe", "w": 0.3, "cat": "Ferramenta", "tags": ["formao"]},
	# ------------------------------------------------------------ materiais
	"tronco": {"n": "Tronco", "w": 9.0, "cat": "Material", "st": 2, "mdl": "log"},
	"galho": {"n": "Galho firme", "w": 0.8, "cat": "Material", "st": 6},
	"graveto": {"n": "Gravetos", "w": 0.1, "cat": "Material", "st": 20},
	"pregos": {"n": "Pregos", "w": 0.01, "cat": "Material", "st": 200},
	"parafusos": {"n": "Parafusos", "w": 0.01, "cat": "Material", "st": 200},
	"sucata": {"n": "Sucata de metal", "w": 0.5, "cat": "Material", "st": 10},
	"chapa_metal": {"n": "Chapa de metal", "w": 2.0, "cat": "Material", "st": 4},
	"barra_metal": {"n": "Barra de metal", "w": 1.5, "cat": "Material", "st": 4},
	"fio": {"n": "Fio elétrico", "w": 0.1, "cat": "Material", "st": 20},
	"sucata_eletronica": {"n": "Sucata eletrônica", "w": 0.1, "cat": "Material", "st": 20},
	"corda": {"n": "Corda", "w": 0.5, "cat": "Material", "st": 4},
	"corda_lencol": {"n": "Corda de lençóis", "w": 0.6, "cat": "Material", "st": 4},
	"lencol": {"n": "Lençol", "w": 0.3, "cat": "Material", "st": 4},
	"linha": {"n": "Linha de costura", "w": 0.02, "cat": "Material", "st": 1, "uses": 10},
	"retalho_couro": {"n": "Retalhos de couro", "w": 0.1, "cat": "Material", "st": 20},
	"retalho_jeans": {"n": "Retalhos de jeans", "w": 0.05, "cat": "Material", "st": 20},
	"fibra": {"n": "Fibra vegetal", "w": 0.05, "cat": "Material", "st": 40},
	"pedra": {"n": "Pedra", "w": 0.8, "cat": "Material", "st": 6},
	"pedra_lascada": {"n": "Pedra lascada", "w": 0.3, "cat": "Material", "st": 6, "tags": ["faca"]},
	"argila": {"n": "Argila", "w": 1.0, "cat": "Material", "st": 6},
	"tijolo": {"n": "Tijolo", "w": 1.2, "cat": "Material", "st": 8},
	"cimento": {"n": "Saco de cimento", "w": 5.0, "cat": "Material", "st": 1, "uses": 6},
	"carvao": {"n": "Carvão", "w": 0.5, "cat": "Material", "st": 8},
	"fertilizante": {"n": "Fertilizante", "w": 1.0, "cat": "Material", "st": 2, "uses": 4},
	"adubo": {"n": "Adubo orgânico", "w": 1.0, "cat": "Material", "st": 4},
	"saco_lixo": {"n": "Saco plástico grande", "w": 0.05, "cat": "Material", "st": 10},
	"fita": {"n": "Fita adesiva", "w": 0.1, "cat": "Material", "st": 1, "uses": 6},
	"cola": {"n": "Cola de madeira", "w": 0.2, "cat": "Material", "st": 1, "uses": 5},
	"pilha": {"n": "Pilha", "w": 0.05, "cat": "Material", "st": 8},
	"lampada": {"n": "Lâmpada", "w": 0.05, "cat": "Material", "st": 6},
	"jornal": {"n": "Jornal velho", "w": 0.1, "cat": "Literatura", "st": 5, "read": {"bor": -0.10, "min": 20}},
	"revista": {"n": "Revista", "w": 0.1, "cat": "Literatura", "st": 5, "read": {"bor": -0.20, "unh": -0.05, "min": 30}},
	"romance": {"n": "Livro de romance", "w": 0.5, "cat": "Literatura", "st": 2, "read": {"bor": -0.45, "unh": -0.15, "stress": -0.2, "min": 90}},
	# ------------------------------------------------------------ livros tecnicos e revistas de receitas
	"livro_carpintaria": {"n": "Carpintaria para iniciantes", "w": 0.6, "cat": "Literatura", "skill": "carpintaria", "lv": [0, 4], "pages": 220},
	"livro_carpintaria2": {"n": "Carpintaria avançada", "w": 0.6, "cat": "Literatura", "skill": "carpintaria", "lv": [4, 8], "pages": 300},
	"livro_culinaria": {"n": "Cozinha do dia a dia", "w": 0.6, "cat": "Literatura", "skill": "culinaria", "lv": [0, 4], "pages": 220},
	"livro_mecanica": {"n": "Mecânica básica", "w": 0.6, "cat": "Literatura", "skill": "mecanica", "lv": [0, 4], "pages": 220},
	"livro_mecanica2": {"n": "Mecânica avançada", "w": 0.6, "cat": "Literatura", "skill": "mecanica", "lv": [4, 8], "pages": 300},
	"livro_agricultura": {"n": "Horta em casa", "w": 0.6, "cat": "Literatura", "skill": "agricultura", "lv": [0, 4], "pages": 220},
	"livro_socorros": {"n": "Primeiros socorros", "w": 0.6, "cat": "Literatura", "skill": "socorros", "lv": [0, 4], "pages": 220},
	"livro_eletrica": {"n": "Eletricidade prática", "w": 0.6, "cat": "Literatura", "skill": "eletrica", "lv": [0, 4], "pages": 220},
	"livro_costura": {"n": "Corte e costura", "w": 0.6, "cat": "Literatura", "skill": "costura", "lv": [0, 4], "pages": 220},
	"livro_coleta": {"n": "Plantas do mato", "w": 0.6, "cat": "Literatura", "skill": "coleta", "lv": [0, 4], "pages": 220},
	"livro_metal": {"n": "Solda e serralheria", "w": 0.6, "cat": "Literatura", "skill": "metalurgia", "lv": [0, 4], "pages": 220},
	"revista_gerador": {"n": "Revista: Geradores sem mistério", "w": 0.1, "cat": "Literatura", "teach": ["usar_gerador"], "pages": 40},
	"revista_ligacao": {"n": "Revista: Elétrica automotiva", "w": 0.1, "cat": "Literatura", "teach": ["ligacao_direta"], "pages": 40},
	"revista_conservas": {"n": "Revista: Conservas caseiras", "w": 0.1, "cat": "Literatura", "teach": ["conserva", "legumes_secos"], "pages": 40},
	"revista_armadilhas": {"n": "Revista: Distrações e alarmes", "w": 0.1, "cat": "Literatura", "teach": ["chamariz"], "pages": 40},
	"revista_ervas": {"n": "Revista: Ervas que curam", "w": 0.1, "cat": "Literatura", "teach": ["cataplasma"], "pages": 40},
	"mapa_sa": {"n": "Mapa de Santa Aurora", "w": 0.05, "cat": "Literatura", "map": 0},
	"mapa_pb": {"n": "Mapa de Porto Bruma", "w": 0.05, "cat": "Literatura", "map": 1},
	# ------------------------------------------------------------ sementes
	"sem_batata": {"n": "Sementes de batata", "w": 0.02, "cat": "Semente", "st": 50, "crop": "batata"},
	"sem_tomate": {"n": "Sementes de tomate", "w": 0.02, "cat": "Semente", "st": 50, "crop": "tomate"},
	"sem_cenoura": {"n": "Sementes de cenoura", "w": 0.02, "cat": "Semente", "st": 50, "crop": "cenoura"},
	"sem_repolho": {"n": "Sementes de repolho", "w": 0.02, "cat": "Semente", "st": 50, "crop": "repolho"},
	"sem_milho": {"n": "Sementes de milho", "w": 0.02, "cat": "Semente", "st": 50, "crop": "milho"},
	"sem_morango": {"n": "Sementes de morango", "w": 0.02, "cat": "Semente", "st": 50, "crop": "morango"},
	"sem_alface": {"n": "Sementes de alface", "w": 0.02, "cat": "Semente", "st": 50, "crop": "alface"},
	"sem_abobora": {"n": "Sementes de abóbora", "w": 0.02, "cat": "Semente", "st": 50, "crop": "abobora"},
	"sem_feijao": {"n": "Sementes de vagem", "w": 0.02, "cat": "Semente", "st": 50, "crop": "feijao_verde"},
	# ------------------------------------------------------------ pecas de veiculo
	"bateria_carro": {"n": "Bateria de carro", "w": 5.0, "cat": "Peça", "part": "bateria"},
	"pneu": {"n": "Pneu", "w": 8.0, "cat": "Peça", "part": "pneu"},
	"freio": {"n": "Jogo de freios", "w": 2.0, "cat": "Peça", "part": "freio"},
	"suspensao": {"n": "Amortecedor", "w": 3.0, "cat": "Peça", "part": "suspensao"},
	"escapamento": {"n": "Silencioso de escapamento", "w": 3.0, "cat": "Peça", "part": "escapamento"},
	"peca_motor": {"n": "Peças de motor", "w": 1.0, "cat": "Peça", "st": 10},
	"chave_carro": {"n": "Chave de carro", "w": 0.02, "cat": "Diversos"},
	# ------------------------------------------------------------ equipamentos de base
	"gerador": {"n": "Gerador", "w": 20.0, "cat": "Diversos", "place": "gerador"},
	"radio": {"n": "Rádio a pilha", "w": 0.6, "cat": "Diversos", "radio": 1},
	"saco_dormir": {"n": "Saco de dormir", "w": 1.5, "cat": "Diversos", "place": "saco_dormir"},
	"barraca": {"n": "Barraca dobrada", "w": 3.0, "cat": "Diversos", "place": "barraca"},
}

const CAT_ORDER := ["Arma", "Munição", "Comida", "Bebida", "Recipiente", "Médico", "Roupa", "Ferramenta", "Material", "Semente", "Peça", "Literatura", "Diversos"]
const LIQ_NAMES := {"agua": "água", "agua_suja": "água contaminada", "gasolina": "gasolina", "": "vazio"}


static func def(id: String) -> Dictionary:
	if id.begins_with("r_"):
		return Clothes.def(id)
	return D.get(id, {"n": id, "w": 0.1, "cat": "Diversos"})


static func exists(id: String) -> bool:
	return D.has(id) or id.begins_with("r_")


## Cria uma instancia de item.
static func make(id: String, n: int = 1, born: float = -1.0) -> Dictionary:
	var d := def(id)
	var it := {"id": id, "n": n}
	if d.has("dmg") or d.has("gun") or d.get("cat", "") == "Roupa" or d.has("part") or d.has("light"):
		it["c"] = 1.0
	if d.has("gun"):
		it["mag"] = 0
		it["ch"] = 0
	if d.has("uses"):
		it["u"] = int(d["uses"])
	if d.has("cap"):
		it["liq"] = float(d["cap"]) if d.has("fill") else 0.0
		it["lt"] = String(d.get("fill", ""))
	if d.has("fresh"):
		it["b"] = born if born >= 0.0 else G.time_min
	if d.has("sharp"):
		it["sh"] = 1.0
	return it


static func name_of(it: Dictionary) -> String:
	var d := def(it["id"])
	var s: String = d.get("n", it["id"])
	if d.has("cap"):
		var l: float = it.get("liq", 0.0)
		if l > 0.01:
			s += " (%s %.1f/%.1f L)" % [LIQ_NAMES.get(it.get("lt", ""), it.get("lt", "")), l, d["cap"]]
		elif d.has("fill"):
			s = "Garrafa vazia"
	if d.has("uses") and it.has("u"):
		s += " (%d)" % it["u"]
	if it.has("hf"):
		s += " (metade)"
	if it.get("ck", 0) == 1:
		s += " (cozido)"
	elif it.get("ck", 0) == 2:
		s += " (queimado)"
	if d.has("fresh"):
		var st := freshness(it)
		if st == 1:
			s += " (passado)"
		elif st == 2:
			s += " (estragado)"
	if d.has("gun"):
		s += " [%d/%d]" % [int(it.get("mag", 0)) + int(it.get("ch", 0)), d["mag"]]
	return s


## 0 fresco, 1 passado, 2 estragado
static func freshness(it: Dictionary) -> int:
	var d := def(it["id"])
	if not d.has("fresh"):
		return 0
	var age_days: float = (G.time_min - float(it.get("b", G.time_min))) / 1440.0 * float(G.sandbox.get("food_spoil", 1.0))
	age_days *= float(it.get("slow", 1.0))
	if age_days > float(d["rot"]):
		return 2
	if age_days > float(d["fresh"]):
		return 1
	return 0


static func weight_of(it: Dictionary) -> float:
	var d := def(it["id"])
	var w: float = float(d.get("w", 0.1))
	if d.has("cap"):
		w += float(it.get("liq", 0.0)) * (0.75 if it.get("lt", "") == "gasolina" else 1.0)
	return w * int(it.get("n", 1))


static func has_tag(it: Dictionary, tag: String) -> bool:
	var d := def(it["id"])
	return d.has("tags") and tag in d["tags"]


static func can_stack(a: Dictionary, b: Dictionary) -> bool:
	if a["id"] != b["id"] or a.has("hf") or b.has("hf"):
		return false
	var d := def(a["id"])
	if int(d.get("st", 1)) <= 1:
		return false
	if d.has("fresh"):
		return absf(float(a.get("b", 0.0)) - float(b.get("b", 0.0))) < 720.0 and a.get("ck", 0) == b.get("ck", 0)
	return true


# =====================================================================================
#  TABELAS DE SAQUE por tipo de recipiente: [id, chance %, min, max]
# =====================================================================================
const LOOT := {
	"geladeira": [["leite", 30, 1, 1], ["queijo", 30, 1, 1], ["presunto", 25, 1, 1], ["ovos", 30, 1, 1], ["bife", 18, 1, 2], ["frango", 15, 1, 1], ["manteiga", 25, 1, 1], ["tomate", 30, 1, 3], ["alface", 22, 1, 1], ["cenoura", 25, 1, 3], ["maca", 30, 1, 3], ["laranja", 25, 1, 3], ["refrigerante", 35, 1, 3], ["suco", 30, 1, 2], ["cerveja", 30, 1, 4], ["garrafa_agua", 35, 1, 2]],
	"armario_cozinha": [["feijao_lata", 30, 1, 2], ["milho_lata", 25, 1, 2], ["atum_lata", 22, 1, 2], ["sardinha_lata", 20, 1, 2], ["sopa_lata", 25, 1, 2], ["ervilha_lata", 20, 1, 1], ["pessego_lata", 12, 1, 1], ["macarrao", 28, 1, 1], ["arroz", 25, 1, 1], ["feijao_seco", 18, 1, 1], ["cereal", 25, 1, 1], ["biscoito", 30, 1, 2], ["chips", 25, 1, 2], ["miojo", 30, 1, 3], ["farinha", 15, 1, 1], ["acucar", 20, 1, 1], ["sal", 20, 1, 1], ["vinagre", 12, 1, 1], ["cafe", 25, 1, 1], ["pasta_amendoim", 12, 1, 1], ["panela", 30, 1, 1], ["frigideira", 25, 1, 1], ["faca_cozinha", 35, 1, 1], ["abridor", 35, 1, 1], ["pote_vidro", 14, 1, 3], ["fosforos", 20, 1, 1], ["garrafa_vazia", 20, 1, 2], ["batata", 20, 1, 4], ["pao", 22, 1, 1], ["saco_lixo", 25, 1, 4]],
	"fogao": [["panela", 30, 1, 1], ["frigideira", 30, 1, 1]],
	"guarda_roupa": [["@top", 70, 1, 3], ["@bottom", 65, 1, 2], ["@over", 40, 1, 2], ["@shoes", 40, 1, 1], ["@hat", 20, 1, 1], ["@gloves", 12, 1, 1], ["@bag", 14, 1, 1], ["lencol", 40, 1, 2], ["r_cinto_0_0", 20, 1, 1], ["@socks", 30, 1, 2]],
	"comoda": [["@top", 50, 1, 2], ["@bottom", 40, 1, 1], ["@socks", 40, 1, 2], ["lencol", 30, 1, 2], ["revista", 15, 1, 1], ["linha", 12, 1, 1], ["agulha", 10, 1, 1], ["tesoura", 10, 1, 1]],
	"criado_mudo": [["romance", 16, 1, 1], ["revista", 16, 1, 1], ["analgesico", 14, 1, 1], ["sonifero", 8, 1, 1], ["lanterna", 14, 1, 1], ["pilha", 16, 1, 2], ["cigarros", 12, 1, 1], ["isqueiro", 12, 1, 1], ["pistola", 2, 1, 1], ["mun_9mm", 3, 6, 15], ["chocolate", 12, 1, 1], ["antidepressivo", 5, 1, 1]],
	"estante": [["romance", 55, 1, 3], ["revista", 40, 1, 2], ["jornal", 25, 1, 2], ["livro_carpintaria", 6, 1, 1], ["livro_culinaria", 8, 1, 1], ["livro_mecanica", 5, 1, 1], ["livro_agricultura", 6, 1, 1], ["livro_socorros", 6, 1, 1], ["livro_eletrica", 4, 1, 1], ["livro_costura", 6, 1, 1], ["livro_coleta", 5, 1, 1], ["revista_conservas", 4, 1, 1], ["revista_ervas", 4, 1, 1]],
	"estante_livraria": [["romance", 70, 1, 4], ["revista", 50, 1, 3], ["livro_carpintaria", 16, 1, 1], ["livro_carpintaria2", 9, 1, 1], ["livro_culinaria", 16, 1, 1], ["livro_mecanica", 14, 1, 1], ["livro_mecanica2", 8, 1, 1], ["livro_agricultura", 16, 1, 1], ["livro_socorros", 16, 1, 1], ["livro_eletrica", 12, 1, 1], ["livro_costura", 14, 1, 1], ["livro_coleta", 14, 1, 1], ["livro_metal", 10, 1, 1], ["revista_gerador", 10, 1, 1], ["revista_ligacao", 8, 1, 1], ["revista_conservas", 10, 1, 1], ["revista_armadilhas", 8, 1, 1], ["revista_ervas", 10, 1, 1], ["mapa_sa", 12, 1, 1], ["mapa_pb", 12, 1, 1]],
	"armario_banheiro": [["atadura", 35, 1, 3], ["alcool", 25, 1, 1], ["analgesico", 35, 1, 1], ["antibiotico", 9, 1, 1], ["vitaminas", 20, 1, 1], ["sonifero", 10, 1, 1], ["tesoura", 12, 1, 1], ["pinca", 18, 1, 1], ["antidepressivo", 8, 1, 1], ["betabloqueador", 8, 1, 1]],
	"armario_medico": [["atadura", 70, 2, 6], ["alcool", 55, 1, 2], ["analgesico", 55, 1, 2], ["antibiotico", 35, 1, 2], ["kit_sutura", 40, 1, 3], ["pinca", 35, 1, 1], ["tala", 30, 1, 2], ["vitaminas", 30, 1, 1], ["betabloqueador", 25, 1, 1], ["antidepressivo", 22, 1, 1], ["sonifero", 22, 1, 1], ["r_luvas_latex_0_0", 30, 1, 1], ["r_mascara_cirurgica_0_0", 30, 1, 2], ["tesoura", 25, 1, 1]],
	"prateleira_comida": [["feijao_lata", 45, 1, 4], ["milho_lata", 40, 1, 4], ["atum_lata", 35, 1, 3], ["sardinha_lata", 35, 1, 3], ["sopa_lata", 40, 1, 3], ["ervilha_lata", 35, 1, 3], ["pessego_lata", 25, 1, 2], ["macarrao", 40, 1, 3], ["arroz", 35, 1, 2], ["feijao_seco", 30, 1, 2], ["cereal", 35, 1, 2], ["biscoito", 45, 1, 4], ["chips", 45, 1, 4], ["chocolate", 40, 1, 4], ["barra_cereal", 35, 1, 4], ["amendoim", 30, 1, 2], ["miojo", 45, 1, 5], ["farinha", 25, 1, 2], ["acucar", 25, 1, 2], ["sal", 20, 1, 1], ["vinagre", 18, 1, 1], ["cafe", 30, 1, 2], ["pasta_amendoim", 22, 1, 2], ["refrigerante", 45, 1, 5], ["suco", 40, 1, 4], ["garrafa_agua", 50, 1, 5], ["cerveja", 30, 1, 5]],
	"prateleira_hortifruti": [["maca", 45, 1, 5], ["banana", 40, 1, 5], ["laranja", 40, 1, 5], ["tomate", 40, 1, 5], ["alface", 30, 1, 2], ["batata", 45, 1, 6], ["cenoura", 40, 1, 5], ["repolho", 30, 1, 2], ["milho", 30, 1, 4], ["abobora", 20, 1, 1]],
	"prateleira_padaria": [["pao", 70, 1, 4], ["biscoito", 50, 1, 3], ["farinha", 40, 1, 2], ["acucar", 35, 1, 2], ["chocolate", 25, 1, 2], ["cafe", 30, 1, 1], ["suco", 30, 1, 2]],
	"prateleira_roupas": [["@top", 85, 1, 4], ["@bottom", 75, 1, 3], ["@over", 55, 1, 2], ["@shoes", 50, 1, 2], ["@hat", 35, 1, 2], ["@gloves", 20, 1, 1], ["@bag", 25, 1, 1], ["@socks", 40, 1, 3], ["r_cinto_0_0", 25, 1, 1], ["@glasses", 15, 1, 1]],
	"prateleira_ferramentas": [["martelo", 40, 1, 1], ["serrote", 35, 1, 1], ["chave_fenda", 40, 1, 1], ["chave_inglesa", 30, 1, 1], ["pregos", 70, 10, 40], ["parafusos", 50, 10, 30], ["machado", 12, 1, 1], ["machadinha", 18, 1, 1], ["pe_de_cabra", 18, 1, 1], ["pa", 20, 1, 1], ["enxada", 18, 1, 1], ["pazinha", 25, 1, 1], ["regador", 20, 1, 1], ["corda", 25, 1, 2], ["fita", 30, 1, 1], ["cola", 25, 1, 1], ["alicate", 25, 1, 1], ["lanterna", 25, 1, 1], ["pilha", 35, 1, 4], ["fio", 30, 1, 4], ["balde", 20, 1, 1], ["galao", 14, 1, 1], ["marreta", 5, 1, 1], ["tabua", 30, 1, 3], ["fertilizante", 16, 1, 1], ["sem_batata", 16, 4, 10], ["sem_tomate", 16, 4, 10], ["sem_cenoura", 16, 4, 10], ["sem_repolho", 14, 4, 10], ["sem_milho", 14, 4, 10], ["sem_alface", 14, 4, 10], ["macarico", 8, 1, 1], ["mascara_solda", 8, 1, 1], ["colher_pedreiro", 14, 1, 1], ["cimento", 10, 1, 1], ["formao", 12, 1, 1], ["pedra_amolar", 16, 1, 1], ["mangueira", 18, 1, 1], ["saco_lixo", 30, 2, 6], ["lampada", 30, 1, 3]],
	"prateleira_armas": [["pistola", 22, 1, 1], ["revolver", 20, 1, 1], ["espingarda", 16, 1, 1], ["rifle", 12, 1, 1], ["carabina", 6, 1, 1], ["mun_9mm", 45, 10, 30], ["mun_38", 40, 6, 24], ["cartucho_12", 40, 4, 12], ["mun_308", 30, 5, 15], ["faca_caca", 25, 1, 1], ["facao", 10, 1, 1], ["kit_limpeza", 30, 1, 1], ["r_colete_utilitario_2_0", 15, 1, 1], ["lanterna", 20, 1, 1]],
	"prateleira_farmacia": [["atadura", 60, 2, 5], ["alcool", 50, 1, 2], ["analgesico", 55, 1, 2], ["antibiotico", 28, 1, 2], ["vitaminas", 45, 1, 2], ["sonifero", 25, 1, 1], ["antidepressivo", 25, 1, 1], ["betabloqueador", 25, 1, 1], ["kit_sutura", 20, 1, 2], ["pinca", 25, 1, 1], ["tala", 15, 1, 1], ["r_mascara_cirurgica_0_0", 30, 1, 2], ["r_luvas_latex_0_0", 25, 1, 1], ["barra_cereal", 20, 1, 3], ["garrafa_agua", 30, 1, 2]],
	"balcao": [["revista", 14, 1, 1], ["jornal", 16, 1, 1], ["chocolate", 14, 1, 2], ["cigarros", 16, 1, 1], ["isqueiro", 14, 1, 1], ["pilha", 12, 1, 2], ["tesoura", 8, 1, 1], ["fita", 8, 1, 1], ["saco_lixo", 20, 1, 4], ["mapa_sa", 4, 1, 1], ["mapa_pb", 4, 1, 1]],
	"balcao_bar": [["cerveja", 70, 2, 8], ["uisque", 45, 1, 2], ["refrigerante", 50, 1, 4], ["amendoim", 45, 1, 3], ["chips", 45, 1, 3], ["garrafa_vazia", 40, 1, 4], ["cigarros", 25, 1, 1], ["isqueiro", 25, 1, 1], ["taco", 8, 1, 1]],
	"mesa_escritorio": [["revista", 15, 1, 1], ["jornal", 20, 1, 1], ["tesoura", 14, 1, 1], ["fita", 14, 1, 1], ["pilha", 14, 1, 2], ["cafe", 10, 1, 1], ["barra_cereal", 10, 1, 1], ["cigarros", 8, 1, 1], ["analgesico", 8, 1, 1], ["mapa_pb", 5, 1, 1]],
	"arquivo": [["jornal", 30, 1, 2], ["revista", 12, 1, 1], ["mapa_sa", 6, 1, 1], ["mapa_pb", 6, 1, 1]],
	"armario_escola": [["romance", 20, 1, 1], ["revista", 14, 1, 1], ["tesoura", 20, 1, 1], ["cola", 20, 1, 1], ["fita", 16, 1, 1], ["barra_cereal", 14, 1, 1], ["suco", 12, 1, 1], ["r_mochila_escolar_1_0", 12, 1, 1], ["livro_socorros", 4, 1, 1], ["livro_agricultura", 4, 1, 1]],
	"armario_policia": [["pistola", 30, 1, 1], ["revolver", 14, 1, 1], ["espingarda", 14, 1, 1], ["mun_9mm", 55, 10, 30], ["mun_38", 20, 6, 18], ["cartucho_12", 35, 4, 12], ["r_colete_policial_0_0", 25, 1, 1], ["r_uniforme_policia_0_0", 25, 1, 1], ["r_calca_policia_0_0", 22, 1, 1], ["r_quepe_0_0", 16, 1, 1], ["lanterna", 30, 1, 1], ["kit_limpeza", 20, 1, 1], ["atadura", 25, 1, 2], ["r_coldre_0_0", 25, 1, 1], ["radio", 16, 1, 1]],
	"armario_bombeiro": [["machado", 45, 1, 1], ["pe_de_cabra", 30, 1, 1], ["r_jaqueta_bombeiro_0_0", 40, 1, 1], ["r_capacete_bombeiro_0_0", 40, 1, 1], ["r_bota_trabalho_0_0", 30, 1, 1], ["corda", 40, 1, 2], ["lanterna", 35, 1, 1], ["atadura", 35, 1, 3], ["alcool", 20, 1, 1], ["marreta", 10, 1, 1], ["mangueira", 25, 1, 1], ["balde", 20, 1, 1]],
	"caixa_ferramentas": [["martelo", 45, 1, 1], ["serrote", 30, 1, 1], ["chave_fenda", 50, 1, 1], ["chave_inglesa", 45, 1, 1], ["pregos", 60, 8, 30], ["parafusos", 45, 8, 20], ["alicate", 30, 1, 1], ["fita", 30, 1, 1], ["fio", 25, 1, 3], ["lanterna", 20, 1, 1], ["chave_roda", 25, 1, 1], ["macaco", 16, 1, 1], ["pedra_amolar", 12, 1, 1]],
	"prateleira_oficina": [["chave_inglesa", 45, 1, 1], ["chave_roda", 45, 1, 1], ["macaco", 35, 1, 1], ["chave_fenda", 40, 1, 1], ["bateria_carro", 25, 1, 1], ["pneu", 30, 1, 2], ["freio", 25, 1, 1], ["suspensao", 20, 1, 1], ["escapamento", 20, 1, 1], ["peca_motor", 35, 1, 4], ["galao", 25, 1, 1], ["mangueira", 25, 1, 1], ["livro_mecanica", 10, 1, 1], ["revista_ligacao", 8, 1, 1], ["sucata", 40, 1, 4], ["fio", 25, 1, 3], ["macarico", 10, 1, 1], ["mascara_solda", 10, 1, 1]],
	"caixote": [["tabua", 35, 1, 4], ["pregos", 40, 5, 30], ["sucata", 35, 1, 4], ["chapa_metal", 14, 1, 2], ["barra_metal", 14, 1, 2], ["fio", 20, 1, 4], ["corda", 16, 1, 1], ["saco_lixo", 25, 1, 5], ["feijao_lata", 12, 1, 4], ["garrafa_agua", 12, 1, 4], ["cimento", 8, 1, 1], ["tijolo", 12, 2, 8], ["fertilizante", 8, 1, 1], ["sucata_eletronica", 16, 1, 4]],
	"caixote_fazenda": [["sem_batata", 35, 5, 15], ["sem_tomate", 35, 5, 15], ["sem_cenoura", 35, 5, 15], ["sem_repolho", 30, 5, 15], ["sem_milho", 35, 5, 15], ["sem_morango", 25, 5, 15], ["sem_alface", 30, 5, 15], ["sem_abobora", 25, 5, 15], ["sem_feijao", 25, 5, 15], ["fertilizante", 35, 1, 2], ["pazinha", 35, 1, 1], ["enxada", 30, 1, 1], ["pa", 25, 1, 1], ["regador", 35, 1, 1], ["balde", 25, 1, 1], ["batata", 25, 2, 8], ["milho", 20, 2, 6], ["abobora", 15, 1, 2], ["corda", 20, 1, 1], ["machado", 10, 1, 1], ["livro_agricultura", 8, 1, 1]],
	"armario_cabana": [["feijao_lata", 35, 1, 3], ["sopa_lata", 30, 1, 2], ["sardinha_lata", 30, 1, 2], ["miojo", 30, 1, 3], ["cafe", 25, 1, 1], ["fosforos", 45, 1, 1], ["lanterna", 30, 1, 1], ["pilha", 30, 1, 3], ["machadinha", 30, 1, 1], ["machado", 16, 1, 1], ["faca_caca", 22, 1, 1], ["corda", 30, 1, 1], ["cantil", 30, 1, 1], ["atadura", 30, 1, 2], ["saco_dormir", 25, 1, 1], ["barraca", 10, 1, 1], ["livro_coleta", 12, 1, 1], ["revista_ervas", 10, 1, 1], ["espingarda", 7, 1, 1], ["cartucho_12", 12, 4, 10], ["panela", 30, 1, 1], ["uisque", 16, 1, 1], ["romance", 20, 1, 1]],
	"lixeira": [["garrafa_vazia", 35, 1, 2], ["jornal", 30, 1, 2], ["saco_lixo", 30, 1, 2], ["pano_sujo", 20, 1, 2], ["sucata", 14, 1, 1]],
	"porta_malas": [["chave_roda", 25, 1, 1], ["macaco", 18, 1, 1], ["galao", 10, 1, 1], ["garrafa_agua", 14, 1, 1], ["lanterna", 10, 1, 1], ["corda", 8, 1, 1], ["pneu", 12, 1, 1], ["atadura", 8, 1, 1], ["mapa_sa", 6, 1, 1], ["mapa_pb", 6, 1, 1], ["@top", 8, 1, 1], ["taco", 4, 1, 1]],
	"zumbi": [["cigarros", 5, 1, 1], ["isqueiro", 5, 1, 1], ["chocolate", 3, 1, 1], ["analgesico", 2, 1, 1], ["pilha", 3, 1, 1], ["garrafa_agua", 3, 1, 1], ["barra_cereal", 3, 1, 1]],
	"zumbi_policia": [["pistola", 22, 1, 1], ["mun_9mm", 40, 5, 15], ["lanterna", 18, 1, 1], ["radio", 8, 1, 1]],
	"zumbi_medico": [["atadura", 35, 1, 2], ["alcool", 14, 1, 1], ["analgesico", 20, 1, 1], ["tesoura", 10, 1, 1], ["kit_sutura", 10, 1, 1]],
	"zumbi_obra": [["martelo", 14, 1, 1], ["chave_fenda", 14, 1, 1], ["pregos", 25, 4, 12], ["chave_inglesa", 10, 1, 1], ["fita", 8, 1, 1]],
	"acampamento": [["feijao_lata", 30, 1, 2], ["miojo", 30, 1, 2], ["garrafa_agua", 35, 1, 2], ["fosforos", 30, 1, 1], ["lanterna", 20, 1, 1], ["saco_dormir", 30, 1, 1], ["faca_caca", 14, 1, 1], ["corda", 20, 1, 1], ["panela", 25, 1, 1], ["barra_cereal", 30, 1, 3], ["atadura", 20, 1, 1], ["cantil", 20, 1, 1]],
}

const CONTAINER_ROLLS := {"geladeira": 5, "armario_cozinha": 6, "guarda_roupa": 5, "prateleira_comida": 7, "prateleira_roupas": 6, "prateleira_ferramentas": 7,
	"prateleira_armas": 4, "prateleira_farmacia": 6, "estante_livraria": 6, "armario_medico": 6, "caixote": 4, "caixote_fazenda": 6, "armario_cabana": 6,
	"prateleira_oficina": 6, "armario_policia": 5, "armario_bombeiro": 5, "prateleira_hortifruti": 6, "prateleira_padaria": 5, "balcao_bar": 5}
const CONTAINER_CAP := {"geladeira": 40, "armario_cozinha": 30, "guarda_roupa": 40, "comoda": 25, "criado_mudo": 8, "estante": 30, "caixote": 50, "caixote_fazenda": 50, "porta_malas": 60, "lixeira": 15, "zumbi": 12, "chao": 9999}


## Gera o conteudo de um recipiente de forma deterministica.
static func roll_loot(kind: String, seed_v: int) -> Array:
	var out: Array = []
	if not LOOT.has(kind):
		return out
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var table: Array = LOOT[kind]
	var rolls: int = CONTAINER_ROLLS.get(kind, 3)
	var mult: float = float(G.sandbox.get("loot", 1.0))
	var day_pen: float = 1.0
	for i in rolls:
		var e: Array = table[r.randi() % table.size()]
		if r.randf() * 100.0 > float(e[1]) * mult * day_pen:
			continue
		var id: String = e[0]
		var n: int = r.randi_range(e[2], e[3])
		if id.begins_with("@"):
			for j in n:
				out.append(Items.make(Clothes.random_id(r, id.substr(1))))
			continue
		var d := def(id)
		var mx: int = int(d.get("st", 1))
		if mx <= 1:
			for j in n:
				var it := make(id, 1, 0.0)
				_randomize(it, d, r)
				out.append(it)
		else:
			out.append(make(id, n, 0.0))
	return out


static func _randomize(it: Dictionary, d: Dictionary, r: RandomNumberGenerator) -> void:
	if it.has("c"):
		it["c"] = clampf(r.randf_range(0.35, 1.0), 0.0, 1.0)
	if d.has("gun"):
		it["mag"] = r.randi_range(0, int(d["mag"]))
	if d.has("uses"):
		it["u"] = r.randi_range(maxi(1, int(d["uses"]) / 3), int(d["uses"]))
	if d.has("cap") and not d.has("fill"):
		it["liq"] = 0.0
