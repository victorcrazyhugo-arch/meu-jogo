class_name Clothes
extends RefCounted
## Vestuario modular: pecas base x cores x estampas/detalhes.
## Id de item: "r_<base>_<indice_cor>_<indice_estampa>".
## Cada combinacao altera a malha do personagem (corte, cor, estampa ou detalhe), logo e visualmente distinta.

const PAL := [
	["branco", Color(0.92, 0.92, 0.90)], ["preto", Color(0.10, 0.10, 0.11)], ["cinza", Color(0.50, 0.51, 0.53)], ["grafite", Color(0.26, 0.27, 0.30)],
	["azul", Color(0.20, 0.38, 0.72)], ["azul-marinho", Color(0.11, 0.16, 0.33)], ["azul-claro", Color(0.55, 0.72, 0.88)], ["vermelho", Color(0.72, 0.14, 0.13)],
	["vinho", Color(0.42, 0.09, 0.14)], ["verde", Color(0.20, 0.52, 0.26)], ["verde-oliva", Color(0.36, 0.40, 0.22)], ["verde-escuro", Color(0.10, 0.26, 0.16)],
	["amarelo", Color(0.90, 0.78, 0.22)], ["mostarda", Color(0.76, 0.58, 0.16)], ["laranja", Color(0.88, 0.48, 0.14)], ["rosa", Color(0.90, 0.55, 0.66)],
	["roxo", Color(0.45, 0.25, 0.60)], ["lilás", Color(0.70, 0.60, 0.84)], ["marrom", Color(0.36, 0.24, 0.15)], ["bege", Color(0.80, 0.72, 0.58)],
	["cáqui", Color(0.62, 0.56, 0.40)], ["turquesa", Color(0.16, 0.62, 0.62)], ["creme", Color(0.93, 0.89, 0.78)], ["ferrugem", Color(0.62, 0.30, 0.16)]]
const DENIM := [5, 4, 6, 3, 1, 2]
const LEATHER := [1, 18, 23, 3, 8, 19]
const EARTH := [18, 19, 20, 10, 3, 1, 2, 11]
const ALL := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
const HALF := [0, 1, 2, 3, 4, 5, 7, 9, 10, 12, 14, 18, 19, 20, 21, 23]

const TOP_PATS := ["liso", "listrado", "bicolor", "xadrez", "com estampa", "com faixa"]
const OVER_PATS := ["liso", "mangas contrastantes", "faixas refletivas"]
const BOT_PATS := ["liso", "faixa lateral", "barra contrastante"]
const ONE := ["liso"]

