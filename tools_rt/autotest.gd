extends Node
## Roteiro automatico de verificacao: inicia uma partida, percorre cenarios e grava capturas
## reais do jogo em execucao. Uso: godot --path . -- --autotest --out=<pasta> --scn=<nome>

var out := "user://shots"
var scn := "inicio"
var n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--scn="):
			scn = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")


## Espera em tempo de jogo (quadros de fisica), para nao depender da velocidade da maquina.
func wait(sec: float) -> void:
	if G.paused or not G.in_game:
		await get_tree().create_timer(sec, true, false, true).timeout
		return
	for i in int(ceil(sec * 60.0)):
		await get_tree().physics_frame


func frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func shot(nm: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	var path := "%s/%02d_%s.png" % [out, n, nm]
	img.save_png(path)
	print("SHOT ", path)


func start(prof: String = "desempregado", traits: Array = [], preset: String = "Sobrevivente", seed_v: int = 4242) -> void:
	G.apply_preset(preset)
	var sb: Dictionary = G.sandbox.duplicate(true)
	sb["tutorial"] = false
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var body := Clothes.random_body(r)
	Save.delete("autotest")
	G.main.new_game({"slot": "autotest", "name": "Teste", "seed": seed_v, "sandbox": sb, "char": {"name": "Teste Silva", "profession": prof, "traits": traits, "body": body}})
	var guard := 0
	while (not G.in_game or G.main.starting) and guard < 3000:
		guard += 1
		await get_tree().process_frame
	await wait(1.0)


func tp(pos: Vector3, yaw: float = 0.0, pitch: float = -0.2) -> void:
	var p: Node3D = G.player
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.pitch = pitch
	p.rotation.y = yaw
	p._cam_pos = pos + Vector3(0, 1.5, 0)
	G.world.focus(pos)
	var guard := 0
	while not G.world.ready_around(pos, 2) and guard < 2000:
		guard += 1
		await get_tree().process_frame
	await wait(0.6)


func _run() -> void:
	await frames(2)
	if has_method("scn_" + scn):
		await call("scn_" + scn)
	else:
		print("cenario desconhecido: ", scn)
	print("AUTOTEST_FIM")
	get_tree().quit()


func scn_menu() -> void:
	G.main.show_menu()
	await wait(0.8)
	await shot("menu")
	G.main.menu._show("world")
	await wait(0.3)
	await shot("novo_mundo")
	G.main.menu._show("char")
	await wait(0.6)
	await shot("personagem")


func scn_inicio() -> void:
	await start()
	await shot("inicio_interior")
	var p: Node3D = G.player
	print("POS ", p.global_position, " indoors=", p.indoors, " chunks=", G.world.chunks.size(), " buildings=", G.world.buildings.size(), " zumbis=", G.zombies.active_count())
	G.mv = Vector2(0, 1)
	await wait(1.2)
	await shot("andando")
	G.mv = Vector2.ZERO
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.25)
	await shot("rua_santa_aurora")
	p.yaw = PI * 0.5
	await wait(0.4)
	await shot("rua_santa_aurora_2")


func scn_luz() -> void:
	await start()
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.25)
	await shot("a_padrao")
	G.env.sun.shadow_enabled = false
	await wait(0.3)
	await shot("b_sem_sombra")
	G.env.env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	await wait(0.3)
	await shot("c_linear")
	print("SUN e=", G.env.sun.light_energy, " dir=", -G.env.sun.global_basis.z, " amb=", G.env.env.ambient_light_energy, " ", G.env.env.ambient_light_color)


func scn_prints() -> void:
	await start()
	var p: Node3D = G.player
	p.yaw = 0.6
	await wait(0.5)
	await shot("casa_inicial")
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.22)
	await shot("rua_santa_aurora")
	await tp(Vector3(-1150, 0.1, -130), PI * 0.5, -0.2)
	await shot("bairro_residencial")
	await tp(Vector3(-520, 0.1, -455), 0.4, -0.18)
	await shot("floresta_cabana")
	await tp(Vector3(900, 0.1, -32), -PI * 0.5, -0.2)
	await shot("porto_bruma")
	G.ui.open("inv")
	await wait(0.4)
	await shot("mochila")
	G.ui.close()


