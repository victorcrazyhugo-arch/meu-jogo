class_name Survivor
extends RefCounted
## Estado de sobrevivencia do personagem: necessidades, saude por partes do corpo,
## ferimentos, doencas, infeccao zumbi, psicologia, habilidades, profissao e tracos.

const PARTS := ["Mão esquerda", "Mão direita", "Antebraço esquerdo", "Antebraço direito", "Braço esquerdo", "Braço direito",
	"Tórax", "Abdômen", "Cabeça", "Pescoço", "Virilha", "Coxa esquerda", "Coxa direita", "Canela esquerda", "Canela direita", "Pé esquerdo", "Pé direito"]
# peso de sorteio de onde um zumbi atinge (frente)
const HIT_WEIGHT := [8, 8, 12, 12, 10, 10, 12, 8, 2, 4, 2, 4, 4, 2, 2, 0, 0]
const WOUND_NAMES := {"arranhao": "Arranhão", "laceracao": "Laceração", "mordida": "Mordida", "profunda": "Ferida profunda",
	"queimadura": "Queimadura", "fratura": "Fratura", "vidro": "Vidro alojado", "corte": "Corte"}
# horas-base de cura, sangramento por hora (pontos de saude), dor
const WOUND_DEF := {
	"arranhao": {"heal": 48.0, "bleed": 1.2, "pain": 0.10, "bleed_h": 3.0},
	"corte": {"heal": 60.0, "bleed": 2.0, "pain": 0.12, "bleed_h": 5.0},
	"laceracao": {"heal": 110.0, "bleed": 4.0, "pain": 0.22, "bleed_h": 12.0},
	"mordida": {"heal": 170.0, "bleed": 4.5, "pain": 0.30, "bleed_h": 16.0},
	"profunda": {"heal": 220.0, "bleed": 8.0, "pain": 0.42, "bleed_h": 9999.0},
	"queimadura": {"heal": 200.0, "bleed": 0.0, "pain": 0.40, "bleed_h": 0.0},
	"fratura": {"heal": 900.0, "bleed": 0.0, "pain": 0.45, "bleed_h": 0.0},
	"vidro": {"heal": 9999.0, "bleed": 2.5, "pain": 0.25, "bleed_h": 9999.0},
}

const SKILLS := {
	"forca": "Força", "fitness": "Condicionamento", "corrida": "Corrida", "furtividade": "Furtividade", "pe_leve": "Passos leves", "agilidade": "Agilidade em combate",
	"machado": "Machados", "cont_longo": "Contundentes longas", "cont_curto": "Contundentes curtas", "lam_longa": "Lâminas longas", "lam_curta": "Lâminas curtas", "lanca": "Lanças",
	"manutencao": "Manutenção", "mira": "Mira", "recarga": "Recarga",
	"carpintaria": "Carpintaria", "culinaria": "Culinária", "socorros": "Primeiros socorros", "eletrica": "Elétrica", "mecanica": "Mecânica", "costura": "Costura",
	"agricultura": "Agricultura", "coleta": "Coleta vegetal", "metalurgia": "Trabalho com metal", "alvenaria": "Alvenaria", "entalhe": "Entalhe"}
const SKILL_GROUPS := [["Físico", ["forca", "fitness", "corrida", "furtividade", "pe_leve", "agilidade"]],
	["Combate", ["machado", "cont_longo", "cont_curto", "lam_longa", "lam_curta", "lanca", "manutencao", "mira", "recarga"]],
	["Ofícios", ["carpintaria", "culinaria", "socorros", "eletrica", "mecanica", "costura", "metalurgia", "alvenaria", "entalhe"]],
	["Sobrevivência", ["agricultura", "coleta"]]]
const WT_SKILL := {"contundente_longo": "cont_longo", "contundente_curto": "cont_curto", "machado": "machado", "lamina_longa": "lam_longa", "lamina_curta": "lam_curta", "lanca": "lanca"}
const LV_XP := [75, 150, 300, 750, 1500, 3000, 4500, 6000, 7500, 9000]

