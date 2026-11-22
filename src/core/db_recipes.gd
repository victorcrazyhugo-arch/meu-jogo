class_name Recipes
extends RefCounted
## Receitas de fabricacao e culinaria. Sem cadeias de caca, pesca ou criacao de animais.
## need: itens consumidos ("@veg" = qualquer legume); use: itens com cargas (1 carga);
## tools: etiquetas de ferramenta; sk: [habilidade, nivel]; st: estacao ("", "fogo", "bancada");
## agua: litros; know: conhecimento exigido; out: [id, quantidade]; t: segundos; xp: [habilidade, pontos]

const LIST := [
	# ---------------- carpintaria e entalhe
	{"id": "tabuas", "n": "Serrar tronco em tábuas", "cat": "Carpintaria", "need": {"tronco": 1}, "tools": ["serrote"], "out": ["tabua", 3], "t": 8.0, "xp": ["carpintaria", 6.0], "snd": "saw"},
	{"id": "gravetos", "n": "Quebrar galho em gravetos", "cat": "Carpintaria", "need": {"galho": 1}, "out": ["graveto", 4], "t": 2.0},
	{"id": "lanca", "n": "Lança de madeira", "cat": "Entalhe", "need": {"galho": 1}, "tools": ["faca"], "out": ["lanca", 1], "t": 6.0, "xp": ["entalhe", 6.0]},
	{"id": "lanca_tabua", "n": "Lança de madeira (de tábua)", "cat": "Entalhe", "need": {"tabua": 1}, "tools": ["faca"], "out": ["lanca", 1], "t": 9.0, "xp": ["entalhe", 6.0]},
	{"id": "lanca_faca", "n": "Lança com faca", "cat": "Entalhe", "need": {"lanca": 1, "faca_cozinha": 1}, "use": {"fita": 1}, "out": ["lanca_faca", 1], "t": 5.0, "xp": ["entalhe", 8.0]},
	{"id": "taco_pregos", "n": "Taco com pregos", "cat": "Carpintaria", "need": {"taco": 1, "pregos": 5}, "tools": ["martelo"], "out": ["taco_pregos", 1], "t": 5.0, "xp": ["carpintaria", 5.0]},
	{"id": "pedra_lascada", "n": "Lascar pedra", "cat": "Entalhe", "need": {"pedra": 2}, "out": ["pedra_lascada", 1], "t": 5.0, "xp": ["entalhe", 4.0]},
	{"id": "machado_pedra", "n": "Machado de pedra", "cat": "Entalhe", "need": {"galho": 1, "pedra_lascada": 1, "fibra": 3}, "sk": ["entalhe", 1], "out": ["machado_pedra", 1], "t": 10.0, "xp": ["entalhe", 10.0]},
	{"id": "tala", "n": "Tala", "cat": "Primeiros socorros", "need": {"galho": 1, "pano": 2}, "out": ["tala", 1], "t": 5.0, "xp": ["socorros", 4.0]},
	# ---------------- costura e fibras
	{"id": "rasgar_lencol", "n": "Rasgar lençol em panos", "cat": "Costura", "need": {"lencol": 1}, "out": ["pano", 4], "t": 3.0, "snd": "bandage"},
	{"id": "corda_lencol", "n": "Corda de lençóis", "cat": "Costura", "need": {"lencol": 2}, "out": ["corda_lencol", 1], "t": 6.0, "xp": ["costura", 3.0]},
	{"id": "corda", "n": "Corda de fibra vegetal", "cat": "Costura", "need": {"fibra": 8}, "sk": ["coleta", 1], "out": ["corda", 1], "t": 12.0, "xp": ["costura", 6.0]},
	{"id": "lavar_pano", "n": "Lavar panos sujos", "cat": "Costura", "need": {"pano_sujo": 1}, "agua": 0.2, "out": ["pano", 1], "t": 3.0, "snd": "water_pour"},
	{"id": "lavar_atadura", "n": "Lavar ataduras sujas", "cat": "Costura", "need": {"atadura_suja": 1}, "agua": 0.2, "out": ["atadura", 1], "t": 3.0, "snd": "water_pour"},
	# ---------------- primeiros socorros
	{"id": "cataplasma", "n": "Cataplasma de ervas", "cat": "Primeiros socorros", "need": {"ervas": 3}, "know": "cataplasma", "out": ["cataplasma", 1], "t": 6.0, "xp": ["socorros", 6.0]},
	# ---------------- culinaria
	{"id": "ferver_agua", "n": "Ferver água (torna potável)", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "special": "ferver", "t": 10.0, "xp": ["culinaria", 2.0]},
	{"id": "salada", "n": "Salada", "cat": "Culinária", "need": {"@veg": 2}, "out": ["salada", 1], "t": 5.0, "xp": ["culinaria", 5.0]},
	{"id": "sopa", "n": "Sopa de legumes", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "need": {"@veg": 2}, "agua": 1.0, "out": ["sopa", 1], "t": 14.0, "xp": ["culinaria", 8.0]},
	{"id": "ensopado", "n": "Ensopado", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "need": {"@veg": 3}, "agua": 1.0, "sk": ["culinaria", 1], "out": ["ensopado", 1], "t": 18.0, "xp": ["culinaria", 12.0]},
	{"id": "arroz_cozido", "n": "Arroz cozido", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "need": {"arroz": 1}, "agua": 1.0, "out": ["arroz_cozido", 4], "t": 14.0, "xp": ["culinaria", 6.0]},
	{"id": "feijao_cozido", "n": "Feijão cozido", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "need": {"feijao_seco": 1}, "agua": 1.5, "out": ["feijao_cozido", 4], "t": 20.0, "xp": ["culinaria", 6.0]},
	{"id": "macarrao_cozido", "n": "Macarrão cozido", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "need": {"macarrao": 1}, "agua": 1.0, "out": ["macarrao_cozido", 3], "t": 12.0, "xp": ["culinaria", 6.0]},
	{"id": "carne_assada", "n": "Carne assada", "cat": "Culinária", "st": "fogo", "tools": ["frigideira"], "need": {"@carne": 1}, "out": ["carne_assada", 1], "t": 12.0, "xp": ["culinaria", 8.0]},
	{"id": "legumes_assados", "n": "Legumes assados", "cat": "Culinária", "st": "fogo", "tools": ["frigideira"], "need": {"@veg": 2}, "out": ["legumes_assados", 1], "t": 10.0, "xp": ["culinaria", 6.0]},
	{"id": "pao_caseiro", "n": "Pão caseiro", "cat": "Culinária", "st": "fogo", "need": {"farinha": 1}, "agua": 0.5, "sk": ["culinaria", 2], "out": ["pao_caseiro", 3], "t": 22.0, "xp": ["culinaria", 14.0]},
	{"id": "conserva", "n": "Conserva de legumes", "cat": "Culinária", "need": {"@veg": 3, "pote_vidro": 1}, "use": {"vinagre": 1, "acucar": 1}, "know": "conserva", "out": ["conserva", 1], "t": 15.0, "xp": ["culinaria", 15.0]},
	{"id": "cafe_pronto", "n": "Preparar café", "cat": "Culinária", "st": "fogo", "tools": ["panela"], "use": {"cafe": 1}, "agua": 0.3, "special": "cafe", "t": 6.0, "xp": ["culinaria", 2.0]},
	# ---------------- armas improvisadas e dispositivos
	{"id": "molotov", "n": "Coquetel incendiário", "cat": "Dispositivos", "need": {"garrafa_vazia": 1, "pano": 1}, "gas": 0.5, "out": ["molotov", 1], "t": 6.0},
	{"id": "chamariz", "n": "Despertador de distração", "cat": "Dispositivos", "need": {"sucata_eletronica": 2, "pilha": 1}, "use": {"fita": 1}, "know": "chamariz", "sk": ["eletrica", 1], "out": ["chamariz", 1], "t": 12.0, "xp": ["eletrica", 12.0]},
	# ---------------- metal e alvenaria
	{"id": "barra_metal", "n": "Fundir sucata em barra", "cat": "Trabalho com metal", "need": {"sucata": 3}, "tools": ["macarico", "mascara_solda"], "sk": ["metalurgia", 1], "out": ["barra_metal", 1], "t": 14.0, "xp": ["metalurgia", 10.0]},
	{"id": "chapa_metal", "n": "Chapa de metal", "cat": "Trabalho com metal", "need": {"sucata": 4}, "tools": ["macarico", "mascara_solda"], "sk": ["metalurgia", 2], "out": ["chapa_metal", 1], "t": 16.0, "xp": ["metalurgia", 12.0]},
	{"id": "pregos_sucata", "n": "Pregos de sucata", "cat": "Trabalho com metal", "need": {"sucata": 1}, "tools": ["martelo"], "sk": ["metalurgia", 1], "out": ["pregos", 8], "t": 10.0, "xp": ["metalurgia", 6.0]},
	{"id": "tijolo", "n": "Tijolos de argila", "cat": "Alvenaria", "st": "fogo", "need": {"argila": 2}, "out": ["tijolo", 2], "t": 20.0, "xp": ["alvenaria", 8.0]},
]

