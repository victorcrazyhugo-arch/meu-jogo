extends Node
## Raiz do jogo: alterna entre menu e partida, monta a cena, salva/carrega, trata o
## ciclo de vida do aplicativo (suspensao, botao voltar) e a morte do personagem.

const EnvScript := preload("res://src/world/env.gd")
const WorldScript := preload("res://src/world/world.gd")
const ZMScript := preload("res://src/actors/zombie_manager.gd")
const HudScript := preload("res://src/ui/hud.gd")
const UiScript := preload("res://src/ui/ui.gd")
const MenuScript := preload("res://src/ui/menu.gd")

var game: Node3D
var menu: CanvasLayer
var hud_layer: CanvasLayer
var overlay: CanvasLayer
var _autosave := 0.0
var _fps_t := 0.0
var _fps_n := 0
var _scale := 1.0
var _tut := 0
var _tut_pos := Vector3.ZERO
var _death_t := -1.0
var starting := false


func _ready() -> void:
	G.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		var t: Node = load("res://tools_rt/autotest.gd").new()
		add_child(t)
		return
	show_menu()


func show_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = MenuScript.new()
	add_child(menu)
	Sfx.stop_loops()
	Sfx.music("music_calm" if bool(G.settings["music_on"]) else "")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# suspensao ou fechamento: grava imediatamente; o tempo do mundo nao avanca fora do jogo
			if G.in_game:
				save_game(false)
			if what == NOTIFICATION_WM_CLOSE_REQUEST:
				get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if G.in_game and G.ui != null:
				if G.ui.is_open():
					G.ui.close()
				elif not G.ui.placing.is_empty():
					G.ui.cancel_placing()
				else:
					G.ui.open("pause")
			elif menu != null and is_instance_valid(menu):
				menu.back()


# =====================================================================================
#  INICIO DE PARTIDA
# =====================================================================================
func _build_scene() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	G.in_game = false
	G.paused = false
	G.time_mult = 1.0
	game = Node3D.new()
	add_child(game)
	var w: Node3D = WorldScript.new()
	G.world = w
	game.add_child(w)
	var e: Node3D = EnvScript.new()
	G.env = e
	game.add_child(e)
	var zm: Node = ZMScript.new()
	G.zombies = zm
	game.add_child(zm)
	var vpath := "res://src/actors/vehicle_manager.gd"
	if not ResourceLoader.exists(vpath):
		vpath = "res://tools_rt/vehicle_stub.gd"
	var vm: Node3D = load(vpath).new()
	G.vehicles = vm
	game.add_child(vm)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	game.add_child(hud_layer)
	var hud: Control = HudScript.new()
	G.hud = hud
	hud_layer.add_child(hud)
	var ui: CanvasLayer = UiScript.new()
	G.ui = ui
	game.add_child(ui)


func _spawn_player() -> Player:
	var p := Player.new()
	p.sv = Survivor.new()
	p.inv = Inv.new()
	G.player = p
	game.add_child(p)
	return p


func _loading(text: String) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(l)


func _wait_world(pos: Vector3) -> void:
	G.world.focus(pos)
	var guard := 0
	while not G.world.ready_around(pos, 2) and guard < 1500:
		guard += 1
		await get_tree().process_frame
	# deixa a navegacao e os edificios proximos assentarem
	for i in 3:
		await get_tree().process_frame