## profissao: n nome, pts pontos livres, sk habilidades iniciais, know conhecimentos, d descricao
const PROFESSIONS := {
	"desempregado": {"n": "Desempregado", "pts": 8, "sk": {}, "d": "Sem especialidade. Mais pontos para traços."},
	"policial": {"n": "Policial", "pts": -4, "sk": {"mira": 3, "recarga": 2, "agilidade": 1}, "d": "Treinado com armas de fogo."},
	"bombeiro": {"n": "Bombeiro", "pts": 0, "sk": {"machado": 1, "fitness": 1, "forca": 1, "corrida": 1}, "d": "Forte, resistente e habituado ao machado."},
	"enfermeiro": {"n": "Enfermeiro", "pts": 2, "sk": {"socorros": 2, "pe_leve": 1}, "d": "Trata ferimentos mais rápido e melhor."},
	"medico": {"n": "Médico", "pts": -2, "sk": {"socorros": 3, "lam_curta": 1}, "d": "Especialista em tratamento."},
	"carpinteiro": {"n": "Carpinteiro", "pts": 2, "sk": {"carpintaria": 3, "cont_curto": 1}, "d": "Constrói e barrica com eficiência."},
	"mecanico": {"n": "Mecânico", "pts": -4, "sk": {"mecanica": 3, "cont_curto": 1}, "know": ["ligacao_direta"], "d": "Conserta veículos e sabe fazer ligação direta."},
	"eletricista": {"n": "Eletricista", "pts": -4, "sk": {"eletrica": 3}, "know": ["usar_gerador"], "d": "Opera geradores sem precisar de manual."},
	"agricultor": {"n": "Agricultor", "pts": 2, "sk": {"agricultura": 3}, "d": "Cultiva com mais rendimento e menos doenças."},
	"cozinheiro": {"n": "Cozinheiro", "pts": -4, "sk": {"culinaria": 3, "manutencao": 1, "lam_curta": 1}, "know": ["conserva", "legumes_secos"], "d": "Prepara e conserva alimentos."},
	"lenhador": {"n": "Lenhador", "pts": 0, "sk": {"machado": 2, "forca": 1}, "d": "Derruba árvores e zumbis com o machado."},
	"guarda_florestal": {"n": "Guarda-florestal", "pts": -2, "sk": {"coleta": 2, "machado": 1, "carpintaria": 1}, "know": ["cataplasma"], "d": "Conhece plantas e se move bem na mata."},
	"operario": {"n": "Operário de obras", "pts": -2, "sk": {"cont_curto": 3, "carpintaria": 1, "alvenaria": 1}, "d": "Acostumado a ferramentas pesadas."},
	"serralheiro": {"n": "Serralheiro", "pts": -6, "sk": {"metalurgia": 3, "manutencao": 2}, "d": "Trabalha com metal e solda."},
	"atleta": {"n": "Atleta", "pts": -6, "sk": {"fitness": 2, "corrida": 2}, "d": "Corre mais e cansa menos."},
	"veterano": {"n": "Veterano", "pts": -8, "sk": {"mira": 2, "recarga": 2}, "tr": ["dessensibilizado"], "d": "Não entra em pânico."},
	"gatuno": {"n": "Gatuno", "pts": -6, "sk": {"agilidade": 2, "furtividade": 2, "pe_leve": 2}, "know": ["ligacao_direta"], "d": "Silencioso; abre e liga carros."},
}

## traco: n nome, c custo (positivo custa pontos, negativo devolve), d descricao, x incompativeis
const TRAITS := {
	"atletico": {"n": "Atlético", "c": 10, "d": "+4 Condicionamento; corre mais rápido.", "x": ["fora_de_forma", "acima_do_peso"], "sk": {"fitness": 4}},
	"forte": {"n": "Forte", "c": 10, "d": "+4 Força; mais dano e carga.", "x": ["fraco", "magro"], "sk": {"forca": 4}},
	"corajoso": {"n": "Corajoso", "c": 4, "d": "Menos propenso ao pânico.", "x": ["covarde"]},
	"gracioso": {"n": "Gracioso", "c": 4, "d": "Faz menos barulho ao se mover.", "x": ["desajeitado"]},
	"discreto": {"n": "Discreto", "c": 4, "d": "Zumbis percebem você com mais dificuldade.", "x": ["chamativo"]},
	"aprende_rapido": {"n": "Aprende rápido", "c": 6, "d": "+30% de experiência.", "x": ["aprende_devagar"]},
	"organizado": {"n": "Organizado", "c": 6, "d": "+30% de capacidade em recipientes.", "x": ["desorganizado"]},
	"estomago_ferro": {"n": "Estômago de ferro", "c": 3, "d": "Menos chance de intoxicação alimentar.", "x": ["estomago_fraco"]},
	"pele_grossa": {"n": "Pele grossa", "c": 8, "d": "Menos chance de arranhões e mordidas romperem a pele.", "x": ["pele_fina"]},
	"cura_rapida": {"n": "Cura rápida", "c": 6, "d": "Ferimentos saram mais depressa.", "x": ["cura_lenta"]},
	"vigilante": {"n": "Dorme pouco", "c": 2, "d": "Precisa de menos sono.", "x": ["sonolento"]},
	"come_pouco": {"n": "Come pouco", "c": 2, "d": "Fome aumenta mais devagar.", "x": ["comilao"]},
	"pouca_sede": {"n": "Pouca sede", "c": 6, "d": "Sede aumenta mais devagar.", "x": ["muita_sede"]},
	"leitor_veloz": {"n": "Leitor veloz", "c": 2, "d": "Lê 30% mais rápido.", "x": ["leitor_lento"]},
	"coruja": {"n": "Coruja", "c": 2, "d": "Enxerga melhor no escuro.", "x": []},
	"sortudo": {"n": "Sortudo", "c": 4, "d": "Encontra mais itens raros.", "x": ["azarado"]},
	"pratico": {"n": "Prático", "c": 8, "d": "+1 Carpintaria e +1 Manutenção; constrói mais resistente.", "x": [], "sk": {"carpintaria": 1, "manutencao": 1}},
	"jardineiro": {"n": "Jardineiro", "c": 4, "d": "+1 Agricultura.", "x": [], "sk": {"agricultura": 1}},
	"socorrista": {"n": "Socorrista", "c": 4, "d": "+1 Primeiros socorros.", "x": [], "sk": {"socorros": 1}},
	"corredor": {"n": "Corredor", "c": 4, "d": "+1 Corrida.", "x": [], "sk": {"corrida": 1}},
	"brigao": {"n": "Brigão", "c": 6, "d": "+1 Contundentes longas e curtas.", "x": [], "sk": {"cont_longo": 1, "cont_curto": 1}},
	"fumante": {"n": "Fumante", "c": -4, "d": "Fica estressado sem cigarros.", "x": []},
	"covarde": {"n": "Covarde", "c": -2, "d": "Entra em pânico com facilidade.", "x": ["corajoso"]},
	"desajeitado": {"n": "Desajeitado", "c": -2, "d": "Faz mais barulho ao se mover.", "x": ["gracioso"]},
	"chamativo": {"n": "Chamativo", "c": -4, "d": "Zumbis percebem você com mais facilidade.", "x": ["discreto"]},
	"aprende_devagar": {"n": "Aprende devagar", "c": -6, "d": "-30% de experiência.", "x": ["aprende_rapido"]},
	"desorganizado": {"n": "Desorganizado", "c": -4, "d": "-30% de capacidade em recipientes.", "x": ["organizado"]},
	"estomago_fraco": {"n": "Estômago fraco", "c": -3, "d": "Mais chance de intoxicação alimentar.", "x": ["estomago_ferro"]},
	"pele_fina": {"n": "Pele fina", "c": -8, "d": "Arranhões e mordidas rompem a pele com mais facilidade.", "x": ["pele_grossa"]},
	"cura_lenta": {"n": "Cura lenta", "c": -6, "d": "Ferimentos demoram mais a sarar.", "x": ["cura_rapida"]},
	"sonolento": {"n": "Sonolento", "c": -4, "d": "Precisa de mais sono.", "x": ["vigilante"]},
	"comilao": {"n": "Comilão", "c": -4, "d": "Fome aumenta mais depressa.", "x": ["come_pouco"]},
	"muita_sede": {"n": "Muita sede", "c": -6, "d": "Sede aumenta mais depressa.", "x": ["pouca_sede"]},
	"leitor_lento": {"n": "Leitor lento", "c": -2, "d": "Lê 30% mais devagar.", "x": ["leitor_veloz"]},
	"azarado": {"n": "Azarado", "c": -4, "d": "Encontra menos itens raros.", "x": ["sortudo"]},
	"fora_de_forma": {"n": "Fora de forma", "c": -6, "d": "-2 Condicionamento.", "x": ["atletico"], "sk": {"fitness": -2}},
	"fraco": {"n": "Fraco", "c": -6, "d": "-2 Força.", "x": ["forte"], "sk": {"forca": -2}},
	"acima_do_peso": {"n": "Acima do peso", "c": -6, "d": "Começa com 95 kg; cansa mais rápido.", "x": ["atletico", "magro"]},
	"magro": {"n": "Abaixo do peso", "c": -6, "d": "Começa com 62 kg; menos força.", "x": ["forte", "acima_do_peso"]},
	"claustrofobico": {"n": "Claustrofóbico", "c": -4, "d": "Pânico em ambientes fechados pequenos.", "x": ["agorafobico"]},
	"agorafobico": {"n": "Agorafóbico", "c": -4, "d": "Pânico em áreas abertas.", "x": ["claustrofobico"]},
	"hemofobico": {"n": "Hemofóbico", "c": -5, "d": "Fica estressado com sangue e ferimentos.", "x": []},
	"pacifista": {"n": "Pacifista", "c": -4, "d": "-25% de experiência com armas.", "x": []},
	"insone": {"n": "Sono agitado", "c": -6, "d": "O sono recupera menos.", "x": []},
	"asmatico": {"n": "Asmático", "c": -5, "d": "Fôlego acaba mais rápido.", "x": ["atletico"]},
	"adoece_facil": {"n": "Adoece fácil", "c": -4, "d": "Mais chance de resfriado e infecção de feridas.", "x": []},
	"dessensibilizado": {"n": "Dessensibilizado", "c": 0, "d": "Não entra em pânico (exclusivo de profissão).", "x": [], "prof": true},
}

