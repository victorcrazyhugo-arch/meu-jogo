class_name Interact
extends RefCounted
## Interacoes com o ambiente e com itens: lista acoes validas para o alvo selecionado,
## explica requisitos ausentes e executa acoes com duracao.

# =====================================================================================
#  ALVO ATUAL
# =====================================================================================
static func scan(p: Node3D) -> Dictionary:
	var out: Array = []
	var pos: Vector3 = p.global_position
	G.world.targets_near(pos, out)
	if out.is_empty():
		return {}
	var fwd := -p.global_transform.basis.z
	var camf := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var best := {}
	var best_s := 1.0e9
	for t in out:
		var to: Vector3 = t["pos"] - pos
		to.y = 0
		var d := to.length()
		var dir := to.normalized() if d > 0.05 else fwd
		var s := d + (1.0 - dir.dot(camf)) * 0.9 + (1.0 - dir.dot(fwd)) * 0.4
		if t["kind"] == "porta" or t["kind"] == "janela":
			s -= 0.25
		if t["kind"] == "veiculo":
			s -= 0.2
		if s < best_s:
			best_s = s
			best = t
	return best


static func _a(id: String, label: String, ok: bool = true, why: String = "") -> Dictionary:
	return {"id": id, "label": label, "ok": ok, "why": why}


static func _need(p: Node, tag: String) -> String:
	return "" if p.inv.has_tag(tag) else "Falta: %s." % Recipes.tool_name(tag)


static func _has_plank_kit(p: Node) -> String:
	if not p.inv.has_tag("martelo"):
		return "Falta: martelo."
	if p.inv.count("tabua") < 1 or p.inv.count("pregos") < 2:
		return "Faltam: 1 tábua e 2 pregos."
	return ""


# =====================================================================================
#  ACOES POR TIPO DE ALVO
# =====================================================================================
static func actions(p: Node3D, t: Dictionary) -> Array:
	var a: Array = []
	match t["kind"]:
		"porta":
			var b: Building = t["b"]
			var i: int = t["i"]
			var st := b.door_state(i)
			var inside := b.contains(p.global_position)
			var ext: bool = b.plan.doors[i]["ext"]
			if st["o"]:
				a.append(_a("fechar", "Fechar"))
			elif int(st["bar"]) > 0:
				a.append(_a("desbarricar", "Remover tábua", p.inv.has_tag("martelo") or p.inv.has_tag("pe_de_cabra"), "Falta: martelo ou pé de cabra."))
			elif st["l"] and not inside:
				a.append(_a("abrir", "Abrir", false, "Porta trancada. Arrombe, quebre ou entre por uma janela."))
				a.append(_a("arrombar", "Arrombar com pé de cabra", p.inv.has_tag("pe_de_cabra"), "Falta: pé de cabra."))
			else:
				a.append(_a("abrir", "Abrir"))
			if ext and inside and not st["o"]:
				a.append(_a("trancar", "Destrancar" if st["l"] else "Trancar"))
			if not st["o"] and int(st["bar"]) < 4:
				var w := _has_plank_kit(p)
				a.append(_a("barricar", "Barricar com tábua", w == "", w))
		"janela":
			var b2: Building = t["b"]
			var i2: int = t["i"]
			var st2 := b2.win_state(i2)
			var s: int = st2["s"]
			var inside2 := b2.contains(p.global_position)
			if int(st2["bar"]) > 0:
				a.append(_a("desbarricar", "Remover tábua", p.inv.has_tag("martelo") or p.inv.has_tag("pe_de_cabra"), "Falta: martelo ou pé de cabra."))
			elif s == Building.W_CLOSED:
				if st2["l"] and not inside2:
					a.append(_a("abrir", "Abrir", false, "Janela travada por dentro."))
				else:
					a.append(_a("abrir", "Abrir"))
				a.append(_a("quebrar", "Quebrar o vidro"))
			else:
				a.append(_a("pular", "Pular a janela", b2.plan.windows[i2]["f"] == 0, "Alto demais."))
				if s == Building.W_OPEN:
					a.append(_a("fechar", "Fechar"))
				if s == Building.W_BROKEN:
					a.append(_a("limpar", "Remover cacos de vidro"))
			if int(st2["bar"]) < 4:
				var w2 := _has_plank_kit(p)
				a.append(_a("barricar", "Barricar com tábua", w2 == "", w2))
			if b2.plan.windows[i2]["f"] >= 1 and s != Building.W_CLOSED:
				a.append(_a("corda", "Descer por corda de lençóis", p.inv.count("corda_lencol") + p.inv.count("corda") > 0, "Falta: corda de lençóis."))
		"movel":
			var b3: Building = t["b"]
			var fu: Dictionary = b3.plan.furn[t["i"]]
			if fu["cont"] != "":
				a.append(_a("vasculhar", "Vasculhar"))
			var pw := Base.has_power(G.world, t["pos"])
			match fu["use"]:
				"bed", "bed_bad":
					a.append(_a("dormir", "Dormir"))
				"sofa":
					a.append(_a("descansar", "Descansar um pouco"))
				"sink", "toilet", "bath":
					var wt := _tap_water(b3, t["i"])
					a.append(_a("beber", "Beber água", wt > 0.0, "Sem água na torneira."))
					a.append(_a("encher", "Encher recipientes", wt > 0.0, "Sem água na torneira."))
					a.append(_a("lavar", "Lavar-se e lavar as roupas", wt > 2.0, "Água insuficiente."))
				"stove", "microwave":
					a.append(_a("cozinhar", "Cozinhar", pw, "Sem energia elétrica."))
				"fire":
					if _fire_lit(b3, t["i"]):
						a.append(_a("cozinhar", "Cozinhar"))
						a.append(_a("lenha", "Pôr mais lenha", _fuel_item(p) != "", "Falta lenha (gravetos, galho ou tábua)."))
					else:
						var why := ""
						if not p.inv.has_tag("fogo"):
							why = "Falta: isqueiro ou fósforos."
						elif _fuel_item(p) == "":
							why = "Falta lenha (gravetos, galho ou tábua)."
						a.append(_a("acender", "Acender o fogo", why == "", why))
				"fridge":
					pass
				"tv":
					a.append(_a("tv", "Assistir televisão", pw, "Sem energia elétrica."))
				"workbench":
					a.append(_a("bancada", "Fabricar na bancada"))
			var tool_ok: bool = p.inv.has_tag("martelo") or p.inv.has_tag("chave_fenda")
			a.append(_a("desmontar", "Desmontar", tool_ok, "Falta: martelo ou chave de fenda."))
		"bomba":
			var pw2 := Base.has_power(G.world, t["pos"])
			var v = G.vehicles.nearest(t["pos"], 6.0) if G.vehicles != null else null
			a.append(_a("abastecer", "Abastecer o veículo", pw2 and v != null, "Sem energia nas bombas." if not pw2 else "Nenhum veículo perto da bomba."))
			a.append(_a("encher_galao", "Encher galão", pw2 and _empty_can(p) != null, "Sem energia nas bombas." if not pw2 else "Falta um galão com espaço."))
		"arvore":
			var kind: int = t["tk"]
			if kind <= 2:
				var w3 := _need(p, "machado")
				a.append(_a("cortar", "Cortar árvore", w3 == "", w3))
				a.append(_a("galhos", "Recolher galhos"))
			elif kind == 3:
				a.append(_a("coletar", "Coletar"))
			else:
				a.append(_a("pedras", "Pegar pedras"))
		"chao":
			a.append(_a("pegar", "Pegar"))
			a.append(_a("ver_chao", "Ver itens no chão"))
		"corpo":
			a.append(_a("revistar", "Revistar"))
			var w4 := _need(p, "pa")
			a.append(_a("enterrar", "Enterrar", w4 == "", w4))
			a.append(_a("arrastar", "Arrastar para fora daqui"))
		"rio":
			a.append(_a("beber_rio", "Beber água do rio"))
			a.append(_a("encher_rio", "Encher recipientes"))
			a.append(_a("lavar_rio", "Lavar-se e lavar as roupas"))
		"veiculo":
			var v2 = t["obj"]
			a.append(_a("entrar", "Entrar"))
			a.append(_a("porta_malas", "Abrir porta-malas"))
			a.append(_a("mecanica", "Mecânica do veículo"))
			var can = p.inv.find_liquid("gasolina", 0.1)
			a.append(_a("abastecer_galao", "Abastecer com galão", can != null, "Falta: galão com gasolina."))
			var w5 := ""
			if not p.inv.has_tag("mangueira"):
				w5 = "Falta: mangueira."
			elif _empty_can(p) == null:
				w5 = "Falta: galão com espaço."
			elif v2.fuel <= 0.2:
				w5 = "Tanque vazio."
			a.append(_a("sifonar", "Retirar combustível", w5 == "", w5))
		"estrutura":
			var s2: Dictionary = t["s"]
			match s2["t"]:
				"porta_madeira":
					a.append(_a("porta_s", "Fechar" if s2.get("open", false) else "Abrir"))
				"caixote", "bolsa_acampamento":
					a.append(_a("vasculhar_s", "Vasculhar"))
				"fogueira":
					if s2.get("on", false):
						a.append(_a("cozinhar", "Cozinhar"))
						a.append(_a("lenha_s", "Pôr mais lenha", _fuel_item(p) != "", "Falta lenha (gravetos, galho ou tábua)."))
						a.append(_a("apagar", "Apagar o fogo"))
					else:
						var why2 := ""
						if not p.inv.has_tag("fogo"):
							why2 = "Falta: isqueiro ou fósforos."
						elif _fuel_item(p) == "":
							why2 = "Falta lenha (gravetos, galho ou tábua)."
						a.append(_a("acender_s", "Acender", why2 == "", why2))
				"cama_simples", "saco_dormir", "barraca":
					a.append(_a("dormir_s", "Dormir"))
				"coletor_chuva":
					var l: float = s2.get("liq", 0.0)
					a.append(_a("encher_col", "Encher recipientes (%.0f L, ferver antes de beber)" % l, l > 0.1, "Coletor vazio."))
				"composteira":
					a.append(_a("comp_por", "Pôr restos vegetais e comida estragada", _compostable(p) > 0, "Nada para compostar."))
					a.append(_a("comp_tirar", "Retirar adubo (%d)" % int(s2.get("out", 0)), int(s2.get("out", 0)) > 0, "Ainda não há adubo pronto."))
				"secador":
					a.append(_a("sec_por", "Pendurar legumes para secar", Recipes.count_group(p.inv, "@veg") >= 2, "Faltam 2 legumes."))
					a.append(_a("sec_tirar", "Retirar legumes secos (%d)" % int(s2.get("out", 0)), int(s2.get("out", 0)) > 0, "Ainda não secou."))
				"gerador":
					var know: bool = p.sv.knows("usar_gerador")
					if s2.get("on", false):
						a.append(_a("ger_off", "Desligar"))
					else:
						var why3 := ""
						if not know:
							why3 = "Você não sabe operar geradores (leia a revista)."
						elif float(s2.get("fuel", 0.0)) <= 0.0:
							why3 = "Sem combustível."
						elif G.world.building_at(s2["p"]) != null:
							why3 = "Perigoso em ambiente fechado: leve para fora."
						a.append(_a("ger_on", "Ligar", why3 == "", why3))
					a.append(_a("ger_fuel", "Abastecer (%.0f%%)" % (float(s2.get("fuel", 0.0)) * 100.0), p.inv.find_liquid("gasolina", 0.1) != null, "Falta: galão com gasolina."))
					a.append(_a("ger_pegar", "Recolher o gerador", not s2.get("on", false), "Desligue antes."))
				"bancada":
					a.append(_a("bancada", "Fabricar na bancada"))
			if s2["t"] != "bolsa_acampamento" and s2["t"] != "gerador":
				var tool2: bool = p.inv.has_tag("martelo") or p.inv.has_tag("pe_de_cabra") or not Base.STRUCTS[s2["t"]].has("tool") or Base.STRUCTS[s2["t"]].get("tool", "") == ""
				a.append(_a("desmontar_s", "Desmontar", tool2, "Falta: martelo ou pé de cabra."))
		"canteiro":
			var pl: Dictionary = t["pl"]
			var stg := Base.plot_stage(pl)
			if stg == 0:
				var any := false
				for it in p.inv.items:
					var d := Items.def(it["id"])
					if d.has("crop"):
						any = true
						a.append(_a("semear:" + String(it["id"]), "Semear %s" % Base.CROPS[d["crop"]]["n"]))
				if not any:
					a.append(_a("semear", "Semear", false, "Você não tem sementes."))
			elif stg == 4 or stg == 5:
				a.append(_a("colher", "Colher"))
			if stg >= 1 and stg <= 4:
				a.append(_a("regar", "Regar", p.inv.total_liquid("agua") + p.inv.total_liquid("agua_suja") >= 0.4, "Falta água (regador, garrafa ou balde)."))
				a.append(_a("adubar", "Adubar", p.inv.find("fertilizante") != null or p.inv.find("adubo") != null, "Falta fertilizante ou adubo."))
				if float(pl["dis"]) > 0.1:
					a.append(_a("tratar_planta", "Remover folhas doentes"))
			a.append(_a("remover", "Desfazer canteiro"))
	return a


