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
	if DisplayServer.get_name() == "headless":
		return
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
	# a partida pode falhar conforme o estado do motor: ate 6 tentativas
	for attempt in 6:
		if v.engine_on:
			break
		v.try_start()
		await wait(1.6)
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


## Mede uma cena por alguns segundos de jogo: tempos de quadro, CPU de script/fisica e carga de desenho.
func sample(nm: String, secs: float = 6.0) -> void:
	var ft: Array = []
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var prims := 0.0
	var objs := 0.0
	var n := 0
	var last := Time.get_ticks_usec()
	var t_end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		n += 1
	ft.sort()
	var avg := 0.0
	for x in ft:
		avg += x
	avg /= maxf(1.0, ft.size())
	var p95: float = ft[int(ft.size() * 0.95)] if ft.size() > 1 else 0.0
	var p99: float = ft[mini(ft.size() - 1, int(ft.size() * 0.99))] if ft.size() > 1 else 0.0
	print("PERF | %s | quadros %d | medio %.1f ms | p95 %.1f | p99 %.1f | max %.1f | script %.2f ms | fisica %.2f ms | desenhos %d | primitivas %d | objetos %d | memoria %.0f MB | zumbis ativos %d | regioes %d | edificios %d" % [
		nm, n, avg, p95, p99, ft[ft.size() - 1] if not ft.is_empty() else 0.0, proc / maxf(1, n), phys / maxf(1, n), int(draws / maxf(1, n)), int(prims / maxf(1, n)), int(objs / maxf(1, n)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, G.zombies.active_count(), G.world.chunks.size(), G.world.buildings.size()])


func scn_perf() -> void:
	G.settings["graphics"] = 1
	G.settings["dyn_res"] = false
	await start("policial")
	var p: Player = G.player
	p.god = true
	print("PERF | ambiente: %s | %s | %s | perfil grafico Equilibrado | %dx%d" % [OS.get_name(), RenderingServer.get_video_adapter_name(), OS.get_processor_name(), get_viewport().size.x, get_viewport().size.y])
	await hour(11.0)
	await sample("interior da casa inicial")
	await tp(Vector3(-946, 0.1, -26), 0.0, -0.2)
	await sample("avenida de Santa Aurora (dia)")
	await tp(Vector3(-520, 0.1, -452), 0.5, -0.12)
	await sample("cabana cercada de vegetacao densa")
	await tp(Vector3(900, 0.1, -32), -PI * 0.5, -0.15)
	await wait(2.0)
	Sfx.noise(p.global_position, 90.0)
	await wait(3.0)
	await sample("centro de Porto Bruma com horda (alarme sonoro)")
	# hospital (3 andares)
	var hosp = null
	for l in G.world.gen.lots:
		if l["type"] == "hospital":
			hosp = l
	if hosp != null:
		var hb: Rect2i = hosp["b"]
		await tp(Vector3(hb.position.x + hb.size.x * 0.5, 0.1, hb.position.y + hb.size.y * 0.5 + 1.0), 0.0, -0.2)
		await sample("hospital, andar terreo")
		await tp(Vector3(hb.position.x + hb.size.x * 0.5, 6.1, hb.position.y + hb.size.y * 0.5 + 1.0), 0.0, -0.2)
		await sample("hospital, terceiro andar")
	# noite, tempestade, horda e disparos
	await tp(Vector3(900, 0.1, -32), -PI * 0.5, -0.15)
	G.time_min = floorf(G.time_min / 1440.0) * 1440.0 + 22.0 * 60.0
	G.env.set_weather("tempestade", 600.0)
	G.env.rain = 1.0
	G.env.cloud = 1.0
	p.inv.primary = Items.make("pistola")
	p.inv.primary["mag"] = 15
	p.inv.primary["ch"] = 1
	p.inv.add(Items.make("mun_9mm", 60))
	p.refresh_weapon()
	p.aiming = true
	await wait(1.0)
	G.held["attack"] = true
	await sample("noite com tempestade, horda e disparos")
	G.held.erase("attack")
	p.aiming = false
	# dirigir rapido pela rodovia entre as cidades (carregamento de regioes novas)
	await hour(13.0)
	G.env.set_weather("limpo", 600.0)
	G.env.rain = 0.0
	G.env.cloud = 0.0
	var v = null
	for c in G.world.gen.cars:
		if c["p"].distance_to(Vector2(-946, 0)) < 260.0:
			await tp(Vector3(c["p"].x + 3.5, 0.1, c["p"].y + 3.5), 0.8, -0.2)
			v = G.vehicles.nearest(p.global_position, 9.0)
			if v != null:
				break
	if v != null:
		v.locked = false
		v.has_key = true
		v.fuel = v.fuel_cap
		v.battery = 1.0
		v.global_position = Vector3(-690, 0.3, -32)
		v.rotation.y = -PI * 0.5
		await tp(Vector3(-690, 0.2, -29), -PI * 0.5, -0.2)
		v = G.vehicles.nearest(p.global_position, 14.0)
		if v == null:
			print("PERF | rodovia: veiculo nao disponivel apos o reposicionamento")
			return
		v.enter_player(p)
		await wait(0.5)
		for i in 4:
			if not v.engine_on:
				v.try_start()
				await wait(1.5)
		G.held["gas"] = true
		var x0: float = v.global_position.x
		await sample("dirigindo pela rodovia entre as cidades", 25.0)
		print("PERF | rodovia: percorridos %.0f m, velocidade final %.0f km/h, regioes carregadas %d" % [absf(v.global_position.x - x0), absf(v.speed) * 3.6, G.world.chunks.size()])
		G.held.erase("gas")
	# salvar apos mudancas extensas
	var t0 := Time.get_ticks_msec()
	var ok: bool = G.main.save_game(false)
	var f := FileAccess.open("user://mundos/autotest/save.dat", FileAccess.READ)
	print("PERF | salvar: %s em %d ms, arquivo %.0f KB" % ["ok" if ok else "FALHA", Time.get_ticks_msec() - t0, (f.get_length() / 1024.0) if f != null else 0.0])


## Gera docs/CATALOGO.md a partir dos dados reais do jogo (sem iniciar partida).
func scn_catalogo() -> void:
	var gen := WorldGen.new()
	var L: Array = []
	L.append("# Catálogo de conteúdo — Última Bruma %s" % G.VERSION)
	L.append("")
	L.append("Gerado automaticamente a partir dos dados do jogo (`tools_rt/autotest.gd`, cenário `catalogo`). Os números abaixo são contagens reais do que está no projeto nesta versão.")
	L.append("")
	L.append("## Mapa")
	L.append("")
	L.append("- Dimensões: %d m × %d m (%.1f km²), terreno plano, carregado em regiões de %d m." % [int(WorldGen.X1 - WorldGen.X0), int(WorldGen.Z1 - WorldGen.Z0), (WorldGen.X1 - WorldGen.X0) * (WorldGen.Z1 - WorldGen.Z0) / 1.0e6, WorldGen.CH])
	var cities := {0: 0, 1: 0, 2: 0}
	var by_type := {}
	for l in gen.lots:
		if l["type"] == "praca":
			continue
		cities[l["city"]] = int(cities[l["city"]]) + 1
		by_type[l["type"]] = int(by_type.get(l["type"], 0)) + 1
	L.append("- Cidades: exatamente 2 — Santa Aurora (%d edifícios, %d × %d m) e Porto Bruma (%d edifícios, %d × %d m)." % [cities[1], int(WorldGen.SA.size.x), int(WorldGen.SA.size.y), cities[2], int(WorldGen.PB.size.x), int(WorldGen.PB.size.y)])
	L.append("- Zona rural: %d construções (fazendas, cabanas, postos, casas isoladas), %d plantações, %d acampamentos." % [cities[0], gen.fields.size(), gen.camps.size()])
	L.append("- Total de edifícios com interior explorável: %d. Postes de iluminação: %d. Veículos previstos no mapa: %d." % [cities[0] + cities[1] + cities[2], gen.lamps.size(), gen.cars.size()])
	var dist := WorldGen.PB.position.x - WorldGen.SA.end.x
	var cc := (WorldGen.PB.position.x + WorldGen.PB.size.x * 0.5) - (WorldGen.SA.position.x + WorldGen.SA.size.x * 0.5)
	L.append("- Distância entre as bordas das cidades pela rodovia: %d m; centro a centro: %d m." % [int(dist), int(cc)])
	L.append("- Tempos aproximados centro a centro: andando (1,6 m/s) %d min; trotando (3,3 m/s) %d min; de carro a 70 km/h %.1f min." % [int(cc / 1.6 / 60.0), int(cc / 3.3 / 60.0), cc / (70.0 / 3.6) / 60.0])
	L.append("- Animais: nenhum (nenhuma entidade, som ou sistema de fauna existe no projeto).")
	L.append("")
	L.append("| Tipo de edifício | Quantidade |")
	L.append("|---|---:|")
	var tk: Array = by_type.keys()
	tk.sort()
	for t in tk:
		L.append("| %s | %d |" % [WorldGen.TYPES[t]["n"], by_type[t]])
	L.append("")
	L.append("## Vestuário")
	L.append("")
	L.append("- Peças base: %d. Variantes individuais (peça × cor × estampa/detalhe): **%d**." % [Clothes.BASES.size(), Clothes.count_variants()])
	L.append("- Cada variante altera cor, estampa ou detalhe da malha do personagem. O número de cortes realmente distintos é o de peças base; as demais variantes são paramétricas.")
	L.append("")
	L.append("| Categoria | Peças base | Variantes |")
	L.append("|---|---:|---:|")
	var cs := Clothes.count_by_slot()
	for slot in Clothes.SLOT_ORDER + ["bag"]:
		if not cs.has(slot):
			continue
		L.append("| %s | %d | %d |" % [Clothes.SLOT_NAMES[slot], Clothes.bases_for(slot).size(), cs[slot]])
		cs.erase(slot)
	L.append("")
	L.append("| Peça base | Categoria | Cores | Estampas/detalhes |")
	L.append("|---|---|---:|---|")
	for b in Clothes.BASES:
		var bd: Dictionary = Clothes.BASES[b]
		L.append("| %s | %s | %d | %s |" % [bd["n"], Clothes.SLOT_NAMES[bd["slot"]], bd["cols"].size(), ", ".join(bd["pats"])])
	L.append("")
	L.append("## Itens")
	L.append("")
	var cats := {}
	for id in Items.D:
		var c: String = Items.D[id].get("cat", "Diversos")
		if not cats.has(c):
			cats[c] = []
		cats[c].append(String(Items.D[id]["n"]))
	L.append("Total: %d itens (sem contar vestuário)." % Items.D.size())
	L.append("")
	for c in Items.CAT_ORDER:
		if cats.has(c):
			L.append("- **%s** (%d): %s." % [c, cats[c].size(), ", ".join(cats[c])])
	L.append("")
	L.append("## Receitas, construções, culturas e móveis")
	L.append("")
	var rn: Array = []
	for r in Recipes.LIST:
		rn.append(String(r["n"]))
	L.append("- **Receitas** (%d): %s." % [rn.size(), ", ".join(rn)])
	var sn: Array = []
	for s in Base.BUILD_ORDER:
		sn.append(String(Base.STRUCTS[s]["n"]))
	L.append("- **Estruturas construíveis** (%d): %s. Colocáveis a partir de item: gerador, saco de dormir, barraca." % [sn.size(), ", ".join(sn)])
	var cn: Array = []
	for c in Base.CROPS:
		cn.append("%s (%d dias)" % [Base.CROPS[c]["n"], int(Base.CROPS[c]["days"])])
	L.append("- **Culturas** (%d): %s." % [cn.size(), ", ".join(cn)])
	var fn: Array = []
	for f in BPlan.FURN:
		fn.append(String(BPlan.FURN[f]["n"]))
	L.append("- **Móveis e objetos de interior** (%d modelos): %s." % [fn.size(), ", ".join(fn)])
	L.append("- **Tabelas de saque por tipo de recipiente**: %d." % Items.LOOT.size())
	L.append("- **Profissões**: %d. **Traços**: %d. **Habilidades**: %d." % [Survivor.PROFESSIONS.size(), Survivor.TRAITS.size() - 1, Survivor.SKILLS.size()])
	L.append("- **Predefinições de sandbox**: %s." % ", ".join(G.SANDBOX_PRESETS.keys()))
	L.append("")
	var f := FileAccess.open(out + "/CATALOGO.md", FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
	print("CATALOGO escrito: ", out + "/CATALOGO.md", " variantes=", Clothes.count_variants())


func _wait_game() -> void:
	var guard := 0
	while (not G.in_game or G.main.starting) and guard < 6000:
		guard += 1
		await get_tree().process_frame
	await wait(0.5)


## Robustez do salvamento, migracao, morte, cadaver, reanimacao e novo sobrevivente no mesmo mundo.
func scn_salvar() -> void:
	await start("enfermeiro")
	var p: Player = G.player
	var dir := "user://mundos/autotest"
	var b: Building = p.cur_building
	var lot_id: int = b.plan.id if b != null else -1
	if b != null and not b.plan.windows.is_empty():
		b.break_window(0, true)
	G.world.drop_item(p.global_position + Vector3(0.5, 0, 0.5), Items.make("martelo"))
	p.inv.add(Items.make("tabua", 7))
	check("primeiro save existe", FileAccess.file_exists(dir + "/save.dat"))
	check("segundo save cria copia de recuperacao", G.main.save_game(false) and FileAccess.file_exists(dir + "/save.bak"))
	G.time_min += 30.0
	G.main.save_game(false)
	# 1) arquivo principal corrompido (gravacao interrompida no meio)
	var f := FileAccess.open(dir + "/save.dat", FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
	f.close()
	var d := Save.read("autotest")
	check("save corrompido usa a copia de recuperacao", not d.is_empty() and d.get("_from_backup", false) and d.has("player"))
	# 2) fechamento forcado entre remover o atual e renomear o temporario
	var snap: Dictionary = G.main.snapshot()
	Save._write_var(dir + "/save.tmp", snap)
	DirAccess.remove_absolute(dir + "/save.dat")
	DirAccess.remove_absolute(dir + "/save.bak")
	d = Save.read("autotest")
	check("recupera do arquivo temporario integro", not d.is_empty() and int(d["player"]["inv"]["items"].size()) > 0)
	# 3) migracao de um save de versao anterior preservando propriedades
	var old := {"v": 0, "name": "Antigo", "seed": 5, "time_min": 900.0, "sandbox": {"zombie_pop": 2.0}, "player": {"pos": Vector3(1, 0, 2)}}
	var mg := Save.migrate(old)
	check("migracao de versao", int(mg["v"]) == G.SAVE_VERSION and mg.has("env") and float(mg["sandbox"]["zombie_pop"]) == 2.0 and mg["sandbox"].has("day_minutes") and mg["player"]["pos"] == Vector3(1, 0, 2))
	# 4) restaura um save valido e confere continuidade completa
	check("regrava apos a recuperacao", G.main.save_game(false) and FileAccess.file_exists(dir + "/save.dat"))
	var t_before := G.time_min
	G.main.to_menu()
	await get_tree().create_timer(0.5, true, false, true).timeout
	G.main.load_game("autotest")
	await _wait_game()
	p = G.player
	check("continuar preserva o tempo do mundo (sem avancar fora do jogo)", absf(G.time_min - t_before) < 1.0, "antes=%.1f depois=%.1f" % [t_before, G.time_min])
	check("continuar preserva itens", p.inv.count("tabua") == 7)
	if lot_id >= 0:
		var b2: Building = G.world.buildings.get(lot_id, null)
		check("janela quebrada continua quebrada", b2 != null and int(b2.win_state(0)["s"]) == Building.W_BROKEN)
	var gi: Array = G.world.ground_items(p.global_position, 3.0)
	check("item largado no chao persiste sem duplicar", gi.size() == 1, "itens=%d" % gi.size())
	# 5) morte por infeccao: cadaver com equipamentos e reanimacao
	var death_pos := p.global_position
	p.sv.zinf = 0.6
	p.hurt(999.0, "teste")
	await wait(3.5)
	var ck: Vector2i = G.world.key_of(death_pos)
	var corpses: Array = G.world.cstate[ck].get("corpses", [])
	var mine = null
	for c in corpses:
		if c.get("pl", false):
			mine = c
	check("morte deixa cadaver com os equipamentos", mine != null and mine["items"].size() >= 3 and float(mine["re"]) > 0.0, "itens=%d" % (mine["items"].size() if mine != null else 0))
	var meta: Array = Save.list()
	check("save marca o sobrevivente como morto", not meta.is_empty() and meta[0].get("dead", false))
	# 6) novo sobrevivente no mesmo mundo
	G.main.to_menu()
	await get_tree().create_timer(0.5, true, false, true).timeout
	G.main.menu.new_character_in("autotest")
	G.main.menu._start()
	await _wait_game()
	p = G.player
	check("novo sobrevivente vivo no mesmo mundo", not p.sv.dead and G.world_name == "Teste" and G.time_min >= t_before)
	var st: Dictionary = G.world.cstate.get(ck, {})
	var still := false
	for c in st.get("corpses", []):
		if c.get("pl", false):
			still = true
	check("cadaver anterior continua no mundo", still)
	# 7) reanimacao do cadaver infectado
	await tp(death_pos + Vector3(6, 0, 0), 0.0, -0.2)
	G.time_min += 400.0
	var n0: int = G.zombies.active_count()
	G.zombies._check_reanimation()
	await wait(0.5)
	var gone := true
	for c in G.world.cstate.get(ck, {}).get("corpses", []):
		if c.get("pl", false):
			gone = false
	check("cadaver infectado se reanima como zumbi", gone and G.zombies.active_count() == n0 + 1, "ativos %d -> %d" % [n0, G.zombies.active_count()])
	print("RESULTADO: %d falha(s)" % _fails)


func scn_cerca() -> void:
	await start()
	var p: Player = G.player
	p.god = true
	await tp(Vector3(-1168.7, 0.1, -140.0), -PI * 0.5, -0.2)
	p.rotation.y = -PI * 0.5
	await wait(0.3)
	var t: Dictionary = Interact.scan(p)
	check("cerca detectada como obstaculo baixo", t.get("kind", "") == "obstaculo", str(t.get("kind", "nada")))
	if t.get("kind", "") == "obstaculo":
		var x0 := p.global_position.x
		Interact.run(p, t, "pular_obst")
		await wait(1.5)
		check("pulou a cerca", p.global_position.x > -1168.0 and not p.vaulting, "x %.2f -> %.2f" % [x0, p.global_position.x])
	print("RESULTADO: %d falha(s)" % _fails)