static var _by_id := {}


static func get_r(id: String) -> Dictionary:
	if _by_id.is_empty():
		for r in LIST:
			_by_id[r["id"]] = r
	return _by_id.get(id, {})


static func is_veg(it: Dictionary) -> bool:
	return Items.def(it["id"]).has("veg") and Items.freshness(it) < 2


static func is_meat(it: Dictionary) -> bool:
	return it["id"] in ["bife", "frango"] and Items.freshness(it) < 2 and int(it.get("ck", 0)) == 0


static func count_group(inv: Inv, key: String) -> int:
	var n := 0
	for it in inv.items:
		if (key == "@veg" and is_veg(it)) or (key == "@carne" and is_meat(it)):
			n += int(it["n"])
	return n


## Verifica requisitos. Retorna "" se pode fabricar, senao o que falta (em portugues).
static func missing(r: Dictionary, p: Node, station: String) -> String:
	var inv: Inv = p.inv
	var sv: Survivor = p.sv
	var miss: Array = []
	if r.has("know") and not sv.knows(r["know"]):
		miss.append("conhecimento (livro ou revista)")
	if r.has("sk") and sv.level(r["sk"][0]) < int(r["sk"][1]):
		miss.append("%s nível %d" % [Survivor.SKILLS[r["sk"][0]], r["sk"][1]])
	var st: String = r.get("st", "")
	if st == "fogo" and station != "fogo":
		miss.append("fonte de calor acesa (fogão, lareira ou fogueira)")
	if st == "bancada" and station != "bancada":
		miss.append("bancada de trabalho")
	for t in r.get("tools", []):
		if not inv.has_tag(t):
			miss.append(tool_name(t))
	for k in r.get("need", {}):
		var need: int = r["need"][k]
		var have := count_group(inv, k) if String(k).begins_with("@") else inv.count(k)
		if have < need:
			var nm := "legumes" if k == "@veg" else ("carne crua" if k == "@carne" else String(Items.def(k)["n"]))
			miss.append("%s %d/%d" % [nm, have, need])
	for k in r.get("use", {}):
		if inv.find(k) == null:
			miss.append(String(Items.def(k)["n"]))
	if r.has("agua") and inv.total_liquid("agua") + inv.total_liquid("agua_suja") < float(r["agua"]):
		miss.append("água %.1f L" % float(r["agua"]))
	if r.has("gas") and inv.total_liquid("gasolina") < float(r["gas"]):
		miss.append("gasolina %.1f L" % float(r["gas"]))
	if r.get("special", "") == "ferver" and inv.find_liquid("agua_suja") == null:
		miss.append("água contaminada em um recipiente")
	return ", ".join(miss)