# =====================================================================================
#  EXECUCAO
# =====================================================================================
static func run(p: Node3D, t: Dictionary, id: String) -> void:
	var sv: Survivor = p.sv
	var inv: Inv = p.inv
	var w: Node3D = G.world
	match t["kind"]:
		"porta":
			var b: Building = t["b"]
			var i: int = t["i"]
			match id:
				"abrir":
					b.door_state(i)["l"] = false
					b.set_door(i, true, p.global_position)
				"fechar":
					b.set_door(i, false, p.global_position)
				"trancar":
					var st := b.door_state(i)
					st["l"] = not st["l"]
					Sfx.play3d("door_locked", t["pos"], -4.0)
					G.say("Porta trancada." if st["l"] else "Porta destrancada.")
				"arrombar":
					Sfx.play3d("door_locked", t["pos"])
					var f := func():
						b.door_state(i)["l"] = false
						b.set_door(i, true, p.global_position)
						Sfx.noise(t["pos"], 14.0)
						b.trigger_alarm(true)
						sv.add_xp("forca", 3.0)
					p.start_action("Arrombando", 5.0 - sv.level("forca") * 0.25, "work", f)
				"barricar":
					_barricade(p, b, "porta", i)
				"desbarricar":
					_unbarricade(p, b, "porta", i)
		"janela":
			var b2: Building = t["b"]
			var i2: int = t["i"]
			match id:
				"abrir":
					b2.win_state(i2)["l"] = false
					b2.set_window(i2, Building.W_OPEN)
					Sfx.play3d("window_open", t["pos"], -4.0)
				"fechar":
					b2.set_window(i2, Building.W_CLOSED)
					Sfx.play3d("window_open", t["pos"], -6.0, 0.9)
				"quebrar":
					b2.break_window(i2, true)
					if inv.primary == null and not inv.worn.has("gloves") and randf() < 0.5:
						sv.add_wound(1, "corte")
						G.say("Você cortou a mão no vidro.")
						Sfx.play3d("hurt", p.global_position)
				"limpar":
					var f2 := func():
						b2.set_window(i2, Building.W_CLEARED)
						if not inv.worn.has("gloves") and randf() < 0.3:
							sv.add_wound(randi() % 2, "corte")
							G.say("Você se cortou ao tirar os cacos.")
					p.start_action("Removendo cacos", 3.0, "work", f2)
				"pular":
					_vault_window(p, b2, i2)
				"barricar":
					_barricade(p, b2, "janela", i2)
				"desbarricar":
					_unbarricade(p, b2, "janela", i2)
				"corda":
					if inv.remove("corda_lencol", 1) == 0:
						inv.remove("corda", 1)
					var wp := b2.win_world_pos(i2)
					var out_dir := (wp - b2.to_global(Vector3(b2.plan.w * 0.5, wp.y, b2.plan.d * 0.5)))
					out_dir.y = 0
					var dst := Vector3(wp.x, 0.1, wp.z) + out_dir.normalized() * 1.2
					_move_arc(p, dst, 2.4, 0.0)
					G.say("Você desceu pela corda.")
		"movel":
			_run_furn(p, t, id)
		"bomba":
			if id == "abastecer":
				var v = G.vehicles.nearest(t["pos"], 6.0)
				if v != null:
					var f3 := func():
						var got: float = v.refuel(v.fuel_cap)
						G.say("Abastecido: +%.0f L." % got)
					p.start_action("Abastecendo", 6.0, "work", f3)
			elif id == "encher_galao":
				var can = _empty_can(p)
				var f4 := func():
					can["liq"] = float(Items.def(can["id"])["cap"])
					can["lt"] = "gasolina"
					G.say("Galão cheio.")
				p.start_action("Enchendo galão", 4.0, "work", f4)
		"arvore":
			match id:
				"cortar":
					_chop(p, t)
				"galhos":
					var f5 := func():
						if randf() < 0.75:
							inv.add(Items.make("graveto", randi_range(1, 3)))
						if randf() < 0.3:
							inv.add(Items.make("galho", 1))
						G.say("Você recolheu galhos e gravetos.")
						Sfx.ui("pickup")
					p.start_action("Recolhendo galhos", 3.0, "work", f5)
				"coletar":
					forage(p, 4.5, 1.3)
				"pedras":
					var f6 := func():
						inv.add(Items.make("pedra", 1))
						if randf() < 0.25:
							inv.add(Items.make("argila", 1))
						Sfx.ui("pickup")
						G.say("Você pegou uma pedra.")
					p.start_action("Pegando pedras", 2.5, "work", f6)
		"chao":
			if id == "pegar":
				var e: Dictionary = t["e"]
				var it: Dictionary = e["it"]
				var f7 := func():
					if e.has("node"):
						w.take_item(t["key"], e)
						inv.add(it)
						Sfx.ui("pickup")
				p.start_action("Pegando", clampf(0.25 + Items.weight_of(it) * 0.08, 0.25, 1.2), "work", f7, true)
			else:
				G.ui.open_ground()
		"corpo":
			var e2: Dictionary = t["e"]
			match id:
				"revistar":
					G.ui.open_container("Cadáver", e2["items"], 20.0)
				"enterrar":
					var f8 := func():
						for it2 in e2["items"]:
							w.drop_item(e2["p"] + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), it2)
						w.remove_corpse(t["key"], e2)
						sv.unhappy = maxf(0.0, sv.unhappy - 0.05)
						sv.add_xp("forca", 6.0)
						G.say("Você enterrou o corpo.")
					Sfx.play3d("plant", p.global_position)
					p.start_action("Cavando cova", 18.0, "work", f8)
				"arrastar":
					var f9 := func():
						var np: Vector3 = p.global_position - p.global_transform.basis.z * -3.0
						var kk: Vector2i = t["key"]
						var saved: Dictionary = e2.duplicate()
						w.remove_corpse(kk, e2)
						w.add_corpse(Vector3(np.x, 0, np.z), saved["r"], saved["look"], saved["items"], saved.get("pl", false), saved.get("re", -1.0))
						sv.spend(0.15)
					p.start_action("Arrastando corpo", 5.0, "work", f9)
		"rio":
			match id:
				"beber_rio":
					var f10 := func():
						sv.drink_water(0.5, true)
						Sfx.ui("drink")
					p.start_action("Bebendo", 2.5, "use", f10)
				"encher_rio":
					_fill(p, "agua_suja", 9999.0)
				"lavar_rio":
					_wash(p)
		"veiculo":
			var v2 = t["obj"]
			match id:
				"entrar":
					v2.enter_player(p)
				"porta_malas":
					if v2.locked and not v2.has_key:
						G.say("Veículo trancado.")
					else:
						G.ui.open_container("Porta-malas", v2.trunk, v2.trunk_cap)
				"mecanica":
					G.ui.open_mechanic(v2)
				"abastecer_galao":
					var can2 = inv.find_liquid("gasolina", 0.1)
					var f11 := func():
						var got2: float = v2.refuel(float(can2["liq"]))
						can2["liq"] = float(can2["liq"]) - got2
						if float(can2["liq"]) <= 0.01:
							can2["liq"] = 0.0
							can2["lt"] = ""
						G.say("Abastecido: +%.1f L." % got2)
					p.start_action("Abastecendo", 5.0, "work", f11)
				"sifonar":
					var can3 = _empty_can(p)
					var f12 := func():
						var space: float = float(Items.def(can3["id"])["cap"]) - float(can3["liq"])
						var got3: float = v2.siphon(space)
						can3["liq"] = float(can3["liq"]) + got3
						can3["lt"] = "gasolina"
						G.say("Você retirou %.1f L de combustível." % got3)
					p.start_action("Retirando combustível", 7.0, "work", f12)
		"estrutura":
			_run_struct(p, t, id)
		"canteiro":
			_run_plot(p, t, id)


