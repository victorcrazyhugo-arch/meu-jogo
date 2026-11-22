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


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


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