## cfg: slot, name, seed, sandbox, char {name, profession, traits, body}
func new_game(cfg: Dictionary, keep_world: bool = false) -> void:
	if starting:
		return
	starting = true
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	_loading("Preparando o mundo...")
	await get_tree().process_frame
	var saved := {}
	if keep_world:
		saved = Save.read(G.slot)
	else:
		G.slot = cfg["slot"]
		G.world_name = cfg["name"]
		G.world_seed = int(cfg["seed"])
		G.sandbox = cfg["sandbox"].duplicate(true)
		G.time_min = G.START_HOUR * 60.0
		G.play_seconds = 0.0
		# cortes de agua e energia variam alguns dias em torno do configurado
		var r := RandomNumberGenerator.new()
		r.seed = G.world_seed
		for k in ["water_off_day", "power_off_day"]:
			if int(G.sandbox[k]) > 0:
				G.sandbox[k] = maxi(1, int(G.sandbox[k]) + r.randi_range(-3, 3))
	_build_scene()
	if keep_world and not saved.is_empty():
		_apply_world(saved)
	var p := _spawn_player()
	var ch: Dictionary = cfg["char"]
	p.sv.name = ch["name"]
	p.sv.body_look = ch["body"]
	p.sv.setup(ch["profession"], ch["traits"])
	_starting_kit(p)
	# casa inicial em Santa Aurora
	var gen: WorldGen = G.world.gen
	var houses: Array = []
	for l in gen.lots:
		if l["type"] == "casa" and l["city"] == 1:
			houses.append(l)
	var hr := RandomNumberGenerator.new()
	hr.seed = G.hash2(G.world_seed, int(G.time_min), 3)
	var lot: Dictionary = houses[hr.randi() % houses.size()]
	var b: Rect2i = lot["b"]
	var pos := Vector3(b.position.x + b.size.x * 0.5, 0.2, b.position.y + b.size.y * 0.5)
	p.global_position = pos
	await _wait_world(pos)
	var bld: Building = G.world.buildings.get(lot["id"], null)
	if bld != null:
		var best := Vector3(bld.plan.w * 0.5, 0.2, bld.plan.d * 0.5)
		for room in bld.plan.rooms[0]:
			var rr: Rect2i = room["r"]
			for x in range(rr.position.x, rr.end.x):
				for z in range(rr.position.y, rr.end.y):
					if bld.plan.tg(0, x, z) == BPlan.T_FLOOR and room["k"] != "corredor":
						best = Vector3(x + 0.5, 0.2, z + 0.5)
						break
			if room["k"] == "sala":
				break
		p.global_position = bld.to_global(best)
		# a casa inicial comeca destrancada por dentro e sem alarme
		bld.state["alarm"] = false
	p._cam_pos = p.global_position + Vector3(0, 1.5, 0)
	G.in_game = true
	_clear_start_zombies(p.global_position)
	_finish_start()
	if bool(G.sandbox.get("tutorial", true)) and not keep_world:
		_tut = 1
		_tut_pos = p.global_position
	save_game(false)
	starting = false