# ---------------------------------------------------------------- moveis
static func _tap_water(b: Building, fi: int) -> float:
	if G.water_on():
		return 9999.0
	var ws: Dictionary = b.state.get("water", {})
	return float(ws.get(fi, 6.0))


static func _use_tap(b: Building, fi: int, l: float) -> void:
	if G.water_on():
		return
	if not b.state.has("water"):
		b.state["water"] = {}
	b.state["water"][fi] = maxf(0.0, float(b.state["water"].get(fi, 6.0)) - l)


static func _fire_lit(b: Building, fi: int) -> bool:
	return G.time_min < float(b.state.get("fire", {}).get(fi, 0.0))


static func _fuel_item(p: Node) -> String:
	for id in ["graveto", "galho", "tabua", "jornal", "tronco"]:
		if p.inv.count(id) > 0:
			return id
	return ""


static func _burn_fuel(p: Node) -> float:
	var id := _fuel_item(p)
	var mins: float = {"graveto": 30.0, "galho": 70.0, "tabua": 110.0, "jornal": 12.0, "tronco": 300.0}.get(id, 0.0)
	if id == "graveto":
		var n: int = p.inv.remove("graveto", 3)
		return 30.0 * n
	p.inv.remove(id, 1)
	return mins


static func _empty_can(p: Node):
	for it in p.inv.items:
		var d := Items.def(it["id"])
		if d.has("fuel") and float(it.get("liq", 0.0)) < float(d["cap"]) - 0.05 and it.get("lt", "") in ["", "gasolina"]:
			return it
	return null


static func _compostable(p: Node) -> int:
	var n := 0
	for it in p.inv.items:
		var d := Items.def(it["id"])
		if d.has("fresh") and (Items.freshness(it) == 2 or d.has("veg")):
			n += int(it["n"])
	return n