static func tool_name(tag: String) -> String:
	return {"serrote": "serrote", "faca": "faca", "martelo": "martelo", "panela": "panela", "frigideira": "frigideira", "macarico": "maçarico",
		"mascara_solda": "máscara de solda", "colher_pedreiro": "colher de pedreiro", "agulha": "agulha", "tesoura": "tesoura", "pa": "pá ou pazinha",
		"machado": "machado", "chave_fenda": "chave de fenda", "pe_de_cabra": "pé de cabra", "fogo": "isqueiro ou fósforos", "regador": "regador",
		"amolar": "pedra de amolar", "enxada": "enxada", "pinca": "pinça", "mangueira": "mangueira"}.get(tag, tag)


## Consome ingredientes e entrega o resultado.
static func craft(r: Dictionary, p: Node) -> String:
	var inv: Inv = p.inv
	var sv: Survivor = p.sv
	var dirty := false
	for k in r.get("need", {}):
		var need: int = r["need"][k]
		if String(k).begins_with("@"):
			var i := inv.items.size() - 1
			while i >= 0 and need > 0:
				var it: Dictionary = inv.items[i]
				if (k == "@veg" and is_veg(it)) or (k == "@carne" and is_meat(it)):
					var t: int = mini(int(it["n"]), need)
					it["n"] = int(it["n"]) - t
					need -= t
					if int(it["n"]) <= 0:
						inv.items.remove_at(i)
				i -= 1
		else:
			inv.remove(k, need)
	for k in r.get("use", {}):
		var u = inv.find(k)
		if u != null:
			inv.use_charge(u)
	if r.has("agua"):
		var clean := inv.use_liquid("agua", float(r["agua"]))
		if clean < float(r["agua"]):
			inv.use_liquid("agua_suja", float(r["agua"]) - clean)
			dirty = r.get("st", "") != "fogo"
	if r.has("gas"):
		inv.use_liquid("gasolina", float(r["gas"]))
	if r.has("xp"):
		sv.add_xp(r["xp"][0], float(r["xp"][1]))
	match r.get("special", ""):
		"ferver":
			var n := 0
			for it in inv.items:
				if it.has("liq") and it.get("lt", "") == "agua_suja" and float(it["liq"]) > 0.0:
					it["lt"] = "agua"
					n += 1
			return "Água fervida: %d recipiente(s) agora com água potável." % n
		"cafe":
			sv.fatigue = maxf(0.0, sv.fatigue - 0.2)
			sv.thirst = maxf(0.0, sv.thirst - 0.1)
			return "Você tomou café: menos sono."
	var out: Array = r["out"]
	var it2 := Items.make(out[0], int(out[1]))
	# habilidade de culinaria melhora o prato
	if r["cat"] == "Culinária" and Items.def(out[0]).has("fresh"):
		it2["ck"] = 1
		if dirty:
			it2["b"] = G.time_min - 3.0 * 1440.0
	inv.add(it2)
	return "Você fez: %s." % Items.def(out[0])["n"]
