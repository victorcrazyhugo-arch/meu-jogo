extends CanvasLayer
## Menu principal: continuar, novo mundo (predefinicoes e sandbox detalhado), criacao de
## personagem (profissao, tracos com custo e incompatibilidades, aparencia), carregar e apagar mundos.

const UiScript := preload("res://src/ui/ui.gd")
const C_ACC := Color(0.93, 0.70, 0.25)

## opcao de sandbox: [chave, rotulo, [[texto, valor], ...]]
const SANDBOX_OPTS := [
	["zombie_pop", "População de zumbis", [["Nenhum", 0.0], ["Baixa", 0.35], ["Normal", 1.0], ["Alta", 2.0], ["Insana", 4.0]]],
	["zombie_speed", "Velocidade dos zumbis", [["Lentos", 0], ["Normais", 1], ["Corredores", 2]]],
	["zombie_strength", "Força dos zumbis", [["Fracos", 0], ["Normais", 1], ["Fortes", 2]]],
	["zombie_tough", "Resistência dos zumbis", [["Frágeis", 0], ["Normais", 1], ["Resistentes", 2]]],
	["zombie_sight", "Visão dos zumbis", [["Ruim", 0], ["Normal", 1], ["Aguçada", 2]]],
	["zombie_hearing", "Audição dos zumbis", [["Ruim", 0], ["Normal", 1], ["Aguçada", 2]]],
	["zombie_memory", "Memória dos zumbis", [["Curta", 0], ["Normal", 1], ["Longa", 2]]],
	["respawn_hours", "Reaparecimento de zumbis", [["Desligado", 0], ["A cada 72 h", 72], ["A cada 36 h", 36], ["A cada 12 h", 12]]],
	["infection", "Transmissão da infecção", [["Sangue e saliva", 0], ["Somente mordida", 1], ["Desligada", 2]]],
	["infection_days", "Evolução da infecção", [["12 horas", 0.5], ["2 a 3 dias", 2.5], ["Uma semana", 7.0]]],
	["wound_severity", "Gravidade dos ferimentos", [["Leve", 0.6], ["Normal", 1.0], ["Grave", 1.5]]],
	["loot", "Quantidade de saque", [["Muito escasso", 0.45], ["Escasso", 0.6], ["Normal", 1.0], ["Farto", 1.3], ["Abundante", 1.6]]],
	["day_minutes", "Duração do dia", [["30 minutos", 30], ["1 hora", 60], ["2 horas", 120], ["4 horas", 240]]],
	["start_month", "Mês inicial", [["Janeiro (verão)", 1], ["Março (outono)", 3], ["Junho (inverno)", 6], ["Setembro (primavera)", 9], ["Novembro", 11]]],
	["water_off_day", "Corte da água", [["Já cortada", 0], ["Por volta do dia 3", 3], ["Por volta do dia 12", 12], ["Por volta do dia 30", 30], ["Depois de um ano", 365]]],
	["power_off_day", "Corte da energia", [["Já cortada", 0], ["Por volta do dia 2", 2], ["Por volta do dia 9", 9], ["Por volta do dia 30", 30], ["Depois de um ano", 365]]],
	["xp_mult", "Ganho de experiência", [["Metade", 0.5], ["Normal", 1.0], ["×1,5", 1.5], ["×2", 2.0], ["×4", 4.0]]],
	["car_spawn", "Veículos no mapa", [["Raros", 0.3], ["Poucos", 0.6], ["Normal", 1.0], ["Muitos", 1.3]]],
	["fuel", "Combustível nos tanques", [["Quase nada", 0.3], ["Pouco", 0.5], ["Normal", 1.0], ["Bastante", 1.5]]],
	["rain", "Chuva", [["Seca", 0.0], ["Pouca", 0.5], ["Normal", 1.0], ["Muita", 2.0]]],
	["food_spoil", "Deterioração da comida", [["Lenta", 0.5], ["Normal", 1.0], ["Rápida", 2.0]]],
	["crop_speed", "Crescimento das plantações", [["Lento", 0.5], ["Normal", 1.0], ["Rápido", 1.5], ["Muito rápido", 3.0]]],
]

var th: Theme
var root: Control
var screen := "main"
var cfg := {}
var sandbox := {}
var chr := {}
var keep_slot := ""
var preview: Humanoid
var _spin := 0.0
var _msg := ""
var _settings_ui: CanvasLayer = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	th = UiScript.make_theme()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = th
	add_child(root)
	sandbox = G.SANDBOX_DEFAULT.duplicate(true)
	_new_char()
	_show("main")


func _exit_tree() -> void:
	if _settings_ui != null and is_instance_valid(_settings_ui):
		_settings_ui.free()