static func _run_furn(p: Node3D, t: Dictionary, id: String) -> void:
	var b: Building = t["b"]
	var fi: int = t["i"]
	var fu: Dictionary = b.plan.furn[fi]
	var sv: Survivor = p.sv
	match id:
		"vasculhar":
			var first: bool = not b.state["cont"].has(fi)
			var open := func():
				var cap: float = float(Items.CONTAINER_CAP.get(fu["cont"], 30.0))
				if sv.has("organizado"):
					cap *= 1.3
				elif sv.has("desorganizado"):
					cap *= 0.7
				if fu["use"] == "fridge":
					_fridge_update(b, fi, Base.generator_power(G.world, t["pos"]))
				G.ui.open_container(BPlan.FURN[fu["id"]]["n"], b.container(fi), cap)
				Sfx.ui("zipper")
			if first:
				p.start_action("Vasculhando", 1.2, "work", open)
			else:
				open.call()
		"dormir":
			p.sleep_start(1.0 if fu["use"] == "bed" else 0.65)
		"descansar":
			var f := func():
				sv.endurance = 1.0
				sv.fatigue = maxf(0.0, sv.fatigue - 0.03)
				G.say("Você descansou um pouco.")
			p.start_action("Descansando", 8.0, "", f)
		"beber":
			var f2 := func():
				var need := minf(sv.thirst / 0.9 + 0.05, 1.0)
				sv.drink_water(need, false)
				_use_tap(b, fi, need)
				Sfx.ui("drink")
			p.start_action("Bebendo", 2.5, "use", f2)
		"encher":
			var got := _fill(p, "agua", _tap_water(b, fi))
			_use_tap(b, fi, got)
		"lavar":
			_use_tap(b, fi, 3.0)
			_wash(p)
		"cozinhar":
			G.ui.open_craft("fogo")
		"bancada":
			G.ui.open_craft("bancada")
		"acender", "lenha":
			if id == "acender":
				var lt = p.inv.find_tag("fogo")
				if lt != null:
					p.inv.use_charge(lt)
			var mins := _burn_fuel(p)
			if not b.state.has("fire"):
				b.state["fire"] = {}
			b.state["fire"][fi] = maxf(G.time_min, float(b.state["fire"].get(fi, 0.0))) + mins
			G.say("O fogo está aceso." if id == "acender" else "Lenha adicionada.")
			Sfx.loop("fire", "fire_loop", 0.5)
		"tv":
			var f3 := func():
				sv.boredom = maxf(0.0, sv.boredom - 0.35)
				sv.stress = maxf(0.0, sv.stress - 0.1)
				if G.day() < 9:
					var sk: String = ["culinaria", "carpintaria", "agricultura", "socorros", "coleta"][G.day() % 5]
					sv.add_xp(sk, 25.0)
					G.say("Programa educativo: você aprendeu sobre %s." % Survivor.SKILLS[sk].to_lower())
				else:
					G.say("Só há chuvisco e avisos de emergência na TV.")
			p.start_action("Assistindo", 12.0, "", f3)
		"desmontar":
			var f4 := func():
				var inside: Array = b.container(fi) if fu["cont"] != "" else []
				for it in inside:
					G.world.drop_item(t["pos"] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), it)
				b.remove_furniture(fi)
				var lvl := sv.level("carpintaria")
				var n := 1 + (1 if randf() < 0.3 + lvl * 0.08 else 0) + (1 if BPlan.FURN[fu["id"]]["w"] == 2 else 0)
				var metal: bool = fu["id"] in ["geladeira", "fogao", "arquivo", "armario", "prateleira", "cama_hospital", "maquina", "microondas"]
				p.inv.add(Items.make("sucata" if metal else "tabua", n))
				if not metal and randf() < 0.7:
					p.inv.add(Items.make("pregos", randi_range(1, 4)))
				if metal and randf() < 0.4:
					p.inv.add(Items.make("parafusos", randi_range(1, 4)))
				sv.add_xp("carpintaria", 6.0)
				Sfx.noise(t["pos"], 10.0)
				G.say("Móvel desmontado.")
			Sfx.play3d("craft", t["pos"])
			p.start_action("Desmontando", 7.0, "work", f4)


## Geladeira: enquanto havia energia (rede ou gerador) os alimentos envelheceram 5x mais devagar.
static func _fridge_update(b: Building, fi: int, generator: bool) -> void:
	var key := "fr%d" % fi
	var last: float = float(b.state.get(key, 0.0))
	var now := G.time_min
	b.state[key] = now
	var off_t := float(G.sandbox.get("power_off_day", 9)) * 1440.0
	var powered := clampf(minf(now, off_t) - last, 0.0, now - last)
	if generator:
		powered = now - last
	if powered <= 0.0:
		return
	for it in b.container(fi):
		if it.has("b"):
			it["b"] = float(it["b"]) + powered * 0.8


## Enche recipientes de agua. Retorna litros usados.
static func _fill(p: Node, lt: String, avail: float) -> float:
	var used := 0.0
	var n := 0
	for it in p.inv.items:
		var d := Items.def(it["id"])
		if not d.has("cap") or d.has("fuel"):
			continue
		var cur: String = it.get("lt", "")
		if float(it.get("liq", 0.0)) > 0.01 and cur != lt:
			continue
		var space: float = float(d["cap"]) - float(it.get("liq", 0.0))
		if space <= 0.01 or used + space > avail:
			continue
		it["liq"] = float(d["cap"])
		it["lt"] = lt
		used += space
		n += 1
	if n == 0:
		G.say("Nenhum recipiente com espaço.")
	else:
		Sfx.ui("water_pour")
		G.say("%d recipiente(s) cheio(s)%s." % [n, " com água contaminada (ferva antes de beber)" if lt == "agua_suja" else ""])
	return used


static func _wash(p: Node3D) -> void:
	var f := func():
		for s in p.inv.worn:
			p.inv.worn[s]["dirt"] = 0.0
			p.inv.worn[s]["bl"] = 0.0
		p.sv.unhappy = maxf(0.0, p.sv.unhappy - 0.05)
		p.refresh_look()
		G.say("Você e suas roupas estão limpos.")
	Sfx.ui("water_pour")
	p.start_action("Lavando", 9.0, "work", f)


# ---------------------------------------------------------------- barricadas e janelas
static func _barricade(p: Node3D, b: Building, kind: String, i: int) -> void:
	var f := func():
		if p.inv.count("tabua") < 1 or p.inv.count("pregos") < 2:
			return
		p.inv.remove("tabua", 1)
		p.inv.remove("pregos", 2)
		b.add_barricade(kind, i)
		p.sv.add_xp("carpintaria", 5.0)
		Sfx.noise(p.global_position, 12.0)
	Sfx.play3d("craft", p.global_position)
	p.start_action("Barricando", 4.5 - p.sv.level("carpintaria") * 0.2, "work", f)


static func _unbarricade(p: Node3D, b: Building, kind: String, i: int) -> void:
	var f := func():
		b.remove_barricade(kind, i)
		p.inv.add(Items.make("tabua", 1))
		if randf() < 0.5:
			p.inv.add(Items.make("pregos", 1))
	Sfx.play3d("craft", p.global_position, -4.0)
	p.start_action("Removendo tábua", 3.5, "work", f)


static func _move_arc(p: Node3D, dst: Vector3, dur: float, height: float) -> void:
	p.vaulting = true
	p.velocity = Vector3.ZERO
	var a: Vector3 = p.global_position
	p.hum.act = "vault"
	var step := func(f: float):
		p.global_position = a.lerp(dst, f) + Vector3(0, sin(f * PI) * height, 0)
		p.hum.act_t = f
	var done := func():
		p.vaulting = false
		p.hum.act = ""
	var tw := p.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(done)


static func _vault_window(p: Node3D, b: Building, i: int) -> void:
	var wn: Dictionary = b.plan.windows[i]
	var wp := b.win_world_pos(i)
	var nloc := Vector3(0, 0, 1) if wn["h"] else Vector3(1, 0, 0)
	var nw := (b.global_transform.basis * nloc).normalized()
	var to := Vector3(wp.x - p.global_position.x, 0, wp.z - p.global_position.z)
	if nw.dot(to) < 0.0:
		nw = -nw
	var base_y: float = b.global_position.y + wn["f"] * BPlan.FH
	var dst := Vector3(wp.x, base_y, wp.z) + nw * 1.0
	p.global_position = Vector3(wp.x, p.global_position.y, wp.z) - nw * 0.8
	p.rotation.y = atan2(-nw.x, -nw.z)
	var st := b.win_state(i)
	if int(st["s"]) == Building.W_BROKEN:
		var ch := 0.6 if not p.inv.worn.has("gloves") else 0.3
		if randf() < ch:
			var part: int = [0, 1, 11, 12, 13, 14][randi() % 6]
			p.sv.add_wound(part, "laceracao" if randf() < 0.4 else "corte")
			G.say("Os cacos cortaram você: %s." % Survivor.PARTS[part])
			Sfx.play3d("hurt", p.global_position)
			if G.hud != null:
				G.hud.flash_damage()
	var slow := 1.0 + p.sv.leg_penalty() + maxf(0.0, p.sv.carry / maxf(p.sv.carry_max, 0.1) - 1.0)
	_move_arc(p, dst, 0.85 * slow, 0.75)
	p.sv.spend(0.04)
	Sfx.noise(wp, 5.0)


