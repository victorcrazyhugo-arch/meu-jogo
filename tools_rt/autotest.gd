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