func _process(dt: float) -> void:
	if preview != null and is_instance_valid(preview):
		_spin += dt * 0.6
		preview.rotation.y = _spin
		preview.speed = 0.0
		preview.animate(dt)


func message(t: String) -> void:
	_msg = t
	_show(screen)


func back() -> void:
	if screen == "main":
		return
	_show("main" if screen != "char" or keep_slot != "" else "world")


func _lbl(text: String, size: int = 20, col: Color = Color(1, 1, 1, 0.92)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable, enabled: bool = true, h: float = 54.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.disabled = not enabled
	b.clip_text = true
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.ui("ui_click", -12.0))
	return b


func _scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _base(title: String) -> VBoxContainer:
	for c in root.get_children():
		c.queue_free()
	preview = null
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.065, 0.075)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(s, 44)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 14)
	bg.add_child(m)
	var v := VBoxContainer.new()
	m.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var tl := _lbl(title, 30, C_ACC)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(tl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	if screen != "main":
		top.add_child(_btn("  VOLTAR  ", back, true, 46.0))
	if _msg != "":
		v.add_child(_lbl(_msg, 20, Color(1, 0.5, 0.4)))
		_msg = ""
	return v


func _show(s: String) -> void:
	screen = s
	match s:
		"main":
			_main()
		"world":
			_world()
		"sandbox":
			_sandbox()
		"char":
			_char()
		"load":
			_load()
		"settings":
			var v := _base("CONFIGURAÇÕES")
			var sc := _scroll(v)
			if _settings_ui == null:
				_settings_ui = UiScript.new()
			_settings_ui.settings_into(sc)
		"about":
			_about()
	_fix_rows(root)


# =====================================================================================
#  TELAS
# =====================================================================================
func _main() -> void:
	var v := _base("")
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(left)
	var t := _lbl("ÚLTIMA BRUMA", 58, C_ACC)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(t)
	left.add_child(_lbl("Sobrevivência em terceira pessoa.\nDuas cidades. Nenhuma ajuda a caminho.", 20, Color(1, 1, 1, 0.7)))
	left.add_child(Control.new())
	var saves := Save.list()
	if not saves.is_empty():
		var s0: Dictionary = saves[0]
		var txt := "Continuar — %s, dia %s" % [s0.get("name", s0["slot"]), str(s0.get("day", "?"))]
		if s0.get("dead", false):
			txt = "Continuar — %s (sobrevivente morto)" % s0.get("name", s0["slot"])
		left.add_child(_btn(txt, func(): G.main.load_game(s0["slot"])))
	left.add_child(_btn("Novo mundo", func():
		keep_slot = ""
		_show("world")))
	left.add_child(_btn("Carregar mundo", func(): _show("load"), not saves.is_empty()))
	left.add_child(_btn("Configurações", func(): _show("settings")))
	left.add_child(_btn("Sobre esta versão", func(): _show("about")))
	left.add_child(_lbl("versão %s" % G.VERSION, 15, Color(1, 1, 1, 0.4)))
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	_add_preview(right)


func _add_preview(parent: Control) -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.fov = 38.0
	sv.add_child(cam)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.7, 0.6, 0)
	l.light_energy = 1.3
	sv.add_child(l)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.065, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	preview = Humanoid.new()
	sv.add_child(preview)
	_refresh_preview()


func _refresh_preview() -> void:
	if preview == null or not is_instance_valid(preview):
		return
	var look: Dictionary = chr["body"].duplicate(true)
	for id in chr["outfit"]:
		Clothes.apply(look, id)
	preview.set_look(look)