## base: n nome, slot, w peso, ins isolamento, prot protecao, water resistencia a agua, cols paleta, pats estampas, vis parametros visuais
const BASES := {
	# ---------------- parte de cima
	"regata": {"n": "Regata", "slot": "top", "w": 0.1, "ins": 0.04, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 0}},
	"camiseta": {"n": "Camiseta", "slot": "top", "w": 0.15, "ins": 0.08, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 1}},
	"polo": {"n": "Camisa polo", "slot": "top", "w": 0.2, "ins": 0.1, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 1, "collar": true}},
	"camisa_curta": {"n": "Camisa de manga curta", "slot": "top", "w": 0.2, "ins": 0.1, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 1, "collar": true, "buttons": true}},
	"manga_longa": {"n": "Camiseta de manga longa", "slot": "top", "w": 0.2, "ins": 0.16, "prot": 0.02, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2}},
	"camisa": {"n": "Camisa social", "slot": "top", "w": 0.25, "ins": 0.16, "prot": 0.02, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2, "collar": true, "buttons": true}},
	"flanela": {"n": "Camisa de flanela", "slot": "top", "w": 0.3, "ins": 0.26, "prot": 0.04, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2, "collar": true, "buttons": true, "thick": true}},
	"gola_alta": {"n": "Blusa de gola alta", "slot": "top", "w": 0.3, "ins": 0.3, "prot": 0.04, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2, "turtle": true}},
	"termica": {"n": "Blusa térmica", "slot": "top", "w": 0.2, "ins": 0.42, "prot": 0.02, "water": 0.1, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2, "turtle": true, "tight": true}},
	"sueter": {"n": "Suéter", "slot": "top", "w": 0.4, "ins": 0.45, "prot": 0.06, "water": 0.0, "cols": ALL, "pats": TOP_PATS, "vis": {"sl": 2, "thick": true}},
	"uniforme_policia": {"n": "Camisa de policial", "slot": "top", "w": 0.3, "ins": 0.16, "prot": 0.05, "water": 0.0, "cols": [5, 3, 1, 20], "pats": ONE, "vis": {"sl": 1, "collar": true, "buttons": true, "badge": true}},
	"uniforme_saude": {"n": "Blusa hospitalar", "slot": "top", "w": 0.2, "ins": 0.08, "prot": 0.0, "water": 0.0, "cols": [6, 21, 9, 0, 15, 17], "pats": ONE, "vis": {"sl": 1, "vneck": true}},
	"uniforme_trabalho": {"n": "Camisa de trabalho", "slot": "top", "w": 0.35, "ins": 0.2, "prot": 0.08, "water": 0.05, "cols": [4, 2, 14, 12, 10, 3, 18, 5], "pats": ["liso", "faixas refletivas"], "vis": {"sl": 2, "collar": true, "buttons": true, "badge": true, "thick": true}},
	# ---------------- vestidos (ocupam cima e baixo)
	"vestido": {"n": "Vestido", "slot": "dress", "w": 0.3, "ins": 0.1, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "listrado", "bicolor", "xadrez"], "vis": {"sl": 1, "skirt": 0.50}},
	"vestido_longo": {"n": "Vestido longo", "slot": "dress", "w": 0.4, "ins": 0.16, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "listrado", "bicolor", "xadrez"], "vis": {"sl": 2, "skirt": 0.26}},
	"vestido_alca": {"n": "Vestido de alça", "slot": "dress", "w": 0.2, "ins": 0.05, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "listrado", "bicolor", "xadrez"], "vis": {"sl": 0, "skirt": 0.56}},
	# ---------------- casacos e coletes
	"jaqueta": {"n": "Jaqueta", "slot": "over", "w": 0.8, "ins": 0.4, "prot": 0.12, "water": 0.25, "cols": ALL, "pats": OVER_PATS, "vis": {"style": 1, "open": true}},
	"jaqueta_jeans": {"n": "Jaqueta jeans", "slot": "over", "w": 0.9, "ins": 0.35, "prot": 0.18, "water": 0.1, "cols": DENIM, "pats": ["liso", "mangas contrastantes"], "vis": {"style": 1, "open": true, "pockets": true}},
	"jaqueta_couro": {"n": "Jaqueta de couro", "slot": "over", "w": 1.5, "ins": 0.45, "prot": 0.38, "water": 0.5, "cols": LEATHER, "pats": ["liso", "mangas contrastantes"], "vis": {"style": 1, "open": true, "wide": true}},
	"corta_vento": {"n": "Corta-vento", "slot": "over", "w": 0.4, "ins": 0.3, "prot": 0.05, "water": 0.7, "cols": ALL, "pats": OVER_PATS, "vis": {"style": 1, "open": false}},
	"moletom": {"n": "Moletom", "slot": "over", "w": 0.6, "ins": 0.5, "prot": 0.08, "water": 0.05, "cols": ALL, "pats": OVER_PATS, "vis": {"style": 2, "open": false}},
	"moletom_capuz": {"n": "Moletom com capuz", "slot": "over", "w": 0.7, "ins": 0.55, "prot": 0.08, "water": 0.1, "cols": ALL, "pats": OVER_PATS, "vis": {"style": 2, "open": false, "hood": true}},
	"acolchoada": {"n": "Jaqueta acolchoada", "slot": "over", "w": 1.0, "ins": 0.85, "prot": 0.16, "water": 0.4, "cols": ALL, "pats": OVER_PATS, "vis": {"style": 1, "open": false, "puffy": true}},
	"casaco_longo": {"n": "Casaco longo", "slot": "over", "w": 1.4, "ins": 0.75, "prot": 0.14, "water": 0.3, "cols": HALF, "pats": ["liso", "mangas contrastantes"], "vis": {"style": 4, "open": true, "long": true}},
	"capa_chuva": {"n": "Capa de chuva", "slot": "over", "w": 0.5, "ins": 0.15, "prot": 0.02, "water": 1.0, "cols": [12, 4, 9, 14, 1, 21, 7, 0], "pats": ["liso", "faixas refletivas"], "vis": {"style": 4, "open": false, "long": true, "hood": true}},
	"jaleco": {"n": "Jaleco", "slot": "over", "w": 0.4, "ins": 0.15, "prot": 0.03, "water": 0.1, "cols": [0, 6, 22], "pats": ONE, "vis": {"style": 4, "open": true, "long": true}},
	"colete_utilitario": {"n": "Colete utilitário", "slot": "over", "w": 0.6, "ins": 0.1, "prot": 0.1, "water": 0.1, "cols": EARTH, "pats": ["liso", "faixas refletivas"], "vis": {"style": 3, "pockets": true}},
	"colete_policial": {"n": "Colete balístico", "slot": "over", "w": 3.0, "ins": 0.25, "prot": 0.7, "water": 0.3, "cols": [1, 5, 3, 10], "pats": ONE, "vis": {"style": 3, "pockets": true, "plate": true}},
	"jaqueta_bombeiro": {"n": "Jaqueta de bombeiro", "slot": "over", "w": 2.5, "ins": 0.8, "prot": 0.55, "water": 0.8, "cols": [20, 1, 12], "pats": ["faixas refletivas"], "vis": {"style": 4, "open": false, "long": true, "puffy": true}},
	# ---------------- parte de baixo
	"calca_jeans": {"n": "Calça jeans", "slot": "bottom", "w": 0.6, "ins": 0.3, "prot": 0.14, "water": 0.0, "cols": DENIM, "pats": BOT_PATS, "vis": {"style": 1}},
	"calca_social": {"n": "Calça social", "slot": "bottom", "w": 0.4, "ins": 0.22, "prot": 0.04, "water": 0.0, "cols": HALF, "pats": BOT_PATS, "vis": {"style": 1}},
	"calca_cargo": {"n": "Calça cargo", "slot": "bottom", "w": 0.6, "ins": 0.3, "prot": 0.12, "water": 0.1, "cols": EARTH, "pats": BOT_PATS, "vis": {"style": 1, "cargo": true}},
	"calca_moletom": {"n": "Calça de moletom", "slot": "bottom", "w": 0.4, "ins": 0.4, "prot": 0.04, "water": 0.0, "cols": HALF, "pats": BOT_PATS, "vis": {"style": 1, "loose": true}},
	"calca_trabalho": {"n": "Calça de trabalho", "slot": "bottom", "w": 0.8, "ins": 0.35, "prot": 0.2, "water": 0.15, "cols": [4, 5, 3, 18, 10, 14, 2, 20], "pats": BOT_PATS, "vis": {"style": 1, "knee": true}},
	"calca_termica": {"n": "Calça térmica", "slot": "bottom", "w": 0.3, "ins": 0.6, "prot": 0.02, "water": 0.1, "cols": HALF, "pats": BOT_PATS, "vis": {"style": 1, "tight": true}},
	"calca_policia": {"n": "Calça de policial", "slot": "bottom", "w": 0.5, "ins": 0.28, "prot": 0.1, "water": 0.05, "cols": [5, 3, 1, 20], "pats": ["liso", "faixa lateral"], "vis": {"style": 1}},
	"shorts": {"n": "Shorts", "slot": "bottom", "w": 0.2, "ins": 0.08, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": BOT_PATS, "vis": {"style": 2, "len": 0.66}},
	"bermuda": {"n": "Bermuda", "slot": "bottom", "w": 0.3, "ins": 0.12, "prot": 0.02, "water": 0.0, "cols": ALL, "pats": BOT_PATS, "vis": {"style": 2, "len": 0.50, "cargo": true}},
	"saia": {"n": "Saia", "slot": "bottom", "w": 0.2, "ins": 0.08, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "listrado", "barra contrastante"], "vis": {"style": 3, "len": 0.56}},
	"saia_longa": {"n": "Saia longa", "slot": "bottom", "w": 0.35, "ins": 0.2, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "listrado", "barra contrastante"], "vis": {"style": 3, "len": 0.28}},
	# ---------------- calcados
	"tenis": {"n": "Tênis", "slot": "shoes", "w": 0.5, "ins": 0.2, "prot": 0.15, "water": 0.1, "cols": HALF, "pats": ["liso", "sola clara"], "vis": {"style": 1}, "run": 1.0},
	"sapato": {"n": "Sapato social", "slot": "shoes", "w": 0.6, "ins": 0.2, "prot": 0.15, "water": 0.2, "cols": [1, 18, 3, 8, 19, 23], "pats": ONE, "vis": {"style": 3}, "run": 0.94},
	"bota_trabalho": {"n": "Bota de trabalho", "slot": "shoes", "w": 1.2, "ins": 0.5, "prot": 0.6, "water": 0.6, "cols": [18, 1, 20, 23, 3, 19], "pats": ["liso", "sola clara"], "vis": {"style": 2}, "run": 0.92},
	"bota_militar": {"n": "Coturno", "slot": "shoes", "w": 1.3, "ins": 0.55, "prot": 0.7, "water": 0.7, "cols": [1, 18, 10, 20], "pats": ONE, "vis": {"style": 2, "tall": true}, "run": 0.95},
	"galocha": {"n": "Galocha", "slot": "shoes", "w": 0.9, "ins": 0.3, "prot": 0.35, "water": 1.0, "cols": [12, 1, 9, 4, 7, 14], "pats": ONE, "vis": {"style": 2, "tall": true}, "run": 0.85},
	"sandalia": {"n": "Sandália", "slot": "shoes", "w": 0.2, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": [1, 18, 19, 7, 4, 15], "pats": ONE, "vis": {"style": 4}, "run": 0.8},
	# ---------------- cabeca
	"bone": {"n": "Boné", "slot": "hat", "w": 0.1, "ins": 0.1, "prot": 0.02, "water": 0.2, "cols": HALF, "pats": ["liso", "aba contrastante"], "vis": {"style": 1}},
	"gorro": {"n": "Gorro", "slot": "hat", "w": 0.1, "ins": 0.5, "prot": 0.04, "water": 0.1, "cols": HALF, "pats": ["liso", "barra contrastante"], "vis": {"style": 2}},
	"capacete_obra": {"n": "Capacete de obra", "slot": "hat", "w": 0.5, "ins": 0.15, "prot": 0.6, "water": 0.6, "cols": [12, 0, 14, 4, 7, 9], "pats": ONE, "vis": {"style": 3}},
	"capacete_bombeiro": {"n": "Capacete de bombeiro", "slot": "hat", "w": 0.9, "ins": 0.3, "prot": 0.8, "water": 0.8, "cols": [7, 12, 1], "pats": ONE, "vis": {"style": 3, "crest": true}},
	"capacete_moto": {"n": "Capacete de moto", "slot": "hat", "w": 1.4, "ins": 0.4, "prot": 0.9, "water": 0.9, "cols": [1, 0, 7, 4, 2, 12], "pats": ONE, "vis": {"style": 3, "full": true}},
	"chapeu": {"n": "Chapéu de aba larga", "slot": "hat", "w": 0.2, "ins": 0.15, "prot": 0.02, "water": 0.4, "cols": [19, 18, 20, 22, 1, 2], "pats": ["liso", "com fita"], "vis": {"style": 4}},
	"quepe": {"n": "Quepe", "slot": "hat", "w": 0.2, "ins": 0.12, "prot": 0.03, "water": 0.3, "cols": [5, 3, 1, 20], "pats": ONE, "vis": {"style": 1, "flat": true}},
	# ---------------- maos, pes, acessorios
	"luvas_couro": {"n": "Luvas de couro", "slot": "gloves", "w": 0.2, "ins": 0.4, "prot": 0.5, "water": 0.4, "cols": LEATHER, "pats": ONE, "vis": {}},
	"luvas_trabalho": {"n": "Luvas de trabalho", "slot": "gloves", "w": 0.2, "ins": 0.25, "prot": 0.4, "water": 0.2, "cols": [19, 12, 2, 14, 20, 0], "pats": ONE, "vis": {}},
	"luvas_la": {"n": "Luvas de lã", "slot": "gloves", "w": 0.1, "ins": 0.6, "prot": 0.1, "water": 0.0, "cols": HALF, "pats": ONE, "vis": {}},
	"luvas_latex": {"n": "Luvas de látex", "slot": "gloves", "w": 0.02, "ins": 0.02, "prot": 0.02, "water": 1.0, "cols": [6, 0, 17], "pats": ONE, "vis": {}},
	"meias": {"n": "Meias", "slot": "socks", "w": 0.05, "ins": 0.2, "prot": 0.0, "water": 0.0, "cols": [0, 1, 2, 4, 7, 18], "pats": ONE, "vis": {}},
	"meias_la": {"n": "Meias de lã", "slot": "socks", "w": 0.08, "ins": 0.45, "prot": 0.02, "water": 0.0, "cols": [2, 18, 19, 8, 11, 5], "pats": ONE, "vis": {}},
	"cinto": {"n": "Cinto", "slot": "belt", "w": 0.2, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": LEATHER, "pats": ONE, "vis": {}},
	"coldre": {"n": "Coldre de cintura", "slot": "holster", "w": 0.3, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": [1, 18], "pats": ONE, "vis": {}},
	"mascara_cirurgica": {"n": "Máscara cirúrgica", "slot": "mask", "w": 0.01, "ins": 0.02, "prot": 0.0, "water": 0.0, "cols": [6, 0, 1, 15], "pats": ONE, "vis": {}},
	"bandana": {"n": "Bandana no rosto", "slot": "mask", "w": 0.05, "ins": 0.08, "prot": 0.0, "water": 0.0, "cols": HALF, "pats": ONE, "vis": {}},
	"oculos": {"n": "Óculos", "slot": "glasses", "w": 0.05, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": [1, 18, 3, 7], "pats": ONE, "vis": {}},
	"oculos_escuros": {"n": "Óculos escuros", "slot": "glasses", "w": 0.05, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": [1, 3, 18, 5], "pats": ONE, "vis": {"dark": true}},
	# ---------------- bolsas e mochilas (cap = capacidade, red = reducao de peso)
	"pochete": {"n": "Pochete", "slot": "bag", "w": 0.2, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": HALF, "pats": ONE, "vis": {"style": 4}, "cap": 3.0, "red": 0.5},
	"bolsa_transversal": {"n": "Bolsa transversal", "slot": "bag", "w": 0.5, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": HALF, "pats": ONE, "vis": {"style": 3}, "cap": 9.0, "red": 0.45},
	"mochila_escolar": {"n": "Mochila escolar", "slot": "bag", "w": 0.6, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": ALL, "pats": ["liso", "bolso contrastante"], "vis": {"style": 1}, "cap": 15.0, "red": 0.6},
	"mochila_trilha": {"n": "Mochila de trilha", "slot": "bag", "w": 1.2, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": HALF, "pats": ["liso", "bolso contrastante"], "vis": {"style": 2}, "cap": 24.0, "red": 0.75},
	"mochila_militar": {"n": "Mochila militar", "slot": "bag", "w": 1.5, "ins": 0.0, "prot": 0.0, "water": 0.0, "cols": [10, 20, 1, 11], "pats": ONE, "vis": {"style": 2, "big": true}, "cap": 28.0, "red": 0.85},
}

const SLOT_NAMES := {"top": "Camisa", "dress": "Vestido", "over": "Casaco", "bottom": "Calça", "shoes": "Calçado", "hat": "Cabeça", "gloves": "Luvas", "socks": "Meias",
	"belt": "Cinto", "holster": "Coldre", "mask": "Rosto", "glasses": "Olhos", "bag": "Costas"}
const SLOT_ORDER := ["hat", "glasses", "mask", "over", "top", "dress", "gloves", "belt", "holster", "bottom", "socks", "shoes", "bag"]
## Partes do corpo cobertas por slot (indices de Survivor.PARTS)
const SLOT_COVER := {"top": [6, 7, 4, 5], "dress": [6, 7, 10, 11, 12], "over": [6, 7, 2, 3, 4, 5, 9], "bottom": [10, 11, 12, 13, 14], "shoes": [15, 16], "hat": [8], "gloves": [0, 1], "mask": [8], "socks": [15, 16]}

static var _by_slot := {}
static var _cache := {}


static func parse(id: String) -> Array:
	var parts := id.split("_")
	var n := parts.size()
	if n < 4:
		return ["camiseta", 0, 0]
	var base := "_".join(parts.slice(1, n - 2))
	return [base, int(parts[n - 2]), int(parts[n - 1])]


static func make_id(base: String, ci: int, pi: int) -> String:
	return "r_%s_%d_%d" % [base, ci, pi]


static func def(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var p := parse(id)
	var b: Dictionary = BASES.get(p[0], BASES["camiseta"])
	var cols: Array = b["cols"]
	var pats: Array = b["pats"]
	var ci: int = clampi(p[1], 0, cols.size() - 1)
	var pi: int = clampi(p[2], 0, pats.size() - 1)
	var nm := "%s (%s" % [b["n"], PAL[cols[ci]][0]]
	if pats[pi] != "liso":
		nm += ", " + String(pats[pi])
	nm += ")"
	var d := {"n": nm, "w": b["w"], "cat": "Roupa", "slot": b["slot"], "ins": b["ins"], "prot": b["prot"], "water": b["water"], "base": p[0], "ci": ci, "pi": pi, "st": 1}
	if b.has("cap"):
		d["bagcap"] = b["cap"]
		d["red"] = b["red"]
	if b.has("run"):
		d["run"] = b["run"]
	_cache[id] = d
	return d


static func color_of(id: String) -> Color:
	var p := parse(id)
	var b: Dictionary = BASES.get(p[0], BASES["camiseta"])
	var cols: Array = b["cols"]
	return PAL[cols[clampi(p[1], 0, cols.size() - 1)]][1]


## Segunda cor (contraste) derivada de forma estavel.
static func color2_of(id: String) -> Color:
	var p := parse(id)
	var b: Dictionary = BASES.get(p[0], BASES["camiseta"])
	var cols: Array = b["cols"]
	var ci: int = clampi(p[1], 0, cols.size() - 1)
	var c: Color = PAL[cols[ci]][1]
	if c.get_luminance() > 0.45:
		return c.darkened(0.55)
	return c.lightened(0.6)


static func count_variants() -> int:
	var t := 0
	for k in BASES:
		t += BASES[k]["cols"].size() * BASES[k]["pats"].size()
	return t


static func count_by_slot() -> Dictionary:
	var o := {}
	for k in BASES:
		var s: String = BASES[k]["slot"]
		o[s] = int(o.get(s, 0)) + BASES[k]["cols"].size() * BASES[k]["pats"].size()
	return o


static func bases_for(slot: String) -> Array:
	if _by_slot.is_empty():
		for k in BASES:
			var s: String = BASES[k]["slot"]
			if not _by_slot.has(s):
				_by_slot[s] = []
			_by_slot[s].append(k)
	return _by_slot.get(slot, [])


static func random_id(r: RandomNumberGenerator, slot: String, civil: bool = true) -> String:
	var bs: Array = bases_for(slot)
	if bs.is_empty():
		return "r_camiseta_0_0"
	var base: String = bs[r.randi() % bs.size()]
	if civil:
		for i in 4:
			if base.begins_with("uniforme") or base in ["colete_policial", "jaqueta_bombeiro", "capacete_bombeiro", "quepe", "calca_policia", "jaleco"]:
				base = bs[r.randi() % bs.size()]
	var b: Dictionary = BASES[base]
	var pi := 0
	if r.randf() < 0.4:
		pi = r.randi() % b["pats"].size()
	return make_id(base, r.randi() % b["cols"].size(), pi)


## Aplica uma peca a um dicionario de aparencia do Humanoid.
static func apply(look: Dictionary, id: String, cond: float = 1.0) -> void:
	var p := parse(id)
	var b: Dictionary = BASES.get(p[0], BASES["camiseta"])
	var col := color_of(id)
	var col2 := color2_of(id)
	if cond < 0.5:
		col = col.lerp(Color(0.4, 0.37, 0.33), (0.5 - cond) * 0.6)
	var v: Dictionary = b["vis"].duplicate()
	v["col"] = col
	v["col2"] = col2
	var pname: String = b["pats"][clampi(p[2], 0, b["pats"].size() - 1)]
	v["pname"] = pname
	match b["slot"]:
		"top":
			v["pat"] = TOP_PATS.find(pname) if pname in TOP_PATS else (6 if pname == "faixas refletivas" else 0)
			look["top"] = v
		"dress":
			v["pat"] = TOP_PATS.find(pname)
			look["top"] = v
			look["bottom"] = {"style": 3, "len": v["skirt"], "col": col, "col2": col2, "pat": 1 if pname == "listrado" else 0}
		"over":
			v["pat"] = OVER_PATS.find(pname) if pname in OVER_PATS else 0
			look["over"] = v
		"bottom":
			v["pat"] = 0
			if pname == "faixa lateral":
				v["pat"] = 1
			elif pname == "barra contrastante":
				v["pat"] = 2
			elif pname == "listrado":
				v["pat"] = 3
			look["bottom"] = v
		"shoes":
			v["sole"] = pname == "sola clara"
			look["shoes"] = v
		"hat":
			v["trim"] = pname != "liso"
			look["hat"] = v
		"gloves":
			look["gloves"] = col
		"belt":
			look["belt"] = col
		"mask":
			look["mask"] = col
		"glasses":
			look["glasses"] = Color(0.05, 0.05, 0.06) if v.get("dark", false) else col
			look["glasses_dark"] = v.get("dark", false)
		"bag":
			v["trim"] = pname != "liso"
			look["bag"] = v


## Constroi a aparencia a partir das pecas vestidas: worn = {slot: item}
static func look_from(base_look: Dictionary, worn: Dictionary) -> Dictionary:
	var l := base_look.duplicate(true)
	for k in ["top", "over", "bottom", "shoes", "hat", "bag", "gloves", "belt", "mask", "glasses"]:
		l.erase(k)
	var dirt := 0.0
	var blood := 0.0
	var cnt := 0
	for slot in worn:
		var it: Dictionary = worn[slot]
		apply(l, it["id"], float(it.get("c", 1.0)))
		dirt += float(it.get("dirt", 0.0))
		blood += float(it.get("bl", 0.0))
		cnt += 1
	if cnt > 0:
		l["dirt"] = clampf(dirt / cnt, 0.0, 1.0)
		l["blood"] = clampf(blood / cnt, 0.0, 1.0)
	if not l.has("shoes"):
		l["shoes"] = {"style": 0}
	return l


const SKINS := [Color(0.95, 0.80, 0.69), Color(0.89, 0.71, 0.58), Color(0.80, 0.60, 0.46), Color(0.68, 0.48, 0.34), Color(0.52, 0.36, 0.25), Color(0.36, 0.24, 0.17)]
const HAIRS := [Color(0.08, 0.07, 0.06), Color(0.20, 0.13, 0.08), Color(0.36, 0.23, 0.12), Color(0.62, 0.44, 0.22), Color(0.80, 0.68, 0.40), Color(0.55, 0.20, 0.10), Color(0.60, 0.60, 0.60), Color(0.86, 0.86, 0.84)]


## Corpo aleatorio (rosto, pele, cabelo, barba, porte).
static func random_body(r: RandomNumberGenerator) -> Dictionary:
	var fem := r.randf() < 0.5
	return {
		"seed": r.randi(), "female": fem, "skin": SKINS[r.randi() % SKINS.size()], "hair": HAIRS[r.randi() % HAIRS.size()],
		"hair_style": (r.randi() % 5 + 1) if fem else (r.randi() % 6), "beard": 0 if fem else ([0, 0, 0, 1, 2][r.randi() % 5]),
		"build": r.randf_range(0.9, 1.16), "height": r.randf_range(0.94, 1.05)}


## Aparencia completa de zumbi conforme o perfil do local.
static func zombie_look(r: RandomNumberGenerator, profile: String) -> Dictionary:
	var l := random_body(r)
	l["zombie"] = true
	l["dirt"] = r.randf_range(0.3, 1.0)
	l["blood"] = r.randf_range(0.2, 1.0)
	var worn: Array = []
	match profile:
		"policia":
			worn = ["r_uniforme_policia_%d_0" % (r.randi() % 2), "r_calca_policia_%d_0" % (r.randi() % 2), "r_bota_militar_0_0"]
			if r.randf() < 0.5:
				worn.append("r_quepe_0_0")
			if r.randf() < 0.4:
				worn.append("r_colete_policial_0_0")
		"saude":
			var c := r.randi() % 6
			worn = ["r_uniforme_saude_%d_0" % c, "r_calca_social_%d_0" % (r.randi() % 4), "r_tenis_0_0"]
			if r.randf() < 0.45:
				worn.append("r_jaleco_0_0")
			if r.randf() < 0.3:
				worn.append("r_mascara_cirurgica_0_0")
		"obra":
			worn = ["r_uniforme_trabalho_%d_%d" % [r.randi() % 8, r.randi() % 2], "r_calca_trabalho_%d_0" % (r.randi() % 8), "r_bota_trabalho_%d_0" % (r.randi() % 6)]
			if r.randf() < 0.6:
				worn.append("r_capacete_obra_%d_0" % (r.randi() % 6))
			if r.randf() < 0.3:
				worn.append("r_colete_utilitario_%d_1" % (r.randi() % 8))
		"bombeiro":
			worn = ["r_camiseta_5_0", "r_calca_trabalho_1_0", "r_bota_trabalho_1_0", "r_jaqueta_bombeiro_%d_0" % (r.randi() % 3)]
			if r.randf() < 0.6:
				worn.append("r_capacete_bombeiro_0_0")
		"escritorio":
			worn = [random_id(r, "top") if r.randf() < 0.3 else "r_camisa_%d_%d" % [r.randi() % 24, 0], "r_calca_social_%d_0" % (r.randi() % 16), "r_sapato_%d_0" % (r.randi() % 6)]
		"fazenda":
			worn = ["r_flanela_%d_3" % (r.randi() % 24), "r_calca_jeans_%d_0" % (r.randi() % 6), "r_bota_trabalho_%d_0" % (r.randi() % 6)]
			if r.randf() < 0.5:
				worn.append("r_chapeu_%d_0" % (r.randi() % 6))
		_:
			if l["female"] and r.randf() < 0.22:
				worn.append(random_id(r, "dress"))
			else:
				worn.append(random_id(r, "top"))
				worn.append(random_id(r, "bottom"))
			if r.randf() < 0.85:
				worn.append(random_id(r, "shoes"))
			if r.randf() < 0.3:
				worn.append(random_id(r, "over"))
			if r.randf() < 0.18:
				worn.append(random_id(r, "hat"))
			if r.randf() < 0.1:
				worn.append(random_id(r, "bag"))
			if r.randf() < 0.08:
				worn.append(random_id(r, "glasses"))
	for id in worn:
		apply(l, id, 0.6)
	if not l.has("shoes"):
		l["shoes"] = {"style": 0}
	l["worn_ids"] = worn
	return l