# ---- identidade
var name := "Sobrevivente"
var profession := "desempregado"
var traits: Array = []
var body_look: Dictionary = {}
var known: Array = []            # receitas e conhecimentos aprendidos

# ---- necessidades (0..1 salvo indicacao)
var hunger := 0.0
var thirst := 0.0
var fatigue := 0.0
var endurance := 1.0
var stress := 0.0
var panic := 0.0
var boredom := 0.0
var unhappy := 0.0
var drunk := 0.0
var wet := 0.0
var sick := 0.0                  # mal-estar geral (derivado)
var cold_ill := 0.0              # resfriado
var food_poison := 0.0
var health := 100.0
var calories := 800.0
var protein := 100.0
var weight := 80.0
var thermal := 0.0               # -1 hipotermia .. +1 hipertermia
var zinf := -1.0                 # infeccao zumbi: -1 nao infectado; 0..1 progresso
var painkiller := 0.0            # horas restantes
var antibiotic := 0.0
var beta := 0.0
var antidep := 0.0
var sleep_pill := 0.0
var last_smoke := 0.0
var muscle_strain := 0.0
var dead := false
var death_cause := ""
var kills := 0
var asleep := false
var bed_quality := 1.0

var parts: Array = []            # por parte: {"w": [ferimentos]}
var skills: Dictionary = {}      # id -> xp
var xp_boost: Dictionary = {}    # id -> multiplicador de livro
var book_progress: Dictionary = {}   # id do livro -> paginas lidas

# ---- derivados (atualizados a cada tick)
var pain := 0.0
var bleeding := 0.0
var carry := 0.0
var carry_max := 12.0
var insulation := 0.0
var air_temp := 20.0
var _acc := 0.0
var _hour_acc := 0.0
var activity := 0                # 0 parado, 1 andando, 2 correndo, 3 disparando, 4 trabalhando


func _init() -> void:
	for i in PARTS.size():
		parts.append({"w": []})
	for k in SKILLS:
		skills[k] = 0.0