func _world() -> void:
	var v := _base("NOVO MUNDO")
	if not cfg.has("name"):
		cfg["name"] = "Mundo %d" % (Save.list().size() + 1)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	hb.add_child(_lbl("Nome do mundo:", 21))
	var le := LineEdit.new()
	le.text = cfg["name"]
	le.custom_minimum_size = Vector2(360, 48)
	le.text_changed.connect(func(t: String): cfg["name"] = t)
	hb.add_child(le)
	v.add_child(_lbl("Experiência", 22, C_ACC))
	var desc := {"Sobrevivente": "A experiência padrão: zumbis numerosos, saque normal, água e energia acabam em poucas semanas.",
		"Aprendiz": "Para conhecer o jogo: menos zumbis e mais lentos, mais saque, infecção só por mordida.",
		"Brutal": "Zumbis fortes e atentos, pouco saque, serviços cortados em dias.",
		"Construtor": "Poucos zumbis e progresso rápido para focar em base, fabricação e plantio.",
		"Seis meses depois": "O mundo já ruiu: sem água nem energia, saque raro, mais zumbis."}
	var list := _scroll(v)
	for pn in G.SANDBOX_PRESETS:
		var name_p: String = pn
		var b := _btn("%s — %s" % [pn, desc.get(pn, "")], func():
			G.apply_preset(name_p)
			sandbox = G.sandbox.duplicate(true)
			_show("world"), true, 62.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if sandbox.get("preset", "") == pn:
			b.add_theme_color_override("font_color", C_ACC)
		list.add_child(b)
	var cb := CheckButton.new()
	cb.text = "Dicas de tutorial durante os primeiros minutos"
	cb.button_pressed = bool(sandbox.get("tutorial", true))
	cb.toggled.connect(func(on: bool): sandbox["tutorial"] = on)
	list.add_child(cb)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	var b1 := _btn("Personalizar regras (sandbox)", func(): _show("sandbox"))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(b1)
	var b2 := _btn("Criar personagem  ▶", func(): _show("char"))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(b2)


func _sandbox() -> void:
	var v := _base("SANDBOX")
	v.add_child(_lbl("Estas regras ficam gravadas no mundo e valem durante toda a partida.", 18, Color(1, 1, 1, 0.6)))
	var list := _scroll(v)
	for o in SANDBOX_OPTS:
		var hb := HBoxContainer.new()
		var l := _lbl(o[1], 20)
		l.custom_minimum_size.x = 380
		hb.add_child(l)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(360, 48)
		var key: String = o[0]
		var opts: Array = o[2]
		var cur := 0
		var best := 1.0e9
		for i in opts.size():
			ob.add_item(opts[i][0])
			var diff := absf(float(opts[i][1]) - float(sandbox[key]))
			if diff < best:
				best = diff
				cur = i
		ob.select(cur)
		ob.item_selected.connect(func(i: int):
			sandbox[key] = opts[i][1]
			sandbox["preset"] = "Personalizado")
		hb.add_child(ob)
		list.add_child(hb)
	v.add_child(_btn("Pronto", func(): _show("world")))


func _new_char() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var body := Clothes.random_body(r)
	var names_m := ["Rafael", "Bruno", "Caio", "Diego", "Henrique", "Marcos", "Tiago", "Vitor", "André", "Lucas"]
	var names_f := ["Ana", "Beatriz", "Camila", "Débora", "Helena", "Júlia", "Marina", "Paula", "Sofia", "Lívia"]
	var sur := ["Almeida", "Barros", "Cardoso", "Duarte", "Fontes", "Moraes", "Nogueira", "Prado", "Ribeiro", "Teixeira"]
	var first: String = (names_f if body["female"] else names_m)[r.randi() % 10]
	chr = {"name": "%s %s" % [first, sur[r.randi() % 10]], "profession": chr.get("profession", "desempregado"), "traits": chr.get("traits", []),
		"body": body, "outfit": [Clothes.random_id(r, "top"), Clothes.random_id(r, "bottom"), Clothes.random_id(r, "shoes")]}


func _points() -> int:
	var pts: int = Survivor.PROFESSIONS[chr["profession"]]["pts"]
	for t in chr["traits"]:
		pts -= int(Survivor.TRAITS[t]["c"])
	return pts


func _char() -> void:
	var v := _base("SOBREVIVENTE" if keep_slot == "" else "NOVO SOBREVIVENTE NO MESMO MUNDO")
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hb)
	# coluna 1: profissao
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(c1)
	c1.add_child(_lbl("Profissão", 22, C_ACC))
	var l1 := _scroll(c1)
	for pid in Survivor.PROFESSIONS:
		var pd: Dictionary = Survivor.PROFESSIONS[pid]
		var id1: String = pid
		var sks: Array = []
		for k in pd["sk"]:
			sks.append("%s +%d" % [Survivor.SKILLS[k], pd["sk"][k]])
		var b := _btn("%s  (%+d pts)\n%s" % [pd["n"], pd["pts"], ", ".join(sks) if not sks.is_empty() else pd["d"]], func():
			chr["profession"] = id1
			_show("char"), true, 70.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		if chr["profession"] == pid:
			b.add_theme_color_override("font_color", C_ACC)
		l1.add_child(b)
	# coluna 2: tracos
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.size_flags_stretch_ratio = 1.25
	hb.add_child(c2)
	var pts := _points()
	c2.add_child(_lbl("Traços — pontos disponíveis: %d" % pts, 22, C_ACC if pts >= 0 else Color(1, 0.4, 0.35)))
	var l2 := _scroll(c2)
	for pass_i in 2:
		l2.add_child(_lbl("Vantagens (custam pontos)" if pass_i == 0 else "Desvantagens (devolvem pontos)", 18, Color(1, 1, 1, 0.6)))
		for tid in Survivor.TRAITS:
			var td: Dictionary = Survivor.TRAITS[tid]
			if td.get("prof", false) or (int(td["c"]) > 0) != (pass_i == 0):
				continue
			var id2: String = tid
			var has: bool = chr["traits"].has(tid)
			var clash := false
			for x in td["x"]:
				if chr["traits"].has(x):
					clash = true
			var b2 := _btn("%s %s  (%+d)  —  %s" % ["☑" if has else "☐", td["n"], -int(td["c"]), td["d"]], func():
				if chr["traits"].has(id2):
					chr["traits"].erase(id2)
				else:
					chr["traits"].append(id2)
				_show("char"), has or not clash, 48.0)
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b2.add_theme_font_size_override("font_size", 16)
			if has:
				b2.add_theme_color_override("font_color", C_ACC)
			l2.add_child(b2)
	# coluna 3: aparencia
	var c3 := VBoxContainer.new()
	c3.custom_minimum_size.x = 300
	hb.add_child(c3)
	var le := LineEdit.new()
	le.text = chr["name"]
	le.custom_minimum_size.y = 46
	le.text_changed.connect(func(t: String): chr["name"] = t)
	c3.add_child(le)
	var pv := Control.new()
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c3.add_child(pv)
	_add_preview(pv)
	c3.add_child(_btn("Outra aparência", func():
		_new_char()
		_show("char"), true, 46.0))
	c3.add_child(_btn("COMEÇAR  ▶", _start, pts >= 0, 60.0))
	if pts < 0:
		c3.add_child(_lbl("Pontos negativos: remova vantagens ou escolha desvantagens.", 15, Color(1, 0.5, 0.4)))


func new_character_in(slot: String) -> void:
	keep_slot = slot
	G.slot = slot
	_new_char()
	_show("char")


func _start() -> void:
	var c := {"name": chr["name"] if String(chr["name"]).strip_edges() != "" else "Sobrevivente", "profession": chr["profession"], "traits": chr["traits"].duplicate(), "body": chr["body"]}
	if keep_slot != "":
		G.main.new_game({"char": c}, true)
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	G.main.new_game({"slot": Save.new_slot(), "name": cfg.get("name", "Mundo"), "seed": r.randi() % 1000000 + 1, "sandbox": sandbox, "char": c})


func _load() -> void:
	var v := _base("CARREGAR MUNDO")
	var list := _scroll(v)
	for s in Save.list():
		var hb := HBoxContainer.new()
		var slot: String = s["slot"]
		var txt := "%s — dia %s — %s (%s)%s" % [s.get("name", slot), str(s.get("day", "?")), s.get("char", "?"), s.get("prof", "?"), "  †" if s.get("dead", false) else ""]
		var b := _btn(txt, func(): G.main.load_game(slot))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		hb.add_child(b)
		hb.add_child(_btn("  Apagar  ", func():
			Save.delete(slot)
			_show("load")))
		list.add_child(hb)
	if Save.list().is_empty():
		list.add_child(_lbl("Nenhum mundo salvo.", 20, Color(1, 1, 1, 0.5)))


func _about() -> void:
	var v := _base("SOBRE ESTA VERSÃO")
	var list := _scroll(v)
	list.add_child(_lbl("Última Bruma %s — primeiro ciclo jogável." % G.VERSION, 22, C_ACC))
	list.add_child(_lbl("Jogo original de sobrevivência em mundo aberto, em terceira pessoa, feito para celular. Código, modelos, animações procedurais, sons sintetizados, mapa e interface são próprios deste projeto.\n\nMapa: duas cidades (Santa Aurora e Porto Bruma) ligadas por rodovia, com rio, fazendas de produção vegetal, florestas, cabanas e acampamentos. O mundo não contém animais; não há caça, pesca nem criação.\n\nModo solo totalmente offline. O jogo salva sozinho e ao sair do aplicativo; o tempo do mundo só passa enquanto você joga.\n\nEsta é uma versão inicial: vários sistemas estão em forma básica e o multiplayer ficou para uma etapa posterior. A lista completa do que está pronto, parcial e pendente acompanha o projeto (pasta docs).", 19))
	list.add_child(_lbl("Variantes de vestuário no catálogo: %d   •   Itens: %d   •   Receitas: %d   •   Edifícios no mapa: %d" % [Clothes.count_variants(), Items.D.size(), Recipes.LIST.size(), WorldGen.new().lots.size()], 17, Color(1, 1, 1, 0.65)))


## Ajusta rotulos e botoes dentro de linhas horizontais: sem quebra de linha e com largura minima.
func _fix_rows(n: Node) -> void:
	for c in n.get_children():
		if c is Label and c.get_parent() is HBoxContainer and c.custom_minimum_size.x <= 0.0 and (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
		elif c is Button and c.get_parent() is HBoxContainer and c.custom_minimum_size.x <= 0.0 and (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			var fs: int = c.get_theme_font_size("font_size")
			c.custom_minimum_size.x = ThemeDB.fallback_font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
		_fix_rows(c)