# ---------------------------------------------------------------- arvores e coleta
static func _chop(p: Node3D, t: Dictionary) -> void:
	var k: Vector2i = t["key"]
	var i: int = t["i"]
	var axe = p.inv.find_tag("machado")
	if axe == null:
		return
	var d := Items.def(axe["id"])
	var hit := func():
		if not G.world.chunks.has(k):
			return
		var lvl: int = p.sv.level("machado")
		var dmg: float = randf_range(float(d["dmg"][0]), float(d["dmg"][1])) * 0.22 * (1.0 + lvl * 0.1) * (0.8 + p.sv.level("forca") * 0.04)
		Sfx.play3d("chop", t["pos"], 0.0, 1.0, 60.0)
		Sfx.noise(t["pos"], 18.0)
		p.sv.spend(float(d["sta"]) * 1.2)
		p.sv.add_xp("machado", 2.0)
		p.sv.add_xp("forca", 0.6)
		if randf() < 1.0 / (float(d["brk"]) * 1.5):
			axe["c"] = float(axe.get("c", 1.0)) - 0.1
			if float(axe["c"]) <= 0.0:
				G.say("%s quebrou!" % d["n"])
				if p.inv.primary == axe:
					p.inv.primary = null
					p.refresh_weapon()
				else:
					p.inv.remove_item(axe)
				return
		var fell: bool = G.world.tree_hit(k, i, dmg)
		if fell:
			G.say("A árvore caiu.")
			p.sv.add_xp("machado", 12.0)
		elif p.sv.endurance > 0.05:
			_chop(p, t)
		else:
			G.say("Você está sem fôlego.")
	p.rotation.y = atan2(-(t["pos"].x - p.global_position.x), -(t["pos"].z - p.global_position.z))
	p.start_action("Cortando árvore", float(d["spd"]) * 1.25, "chop", hit)


## Coleta vegetal: resultados dependem do ambiente, estacao, luz, clima e habilidade.
static func forage(p: Node3D, secs: float, bonus: float = 1.0) -> void:
	var f := func():
		var sv: Survivor = p.sv
		var lvl := sv.level("coleta")
		var zone: int = G.world.zone_at(p.global_position.x, p.global_position.z)
		var light: float = G.env.light_level() if G.env != null else 1.0
		var ch := (0.35 + lvl * 0.06) * bonus * lerpf(0.4, 1.0, light)
		if G.env != null and G.env.raining():
			ch *= 0.8
		if zone == WorldGen.Z_CITY:
			ch *= 0.3
		var season := G.season_name()
		var table: Array = [["graveto", 30], ["fibra", 26], ["pedra", 12]]
		if zone == WorldGen.Z_FOREST or zone == WorldGen.Z_MEADOW:
			table.append_array([["ervas", 16], ["raiz", 10], ["cogumelo", 14 if season == "outono" else 6], ["nozes", 12 if season != "primavera" else 3],
				["frutas_silvestres", 20 if (season == "verão" or season == "primavera") else 4]])
		if zone == WorldGen.Z_FARM:
			table.append_array([["batata", 10], ["cenoura", 10], ["milho", 10], ["repolho", 6], ["sem_batata", 5], ["sem_milho", 5], ["sem_cenoura", 5]])
		if zone == WorldGen.Z_RIVER or G.world.river_dist(p.global_position.x, p.global_position.z) < 12.0:
			table.append_array([["argila", 30], ["pedra", 14]])
		var found: Array = []
		for roll in 2 + lvl / 4:
			if randf() > ch:
				continue
			var tot := 0
			for e in table:
				tot += int(e[1])
			var r := randi() % tot
			for e in table:
				r -= int(e[1])
				if r < 0:
					p.inv.add(Items.make(e[0], 1 + (1 if randf() < 0.3 else 0)))
					found.append(String(Items.def(e[0])["n"]))
					break
		sv.add_xp("coleta", 4.0 + found.size() * 4.0)
		if found.is_empty():
			G.say("Você não encontrou nada desta vez.")
		else:
			G.say("Encontrado: %s." % ", ".join(found))
			Sfx.ui("pickup")
	p.start_action("Procurando", secs, "work", f)


# ---------------------------------------------------------------- estruturas
static func _run_struct(p: Node3D, t: Dictionary, id: String) -> void:
	var s: Dictionary = t["s"]
	var w: Node3D = G.world
	var inv: Inv = p.inv
	match id:
		"porta_s":
			Base.set_door(w, s, not s.get("open", false))
		"vasculhar_s":
			G.ui.open_container(Base.STRUCTS[s["t"]]["n"], s["items"], 50.0 if s["t"] == "caixote" else 15.0)
		"cozinhar":
			G.ui.open_craft("fogo")
		"bancada":
			G.ui.open_craft("bancada")
		"acender_s", "lenha_s":
			if id == "acender_s":
				var lt = inv.find_tag("fogo")
				if lt != null:
					inv.use_charge(lt)
			s["fuel"] = float(s.get("fuel", 0.0)) + _burn_fuel(p)
			Base.set_fire(w, s, true)
			Sfx.noise(s["p"], 4.0)
			G.say("A fogueira está acesa." if id == "acender_s" else "Lenha adicionada.")
		"apagar":
			Base.set_fire(w, s, false)
		"dormir_s":
			p.sleep_start({"cama_simples": 0.9, "saco_dormir": 0.75, "barraca": 0.8}.get(s["t"], 0.7))
		"encher_col":
			var got := _fill(p, "agua_suja", float(s.get("liq", 0.0)))
			s["liq"] = float(s.get("liq", 0.0)) - got
		"comp_por":
			var n := 0
			var i := inv.items.size() - 1
			while i >= 0:
				var it: Dictionary = inv.items[i]
				var d := Items.def(it["id"])
				if d.has("fresh") and (Items.freshness(it) == 2 or d.has("veg")):
					n += int(it["n"])
					inv.items.remove_at(i)
				i -= 1
			s["load"] = int(s.get("load", 0)) + n
			G.say("%d item(ns) na composteira." % n)
		"comp_tirar":
			inv.add(Items.make("adubo", int(s["out"])))
			s["out"] = 0
		"sec_por":
			var left := 4
			var j := inv.items.size() - 1
			var put := 0
			while j >= 0 and left > 0:
				var it2: Dictionary = inv.items[j]
				if Recipes.is_veg(it2):
					var take: int = mini(int(it2["n"]), left)
					it2["n"] = int(it2["n"]) - take
					left -= take
					put += take
					if int(it2["n"]) <= 0:
						inv.items.remove_at(j)
				j -= 1
			s["load"] = int(s.get("load", 0)) + put / 2
			G.say("Legumes pendurados para secar.")
		"sec_tirar":
			inv.add(Items.make("legumes_secos", int(s["out"])))
			s["out"] = 0
		"ger_on":
			s["on"] = true
			Sfx.play3d("engine_start", s["p"])
			G.say("Gerador ligado: energia em um raio de 22 m.")
		"ger_off":
			s["on"] = false
		"ger_fuel":
			var can = inv.find_liquid("gasolina", 0.1)
			var add: float = minf(float(can["liq"]), (1.0 - float(s.get("fuel", 0.0))) * 10.0)
			can["liq"] = float(can["liq"]) - add
			s["fuel"] = float(s.get("fuel", 0.0)) + add / 10.0
			G.say("Gerador abastecido.")
		"ger_pegar":
			var itg := Items.make("gerador")
			itg["fuel"] = float(s.get("fuel", 0.0))
			inv.add(itg)
			Base.remove_struct(w, s)
		"desmontar_s":
			var f := func():
				var d2: Dictionary = Base.STRUCTS[s["t"]]
				if d2.has("item"):
					inv.add(Items.make(d2["item"]))
				for k in d2.get("need", {}):
					var back := int(floor(float(d2["need"][k]) * (0.4 + p.sv.level("carpintaria") * 0.05)))
					if back > 0:
						inv.add(Items.make(k, back))
				for it3 in s.get("items", []):
					w.drop_item(s["p"] + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), it3)
				Base.remove_struct(w, s)
				G.say("Estrutura desmontada.")
			Sfx.play3d("craft", s["p"])
			p.start_action("Desmontando", 5.0, "work", f)