func setup(prof: String, trs: Array) -> void:
	profession = prof
	traits = trs.duplicate()
	var p: Dictionary = PROFESSIONS.get(prof, PROFESSIONS["desempregado"])
	# forca e condicionamento comecam no nivel 5
	skills["forca"] = xp_for_level(5)
	skills["fitness"] = xp_for_level(5)
	var add := {}
	for k in p.get("sk", {}):
		add[k] = int(add.get(k, 0)) + int(p["sk"][k])
		xp_boost[k] = maxf(float(xp_boost.get(k, 1.0)), 1.0 + 0.25 * mini(3, int(p["sk"][k])) + 0.5)
	for t in p.get("tr", []):
		if not traits.has(t):
			traits.append(t)
	for t in traits:
		var td: Dictionary = TRAITS.get(t, {})
		for k in td.get("sk", {}):
			add[k] = int(add.get(k, 0)) + int(td["sk"][k])
	for k in add:
		var base := 5 if (k == "forca" or k == "fitness") else 0
		skills[k] = xp_for_level(clampi(base + int(add[k]), 0, 10))
	for k in p.get("know", []):
		known.append(k)
	if has("acima_do_peso"):
		weight = 95.0
	elif has("magro"):
		weight = 62.0


func has(t: String) -> bool:
	return traits.has(t)


func knows(k: String) -> bool:
	return known.has(k)


# =====================================================================================
#  HABILIDADES
# =====================================================================================
static func xp_for_level(lv: int) -> float:
	var t := 0.0
	for i in mini(lv, 10):
		t += LV_XP[i]
	return t


func level(sk: String) -> int:
	var xp: float = skills.get(sk, 0.0)
	var lv := 0
	for i in 10:
		if xp >= LV_XP[i]:
			xp -= LV_XP[i]
			lv += 1
		else:
			break
	return lv


## Progresso 0..1 dentro do nivel atual.
func level_frac(sk: String) -> float:
	var xp: float = skills.get(sk, 0.0)
	for i in 10:
		if xp >= LV_XP[i]:
			xp -= LV_XP[i]
		else:
			return xp / LV_XP[i]
	return 1.0


func add_xp(sk: String, amount: float) -> void:
	if not skills.has(sk):
		return
	var m: float = float(G.sandbox.get("xp_mult", 1.0)) * float(xp_boost.get(sk, 1.0))
	if has("aprende_rapido"):
		m *= 1.3
	if has("aprende_devagar"):
		m *= 0.7
	if has("pacifista") and sk in ["machado", "cont_longo", "cont_curto", "lam_longa", "lam_curta", "lanca", "mira"]:
		m *= 0.75
	var before := level(sk)
	skills[sk] = minf(float(skills[sk]) + amount * m, xp_for_level(10))
	var after := level(sk)
	if after > before:
		G.say("%s subiu para o nível %d" % [SKILLS[sk], after])
		Sfx.ui("ui_open")


# =====================================================================================
#  FERIMENTOS
# =====================================================================================
func add_wound(part: int, type: String, infected_chance: float = 0.0) -> Dictionary:
	var d: Dictionary = WOUND_DEF[type]
	var sev: float = float(G.sandbox.get("wound_severity", 1.0))
	var w := {"t": type, "h": float(d["heal"]) * sev * (1.3 if has("cura_lenta") else (0.75 if has("cura_rapida") else 1.0)),
		"bl": float(d["bleed_h"]), "band": 0, "bt": 0.0, "dis": 0.0, "inf": 0.0, "st": 0, "sp": 0}
	parts[part]["w"].append(w)
	if infected_chance > 0.0 and zinf < 0.0 and randf() < infected_chance:
		zinf = 0.0
	return w


func wound_count() -> int:
	var c := 0
	for p in parts:
		c += p["w"].size()
	return c


func part_pain(i: int) -> float:
	var s := 0.0
	for w in parts[i]["w"]:
		var p: float = float(WOUND_DEF[w["t"]]["pain"])
		if w["band"] > 0:
			p *= 0.7
		if w["t"] == "fratura" and w["sp"] > 0:
			p *= 0.4
		s += p + float(w["inf"]) * 0.2
	return s


func has_fracture(indices: Array) -> bool:
	for i in indices:
		for w in parts[i]["w"]:
			if w["t"] == "fratura":
				return true
	return false


## Penalidade de movimento por ferimentos nas pernas e pes (0..0.6)
func leg_penalty() -> float:
	var s := 0.0
	for i in [11, 12, 13, 14, 15, 16]:
		s += part_pain(i)
	return clampf(s * 0.6, 0.0, 0.6)


## Penalidade de acoes manuais por ferimentos em maos e bracos (0..0.6)
func arm_penalty() -> float:
	var s := 0.0
	for i in [0, 1, 2, 3, 4, 5]:
		s += part_pain(i)
	return clampf(s * 0.6, 0.0, 0.6)


## Protecao de roupa (0..1) sobre uma parte do corpo.
func protection(part: int, worn: Dictionary) -> float:
	var p := 0.0
	for slot in worn:
		var cov: Array = Clothes.SLOT_COVER.get(slot, [])
		if part in cov:
			var it: Dictionary = worn[slot]
			var d := Clothes.def(it["id"])
			p = 1.0 - (1.0 - p) * (1.0 - float(d["prot"]) * (0.4 + 0.6 * float(it.get("c", 1.0))))
	return p