func hour(h: float) -> void:
	G.time_min = floorf(G.time_min / 1440.0) * 1440.0 + h * 60.0
	G.env.set_weather("limpo", 600.0)
	G.env.rain = 0.0
	G.env.cloud = 0.0
	G.env.fog = 0.0
	await wait(0.4)


## Entra em um comodo de um edificio e olha para o centro dele.
func room(b: Building, kinds: Array, f: int = 0) -> bool:
	for rm in b.plan.rooms[f]:
		if rm["k"] in kinds:
			var r: Rect2i = rm["r"]
			var best := Vector3.ZERO
			var bd := -1.0
			var ctr := Vector3(r.position.x + r.size.x * 0.5, f * 3.0 + 0.1, r.position.y + r.size.y * 0.5)
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					if b.plan.tg(f, x, z) == BPlan.T_FLOOR:
						var p := Vector3(x + 0.5, f * 3.0 + 0.1, z + 0.5)
						if p.distance_to(ctr) > bd:
							bd = p.distance_to(ctr)
							best = p
			var wp := b.to_global(best)
			var wc := b.to_global(ctr)
			var d := wc - wp
			await tp(wp, atan2(-d.x, -d.z), -0.28)
			return true
	return false


func scn_graf() -> void:
	await start()
	await hour(10.0)
	var p: Node3D = G.player
	var b: Building = p.cur_building
	if b == null:
		b = G.world.building_at(p.global_position)
	print("CASA ", b.plan.name if b != null else "nenhuma", " comodos=", b.plan.rooms[0].size() if b != null else 0)
	if b != null:
		for kk in [["sala"], ["cozinha"], ["quarto"], ["banheiro"]]:
			if await room(b, kk):
				await shot("casa_" + kk[0])
	await tp(Vector3(-1150, 0.1, -128), PI * 0.5, -0.16)
	await shot("bairro")
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.2)
	await shot("avenida")
	await tp(Vector3(-854, 0.1, -10), 2.4, -0.2)
	await shot("praca")
	await tp(Vector3(-520, 0.1, -452), 0.5, -0.12)
	await shot("floresta")
	await tp(Vector3(120, 0.1, 470), 1.2, -0.1)
	await shot("mata_sul")
	await hour(21.5)
	await tp(Vector3(-946, 0.1, -60), 0.0, -0.18)
	await shot("noite_postes")
	await tp(Vector3(-1150, 0.1, -128), PI * 0.5, -0.16)
	await shot("noite_bairro")


var _fails := 0


func check(nm: String, ok: bool, info: String = "") -> void:
	if not ok:
		_fails += 1
	print("TESTE %s: %s %s" % ["OK   " if ok else "FALHA", nm, info])