# ---------------------------------------------------------------- canteiros
static func _run_plot(p: Node3D, t: Dictionary, id: String) -> void:
	var pl: Dictionary = t["pl"]
	var sv: Survivor = p.sv
	var inv: Inv = p.inv
	var w: Node3D = G.world
	var ch: Dictionary = w.chunks[t["key"]]
	if id.begins_with("semear:"):
		var seed_id := id.substr(7)
		var f := func():
			if inv.remove(seed_id, 2) < 1:
				return
			pl["crop"] = Items.def(seed_id)["crop"]
			pl["g"] = 0.0
			pl["hl"] = 1.0
			pl["dis"] = 0.0
			pl["last"] = G.time_min
			Base._refresh_plot(ch, pl)
			sv.add_xp("agricultura", 5.0)
			G.say("Semeado: %s." % Base.CROPS[pl["crop"]]["n"])
		Sfx.play3d("plant", p.global_position)
		p.start_action("Semeando", 3.0, "work", f)
		return
	match id:
		"regar":
			var f2 := func():
				var got := inv.use_liquid("agua", 0.4)
				if got < 0.4:
					inv.use_liquid("agua_suja", 0.4 - got)
				pl["w"] = minf(1.0, float(pl["w"]) + 0.45)
				Base._refresh_plot(ch, pl)
				sv.add_xp("agricultura", 1.5)
			Sfx.ui("water_pour")
			p.start_action("Regando", 2.0, "work", f2)
		"adubar":
			var fz = inv.find("fertilizante")
			if fz == null:
				fz = inv.find("adubo")
			inv.use_charge(fz)
			pl["fz"] = 4.0
			G.say("Canteiro adubado.")
		"tratar_planta":
			var f3 := func():
				pl["dis"] = maxf(0.0, float(pl["dis"]) - 0.4 - sv.level("agricultura") * 0.06)
				sv.add_xp("agricultura", 4.0)
				Base._refresh_plot(ch, pl)
			p.start_action("Cuidando da planta", 4.0, "work", f3)
		"colher":
			var f4 := func():
				var c: Dictionary = Base.CROPS[pl["crop"]]
				var lvl := sv.level("agricultura")
				var n := randi_range(int(c["y"][0]), int(c["y"][1])) + lvl / 3
				if Base.plot_stage(pl) == 5:
					n = maxi(1, n / 2)
				n = maxi(1, int(n * clampf(float(pl["hl"]), 0.3, 1.0)))
				inv.add(Items.make(pl["crop"], n))
				inv.add(Items.make(c["seed"], randi_range(2, 4) + lvl / 2))
				sv.add_xp("agricultura", 12.0)
				G.say("Colheita: %d × %s e novas sementes." % [n, c["n"]])
				pl["crop"] = ""
				pl["g"] = 0.0
				Base._refresh_plot(ch, pl)
				Sfx.ui("pickup")
			p.start_action("Colhendo", 3.5, "work", f4)
		"remover":
			Base.remove_plot(w, pl)


# =====================================================================================
#  EQUIPAMENTOS E ITENS DO INVENTARIO
# =====================================================================================
static func swap_weapons(p: Node3D) -> void:
	if p.busy():
		return
	var a = p.inv.primary
	p.inv.primary = p.inv.secondary
	p.inv.secondary = a
	p.refresh_weapon()
	Sfx.ui("zipper", -10.0)


static func item_actions(p: Node3D, it: Dictionary) -> Array:
	var a: Array = []
	var d := Items.def(it["id"])
	var inv: Inv = p.inv
	var cat: String = d.get("cat", "")
	if d.has("hun") or d.has("thi"):
		var can_ok := not d.has("can") or inv.has_tag("abridor") or inv.has_tag("faca")
		var dry: bool = d.has("dry")
		a.append(_a("comer", "Beber" if cat == "Bebida" else "Comer", can_ok and not dry, "Precisa ser cozido antes." if dry else "Falta: abridor de latas ou faca."))
		if int(it.get("n", 1)) == 1 and not d.has("uses") and float(d.get("hun", 0.0)) >= 0.2 and int(it.get("hf", 0)) == 0:
			a.append(_a("comer_meio", "Comer metade", can_ok and not dry))
		if d.has("cook") and int(it.get("ck", 0)) == 0:
			var st := station(p)
			a.append(_a("cozinhar_item", "Cozinhar", st == "fogo", "Precisa de uma fonte de calor acesa por perto."))
	if d.has("cap") and not d.has("fuel"):
		var l: float = it.get("liq", 0.0)
		a.append(_a("beber_rec", "Beber", l > 0.01, "Vazio."))
		a.append(_a("esvaziar", "Esvaziar", l > 0.01, "Vazio."))
	if d.has("med"):
		match d["med"]:
			"atadura", "desinfetar", "sutura", "tala", "cataplasma":
				a.append(_a("saude", "Usar na tela de Saúde"))
			_:
				a.append(_a("tomar", "Usar" if d["med"] == "cigarro" else "Tomar", d["med"] != "cigarro" or inv.has_tag("fogo"), "Falta: isqueiro ou fósforos."))
	if d.has("dmg") or d.has("gun"):
		a.append(_a("equipar", "Equipar nas mãos"))
		a.append(_a("equipar2", "Guardar nas costas"))
		if d.has("sharp"):
			a.append(_a("afiar", "Afiar", inv.has_tag("amolar") and float(it.get("sh", 1.0)) < 0.95, "Falta: pedra de amolar (ou já está afiado)."))
		if float(it.get("c", 1.0)) < 0.9 and not d.has("gun"):
			a.append(_a("reparar", "Reparar com fita adesiva", inv.find("fita") != null, "Falta: fita adesiva."))
		if d.has("gun"):
			a.append(_a("limpar_arma", "Limpar e lubrificar", inv.has_tag("limpeza_arma") and float(it.get("c", 1.0)) < 0.98, "Falta: kit de limpeza (ou arma em bom estado)."))
			a.append(_a("descarregar", "Descarregar", int(it.get("mag", 0)) + int(it.get("ch", 0)) > 0, "Arma vazia."))
	elif d.has("mdl") or d.has("tags"):
		a.append(_a("equipar", "Segurar nas mãos"))
	if cat == "Roupa":
		a.append(_a("vestir", "Vestir"))
		a.append(_a("rasgar", "Rasgar em panos", d["slot"] in ["top", "bottom", "over", "dress"], "Não rende tecido."))
		if float(it.get("c", 1.0)) < 0.95:
			var why := ""
			if not inv.has_tag("agulha"):
				why = "Falta: agulha."
			elif inv.find("linha") == null:
				why = "Falta: linha."
			elif inv.count("pano") + inv.count("retalho_jeans") + inv.count("retalho_couro") < 1:
				why = "Falta: pano ou retalho."
			a.append(_a("remendar", "Remendar", why == "", why))
	if d.has("skill") or d.has("teach") or d.has("read"):
		var dark: bool = G.daylight() < 0.2 and not p.light_on and not (p.indoors and Base.has_power(G.world, p.global_position))
		a.append(_a("ler", "Ler", not dark, "Escuro demais para ler."))
	if d.has("map"):
		a.append(_a("mapa", "Estudar o mapa"))
	if d.has("place"):
		a.append(_a("colocar", "Colocar no chão"))
	if d.has("throw"):
		a.append(_a("arremessar", "Arremessar"))
	if d.has("crop"):
		a.append(_a("info_semente", "Como plantar"))
	a.append(_a("fav", "Desmarcar favorito" if inv.favorites.has(it["id"]) else "Marcar como favorito"))
	if int(it.get("n", 1)) > 1:
		a.append(_a("largar1", "Largar 1"))
	a.append(_a("largar", "Largar"))
	return a


## Estacao de trabalho disponivel perto do jogador: "fogo", "bancada" ou "".
static func station(p: Node3D) -> String:
	var out: Array = []
	G.world.targets_near(p.global_position, out)
	var bench := false
	for t in out:
		if t["pos"].distance_to(p.global_position) > 2.6:
			continue
		if t["kind"] == "movel":
			var b: Building = t["b"]
			var fu: Dictionary = b.plan.furn[t["i"]]
			if (fu["use"] == "stove" or fu["use"] == "microwave") and Base.has_power(G.world, t["pos"]):
				return "fogo"
			if fu["use"] == "fire" and _fire_lit(b, t["i"]):
				return "fogo"
			if fu["use"] == "workbench":
				bench = true
		elif t["kind"] == "estrutura":
			if t["s"]["t"] == "fogueira" and t["s"].get("on", false):
				return "fogo"
			if t["s"]["t"] == "bancada":
				bench = true
	return "bancada" if bench else ""