func _clear_start_zombies(pos: Vector3) -> void:
	var zm: Node = G.zombies
	var k0 := WorldGen.ck(pos.x, pos.z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k := Vector2i(k0.x + dx, k0.y + dz)
			if not zm.pop.has(k):
				zm._init_chunk(k)
			if zm.pop.has(k):
				var list: Array = zm.pop[k]
				var i := list.size() - 1
				while i >= 0:
					if list[i]["p"].distance_to(pos) < 24.0:
						list.remove_at(i)
					i -= 1


func _starting_kit(p: Player) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = G.hash2(G.world_seed, 77, int(G.time_min))
	var inv := p.inv
	for slot in ["top", "bottom", "shoes", "socks"]:
		var it := Items.make(Clothes.random_id(r, slot))
		inv.worn[slot] = it
	inv.worn["belt"] = Items.make("r_cinto_%d_0" % (r.randi() % 6))
	inv.add(Items.make("garrafa_agua"))
	inv.add(Items.make("barra_cereal", 2))
	match p.sv.profession:
		"policial":
			inv.worn["top"] = Items.make("r_uniforme_policia_0_0")
			inv.worn["bottom"] = Items.make("r_calca_policia_0_0")
		"bombeiro":
			inv.worn["over"] = Items.make("r_jaqueta_bombeiro_0_0")
		"enfermeiro", "medico":
			inv.worn["top"] = Items.make("r_uniforme_saude_%d_0" % (r.randi() % 6))
			inv.add(Items.make("atadura", 2))
		"operario", "carpinteiro", "mecanico", "eletricista", "serralheiro":
			inv.worn["top"] = Items.make("r_uniforme_trabalho_%d_0" % (r.randi() % 8))
			inv.worn["shoes"] = Items.make("r_bota_trabalho_%d_0" % (r.randi() % 6))
		"lenhador", "guarda_florestal", "agricultor":
			inv.worn["top"] = Items.make("r_flanela_%d_3" % (r.randi() % 24))
			inv.worn["shoes"] = Items.make("r_bota_trabalho_0_0")
	if p.sv.has("fumante"):
		inv.add(Items.make("cigarros"))
		inv.add(Items.make("isqueiro"))
		p.sv.last_smoke = G.time_min
	p.refresh_look()


func _apply_world(d: Dictionary) -> void:
	G.world_name = d.get("name", G.world_name)
	G.world_seed = int(d.get("seed", 1))
	G.sandbox = d.get("sandbox", G.sandbox)
	G.time_min = float(d.get("time_min", G.time_min))
	G.play_seconds = float(d.get("play_seconds", 0.0))
	G.world.from_dict(d.get("world", {}))
	G.zombies.from_dict(d.get("zombies", {}))
	G.vehicles.from_dict(d.get("vehicles", {}))
	G.env.from_dict(d.get("env", {}))
	G.ui.from_dict(d.get("ui", {}))


func load_game(slot: String) -> void:
	if starting:
		return
	var d := Save.read(slot)
	if d.is_empty():
		if menu != null and is_instance_valid(menu):
			menu.message("Não foi possível ler este mundo.")
		return
	starting = true
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	_loading("Carregando %s..." % d.get("name", slot))
	await get_tree().process_frame
	G.slot = slot
	_build_scene()
	_apply_world(d)
	var p := _spawn_player()
	var pd: Dictionary = d.get("player", {})
	p.global_position = pd.get("pos", Vector3.ZERO)
	await _wait_world(p.global_position)
	p.from_dict(pd)
	G.in_game = true
	_finish_start()
	if d.get("_from_backup", false):
		G.say("O save principal estava corrompido: carregada a cópia de recuperação.")
	if p.sv.dead:
		p.dead_handled = true
		p.hum.down = 1.0
		_show_death()
	starting = false


func _finish_start() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_autosave = 0.0
	_death_t = -1.0
	_scale = 1.0
	Sfx.music("music_calm" if bool(G.settings["music_on"]) else "")


func to_menu() -> void:
	G.in_game = false
	G.paused = false
	G.time_mult = 1.0
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null
	G.player = null
	G.world = null
	G.zombies = null
	G.vehicles = null
	G.env = null
	G.hud = null
	G.ui = null
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	show_menu()


# =====================================================================================
#  SALVAMENTO
# =====================================================================================
func snapshot() -> Dictionary:
	return {"v": G.SAVE_VERSION, "version": G.VERSION, "name": G.world_name, "seed": G.world_seed, "time_min": G.time_min, "play_seconds": G.play_seconds,
		"sandbox": G.sandbox, "player": G.player.to_dict(), "world": G.world.to_dict(), "zombies": G.zombies.to_dict(), "vehicles": G.vehicles.to_dict(),
		"env": G.env.to_dict(), "ui": G.ui.to_dict(), "saved_at": int(Time.get_unix_time_from_system())}


func save_game(notify: bool) -> bool:
	if not G.in_game or G.player == null or not is_instance_valid(G.player):
		return false
	var sv: Survivor = G.player.sv
	var meta := {"name": G.world_name, "day": G.day() + 1, "survived": G.fmt_survived(), "char": sv.name, "prof": Survivor.PROFESSIONS[sv.profession]["n"],
		"dead": sv.dead, "saved_at": int(Time.get_unix_time_from_system()), "preset": G.sandbox["preset"], "version": G.VERSION}
	var ok := Save.write(G.slot, snapshot(), meta)
	if notify:
		G.say("Jogo salvo." if ok else "Falha ao salvar!")
	_autosave = 0.0
	return ok


# =====================================================================================
#  LACO PRINCIPAL
# =====================================================================================
func _process(dt: float) -> void:
	if not G.in_game or G.player == null or not is_instance_valid(G.player):
		return
	var p: Node3D = G.player
	var vel: Vector3 = p.velocity
	if p.vehicle != null:
		vel = p.vehicle.velocity
	G.world.focus(p.global_position, vel)
	if not G.paused:
		_autosave += dt
		if _autosave >= float(G.settings["autosave_min"]) * 60.0 and not p.sv.dead:
			save_game(false)
		_tutorial()
		if _death_t >= 0.0:
			_death_t += dt
			if _death_t > 2.6:
				_death_t = -1.0
				_show_death()
	_dyn_res(dt)


## Resolucao adaptativa: reduz a escala 3D quando o desempenho cai (inclui aquecimento).
func _dyn_res(dt: float) -> void:
	_fps_t += dt
	_fps_n += 1
	if _fps_t < 2.0:
		return
	var fps := _fps_n / _fps_t
	_fps_t = 0.0
	_fps_n = 0
	var base := 0.8 if int(G.settings["graphics"]) == 0 else 1.0
	if not bool(G.settings["dyn_res"]):
		_scale = base
	elif fps < 26.0:
		_scale = maxf(0.55, _scale - 0.07)
	elif fps > 50.0:
		_scale = minf(base, _scale + 0.05)
	_scale = minf(_scale, base)
	get_viewport().scaling_3d_scale = _scale


func _tutorial() -> void:
	if _tut <= 0 or G.hud == null:
		return
	var p: Node3D = G.player
	var hud: Control = G.hud
	match _tut:
		1:
			hud.tutorial_text = "Arraste o lado esquerdo da tela para andar e o lado direito para olhar ao redor."
			if p.global_position.distance_to(_tut_pos) > 3.0:
				_tut = 2
		2:
			hud.tutorial_text = "Chegue perto de um móvel e toque no botão de ação para vasculhar. Segure o botão para ver todas as opções."
			if G.ui.current == "cont":
				_tut = 3
		3:
			hud.tutorial_text = "Toque nos itens para pegar. Depois abra a MOCHILA para equipar, comer, beber ou vestir."
			if G.ui.current == "inv":
				_tut = 4
		4:
			hud.tutorial_text = "Zumbis veem e ouvem você. AGACHAR faz menos barulho; CORRER gasta fôlego. Portas e janelas podem ser barricadas."
			if p.global_position.distance_to(_tut_pos) > 25.0:
				_tut = 5
				_tut_pos = p.global_position
		5:
			hud.tutorial_text = "Use ATACAR de perto ou MIRAR e ATIRAR com armas de fogo. Trate ferimentos em SAÚDE; mordidas costumam ser fatais."
			if p.global_position.distance_to(_tut_pos) > 30.0 or p.sv.kills > 0:
				_tut = 6
				_tut_pos = p.global_position
		6:
			hud.tutorial_text = "Em FABRICAR você constrói, planta e coleta. Água e energia vão acabar: prepare-se. Boa sorte."
			if p.global_position.distance_to(_tut_pos) > 30.0:
				_tut = 0
				hud.tutorial_text = ""


# =====================================================================================
#  MORTE
# =====================================================================================
func on_player_death() -> void:
	var p: Player = G.player
	# o cadaver permanece no mundo com todos os equipamentos; infectados se reanimam
	var items: Array = p.inv.items.duplicate(true)
	for s in p.inv.worn:
		items.append(p.inv.worn[s])
	if p.inv.primary != null:
		items.append(p.inv.primary)
	if p.inv.secondary != null:
		items.append(p.inv.secondary)
	var re := -1.0
	if p.sv.zinf >= 0.0:
		re = G.time_min + randf_range(30.0, 180.0)
	G.world.add_corpse(p.global_position, p.rotation.y, Clothes.look_from(p.sv.body_look, p.inv.worn), items, true, re)
	p.inv.items = []
	p.inv.worn = {}
	p.inv.primary = null
	p.inv.secondary = null
	p.hum.visible = false
	save_game(false)
	_death_t = 0.0


func _show_death() -> void:
	if G.ui != null:
		G.ui.close()
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = UiScript.make_theme()
	overlay.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -330
	v.offset_right = 330
	v.offset_top = -190
	v.offset_bottom = 190
	bg.add_child(v)
	var sv: Survivor = G.player.sv
	var t := Label.new()
	t.text = "VOCÊ MORREU"
	t.add_theme_font_size_override("font_size", 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "%s sobreviveu por %s.\nCausa: %s.   Zumbis eliminados: %d.\nSeu corpo e seus equipamentos permanecem no mundo." % [sv.name, G.fmt_survived(), sv.death_cause if sv.death_cause != "" else "desconhecida", sv.kills]
	s.add_theme_font_size_override("font_size", 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b1 := Button.new()
	b1.text = "Novo sobrevivente neste mundo"
	b1.custom_minimum_size.y = 58
	b1.pressed.connect(func():
		var slot := G.slot
		to_menu()
		menu.new_character_in(slot))
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "Menu principal"
	b2.custom_minimum_size.y = 58
	b2.pressed.connect(to_menu)
	v.add_child(b2)