## Ataque de zumbi. Retorna descricao do resultado ("" = roupa protegeu).
func zombie_hit(worn: Dictionary, from_behind: bool, strength: int) -> String:
	var tw := 0
	var wts := HIT_WEIGHT.duplicate()
	if from_behind:
		wts[9] = 14
		wts[8] = 6
		wts[6] = 14
	for x in wts:
		tw += x
	var r := randi() % tw
	var part := 0
	for i in wts.size():
		r -= wts[i]
		if r < 0:
			part = i
			break
	var prot := protection(part, worn)
	# desgaste da roupa que cobre a parte
	for slot in worn:
		if part in Clothes.SLOT_COVER.get(slot, []):
			worn[slot]["c"] = maxf(0.0, float(worn[slot].get("c", 1.0)) - randf_range(0.02, 0.08))
			worn[slot]["bl"] = minf(1.0, float(worn[slot].get("bl", 0.0)) + 0.1)
	var skin_m := 1.0
	if has("pele_grossa"):
		skin_m = 0.7
	elif has("pele_fina"):
		skin_m = 1.3
	if randf() < prot or randf() > (0.62 + 0.1 * strength) * skin_m:
		return ""
	var roll := randf()
	var bite_ch := 0.14 + 0.05 * strength
	var lac_ch := 0.30
	var type := "arranhao"
	var inf_ch := 0.07
	if roll < bite_ch:
		type = "mordida"
		inf_ch = 1.0
	elif roll < bite_ch + lac_ch:
		type = "laceracao"
		inf_ch = 0.25
	var mode := int(G.sandbox.get("infection", 0))
	if mode == 2:
		inf_ch = 0.0
	elif mode == 1 and type != "mordida":
		inf_ch = 0.0
	add_wound(part, type, inf_ch)
	health -= {"arranhao": 3.0, "laceracao": 7.0, "mordida": 10.0}[type] * float(G.sandbox.get("wound_severity", 1.0))
	stress = minf(1.0, stress + 0.1)
	return "%s: %s" % [WOUND_NAMES[type], PARTS[part]]