static func item_run(p: Node3D, it: Dictionary, id: String) -> void:
	var d := Items.def(it["id"])
	var inv: Inv = p.inv
	var sv: Survivor = p.sv
	match id:
		"comer", "comer_meio":
			var frac := 0.5 if id == "comer_meio" else 1.0
			var f := func():
				if d.has("uses"):
					sv.eat(it, 1.0 / float(d["uses"]))
					inv.use_charge(it)
				elif frac < 1.0:
					sv.eat(it, 0.5)
					it["hf"] = 1
				else:
					sv.eat(it, 0.5 if int(it.get("hf", 0)) == 1 else 1.0)
					it["n"] = int(it["n"]) - 1
					it.erase("hf")
					if int(it["n"]) <= 0:
						inv.remove_item(it)
					if it["id"] in ["refrigerante", "cerveja"]:
						inv.add(Items.make("garrafa_vazia", 1))
				Sfx.ui("drink" if d.get("cat", "") == "Bebida" else "eat")
			p.start_action("Bebendo" if d.get("cat", "") == "Bebida" else "Comendo", 2.6, "use", f, true)
		"cozinhar_item":
			var f2 := func():
				var lvl := sv.level("culinaria")
				it["ck"] = 2 if randf() < maxf(0.0, 0.18 - lvl * 0.03) else 1
				sv.add_xp("culinaria", 4.0)
				G.say("Queimou!" if it["ck"] == 2 else "Cozido.")
			p.start_action("Cozinhando", 8.0, "work", f2)
		"beber_rec":
			var f3 := func():
				var l: float = minf(float(it["liq"]), maxf(0.25, sv.thirst / 0.9))
				sv.drink_water(l, it.get("lt", "") == "agua_suja")
				it["liq"] = float(it["liq"]) - l
				if float(it["liq"]) <= 0.01:
					it["liq"] = 0.0
					it["lt"] = ""
				Sfx.ui("drink")
			if it.get("lt", "") == "gasolina":
				G.say("Isso é gasolina.")
			else:
				p.start_action("Bebendo", 2.2, "use", f3, true)
		"esvaziar":
			it["liq"] = 0.0
			it["lt"] = ""
			Sfx.ui("water_pour")
		"tomar":
			var msg := sv.take_med(d["med"])
			if d["med"] == "cigarro":
				var lt = inv.find_tag("fogo")
				if lt != null and lt.has("u") and randf() < 0.2:
					inv.use_charge(lt)
			inv.use_charge(it)
			G.say(msg)
		"saude":
			G.ui.open("health")
		"equipar":
			_equip(p, it, true)
		"equipar2":
			_equip(p, it, false)
		"afiar":
			var st = inv.find_tag("amolar")
			var f4 := func():
				it["sh"] = 1.0
				inv.use_charge(st)
				sv.add_xp("manutencao", 5.0)
				G.say("Lâmina afiada.")
			p.start_action("Afiando", 6.0, "work", f4)
		"reparar":
			var tape = inv.find("fita")
			var f5 := func():
				var gain := 0.2 + sv.level("manutencao") * 0.04
				it["c"] = minf(1.0, float(it.get("c", 1.0)) + gain)
				it["rep"] = int(it.get("rep", 0)) + 1
				inv.use_charge(tape)
				sv.add_xp("manutencao", 6.0)
				G.say("Reparo feito (cada reparo rende menos).")
			p.start_action("Reparando", 5.0, "work", f5)
		"limpar_arma":
			var kit = inv.find_tag("limpeza_arma")
			var f6 := func():
				it["c"] = minf(1.0, float(it.get("c", 1.0)) + 0.3)
				it["jam"] = false
				inv.use_charge(kit)
				sv.add_xp("manutencao", 8.0)
				G.say("Arma limpa e lubrificada.")
			p.start_action("Limpando a arma", 9.0, "work", f6)
		"descarregar":
			var n := int(it.get("mag", 0)) + int(it.get("ch", 0))
			it["mag"] = 0
			it["ch"] = 0
			inv.add(Items.make(d["ammo"], n))
			Sfx.ui("reload_mag")
		"vestir":
			_wear(p, it)
		"rasgar":
			var f7 := func():
				inv.remove_item(it)
				var base: String = d.get("base", "")
				var out_id := "pano"
				if base.find("jeans") >= 0:
					out_id = "retalho_jeans"
				elif base.find("couro") >= 0:
					out_id = "retalho_couro"
				inv.add(Items.make(out_id, 2 + (1 if randf() < 0.4 + sv.level("costura") * 0.06 else 0)))
				sv.add_xp("costura", 2.0)
				Sfx.ui("bandage")
			p.start_action("Rasgando", 2.5, "work", f7)
		"remendar":
			var th = inv.find("linha")
			var f8 := func():
				if inv.remove("pano", 1) == 0:
					if inv.remove("retalho_jeans", 1) == 0:
						inv.remove("retalho_couro", 1)
				inv.use_charge(th)
				it["c"] = minf(1.0, float(it.get("c", 1.0)) + 0.2 + sv.level("costura") * 0.04)
				sv.add_xp("costura", 8.0)
				p.refresh_look()
				G.say("Roupa remendada.")
			p.start_action("Remendando", 8.0, "work", f8)
		"ler":
			_read(p, it)
		"mapa":
			G.ui.reveal_city(int(d["map"]))
			G.say("Locais anotados no mapa.")
		"colocar":
			G.ui.start_placing(d["place"], it)
		"arremessar":
			_throw(p, it)
		"info_semente":
			var c: Dictionary = Base.CROPS[d["crop"]]
			G.say("%s: cave um canteiro (pá, pazinha ou enxada), semeie, regue e colha em cerca de %d dias." % [c["n"], int(c["days"])])
		"fav":
			if inv.favorites.has(it["id"]):
				inv.favorites.erase(it["id"])
			else:
				inv.favorites[it["id"]] = true
		"largar", "largar1":
			var drop := it
			if id == "largar1" and int(it["n"]) > 1:
				drop = it.duplicate(true)
				drop["n"] = 1
				it["n"] = int(it["n"]) - 1
			else:
				inv.remove_item(it)
			var fwd := -p.global_transform.basis.z
			G.world.drop_item(p.global_position + fwd * 0.7 + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), drop)
			Sfx.ui("drop")


static func _equip(p: Node3D, it: Dictionary, hands: bool) -> void:
	var inv: Inv = p.inv
	var one := it
	if int(it.get("n", 1)) > 1:
		one = it.duplicate(true)
		one["n"] = 1
		it["n"] = int(it["n"]) - 1
	else:
		inv.remove_item(it)
	if hands:
		if inv.primary != null:
			inv.add(inv.primary)
		inv.primary = one
	else:
		if inv.secondary != null:
			inv.add(inv.secondary)
		inv.secondary = one
	p.refresh_weapon()
	Sfx.ui("zipper", -10.0)


static func unequip(p: Node3D, slot: String) -> void:
	var inv: Inv = p.inv
	if slot == "primary" and inv.primary != null:
		inv.add(inv.primary)
		inv.primary = null
	elif slot == "secondary" and inv.secondary != null:
		inv.add(inv.secondary)
		inv.secondary = null
	elif inv.worn.has(slot):
		inv.add(inv.worn[slot])
		inv.worn.erase(slot)
		p.refresh_look()
	p.refresh_weapon()


static func _wear(p: Node3D, it: Dictionary) -> void:
	var inv: Inv = p.inv
	var d := Items.def(it["id"])
	var slot: String = d["slot"]
	inv.remove_item(it)
	# vestido ocupa cima e baixo
	var clash: Array = [slot]
	if slot == "dress":
		clash = ["dress", "top", "bottom"]
	elif slot == "top" or slot == "bottom":
		clash = [slot, "dress"]
	for s in clash:
		if inv.worn.has(s):
			inv.add(inv.worn[s])
			inv.worn.erase(s)
	inv.worn[slot] = it
	p.refresh_look()
	Sfx.ui("zipper", -10.0)