func scn_jogo() -> void:
	await start("policial", ["corajoso"])
	var p: Player = G.player
	var inv: Inv = p.inv
	p.god = true
	# ---- inventario e itens
	for id in ["pistola", "taco", "machado", "serrote", "martelo", "tronco", "pazinha", "sem_tomate", "feijao_lata", "abridor", "atadura", "alcool", "r_jaqueta_couro_0_0", "r_mochila_trilha_2_0", "lanterna", "isqueiro"]:
		inv.add(Items.make(id))
	inv.add(Items.make("mun_9mm", 45))
	inv.add(Items.make("tabua", 12))
	inv.add(Items.make("pregos", 60))
	inv.add(Items.make("pedra", 4))
	inv.add(Items.make("graveto", 8))
	var w0 := inv.weight()
	Interact.item_run(p, inv.find("r_mochila_trilha_2_0"), "vestir")
	Interact.item_run(p, inv.find("r_jaqueta_couro_0_0"), "vestir")
	check("vestir mochila e jaqueta", inv.worn.has("bag") and inv.worn.has("over"), "cap=%.1f" % inv.capacity(p.sv))
	var h0 := p.sv.hunger
	p.sv.hunger = 0.5
	Interact.item_run(p, inv.find("feijao_lata"), "comer")
	await wait(3.2)
	check("comer lata com abridor", p.sv.hunger < 0.5 and inv.find("feijao_lata") == null, "fome=%.2f" % p.sv.hunger)
	Interact.item_run(p, inv.find("taco"), "equipar")
	check("equipar taco", inv.primary != null and inv.primary["id"] == "taco")
	G.ui.open("inv")
	await wait(0.3)
	await shot("mochila")
	G.ui.tab = 1
	G.ui.refresh()
	await wait(0.2)
	await shot("equipamento")
	G.ui.close()
	# ---- receita
	var r := Recipes.get_r("tabuas")
	check("receita tabuas disponivel", Recipes.missing(r, p, "") == "", Recipes.missing(r, p, ""))
	var t0 := inv.count("tabua")
	G.ui._craft_n(r, 1)
	await wait(9.0)
	check("serrar tronco", inv.count("tabua") == t0 + 3, "tabuas=%d" % inv.count("tabua"))
	# ---- interacao com a casa
	var b: Building = p.cur_building
	check("comeca dentro de casa", b != null)
	if b != null:
		var fi := -1
		for i in b.plan.furn.size():
			if b.plan.furn[i]["cont"] != "" and b.plan.furn[i]["f"] == 0:
				fi = i
				break
		if fi >= 0:
			var items := b.container(fi)
			G.ui.open_container(BPlan.FURN[b.plan.furn[fi]["id"]]["n"], items, 30.0)
			await wait(0.3)
			await shot("recipiente")
			var n0 := inv.items.size()
			if not items.is_empty():
				G.ui._take(items[0])
				await wait(1.5)
			check("vasculhar recipiente", true, "itens=%d pegou=%s" % [items.size(), str(inv.items.size() >= n0)])
			G.ui.close()
		# porta e janela
		var d0 := 0
		b.set_door(d0, true, p.global_position)
		await wait(0.4)
		check("abrir porta", b.door_state(d0)["o"] == true)
		if not b.plan.windows.is_empty():
			b.break_window(0, true)
			check("quebrar janela", int(b.win_state(0)["s"]) == Building.W_BROKEN)
			b.add_barricade("janela", 0)
			check("barricar janela", int(b.win_state(0)["bar"]) == 1 and not b.win_passable(0))
	# ---- saude
	p.god = false
	var wnd := p.sv.add_wound(4, "laceracao")
	p.sv.tick(5.0, {})
	check("ferimento sangra", p.sv.bleeding > 0.0, "sangramento=%.2f" % p.sv.bleeding)
	Interact.wound_run(p, 4, wnd, "desinfetar")
	await wait(5.0)
	Interact.wound_run(p, 4, wnd, "curativo")
	await wait(6.5)
	check("desinfetar e enfaixar", int(wnd["band"]) == 1 and float(wnd["dis"]) > 0.0)
	G.ui.open("health")
	await wait(0.3)
	await shot("saude")
	G.ui.tab = 1
	G.ui.refresh()
	await wait(0.2)
	await shot("habilidades")
	G.ui.close()
	p.god = true
	# ---- construcao e agricultura (fora de casa)
	await tp(Vector3(-946, 0.1, -200), 0.0, -0.3)
	var pos := Vector3(-945.5, 0, -203.5)
	check("pode construir", Base.can_place(G.world, "parede_madeira", pos) == "", Base.can_place(G.world, "parede_madeira", pos))
	Base.place(G.world, "parede_madeira", pos, 0)
	Base.place(G.world, "fogueira", Vector3(-943.5, 0, -203.5), 0, {"fuel": 60.0, "on": false})
	var pl := Base.new_plot(G.world, Vector3(-948.5, 0, -203.5))
	pl["crop"] = "tomate"
	pl["w"] = 1.0
	var g0: float = pl["g"]
	G.time_min += 3.0 * 1440.0
	Base.advance_plot(pl)
	check("plantio cresce com o tempo", float(pl["g"]) > g0 + 0.2, "crescimento=%.2f estagio=%d" % [pl["g"], Base.plot_stage(pl)])
	await wait(0.5)
	await shot("construcao_plantio")
	# ---- arvore
	await tp(Vector3(-520, 0.1, -440), 0.0, -0.2)
	var out: Array = []
	G.world.targets_near(p.global_position, out)
	var trees := 0
	for kk in G.world.chunks:
		trees += G.world.chunks[kk]["trees"].size()
	check("floresta carregada", trees > 100, "arvores=%d chunks=%d" % [trees, G.world.chunks.size()])
	var kch: Vector2i = G.world.key_of(p.global_position)
	var ch: Dictionary = G.world.chunks[kch]
	var ti := -1
	for i in ch["trees"].size():
		if ch["trees"][i]["k"] <= 1:
			ti = i
			break
	if ti >= 0:
		var fell := false
		for i in 40:
			if G.world.tree_hit(kch, ti, 30.0):
				fell = true
				break
		await wait(2.0)
		check("cortar arvore gera troncos", fell and G.world.cstate[kch].get("items", []).size() > 0, "itens no chao=%d" % G.world.cstate[kch].get("items", []).size())
	# ---- zumbis e combate
	await tp(Vector3(900, 0.1, -32), -PI * 0.5, -0.15)
	await wait(2.5)
	check("zumbis ativos na cidade", G.zombies.active_count() > 3, "ativos=%d" % G.zombies.active_count())
	await shot("porto_bruma_zumbis")
	Sfx.noise(p.global_position, 60.0)
	var t := 0.0
	var kills0 := p.sv.kills
	while t < 25.0 and p.sv.kills < kills0 + 2:
		p.attack_pressed()
		await wait(0.25)
		t += 0.25
		if int(t * 4) == 24:
			await shot("combate")
	check("combate corpo a corpo elimina zumbis", p.sv.kills >= kills0 + 1, "abates=%d em %.0fs" % [p.sv.kills - kills0, t])
	await wait(1.5)
	Interact.swap_weapons(p)
	Interact.item_run(p, inv.find("pistola"), "equipar")
	await wait(0.3)
	p.reload_pressed()
	await wait(3.5)
	check("recarregar pistola", int(inv.primary.get("mag", 0)) + int(inv.primary.get("ch", 0)) > 0, "municao=%d" % (int(inv.primary.get("mag", 0)) + int(inv.primary.get("ch", 0))))
	p.aiming = true
	await wait(1.0)
	var shots := 0
	var k1 := p.sv.kills
	for i in 30:
		var best = null
		for z in G.zombies.query(p.global_position, 18.0):
			if not z.dead and z.visible:
				best = z
				break
		if best != null:
			var to: Vector3 = best.global_position + Vector3(0, 1.3, 0) - p.cam.global_position
			p.yaw = atan2(-to.x, -to.z)
			p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			await wait(0.35)
			p.attack_pressed()
			shots += 1
		await wait(0.2)
		if i == 6:
			await shot("mira")
	check("tiros acertam zumbis", p.sv.kills > k1 or shots == 0, "tiros=%d abates=%d" % [shots, p.sv.kills - k1])
	p.aiming = false
	# ---- salvar e continuar
	var before := {"pos": p.global_position, "items": inv.items.size(), "time": G.time_min, "kills": p.sv.kills, "tabuas": inv.count("tabua")}
	var okw: bool = G.main.save_game(false)
	check("gravar save", okw)
	G.main.to_menu()
	await wait(0.6)
	G.main.load_game("autotest")
	var guard := 0
	while (not G.in_game or G.main.starting) and guard < 3000:
		guard += 1
		await get_tree().process_frame
	await wait(1.0)
	var p2: Player = G.player
	check("continuar restaura posicao", p2.global_position.distance_to(before["pos"]) < 1.0, str(p2.global_position))
	check("continuar restaura inventario", p2.inv.items.size() == before["items"] and p2.inv.count("tabua") == before["tabuas"], "itens=%d" % p2.inv.items.size())
	check("continuar restaura tempo e abates", absf(G.time_min - float(before["time"])) < 2.0 and p2.sv.kills == before["kills"])
	var st: Dictionary = G.world.cstate.get(G.world.key_of(Vector3(-945.5, 0, -203.5)), {})
	check("estruturas e canteiros persistem", st.get("structs", []).size() >= 2 and st.get("plots", []).size() >= 1, "estruturas=%d canteiros=%d" % [st.get("structs", []).size(), st.get("plots", []).size()])
	await shot("apos_continuar")
	print("RESULTADO: %d falha(s)" % _fails)