# =====================================================================================
#  ATUALIZACAO (dm = minutos de jogo decorridos)
# =====================================================================================
func tick(dm: float, ctx: Dictionary) -> void:
	if dead:
		return
	_acc += dm
	if _acc < 0.25:
		return
	var m := _acc
	_acc = 0.0
	var h := m / 60.0
	var indoors: bool = ctx.get("indoors", false)
	air_temp = float(ctx.get("temp", 20.0))
	insulation = float(ctx.get("insulation", 0.0))
	var raining: bool = ctx.get("rain", false)
	var water_res: float = float(ctx.get("water_res", 0.0))
	var near_heat: bool = ctx.get("heat", false)
	var zombies_near: int = int(ctx.get("zombies_near", 0))
	var act_m: float = [1.0, 1.25, 1.7, 2.3, 1.5][clampi(activity, 0, 4)]
	if asleep:
		act_m = 0.5

	# ---- fome, sede, calorias
	var hm := act_m
	if has("comilao"):
		hm *= 1.5
	if has("come_pouco"):
		hm *= 0.75
	if thermal < -0.3:
		hm *= 1.3
	hunger = minf(1.0, hunger + 0.022 * h * hm)
	var tm := act_m
	if has("muita_sede"):
		tm *= 2.0
	if has("pouca_sede"):
		tm *= 0.5
	if thermal > 0.3:
		tm *= 1.6
	thirst = minf(1.0, thirst + 0.036 * h * tm)
	calories -= 1.15 * m * act_m * (weight / 80.0)
	protein = maxf(0.0, protein - 0.05 * m)

	# ---- sono
	if asleep:
		var q := bed_quality * (0.7 if has("insone") else 1.0) * (1.0 - 0.4 * clampf(pain - 0.3, 0.0, 1.0))
		var rate := 0.125 * q * (1.3 if has("vigilante") else (0.8 if has("sonolento") else 1.0))
		fatigue = maxf(0.0, fatigue - rate * h)
		endurance = minf(1.0, endurance + 0.6 * h)
	else:
		var fr := 0.042 * (0.7 if has("vigilante") else (1.3 if has("sonolento") else 1.0))
		fatigue = minf(1.0, fatigue + fr * h * (1.0 + 0.3 * float(activity >= 2)))
	if sleep_pill > 0.0:
		sleep_pill -= h
		if not asleep:
			fatigue = minf(1.0, fatigue + 0.1 * h)

	# ---- temperatura corporal
	var feels := air_temp + insulation * 16.0
	if indoors:
		feels += 4.0
	if near_heat:
		feels += 14.0
	feels -= wet * 9.0
	if activity >= 2:
		feels += 5.0
	var target := 0.0
	if feels < 16.0:
		target = -clampf((16.0 - feels) / 22.0, 0.0, 1.0)
	elif feels > 31.0:
		target = clampf((feels - 31.0) / 14.0, 0.0, 1.0)
	thermal = move_toward(thermal, target, h * 1.2)
	# ---- umidade
	if raining and not indoors:
		wet = minf(1.0, wet + h * 2.2 * (1.0 - water_res * 0.9))
	else:
		wet = maxf(0.0, wet - h * (0.9 if indoors else 0.5) * (3.0 if near_heat else 1.0))

	# ---- psicologia
	var pan_gain := 0.0
	if zombies_near > 0 and not has("dessensibilizado"):
		var days := G.time_min / 1440.0
		var habit := clampf(1.0 - days / 150.0, 0.25, 1.0)
		pan_gain = float(zombies_near) * 0.9 * habit * (1.6 if has("covarde") else (0.5 if has("corajoso") else 1.0))
	if has("claustrofobico") and indoors and ctx.get("small_room", false):
		pan_gain += 0.6
	if has("agorafobico") and not indoors:
		pan_gain += 0.25
	if beta > 0.0:
		pan_gain *= 0.25
		beta -= h
	pan_gain *= 1.0 - 0.5 * drunk
	if pan_gain > 0.0:
		panic = minf(1.0, panic + pan_gain * h * 8.0)
	else:
		panic = maxf(0.0, panic - h * 6.0)
	var st_gain := panic * 0.25
	if has("fumante"):
		var since := (G.time_min - last_smoke) / 60.0
		if since > 6.0:
			st_gain += 0.05 * minf(4.0, since / 12.0)
	if has("hemofobico") and bleeding > 0.0:
		st_gain += 0.4
	if cold_ill > 0.4 or thermal < -0.5:
		st_gain += 0.03
	stress = clampf(stress + (st_gain - 0.06) * h, 0.0, 1.0)
	if indoors and activity == 0 and not asleep:
		boredom = minf(1.0, boredom + 0.035 * h)
	else:
		boredom = maxf(0.0, boredom - 0.05 * h * float(activity >= 1))
	var un := 0.0
	if boredom > 0.5:
		un += 0.03
	if hunger > 0.7:
		un += 0.02
	if antidep > 0.0:
		antidep -= h
		un -= 0.08
	unhappy = clampf(unhappy + (un - 0.004) * h, 0.0, 1.0)
	drunk = maxf(0.0, drunk - 0.12 * h)
	if painkiller > 0.0:
		painkiller -= h
	if antibiotic > 0.0:
		antibiotic -= h
	muscle_strain = maxf(0.0, muscle_strain - 0.03 * h)

	# ---- ferimentos
	bleeding = 0.0
	var pn := 0.0
	var heal_m := 1.0
	if hunger < 0.25 and thirst < 0.25:
		heal_m = 1.4
	if hunger > 0.7:
		heal_m = 0.5
	for pi in parts.size():
		var ws: Array = parts[pi]["w"]
		var k := ws.size() - 1
		while k >= 0:
			var w: Dictionary = ws[k]
			var d: Dictionary = WOUND_DEF[w["t"]]
			# sangramento
			if float(w["bl"]) > 0.0 and w["st"] == 0:
				var b: float = float(d["bleed"])
				if w["band"] > 0:
					b *= 0.08
					w["bl"] = float(w["bl"]) - h * 2.5
				else:
					w["bl"] = float(w["bl"]) - h
				if pi == 9:
					b *= 4.0
				bleeding += b
			# curativo suja com o tempo
			if w["band"] > 0:
				w["bt"] = float(w["bt"]) + h
				if w["band"] == 1 and float(w["bt"]) > (30.0 if float(w["bl"]) <= 0.0 else 9.0):
					w["band"] = 2
			# infeccao comum de ferida
			var inf_r := 0.0
			if w["t"] != "fratura":
				if w["band"] == 0:
					inf_r = 0.006
				elif w["band"] == 2:
					inf_r = 0.012
				if float(w["dis"]) > 0.0:
					inf_r *= 0.15
					w["dis"] = float(w["dis"]) - h
				if has("adoece_facil"):
					inf_r *= 1.5
				if antibiotic > 0.0:
					inf_r = -0.05
				elif w["band"] == 1:
					inf_r -= 0.004
				w["inf"] = clampf(float(w["inf"]) + inf_r * h, 0.0, 1.0)
			# cura
			var hm2 := heal_m
			if w["band"] == 1:
				hm2 *= 1.6
			if w["st"] > 0:
				hm2 *= 2.2
			if w["t"] == "fratura":
				hm2 *= 2.5 if w["sp"] > 0 else 0.6
			if float(w["inf"]) > 0.3:
				hm2 *= 0.3
			if w["t"] != "vidro":
				w["h"] = float(w["h"]) - h * hm2
			if float(w["h"]) <= 0.0:
				ws.remove_at(k)
			k -= 1
		pn += part_pain(pi)
	pain = clampf(pn, 0.0, 1.0)
	if painkiller > 0.0:
		pain *= 0.3
	pain *= 1.0 - 0.4 * drunk

	# ---- doencas
	if (thermal < -0.4 or (wet > 0.6 and air_temp < 16.0)) and cold_ill <= 0.0:
		if randf() < 0.02 * h * (2.0 if has("adoece_facil") else 1.0) * 6.0:
			cold_ill = 0.15
			G.say("Você pegou um resfriado.")
	if cold_ill > 0.0:
		if thermal < -0.2 or hunger > 0.6 or wet > 0.5:
			cold_ill = minf(1.0, cold_ill + 0.03 * h)
		else:
			cold_ill = maxf(0.0, cold_ill - 0.02 * h)
	if food_poison > 0.0:
		food_poison = maxf(0.0, food_poison - 0.035 * h)
	var winf := 0.0
	for p in parts:
		for w in p["w"]:
			winf = maxf(winf, float(w["inf"]))
	# ---- infeccao zumbi: progride ate a morte, sem cura
	if zinf >= 0.0:
		var days: float = maxf(0.5, float(G.sandbox.get("infection_days", 2.5)))
		zinf += h / (days * 24.0)
	sick = clampf(maxf(maxf(food_poison, cold_ill * 0.5), maxf(winf * 0.6, zinf if zinf >= 0.0 else 0.0)), 0.0, 1.0)

	# ---- saude geral
	var dmg := bleeding * h
	if hunger >= 1.0:
		dmg += 2.5 * h
	if thirst >= 1.0:
		dmg += 5.0 * h
	if thermal <= -0.9:
		dmg += 3.0 * h
	if thermal >= 0.95:
		dmg += 2.0 * h
	if food_poison > 0.4:
		dmg += food_poison * 3.0 * h
	if winf > 0.7:
		dmg += 1.2 * h
	if zinf >= 0.35:
		dmg += (zinf - 0.3) * 9.0 * h
	if dmg > 0.0:
		health -= dmg
	elif hunger < 0.5 and thirst < 0.5 and sick < 0.2:
		health = minf(100.0, health + (1.6 if hunger < 0.15 else 0.8) * h * (1.4 if asleep else 1.0))
	if zinf >= 1.0:
		health = 0.0
	if health <= 0.0:
		dead = true
		health = 0.0
		if zinf >= 0.35:
			death_cause = "infecção"
		elif bleeding > 2.0:
			death_cause = "hemorragia"
		elif hunger >= 1.0:
			death_cause = "fome"
		elif thirst >= 1.0:
			death_cause = "desidratação"
		elif thermal <= -0.9:
			death_cause = "hipotermia"
		else:
			death_cause = "ferimentos"

	# ---- peso corporal (por hora de jogo)
	_hour_acc += h
	if _hour_acc >= 1.0:
		_hour_acc -= 1.0
		if calories > 1500.0:
			weight = minf(130.0, weight + 0.012)
		elif calories < 0.0:
			weight = maxf(40.0, weight - 0.02)
			calories = maxf(calories, -2200.0)
		if weight < 50.0:
			health -= 0.3