static func _read(p: Node3D, it: Dictionary) -> void:
	var d := Items.def(it["id"])
	var sv: Survivor = p.sv
	var speed := 1.3 if sv.has("leitor_veloz") else (0.7 if sv.has("leitor_lento") else 1.0)
	if d.has("read"):
		var rd: Dictionary = d["read"]
		var f := func():
			sv.boredom = clampf(sv.boredom + float(rd.get("bor", 0.0)), 0.0, 1.0)
			sv.unhappy = clampf(sv.unhappy + float(rd.get("unh", 0.0)), 0.0, 1.0)
			sv.stress = clampf(sv.stress + float(rd.get("stress", 0.0)), 0.0, 1.0)
			G.say("Leitura concluída.")
		p.start_action("Lendo", 10.0 / speed, "use", f)
		return
	if d.has("teach"):
		var f2 := func():
			for k in d["teach"]:
				if not sv.known.has(k):
					sv.known.append(k)
			G.say("Você aprendeu algo novo com a revista.")
		p.start_action("Lendo", 9.0 / speed, "use", f2)
		return
	var sk: String = d["skill"]
	var lv := sv.level(sk)
	if lv < int(d["lv"][0]):
		G.say("Este livro é avançado demais para você agora.")
		return
	if lv >= int(d["lv"][1]):
		G.say("Você já domina o conteúdo deste livro.")
		return
	var f3 := func():
		var pg: float = float(sv.book_progress.get(it["id"], 0.0)) + 40.0 * speed
		sv.book_progress[it["id"]] = pg
		sv.boredom = clampf(sv.boredom + 0.05, 0.0, 1.0)
		if pg >= float(d["pages"]):
			sv.xp_boost[sk] = maxf(float(sv.xp_boost.get(sk, 1.0)), 3.0)
			G.say("Livro concluído: experiência de %s multiplicada por 3." % Survivor.SKILLS[sk].to_lower())
		else:
			G.say("Lido: %d de %d páginas." % [int(pg), int(d["pages"])])
	p.start_action("Lendo", 12.0, "use", f3)


static func _throw(p: Node3D, it: Dictionary) -> void:
	var d := Items.def(it["id"])
	if d["throw"] == "fogo" and not p.inv.has_tag("fogo"):
		G.say("Falta: isqueiro ou fósforos.")
		return
	it["n"] = int(it["n"]) - 1
	if int(it["n"]) <= 0:
		p.inv.remove_item(it)
	var dir: Vector3 = p.cam_forward()
	dir.y = 0
	var dst: Vector3 = p.global_position + dir.normalized() * 11.0
	var kind: String = d["throw"]
	var land := func():
		if kind == "ruido":
			Sfx.play3d("alarm_loop", dst, 4.0, 1.4, 120.0)
			Sfx.noise(dst, 55.0)
			G.say("O despertador disparou e está atraindo zumbis.")
		else:
			Sfx.play3d("glass_break", dst, 2.0)
			Sfx.noise(dst, 20.0)
			for z in G.zombies.query(dst, 3.6):
				z.take_hit(randf_range(70.0, 150.0), (z.global_position - dst).normalized(), 0.4, false, false)
			var s := Base.place(G.world, "fogueira", Vector3(dst.x, 0, dst.z), 0, {"fuel": 25.0, "on": true, "temp": true})
			Base.set_fire(G.world, s, true)
	Sfx.play3d("swing", p.global_position)
	var tw := p.create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(land)


# =====================================================================================
#  TRATAMENTO DE FERIMENTOS (tela de Saude)
# =====================================================================================
static func wound_actions(p: Node3D, part: int, w: Dictionary) -> Array:
	var a: Array = []
	var inv: Inv = p.inv
	var t: String = w["t"]
	if t == "vidro":
		a.append(_a("remover_vidro", "Remover vidro", true, "") if inv.has_tag("pinca") else _a("remover_vidro", "Remover vidro com as mãos (doloroso)"))
	if t == "fratura":
		a.append(_a("tala", "Imobilizar com tala", w["sp"] == 0 and inv.find("tala") != null, "Falta: tala." if w["sp"] == 0 else "Já imobilizado."))
		return a
	if w["band"] > 0:
		a.append(_a("tirar_curativo", "Remover curativo" + (" sujo" if w["band"] == 2 else "")))
	else:
		var bd = _bandage_item(inv)
		a.append(_a("curativo", "Aplicar curativo", bd != null, "Falta: atadura ou pano."))
	var dis = _disinfect_item(inv)
	a.append(_a("desinfetar", "Desinfetar", dis != null and w["band"] == 0, "Falta: álcool ou uísque." if dis == null else "Remova o curativo antes."))
	if t in ["laceracao", "profunda", "mordida"] and w["st"] == 0:
		var why := ""
		if inv.find("kit_sutura") == null and not (inv.has_tag("agulha") and inv.find("linha") != null):
			why = "Falta: agulha de sutura (ou agulha e linha)."
		a.append(_a("suturar", "Suturar", why == "", why))
	if inv.find("cataplasma") != null and float(w["inf"]) > 0.05:
		a.append(_a("cataplasma", "Aplicar cataplasma"))
	return a


static func _bandage_item(inv: Inv):
	for id in ["atadura", "pano", "atadura_suja", "pano_sujo"]:
		var it = inv.find(id)
		if it != null:
			return it
	return null


static func _disinfect_item(inv: Inv):
	for id in ["alcool", "uisque"]:
		var it = inv.find(id)
		if it != null:
			return it
	return null


static func wound_run(p: Node3D, part: int, w: Dictionary, id: String) -> void:
	var inv: Inv = p.inv
	var sv: Survivor = p.sv
	var lvl := sv.level("socorros")
	var tm := 1.0 - lvl * 0.06 + sv.arm_penalty() * 0.5
	if part <= 5 and (part % 2 == 1):
		tm *= 1.25
	match id:
		"curativo":
			var bd = _bandage_item(inv)
			var bdef := Items.def(bd["id"])
			var f := func():
				inv.use_charge(bd)
				w["band"] = 2 if bdef.has("dirty") else 1
				w["bt"] = 0.0
				if bdef.has("weak"):
					w["bt"] = 6.0
				sv.add_xp("socorros", 6.0)
				Sfx.ui("bandage")
			p.start_action("Aplicando curativo", 4.0 * tm, "work", f)
		"tirar_curativo":
			var f2 := func():
				inv.add(Items.make("atadura_suja" if w["band"] == 2 else "atadura", 1))
				w["band"] = 0
				Sfx.ui("bandage")
			p.start_action("Removendo curativo", 2.5 * tm, "work", f2)
		"desinfetar":
			var dis = _disinfect_item(inv)
			var f3 := func():
				inv.use_charge(dis)
				w["dis"] = 24.0
				w["inf"] = maxf(0.0, float(w["inf"]) - 0.15)
				sv.add_xp("socorros", 4.0)
				G.say("Ferimento desinfetado (arde).")
			p.start_action("Desinfetando", 3.0 * tm, "work", f3)
		"suturar":
			var f4 := func():
				var kit = inv.find("kit_sutura")
				if kit != null:
					inv.use_charge(kit)
				else:
					var th = inv.find("linha")
					if th != null:
						inv.use_charge(th)
					sv.stress = minf(1.0, sv.stress + 0.1)
				w["st"] = 1
				w["bl"] = 0.0
				sv.add_xp("socorros", 12.0)
				Sfx.play3d("hurt", p.global_position, -6.0)
				G.say("Ferimento suturado.")
			p.start_action("Suturando", 8.0 * tm, "work", f4)
		"tala":
			var sp = inv.find("tala")
			var f5 := func():
				inv.use_charge(sp)
				w["sp"] = 1
				sv.add_xp("socorros", 10.0)
				G.say("Fratura imobilizada.")
			p.start_action("Imobilizando", 7.0 * tm, "work", f5)
		"remover_vidro":
			var tweez: bool = inv.has_tag("pinca")
			var f6 := func():
				sv.parts[part]["w"].erase(w)
				sv.add_wound(part, "corte")
				if not tweez:
					sv.health -= 3.0
					Sfx.play3d("hurt", p.global_position)
				sv.add_xp("socorros", 8.0)
				G.say("Vidro removido.")
			p.start_action("Removendo vidro", (5.0 if tweez else 8.0) * tm, "work", f6)
		"cataplasma":
			inv.use_charge(inv.find("cataplasma"))
			w["inf"] = maxf(0.0, float(w["inf"]) - 0.35)
			w["dis"] = 12.0
			G.say("Cataplasma aplicado.")