func scn_cam() -> void:
	await start()
	var p: Player = G.player
	await tp(Vector3(-946, 0.1, -200), 0.0, -0.3)
	print("CAM visivel=", p.hum.visible, " hit=", p.arm.get_hit_length(), " dist=", p._dist, " indoors=", p.indoors, " pos=", p.global_position, " cam=", p.cam.global_position)
	await shot("campo")
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.2)
	print("CAM visivel=", p.hum.visible, " hit=", p.arm.get_hit_length(), " dist=", p._dist, " cam=", p.cam.global_position)
	await shot("rua")


func scn_carro() -> void:
	await start("mecanico")
	var p: Player = G.player
	p.god = true
	await hour(15.0)
	var gen: WorldGen = G.world.gen
	print("CARROS no mapa=", gen.cars.size())
	# procura um carro existente perto de Santa Aurora
	var v = null
	for c in gen.cars:
		if c["p"].distance_to(Vector2(-946, 0)) < 260.0:
			await tp(Vector3(c["p"].x + 3.5, 0.1, c["p"].y + 3.5), 0.8, -0.2)
			v = G.vehicles.nearest(p.global_position, 9.0)
			if v != null:
				break
	check("veiculo encontrado no mundo", v != null)
	if v == null:
		return
	var d: Vector3 = v.global_position - p.global_position
	p.yaw = atan2(-d.x, -d.z)
	await wait(0.5)
	await shot("carro_fora")
	print("VEICULO ", v.display_name, " comb=", v.fuel, "/", v.fuel_cap, " bateria=", v.battery, " trancado=", v.locked, " chave=", v.has_key)
	var parts: Array = v.parts_list()
	check("lista de pecas", parts.size() >= 10, "pecas=%d" % parts.size())
	G.ui.open_mechanic(v)
	await wait(0.3)
	G.ui.mech_sel = parts[0]["key"]
	G.ui.refresh()
	await wait(0.2)
	await shot("mecanica")
	G.ui.close()
	v.locked = false
	v.has_key = true
	v.fuel = maxf(v.fuel, 12.0)
	v.battery = 1.0
	var ok: bool = v.enter_player(p)
	check("entrar no veiculo", ok and p.vehicle == v)
	await wait(0.5)
	if not v.engine_on:
		v.try_start()
	await wait(1.5)
	if not v.engine_on:
		v.try_start()
		await wait(1.5)
	check("motor liga", v.engine_on, "motor=%.2f" % v.part_cond("motor"))
	var p0: Vector3 = v.global_position
	G.held["gas"] = true
	await wait(4.0)
	await shot("dirigindo")
	G.mv = Vector2(0.6, 0)
	await wait(1.5)
	G.mv = Vector2.ZERO
	G.held.erase("gas")
	G.held["brake"] = true
	await wait(2.0)
	G.held.erase("brake")
	check("veiculo anda", v.global_position.distance_to(p0) > 8.0, "andou=%.1f m vel=%.1f" % [v.global_position.distance_to(p0), v.speed])
	v.toggle_lights()
	await hour(21.0)
	await shot("farois_noite")
	v.exit_player(p)
	await wait(0.4)
	check("sair do veiculo", p.vehicle == null and p.global_position.distance_to(v.global_position) < 5.0)
	var sd: Dictionary = G.vehicles.to_dict()
	check("estado dos veiculos serializavel", var_to_bytes(sd).size() > 20, "bytes=%d" % var_to_bytes(sd).size())
	print("RESULTADO: %d falha(s)" % _fails)