## Recupera/gasta folego em tempo real (dt em segundos).
func tick_endurance(dt: float, sprinting: bool, moving: bool) -> void:
	var fit := level("fitness")
	if sprinting:
		var drain := 0.022 * (1.0 - fit * 0.045)
		if has("asmatico"):
			drain *= 1.4
		if weight > 90.0:
			drain *= 1.25
		drain *= 1.0 + maxf(0.0, carry / maxf(carry_max, 1.0) - 0.8) * 2.0
		endurance = maxf(0.0, endurance - drain * dt)
	else:
		var rec := (0.016 if moving else 0.03) * (1.0 + fit * 0.05)
		if fatigue > 0.7:
			rec *= 0.5
		if hunger > 0.7 or thirst > 0.7:
			rec *= 0.6
		if carry > carry_max:
			rec *= 0.4
		endurance = minf(1.0, endurance + rec * dt)


func spend(amount: float) -> void:
	endurance = maxf(0.0, endurance - amount * (1.0 - level("fitness") * 0.03))


# =====================================================================================
#  CONSUMO E TRATAMENTO
# =====================================================================================
func eat(it: Dictionary, frac: float = 1.0) -> void:
	var d := Items.def(it["id"])
	var fresh := Items.freshness(it)
	var hun: float = float(d.get("hun", 0.0)) * frac
	var cooked: int = it.get("ck", 0)
	if cooked == 1 and d.has("cook"):
		hun *= 1.3
	elif cooked == 2:
		hun *= 0.5
	hunger = clampf(hunger - hun, 0.0, 1.0)
	thirst = clampf(thirst - float(d.get("thi", 0.0)) * frac, 0.0, 1.0)
	calories += float(d.get("cal", 0.0)) * frac
	protein += float(d.get("pro", 0.0)) * frac
	var un: float = float(d.get("unh", 0.0)) * frac
	if fresh == 1:
		un += 0.05
	if cooked == 2:
		un += 0.1
	unhappy = clampf(unhappy + un, 0.0, 1.0)
	boredom = clampf(boredom + float(d.get("bor", 0.0)) * frac - 0.03, 0.0, 1.0)
	if d.has("alc"):
		drunk = clampf(drunk + float(d["alc"]) * frac, 0.0, 1.0)
	if d.has("fat"):
		fatigue = clampf(fatigue + float(d["fat"]), 0.0, 1.0)
	# riscos: cru, estragado, cogumelo desconhecido
	var risk := 0.0
	if fresh == 2:
		risk += 0.55
	if d.has("raw") and cooked == 0:
		risk += 0.4
	if d.has("poison") and not (level("coleta") >= 4):
		risk += float(d["poison"])
	if has("estomago_ferro"):
		risk *= 0.5
	if has("estomago_fraco"):
		risk *= 1.6
	if risk > 0.0 and randf() < risk:
		food_poison = clampf(food_poison + randf_range(0.3, 0.7) * frac, 0.0, 1.0)
		G.say("Algo não caiu bem...")


func drink_water(liters: float, dirty: bool) -> void:
	thirst = clampf(thirst - liters * 0.9, 0.0, 1.0)
	if dirty and randf() < 0.6:
		food_poison = clampf(food_poison + randf_range(0.15, 0.45), 0.0, 1.0)
		G.say("A água estava contaminada.")


func take_med(kind: String) -> String:
	match kind:
		"analgesico":
			painkiller = 6.0
			return "Analgésico tomado: a dor vai diminuir."
		"antibiotico":
			antibiotic = 24.0
			return "Antibiótico tomado: combate infecções comuns de feridas."
		"antidepressivo":
			antidep = 48.0
			return "Antidepressivo tomado: o efeito é lento."
		"betabloqueador":
			beta = 6.0
			panic *= 0.3
			return "Betabloqueador tomado: menos pânico."
		"sonifero":
			sleep_pill = 6.0
			return "Sonífero tomado."
		"vitaminas":
			fatigue = maxf(0.0, fatigue - 0.12)
			return "Vitaminas tomadas: um pouco menos cansado."
		"cigarro":
			last_smoke = G.time_min
			stress = maxf(0.0, stress - 0.35)
			return "Você fumou um cigarro."
	return ""


## Lista ferimentos como [indice_da_parte, indice_do_ferimento, dicionario]
func wounds_list() -> Array:
	var o: Array = []
	for i in parts.size():
		var ws: Array = parts[i]["w"]
		for k in ws.size():
			o.append([i, k, ws[k]])
	return o


func moodles() -> Array:
	var o: Array = []
	_m(o, "FOME", "Fome", hunger, [0.15, 0.25, 0.45, 0.70], ["Com um pouco de fome", "Com fome", "Muita fome", "Faminto"])
	_m(o, "SEDE", "Sede", thirst, [0.12, 0.25, 0.50, 0.75], ["Boca seca", "Com sede", "Muita sede", "Desidratado"])
	_m(o, "SONO", "Sono", fatigue, [0.60, 0.70, 0.80, 0.90], ["Sonolento", "Cansado", "Muito cansado", "Exausto de sono"])
	_m(o, "FÔLE", "Fôlego", 1.0 - endurance, [0.25, 0.50, 0.75, 0.90], ["Esforço moderado", "Ofegante", "Muito ofegante", "Sem fôlego"])
	_m(o, "DOR", "Dor", pain, [0.10, 0.25, 0.50, 0.75], ["Dor leve", "Dor", "Dor forte", "Dor intensa"])
	_m(o, "PÂNI", "Pânico", panic, [0.10, 0.30, 0.55, 0.80], ["Apreensivo", "Com medo", "Em pânico", "Pânico extremo"])
	_m(o, "ESTR", "Estresse", stress, [0.25, 0.50, 0.75, 0.90], ["Ansioso", "Agitado", "Estressado", "Nervos à flor da pele"])
	_m(o, "TÉDI", "Tédio", boredom, [0.25, 0.50, 0.75, 0.90], ["Entediando-se", "Entediado", "Muito entediado", "Tédio extremo"])
	_m(o, "TRIS", "Tristeza", unhappy, [0.20, 0.45, 0.60, 0.80], ["Abatido", "Triste", "Deprimido", "Depressão severa"])
	_m(o, "SANG", "Sangramento", bleeding / 8.0, [0.01, 0.20, 0.50, 0.90], ["Sangramento leve", "Sangrando", "Sangramento grave", "Hemorragia"])
	_m(o, "DOEN", "Doença", sick, [0.15, 0.35, 0.60, 0.85], ["Indisposto", "Enjoado", "Febril", "Febre alta"])
	_m(o, "FRIO", "Frio", -thermal, [0.20, 0.45, 0.70, 0.90], ["Arrepiado", "Com frio", "Muito frio", "Hipotermia"])
	_m(o, "CALO", "Calor", thermal, [0.20, 0.45, 0.70, 0.90], ["Abafado", "Com calor", "Muito calor", "Hipertermia"])
	_m(o, "MOLH", "Molhado", wet, [0.15, 0.40, 0.70, 0.90], ["Úmido", "Molhado", "Encharcado", "Ensopado"])
	_m(o, "BÊBA", "Embriaguez", drunk, [0.15, 0.35, 0.60, 0.85], ["Alegrinho", "Tonto", "Bêbado", "Embriagado"])
	_m(o, "CARG", "Carga", carry / maxf(carry_max, 0.1) - 1.0, [0.001, 0.25, 0.50, 0.75], ["Carga pesada", "Sobrecarregado", "Muito sobrecarregado", "Carga extrema"])
	_m(o, "RESF", "Resfriado", cold_ill, [0.10, 0.40, 0.70, 0.90], ["Nariz escorrendo", "Resfriado", "Resfriado forte", "Gripe forte"])
	if health < 80.0:
		_m(o, "SAÚD", "Saúde", 1.0 - health / 100.0, [0.20, 0.40, 0.60, 0.80], ["Ferimentos leves", "Ferido", "Gravemente ferido", "À beira da morte"])
	return o


func _m(o: Array, abbr: String, title: String, v: float, th: Array, names: Array) -> void:
	var lv := 0
	for i in 4:
		if v >= th[i]:
			lv = i + 1
	if lv > 0:
		o.append({"a": abbr, "t": title, "lv": lv, "d": names[lv - 1]})


# =====================================================================================
#  SALVAMENTO
# =====================================================================================
const SAVE_KEYS := ["name", "profession", "traits", "body_look", "known", "hunger", "thirst", "fatigue", "endurance", "stress", "panic", "boredom", "unhappy",
	"drunk", "wet", "cold_ill", "food_poison", "health", "calories", "protein", "weight", "thermal", "zinf", "painkiller", "antibiotic", "beta", "antidep",
	"sleep_pill", "last_smoke", "muscle_strain", "dead", "death_cause", "kills", "parts", "skills", "xp_boost", "book_progress"]


func to_dict() -> Dictionary:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	return d


func from_dict(d: Dictionary) -> void:
	for k in SAVE_KEYS:
		if d.has(k):
			set(k, d[k])
	for k in SKILLS:
		if not skills.has(k):
			skills[k] = 0.0
