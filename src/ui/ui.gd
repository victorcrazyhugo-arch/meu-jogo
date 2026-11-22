extends CanvasLayer
## Telas do jogo: inventario, equipamentos, recipientes, saude por partes do corpo,
## habilidades, tracos, fabricacao, construcao, mapa, mecanica, configuracoes e pausa.
## Todas operaveis por toque; o mundo continua correndo enquanto as telas estao abertas
## (exceto no menu de pausa).

const C_BG := Color(0.07, 0.08, 0.09, 0.96)
const C_PANEL := Color(0.12, 0.13, 0.15, 1.0)
const C_ACC := Color(0.93, 0.70, 0.25)
const C_BAD := Color(0.9, 0.35, 0.3)
const C_OK := Color(0.5, 0.82, 0.5)

var th: Theme
var root: Control
var current := ""
var body: Control
var tab := 0
var sel = null
var cat_filter := ""
var search := ""
var cont_items = null
var cont_title := ""
var cont_cap := 30.0
var craft_station := ""
var mech_vehicle = null
var mech_sel := ""
var xfer: Array = []
var placing: Dictionary = {}
var place_bar: Control
var map_zoom := 1.0
var map_center := Vector2.ZERO
var map_ctrl: Control
var explored := {}
var revealed := [false, false]
var markers: Array = []
var _exp_t := 0.0
var ground_mode := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	th = make_theme()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = th
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)


static func _sb(c: Color, border: Color = Color(1, 1, 1, 0.16)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = border
	s.set_content_margin_all(10)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", _sb(Color(0.19, 0.21, 0.24)))
	t.set_stylebox("hover", "Button", _sb(Color(0.24, 0.26, 0.30)))
	t.set_stylebox("pressed", "Button", _sb(Color(0.45, 0.35, 0.14), C_ACC))
	t.set_stylebox("disabled", "Button", _sb(Color(0.13, 0.14, 0.15), Color(1, 1, 1, 0.06)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL))
	t.set_stylebox("normal", "LineEdit", _sb(Color(0.1, 0.11, 0.12)))
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


func is_open() -> bool:
	return current != ""


func _lbl(text: String, size: int = 20, col: Color = Color(1, 1, 1, 0.92)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable, enabled: bool = true, min_h: float = 50.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.ui("ui_click", -12.0))
	return b


func _scroll(parent: Control, expand: bool = true) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if expand:
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func close() -> void:
	if current == "pause" or current == "settings":
		G.paused = false
	current = ""
	sel = null
	cont_items = null
	mech_vehicle = null
	ground_mode = false
	xfer.clear()
	for c in root.get_children():
		if c != place_bar:
			c.queue_free()
	body = null
	map_ctrl = null


## Monta a moldura padrao: fundo, titulo, abas e botao de fechar. Retorna a area de conteudo.
func _frame(title: String, tabs: Array = []) -> void:
	for c in root.get_children():
		if c != place_bar:
			c.queue_free()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := 14
	if G.hud != null:
		safe = int(maxf(14.0, maxf(G.hud.margin.x, G.hud.margin.z) + 6.0))
	m.add_theme_constant_override("margin_left", safe)
	m.add_theme_constant_override("margin_right", safe)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	bg.add_child(m)
	var v := VBoxContainer.new()
	m.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var tl := _lbl(title, 26, C_ACC)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(tl)
	for i in tabs.size():
		var tb := _btn(tabs[i], _set_tab.bind(i), true, 46.0)
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.custom_minimum_size.x = 150
		if i == tab:
			tb.add_theme_color_override("font_color", C_ACC)
		top.add_child(tb)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var cb := _btn("  FECHAR  ", close, true, 46.0)
	top.add_child(cb)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)


func _set_tab(i: int) -> void:
	tab = i
	sel = null
	refresh()


func open(nm: String) -> void:
	if G.player == null or (G.player.sv.dead and nm != "pause"):
		return
	if current == nm:
		close()
		return
	if is_open():
		close()
	current = nm
	tab = 0
	sel = null
	if nm == "pause":
		G.paused = true
	Sfx.ui("ui_open")
	refresh()


func refresh() -> void:
	match current:
		"inv":
			_build_inv()
		"cont":
			_build_cont()
		"health":
			_build_health()
		"craft":
			_build_craft()
		"map":
			_build_map()
		"pause":
			_build_pause()
		"settings":
			_build_settings()
		"mech":
			_build_mech()
		"ctx":
			pass
	_fix_rows(root)


func _process(dt: float) -> void:
	# fila de transferencias com duracao
	if not xfer.is_empty() and G.player != null and G.player.action.is_empty():
		var x: Array = xfer.pop_front()
		var it: Dictionary = x[0]
		var cb: Callable = x[1]
		G.player.start_action("Transferindo", clampf(0.22 + Items.weight_of(it) * 0.06, 0.22, 1.0), "work", cb, true)
	if G.in_game and G.player != null and is_instance_valid(G.player):
		_exp_t -= dt
		if _exp_t <= 0.0:
			_exp_t = 1.0
			var p: Vector3 = G.player.global_position
			explored[Vector2i(floori(p.x / 80.0), floori(p.z / 80.0))] = true
		if not placing.is_empty():
			_update_placing()
	if current == "map" and map_ctrl != null:
		map_ctrl.queue_redraw()


# =====================================================================================
#  INVENTARIO
# =====================================================================================
func _item_line(it: Dictionary) -> String:
	var s := Items.name_of(it)
	if int(it.get("n", 1)) > 1:
		s += "  ×%d" % int(it["n"])
	if it.has("c") and float(it["c"]) < 0.999:
		s += "  [%d%%]" % int(float(it["c"]) * 100.0)
	if G.player.inv.favorites.has(it["id"]):
		s = "★ " + s
	return "%s   %.1f kg" % [s, Items.weight_of(it)]


func _sorted(items: Array) -> Array:
	var arr := items.duplicate()
	var favs: Dictionary = G.player.inv.favorites
	arr.sort_custom(func(a, b):
		var fa := favs.has(a["id"])
		var fb := favs.has(b["id"])
		if fa != fb:
			return fa
		var ca := Items.CAT_ORDER.find(Items.def(a["id"]).get("cat", "Diversos"))
		var cb := Items.CAT_ORDER.find(Items.def(b["id"]).get("cat", "Diversos"))
		if ca != cb:
			return ca < cb
		return String(Items.def(a["id"])["n"]) < String(Items.def(b["id"])["n"]))
	return arr


func _weight_text() -> String:
	var p: Node = G.player
	return "Carga: %.1f / %.1f kg" % [p.inv.weight(), p.inv.capacity(p.sv)]


func _build_inv() -> void:
	_frame("MOCHILA", ["Itens", "Equipamento"])
	var p: Node = G.player
	var inv: Inv = p.inv
	if tab == 1:
		_build_equip()
		return
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	body.add_child(left)
	var hb := HBoxContainer.new()
	left.add_child(hb)
	var over := inv.weight() > inv.capacity(p.sv)
	hb.add_child(_lbl(_weight_text(), 20, C_BAD if over else Color(1, 1, 1, 0.9)))
	var le := LineEdit.new()
	le.placeholder_text = "buscar..."
	le.text = search
	le.custom_minimum_size = Vector2(190, 44)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t: String):
		search = t
		refresh())
	hb.add_child(le)
	# filtro por categoria
	var chips := HBoxContainer.new()
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 52
	sc.add_child(chips)
	left.add_child(sc)
	var cats := [""]
	for it in inv.items:
		var c: String = Items.def(it["id"]).get("cat", "Diversos")
		if not cats.has(c):
			cats.append(c)
	for c in cats:
		var cbn := _btn("Tudo" if c == "" else c, func():
			cat_filter = c
			refresh(), true, 44.0)
		if c == cat_filter:
			cbn.add_theme_color_override("font_color", C_ACC)
		chips.add_child(cbn)
	var list := _scroll(left)
	for it in _sorted(inv.items):
		var d := Items.def(it["id"])
		if cat_filter != "" and d.get("cat", "Diversos") != cat_filter:
			continue
		if search != "" and String(d["n"]).to_lower().find(search.to_lower()) < 0:
			continue
		var b := _btn(_item_line(it), func():
			sel = it
			refresh())
		if sel != null and is_same(sel, it):
			b.add_theme_color_override("font_color", C_ACC)
		list.add_child(b)
	if inv.items.is_empty():
		list.add_child(_lbl("Mochila vazia.", 20, Color(1, 1, 1, 0.5)))
	# detalhes e acoes
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	if sel == null or not inv.items.has(sel):
		right.add_child(_lbl("Toque em um item para ver as ações.", 20, Color(1, 1, 1, 0.55)))
		return
	right.add_child(_lbl(Items.name_of(sel), 24, C_ACC))
	right.add_child(_lbl(_describe(sel), 18, Color(1, 1, 1, 0.75)))
	var av := _scroll(right)
	for a in Interact.item_actions(p, sel):
		var it2: Dictionary = sel
		var aid: String = a["id"]
		var ab := _btn(a["label"] + ("" if a["ok"] else "  —  " + String(a["why"])), func():
			var keep: bool = aid in ["fav", "largar1", "esvaziar", "tomar", "descarregar", "equipar", "equipar2", "vestir", "largar", "mapa", "info_semente"]
			if not keep:
				close()
			Interact.item_run(G.player, it2, aid)
			if keep and current == "inv":
				refresh(), a["ok"])
		av.add_child(ab)


func _describe(it: Dictionary) -> String:
	var d := Items.def(it["id"])
	var parts: Array = [String(d.get("cat", ""))]
	if d.has("dmg") and not d.has("gun"):
		parts.append("dano %d–%d  •  alcance %.1f m  •  %s" % [d["dmg"][0], d["dmg"][1], d["rng"], "duas mãos" if d.get("two", 0) == 1 else "uma mão"])
	if d.has("gun"):
		parts.append("dano %d–%d  •  alcance %d m  •  ruído %d m  •  munição: %s" % [d["dmg"][0], d["dmg"][1], int(d["rng"]), int(d["noise"]), Items.def(d["ammo"])["n"]])
	if d.has("hun") and float(d["hun"]) > 0.0:
		parts.append("fome −%d  •  %d kcal" % [int(float(d["hun"]) * 100.0), int(d.get("cal", 0))])
	if d.has("fresh"):
		var st := Items.freshness(it)
		parts.append(["fresco", "passado (menos saboroso)", "estragado (risco de intoxicação)"][st])
	if d.has("raw") and int(it.get("ck", 0)) == 0:
		parts.append("cru: cozinhe antes de comer")
	if d.has("can"):
		parts.append("lata: precisa de abridor ou faca")
	if d.get("cat", "") == "Roupa":
		parts.append("isolamento %d%%  •  proteção %d%%  •  água %d%%" % [int(float(d["ins"]) * 100.0), int(float(d["prot"]) * 100.0), int(float(d["water"]) * 100.0)])
		if d.has("bagcap"):
			parts.append("capacidade +%.0f kg" % (float(d["bagcap"]) * float(d["red"])))
	if it.has("sh"):
		parts.append("fio %d%%" % int(float(it["sh"]) * 100.0))
	if d.has("skill"):
		parts.append("ensina %s (níveis %d a %d)" % [Survivor.SKILLS[d["skill"]], int(d["lv"][0]) + 1, d["lv"][1]])
	return "\n".join(parts)


func _build_equip() -> void:
	var p: Node = G.player
	var inv: Inv = p.inv
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var list := _scroll(left)
	var rows := [["primary", "Mãos", inv.primary], ["secondary", "Costas / cintura", inv.secondary]]
	for s in Clothes.SLOT_ORDER:
		rows.append([s, Clothes.SLOT_NAMES[s], inv.worn.get(s, null)])
	for r in rows:
		var it = r[2]
		var slot: String = r[0]
		var txt := "%s:  %s" % [r[1], "—" if it == null else _item_line(it)]
		var b := _btn(txt, func():
			Interact.unequip(G.player, slot)
			refresh(), it != null)
		list.add_child(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.7
	body.add_child(right)
	var ins := 0.0
	for s in inv.worn:
		ins += float(Items.def(inv.worn[s]["id"]).get("ins", 0.0))
	right.add_child(_lbl("Toque em uma peça para tirar.", 18, Color(1, 1, 1, 0.6)))
	right.add_child(_lbl(_weight_text()))
	right.add_child(_lbl("Isolamento térmico: %d%%" % int(ins * 100.0)))
	right.add_child(_lbl("Temperatura do ar: %d°C" % int(p.sv.air_temp)))
	var wet := 0.0
	right.add_child(_lbl("Umidade do corpo: %d%%" % int(p.sv.wet * 100.0)))
	right.add_child(_lbl("Proteção contra mordidas por região:", 18, C_ACC))
	for i in [8, 9, 6, 4, 2, 0, 11, 13, 15]:
		right.add_child(_lbl("  %s: %d%%" % [Survivor.PARTS[i], int(p.sv.protection(i, inv.worn) * 100.0 + wet)], 17))


# =====================================================================================
#  RECIPIENTES
# =====================================================================================
func open_container(title: String, items: Array, cap: float) -> void:
	if is_open():
		close()
	current = "cont"
	cont_title = title
	cont_items = items
	cont_cap = cap
	ground_mode = false
	sel = null
	Sfx.ui("ui_open")
	refresh()


func open_ground() -> void:
	if is_open():
		close()
	current = "cont"
	cont_title = "Chão"
	cont_items = []
	cont_cap = 9999.0
	ground_mode = true
	refresh()


func _build_cont() -> void:
	_frame(cont_title.to_upper())
	var p: Node = G.player
	var inv: Inv = p.inv
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var entries: Array = []
	if ground_mode:
		for g in G.world.ground_items(p.global_position):
			entries.append(g)
		left.add_child(_lbl("No chão (toque para pegar)", 19, C_ACC))
	else:
		left.add_child(_lbl("%s — %.1f / %.0f kg (toque para pegar)" % [cont_title, Inv.weight_of_list(cont_items), cont_cap], 19, C_ACC))
	var hb := HBoxContainer.new()
	left.add_child(hb)
	hb.add_child(_btn("Pegar tudo", func():
		if ground_mode:
			for g in G.world.ground_items(G.player.global_position):
				_take_ground(g)
		else:
			for it in cont_items.duplicate():
				_take(it)))
	var l1 := _scroll(left)
	if ground_mode:
		for g in entries:
			var gg: Array = g
			l1.add_child(_btn(_item_line(gg[1]["it"]), func(): _take_ground(gg)))
	else:
		for it in _sorted(cont_items):
			var it1: Dictionary = it
			l1.add_child(_btn(_item_line(it1), func(): _take(it1)))
		if cont_items.is_empty():
			l1.add_child(_lbl("Vazio.", 20, Color(1, 1, 1, 0.5)))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var over := inv.weight() > inv.capacity(p.sv)
	right.add_child(_lbl("Mochila — %s (toque para guardar)" % _weight_text(), 19, C_BAD if over else C_ACC))
	var l2 := _scroll(right)
	for it in _sorted(inv.items):
		var it2: Dictionary = it
		l2.add_child(_btn(_item_line(it2), func(): _put(it2)))


func _take(it: Dictionary) -> void:
	var items: Array = cont_items
	xfer.append([it, func():
		if not items.has(it):
			return
		var inv: Inv = G.player.inv
		if inv.weight() + Items.weight_of(it) > inv.capacity(G.player.sv) * 1.6:
			G.say("Pesado demais para carregar.")
			return
		items.erase(it)
		inv.add(it)
		Sfx.ui("pickup", -10.0)
		if current == "cont":
			refresh()])


func _take_ground(g: Array) -> void:
	var e: Dictionary = g[1]
	var key: Vector2i = g[0]
	xfer.append([e["it"], func():
		if not e.has("node"):
			return
		var inv: Inv = G.player.inv
		if inv.weight() + Items.weight_of(e["it"]) > inv.capacity(G.player.sv) * 1.6:
			G.say("Pesado demais para carregar.")
			return
		G.world.take_item(key, e)
		inv.add(e["it"])
		Sfx.ui("pickup", -10.0)
		if current == "cont":
			refresh()])


func _put(it: Dictionary) -> void:
	var items = cont_items
	var ground := ground_mode
	xfer.append([it, func():
		var inv: Inv = G.player.inv
		if not inv.items.has(it):
			return
		if ground:
			inv.remove_item(it)
			var fwd: Vector3 = -G.player.global_transform.basis.z
			G.world.drop_item(G.player.global_position + fwd * 0.7 + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), it)
		else:
			if Inv.weight_of_list(items) + Items.weight_of(it) > cont_cap:
				G.say("O recipiente está cheio.")
				return
			inv.remove_item(it)
			Inv.add_to(items, it)
		Sfx.ui("drop", -10.0)
		if current == "cont":
			refresh()])


# =====================================================================================
#  SAUDE, HABILIDADES E TRACOS
# =====================================================================================
func _build_health() -> void:
	_frame("SAÚDE", ["Corpo", "Habilidades", "Personagem"])
	var p: Node = G.player
	var sv: Survivor = p.sv
	if tab == 1:
		var grid := _scroll(body)
		for g in Survivor.SKILL_GROUPS:
			grid.add_child(_lbl(g[0], 22, C_ACC))
			for sk in g[1]:
				var hb := HBoxContainer.new()
				var nm := _lbl(Survivor.SKILLS[sk], 19)
				nm.custom_minimum_size.x = 300
				hb.add_child(nm)
				var lv := sv.level(sk)
				hb.add_child(_lbl("nível %d" % lv, 19, C_ACC if lv > 0 else Color(1, 1, 1, 0.6)))
				var pb := ProgressBar.new()
				pb.custom_minimum_size = Vector2(260, 22)
				pb.max_value = 1.0
				pb.value = sv.level_frac(sk)
				pb.show_percentage = false
				hb.add_child(pb)
				var boost: float = float(sv.xp_boost.get(sk, 1.0))
				if boost > 1.01:
					hb.add_child(_lbl("exp ×%.1f" % boost, 17, C_OK))
				grid.add_child(hb)
		return
	if tab == 2:
		var v := _scroll(body)
		v.add_child(_lbl("%s — %s" % [sv.name, Survivor.PROFESSIONS[sv.profession]["n"]], 24, C_ACC))
		v.add_child(_lbl("Sobreviveu: %s   •   Zumbis eliminados: %d" % [G.fmt_survived(), sv.kills]))
		v.add_child(_lbl("Peso corporal: %.1f kg   •   Calorias em reserva: %d   •   Proteínas: %d" % [sv.weight, int(sv.calories), int(sv.protein)]))
		v.add_child(_lbl("Estação: %s   •   Clima: %s   •   Energia elétrica: %s   •   Água encanada: %s" % [G.season_name(), G.env.WEATHER_NAMES[G.env.weather],
			"sim" if G.power_on() else "não", "sim" if G.water_on() else "não"]))
		v.add_child(_lbl("Traços", 22, C_ACC))
		for t in sv.traits:
			var td: Dictionary = Survivor.TRAITS.get(t, {})
			v.add_child(_lbl("• %s — %s" % [td.get("n", t), td.get("d", "")], 18))
		if sv.traits.is_empty():
			v.add_child(_lbl("Nenhum traço.", 18, Color(1, 1, 1, 0.5)))
		v.add_child(_lbl("Conhecimentos", 22, C_ACC))
		v.add_child(_lbl(", ".join(sv.known) if not sv.known.is_empty() else "Nenhum conhecimento especial ainda.", 18))
		return
	# ---- corpo
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var status := "Saúde geral: %d%%" % int(sv.health)
	if sv.zinf >= 0.0 and sv.zinf > 0.25:
		status += "   •   febre sem causa aparente"
	left.add_child(_lbl(status, 22, C_BAD if sv.health < 40.0 else C_OK))
	var mood: Array = []
	for m in sv.moodles():
		mood.append("%s (%s)" % [m["d"], m["t"].to_lower()])
	left.add_child(_lbl(" • ".join(mood) if not mood.is_empty() else "Você se sente bem.", 17, Color(1, 1, 1, 0.75)))
	var list := _scroll(left)
	for i in Survivor.PARTS.size():
		var ws: Array = sv.parts[i]["w"]
		if ws.is_empty():
			continue
		list.add_child(_lbl(Survivor.PARTS[i], 20, C_ACC))
		for w in ws:
			var wd: Dictionary = w
			var pi: int = i
			var txt := "   " + String(Survivor.WOUND_NAMES[w["t"]])
			if float(w["bl"]) > 0.0 and w["st"] == 0 and w["t"] != "fratura" and w["t"] != "queimadura":
				txt += "  •  sangrando" if w["band"] == 0 else "  •  sangramento contido"
			if w["band"] == 1:
				txt += "  •  curativo limpo"
			elif w["band"] == 2:
				txt += "  •  curativo SUJO"
			if w["st"] > 0:
				txt += "  •  suturado"
			if w["sp"] > 0:
				txt += "  •  imobilizado"
			if float(w["inf"]) > 0.25:
				txt += "  •  INFECCIONADO"
			if float(w["dis"]) > 0.0:
				txt += "  •  desinfetado"
			var b := _btn(txt, func():
				sel = [pi, wd]
				refresh())
			if sel != null and is_same(sel[1], wd):
				b.add_theme_color_override("font_color", C_ACC)
			list.add_child(b)
	if sv.wound_count() == 0:
		list.add_child(_lbl("Nenhum ferimento.", 20, Color(1, 1, 1, 0.55)))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.8
	body.add_child(right)
	var man := Control.new()
	man.custom_minimum_size = Vector2(200, 250)
	man.draw.connect(_draw_body.bind(man))
	right.add_child(man)
	if sel != null and sel is Array and sv.parts[sel[0]]["w"].has(sel[1]):
		right.add_child(_lbl("%s — %s" % [Survivor.PARTS[sel[0]], Survivor.WOUND_NAMES[sel[1]["t"]]], 20, C_ACC))
		var av := _scroll(right)
		for a in Interact.wound_actions(p, sel[0], sel[1]):
			var aid: String = a["id"]
			var part: int = sel[0]
			var wnd: Dictionary = sel[1]
			av.add_child(_btn(a["label"] + ("" if a["ok"] else "  —  " + String(a["why"])), func():
				close()
				Interact.wound_run(G.player, part, wnd, aid), a["ok"]))
	else:
		right.add_child(_lbl("Selecione um ferimento para tratar. Curativos sujos e feridas abertas podem infeccionar. Antibióticos tratam apenas infecções comuns.", 17, Color(1, 1, 1, 0.6)))


func _draw_body(c: Control) -> void:
	var sv: Survivor = G.player.sv
	var o := Vector2(c.size.x * 0.5, 8)
	# [parte, x, y, largura, altura]
	var shapes := [[8, -18, 0, 36, 36], [9, -8, 36, 16, 10], [6, -30, 46, 60, 44], [7, -27, 90, 54, 34], [10, -24, 124, 48, 16],
		[4, -52, 48, 20, 44], [5, 32, 48, 20, 44], [2, -54, 94, 18, 42], [3, 36, 94, 18, 42], [0, -56, 138, 18, 18], [1, 38, 138, 18, 18],
		[11, -27, 142, 24, 44], [12, 3, 142, 24, 44], [13, -26, 188, 21, 44], [14, 5, 188, 21, 44], [15, -30, 234, 26, 12], [16, 4, 234, 26, 12]]
	for s in shapes:
		var i: int = s[0]
		var pain := sv.part_pain(i)
		var col := Color(0.32, 0.36, 0.40)
		var mark := ""
		if not sv.parts[i]["w"].is_empty():
			col = Color(0.75, 0.55, 0.2).lerp(Color(0.85, 0.2, 0.15), clampf(pain * 2.0, 0.0, 1.0))
			mark = "!"
			for w in sv.parts[i]["w"]:
				if float(w["bl"]) > 0.0 and w["band"] == 0 and w["st"] == 0:
					mark = "S"
		var r := Rect2(o + Vector2(s[1], s[2]), Vector2(s[3], s[4]))
		c.draw_rect(r, col)
		c.draw_rect(r, Color(0, 0, 0, 0.6), false, 1.5)
		if mark != "":
			c.draw_string(ThemeDB.fallback_font, r.position + Vector2(r.size.x * 0.5 - 5, r.size.y * 0.5 + 6), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


# =====================================================================================
#  FABRICACAO, CONSTRUCAO E SOBREVIVENCIA
# =====================================================================================
func open_craft(station: String) -> void:
	if is_open():
		close()
	current = "craft"
	craft_station = station
	tab = 0
	sel = null
	Sfx.ui("ui_open")
	refresh()


func _build_craft() -> void:
	_frame("FABRICAR", ["Receitas", "Construir", "Sobrevivência"])
	var p: Node = G.player
	if current == "craft" and craft_station == "":
		craft_station = Interact.station(p)
	if tab == 1:
		_build_build()
		return
	if tab == 2:
		_build_survival()
		return
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var st := Interact.station(p)
	if craft_station == "fogo" and st != "fogo":
		st = "fogo" if craft_station == "fogo" else st
	left.add_child(_lbl("Estação: %s" % {"fogo": "fonte de calor acesa", "bancada": "bancada de trabalho", "": "nenhuma (mãos)"}[st], 18, Color(1, 1, 1, 0.7)))
	var list := _scroll(left)
	var last_cat := ""
	var rs: Array = Recipes.LIST.duplicate()
	rs.sort_custom(func(a, b): return String(a["cat"]) < String(b["cat"]))
	for r in rs:
		if r["cat"] != last_cat:
			last_cat = r["cat"]
			list.add_child(_lbl(last_cat, 21, C_ACC))
		var miss := Recipes.missing(r, p, st)
		var rr: Dictionary = r
		var b := _btn(("✔ " if miss == "" else "   ") + String(r["n"]), func():
			sel = rr
			refresh())
		if miss != "":
			b.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		if sel != null and sel is Dictionary and sel.get("id", "") == r["id"]:
			b.add_theme_color_override("font_color", C_ACC)
		list.add_child(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.85
	body.add_child(right)
	if sel == null or not (sel is Dictionary) or not sel.has("cat"):
		right.add_child(_lbl("Escolha uma receita. As marcadas com ✔ podem ser feitas agora.", 19, Color(1, 1, 1, 0.6)))
		return
	var r2: Dictionary = sel
	right.add_child(_lbl(r2["n"], 24, C_ACC))
	var lines: Array = []
	for k in r2.get("need", {}):
		var nm := "legumes (qualquer)" if k == "@veg" else ("carne crua" if k == "@carne" else String(Items.def(k)["n"]))
		lines.append("%d × %s" % [r2["need"][k], nm])
	for k in r2.get("use", {}):
		lines.append("1 uso de %s" % Items.def(k)["n"])
	if r2.has("agua"):
		lines.append("%.1f L de água" % float(r2["agua"]))
	if r2.has("gas"):
		lines.append("%.1f L de gasolina" % float(r2["gas"]))
	for t in r2.get("tools", []):
		lines.append("ferramenta: %s" % Recipes.tool_name(t))
	if r2.has("sk"):
		lines.append("habilidade: %s nível %d" % [Survivor.SKILLS[r2["sk"][0]], r2["sk"][1]])
	if r2.get("st", "") != "":
		lines.append("estação: %s" % ("fonte de calor" if r2["st"] == "fogo" else "bancada"))
	lines.append("tempo: %d s" % int(r2["t"]))
	right.add_child(_lbl("\n".join(lines), 18))
	var miss2 := Recipes.missing(r2, p, st)
	if miss2 != "":
		right.add_child(_lbl("Falta: " + miss2, 18, C_BAD))
	var hb := HBoxContainer.new()
	right.add_child(hb)
	for n in [1, 5]:
		var cnt: int = n
		var cb := _btn("Fabricar ×%d" % n, func():
			close()
			_craft_n(r2, cnt), miss2 == "")
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(cb)


func _craft_n(r: Dictionary, n: int) -> void:
	var p: Node = G.player
	var st := Interact.station(p)
	if Recipes.missing(r, p, st) != "":
		if n > 0:
			G.say("Faltam materiais para continuar.")
		return
	if r.has("snd"):
		Sfx.play3d(r["snd"], p.global_position)
	else:
		Sfx.play3d("craft", p.global_position, -6.0)
	var lvl: int = p.sv.level(r["xp"][0]) if r.has("xp") else 0
	var done := func():
		G.say(Recipes.craft(r, p))
		if n > 1:
			_craft_n(r, n - 1)
	p.start_action(r["n"], float(r["t"]) * (1.0 - lvl * 0.04), "work", done)


func _build_build() -> void:
	var p: Node = G.player
	var list := _scroll(body)
	list.add_child(_lbl("Escolha o que construir; depois posicione à sua frente, gire e confirme.", 18, Color(1, 1, 1, 0.65)))
	for id in Base.BUILD_ORDER:
		var d: Dictionary = Base.STRUCTS[id]
		var miss: Array = []
		for k in d["need"]:
			if p.inv.count(k) < int(d["need"][k]):
				miss.append("%s %d/%d" % [Items.def(k)["n"], p.inv.count(k), d["need"][k]])
		if String(d.get("tool", "")) != "" and not p.inv.has_tag(d["tool"]):
			miss.append(Recipes.tool_name(d["tool"]))
		if p.sv.level(d["sk"][0]) < int(d["sk"][1]):
			miss.append("%s nível %d" % [Survivor.SKILLS[d["sk"][0]], d["sk"][1]])
		var need: Array = []
		for k in d["need"]:
			need.append("%d %s" % [d["need"][k], Items.def(k)["n"]])
		var txt := "%s   (%s)" % [d["n"], ", ".join(need)]
		if not miss.is_empty():
			txt += "   — falta: " + ", ".join(miss)
		var sid: String = id
		list.add_child(_btn(txt, func():
			close()
			start_placing(sid, {}), miss.is_empty()))


func _build_survival() -> void:
	var p: Node = G.player
	var list := _scroll(body)
	var dig: bool = p.inv.has_tag("pa") or p.inv.has_tag("enxada")
	list.add_child(_lbl("Agricultura e coleta", 22, C_ACC))
	list.add_child(_btn("Cavar canteiro à frente" + ("" if dig else "  —  falta: pá, pazinha ou enxada"), func():
		close()
		_dig_plot(), dig))
	list.add_child(_btn("Procurar plantas e materiais por perto (coleta vegetal)", func():
		close()
		Interact.forage(G.player, 6.0)))
	list.add_child(_lbl("Exercícios (desenvolvem atributos; causam cansaço e dor muscular)", 22, C_ACC))
	list.add_child(_btn("Flexões — Força", func():
		close()
		_exercise("forca", "Fazendo flexões"), p.sv.endurance > 0.3))
	list.add_child(_btn("Agachamentos — Condicionamento", func():
		close()
		_exercise("fitness", "Fazendo agachamentos"), p.sv.endurance > 0.3))
	list.add_child(_lbl("Tempo", 22, C_ACC))
	list.add_child(_btn("Descansar no chão por uma hora", func():
		close()
		var pl: Node = G.player
		G.time_mult = 30.0
		var done := func():
			G.time_mult = 1.0
			pl.sv.endurance = 1.0
		pl.start_action("Descansando", 60.0 / (G.minutes_per_second() * 30.0), "", done)))
	var st := Interact.station(p)
	list.add_child(_lbl("Estação por perto: %s" % {"fogo": "fonte de calor acesa", "bancada": "bancada", "": "nenhuma"}[st], 18, Color(1, 1, 1, 0.6)))


func _exercise(sk: String, label: String) -> void:
	var p: Node = G.player
	var done := func():
		p.sv.add_xp(sk, 22.0 * (1.0 - p.sv.muscle_strain * 0.6))
		p.sv.spend(0.35)
		p.sv.muscle_strain = minf(1.0, p.sv.muscle_strain + 0.18)
		p.sv.hunger = minf(1.0, p.sv.hunger + 0.02)
		p.sv.thirst = minf(1.0, p.sv.thirst + 0.03)
		if p.sv.muscle_strain > 0.7:
			G.say("Seus músculos doem: descanse antes de continuar.")
	p.start_action(label, 12.0, "work", done)


func _dig_plot() -> void:
	var p: Node3D = G.player
	var pos: Vector3 = p.global_position - p.global_transform.basis.z * 1.3
	var w: Node3D = G.world
	if w.building_at(pos) != null or w.gen.road_at(pos.x, pos.z) >= 0 or w.cell_blocked(pos.x, pos.z) or w.gen.zone_at(pos.x, pos.z) == WorldGen.Z_RIVER:
		G.say("Não dá para cavar aqui.")
		return
	if Base.plot_at(w, Vector3(floorf(pos.x) + 0.5, 0, floorf(pos.z) + 0.5)) != null:
		G.say("Já existe um canteiro aqui.")
		return
	var done := func():
		Base.new_plot(w, pos)
		p.sv.add_xp("agricultura", 4.0)
		p.sv.spend(0.08)
		G.say("Canteiro pronto para semear.")
	Sfx.play3d("plant", p.global_position)
	p.start_action("Cavando canteiro", 5.0, "work", done)


# ---------------------------------------------------------------- posicionamento de estruturas
func start_placing(type: String, item) -> void:
	if is_open():
		close()
	cancel_placing()
	var mi := MeshInstance3D.new()
	mi.mesh = Base._mesh(type).to_mesh(Mats.ghost_ok)
	G.world.add_child(mi)
	placing = {"type": type, "rot": 0, "ghost": mi, "item": item, "ok": false}
	place_bar = HBoxContainer.new()
	place_bar.theme = th
	place_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	place_bar.position = Vector2(-260, -84)
	place_bar.custom_minimum_size = Vector2(520, 60)
	place_bar.anchor_left = 0.5
	place_bar.anchor_right = 0.5
	place_bar.anchor_top = 1.0
	place_bar.anchor_bottom = 1.0
	place_bar.offset_left = -270
	place_bar.offset_right = 270
	place_bar.offset_top = -96
	place_bar.offset_bottom = -34
	for e in [["GIRAR", func(): placing["rot"] = (int(placing["rot"]) + 1) % 4], ["CONFIRMAR", _confirm_place], ["CANCELAR", cancel_placing]]:
		var b := _btn(e[0], e[1], true, 58.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		place_bar.add_child(b)
	root.add_child(place_bar)
	G.say("Posicione a estrutura e confirme.")


func cancel_placing() -> void:
	if not placing.is_empty():
		if is_instance_valid(placing["ghost"]):
			placing["ghost"].queue_free()
		placing = {}
	if place_bar != null and is_instance_valid(place_bar):
		place_bar.queue_free()
	place_bar = null


func _place_pos() -> Vector3:
	var p: Node3D = G.player
	var f := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var q: Vector3 = p.global_position + f * 1.7
	var y := 0.0
	if p.cur_building != null:
		y = p.cur_building.floor_of(p.cur_building.to_local(p.global_position).y) * BPlan.FH + 0.06
	return Vector3(floorf(q.x) + 0.5, y, floorf(q.z) + 0.5)


func _update_placing() -> void:
	var g: MeshInstance3D = placing["ghost"]
	var pos := _place_pos()
	g.global_position = pos
	g.rotation.y = int(placing["rot"]) * PI * 0.5
	var why := Base.can_place(G.world, placing["type"], pos)
	placing["ok"] = why == ""
	placing["why"] = why
	g.material_override = Mats.ghost_ok if why == "" else Mats.ghost_bad


func _confirm_place() -> void:
	if placing.is_empty():
		return
	if not placing["ok"]:
		G.say(String(placing.get("why", "Local inválido.")))
		return
	var type: String = placing["type"]
	var d: Dictionary = Base.STRUCTS[type]
	var pos := _place_pos()
	var rot: int = placing["rot"]
	var item = placing["item"]
	var p: Node = G.player
	cancel_placing()
	var done := func():
		if d.has("item"):
			if item is Dictionary and p.inv.items.has(item):
				p.inv.remove_item(item)
				var extra := {}
				if type == "gerador":
					extra = {"fuel": float(item.get("fuel", 0.0)), "on": false}
				Base.place(G.world, type, pos, rot, extra)
			return
		for k in d["need"]:
			if p.inv.count(k) < int(d["need"][k]):
				G.say("Faltam materiais.")
				return
		for k in d["need"]:
			p.inv.remove(k, int(d["need"][k]))
		var extra2 := {}
		if type == "fogueira":
			extra2 = {"fuel": 0.0, "on": false}
		Base.place(G.world, type, pos, rot, extra2)
		p.sv.add_xp(d["sk"][0], 10.0)
		Sfx.noise(pos, 12.0)
		G.say("%s: construção concluída." % d["n"])
	Sfx.play3d("craft", pos)
	var secs: float = 2.0 if d.has("item") else 6.0 - p.sv.level("carpintaria") * 0.3
	p.start_action("Construindo" if not d.has("item") else "Colocando", secs, "work", done)


# =====================================================================================
#  MAPA
# =====================================================================================
func reveal_city(i: int) -> void:
	revealed[clampi(i, 0, 1)] = true


func _build_map() -> void:
	_frame("MAPA")
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	var p: Vector3 = G.player.global_position
	if map_center == Vector2.ZERO:
		map_center = Vector2(p.x, p.z)
	hb.add_child(_btn("  +  ", func(): map_zoom = minf(8.0, map_zoom * 1.5), true, 46.0))
	hb.add_child(_btn("  −  ", func(): map_zoom = maxf(0.6, map_zoom / 1.5), true, 46.0))
	hb.add_child(_btn("Centralizar em mim", func(): map_center = Vector2(G.player.global_position.x, G.player.global_position.z), true, 46.0))
	var le := LineEdit.new()
	le.placeholder_text = "anotação do marcador..."
	le.custom_minimum_size = Vector2(260, 46)
	hb.add_child(le)
	hb.add_child(_btn("Marcar minha posição", func():
		var pp: Vector3 = G.player.global_position
		markers.append({"p": Vector2(pp.x, pp.z), "n": le.text if le.text != "" else "Marcador %d" % (markers.size() + 1)})
		le.text = "", true, 46.0))
	hb.add_child(_btn("Apagar último", func():
		if not markers.is_empty():
			markers.pop_back(), true, 46.0))
	map_ctrl = Control.new()
	map_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_ctrl.clip_contents = true
	map_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	map_ctrl.draw.connect(_draw_map)
	map_ctrl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and (ev.button_mask & 1) != 0):
			var sc := _map_scale()
			map_center -= ev.relative / sc)
	v.add_child(map_ctrl)
	v.add_child(_lbl("Arraste para mover. Áreas ainda não visitadas aparecem sem detalhes; mapas das cidades revelam os estabelecimentos.", 16, Color(1, 1, 1, 0.55)))


func _map_scale() -> float:
	return map_ctrl.size.x / 3300.0 * map_zoom


func _draw_map() -> void:
	var c := map_ctrl
	var gen: WorldGen = G.world.gen
	var sc := _map_scale()
	var mid := c.size * 0.5
	var tf := func(x: float, z: float) -> Vector2:
		return mid + (Vector2(x, z) - map_center) * sc
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.16, 0.2, 0.15))
	var a: Vector2 = tf.call(WorldGen.X0, WorldGen.Z0)
	var b: Vector2 = tf.call(WorldGen.X1, WorldGen.Z1)
	c.draw_rect(Rect2(a, b - a), Color(0.23, 0.29, 0.2))
	# areas exploradas
	for k in explored:
		var e0: Vector2 = tf.call(k.x * 80.0, k.y * 80.0)
		c.draw_rect(Rect2(e0, Vector2(80.0, 80.0) * sc), Color(0.3, 0.37, 0.25))
	# rio
	var pts := PackedVector2Array()
	var z := WorldGen.Z0
	while z <= WorldGen.Z1:
		pts.append(tf.call(WorldGen.river_x(z), z))
		z += 25.0
	c.draw_polyline(pts, Color(0.25, 0.42, 0.55), maxf(2.0, 26.0 * sc), true)
	# estradas
	for r in gen.roads:
		var rr: Rect2 = r["r"]
		var col := Color(0.42, 0.42, 0.42) if r["kind"] != 2 else Color(0.48, 0.4, 0.28)
		var p0: Vector2 = tf.call(rr.position.x, rr.position.y)
		var s := rr.size * sc
		c.draw_rect(Rect2(p0, Vector2(maxf(s.x, 1.5), maxf(s.y, 1.5))), col)
	# edificios (se explorados ou revelados por mapa)
	var font := ThemeDB.fallback_font
	for l in gen.lots:
		var bb: Rect2i = l["b"]
		if bb.size.x == 0:
			continue
		var cx := bb.position.x + bb.size.x * 0.5
		var cz := bb.position.y + bb.size.y * 0.5
		var known: bool = explored.has(Vector2i(floori(cx / 80.0), floori(cz / 80.0))) or (int(l["city"]) > 0 and revealed[int(l["city"]) - 1])
		if not known:
			continue
		var bp: Vector2 = tf.call(bb.position.x, bb.position.y)
		var col2 := Color(0.62, 0.58, 0.5)
		if l["type"] != "casa" and l["type"] != "apto":
			col2 = Color(0.78, 0.66, 0.4)
		c.draw_rect(Rect2(bp, Vector2(bb.size) * sc), col2)
		if map_zoom >= 2.4 and l["type"] != "casa":
			c.draw_string(font, bp + Vector2(0, -3), String(l["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
	for poi in gen.pois:
		var pp: Vector2 = tf.call(poi["p"].x, poi["p"].y)
		var big: bool = poi["k"] == "cidade"
		if big or map_zoom >= 1.4:
			c.draw_string_outline(font, pp + Vector2(-60, 0), String(poi["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 20 if big else 13, 4, Color(0, 0, 0, 0.7))
			c.draw_string(font, pp + Vector2(-60, 0), String(poi["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 20 if big else 13, Color(1, 0.95, 0.8))
	for m in markers:
		var mp: Vector2 = tf.call(m["p"].x, m["p"].y)
		c.draw_circle(mp, 6.0, Color(0.95, 0.3, 0.25))
		c.draw_string(font, mp + Vector2(9, 5), String(m["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.85))
	# jogador
	var pl: Node3D = G.player
	var me: Vector2 = tf.call(pl.global_position.x, pl.global_position.z)
	var dir := Vector2(-sin(pl.yaw), -cos(pl.yaw))
	c.draw_circle(me, 7.0, Color(0.2, 0.8, 1.0))
	c.draw_line(me, me + dir * 16.0, Color(0.2, 0.8, 1.0), 3.0)
	# escala
	var bar := 200.0 * sc
	c.draw_line(Vector2(16, c.size.y - 16), Vector2(16 + bar, c.size.y - 16), Color.WHITE, 2.0)
	c.draw_string(font, Vector2(16, c.size.y - 22), "200 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


# =====================================================================================
#  MECANICA DE VEICULOS
# =====================================================================================
func open_mechanic(v) -> void:
	if is_open():
		close()
	current = "mech"
	mech_vehicle = v
	mech_sel = ""
	Sfx.ui("ui_open")
	refresh()


func _build_mech() -> void:
	var v = mech_vehicle
	if v == null or not is_instance_valid(v):
		close()
		return
	_frame("MECÂNICA — " + String(v.display_name).to_upper())
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(_lbl("Mecânica nível %d   •   combustível %.0f / %.0f L" % [G.player.sv.level("mecanica"), v.fuel, v.fuel_cap], 18, Color(1, 1, 1, 0.7)))
	var list := _scroll(left)
	for part in v.parts_list():
		var key: String = part["key"]
		var cond: float = part["cond"]
		var txt := "%s   %s   %s" % [part["name"], "AUSENTE" if cond < 0.0 else "%d%%" % int(cond * 100.0), part.get("info", "")]
		var b := _btn(txt, func():
			mech_sel = key
			refresh())
		if cond >= 0.0 and cond < 0.3:
			b.add_theme_color_override("font_color", C_BAD)
		if key == mech_sel:
			b.add_theme_color_override("font_color", C_ACC)
		list.add_child(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.85
	body.add_child(right)
	var gen := _scroll(right)
	if not v.hotwired and not v.has_key:
		var can: bool = G.player.sv.knows("ligacao_direta") or (G.player.sv.level("eletrica") >= 1 and G.player.sv.level("mecanica") >= 2)
		gen.add_child(_btn("Ligação direta" + ("" if can else "  —  requer conhecimento (revista) ou Elétrica 1 e Mecânica 2"), func():
			close()
			var done := func():
				G.say(v.hotwire(G.player))
			G.player.start_action("Fazendo ligação direta", 8.0, "work", done), can))
	if mech_sel == "":
		gen.add_child(_lbl("Selecione uma peça para ver os serviços disponíveis.", 18, Color(1, 1, 1, 0.6)))
		return
	for a in v.mechanic_actions(mech_sel, G.player):
		var aid: String = a["id"]
		var key2 := mech_sel
		var secs: float = float(a.get("time", 5.0))
		var lab: String = a["label"]
		gen.add_child(_btn(lab + ("" if a["ok"] else "  —  " + String(a["why"])), func():
			close()
			var done2 := func():
				if is_instance_valid(v):
					G.say(v.mechanic_do(key2, aid, G.player))
			Sfx.play3d("craft", v.global_position, -4.0)
			G.player.start_action(lab, secs, "work", done2), a["ok"]))


# =====================================================================================
#  MENU DE CONTEXTO, PAUSA E CONFIGURACOES
# =====================================================================================
func show_context(target: Dictionary, acts: Array) -> void:
	if is_open():
		close()
	current = "ctx"
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	root.add_child(bg)
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(520, 0)
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 0.5
	pc.anchor_bottom = 0.5
	pc.offset_left = -260
	pc.offset_right = 260
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(_lbl(String(target.get("name", "")), 23, C_ACC))
	for a in acts:
		var aid: String = a["id"]
		v.add_child(_btn(String(a["label"]) + ("" if a["ok"] else "  —  " + String(a["why"])), func():
			close()
			Interact.run(G.player, target, aid), a["ok"]))
	v.add_child(_btn("Cancelar", close))


func _build_pause() -> void:
	_frame("PAUSA")
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	v.add_child(_lbl("%s   •   %s   •   sobreviveu %s" % [G.world_name, G.fmt_date(), G.fmt_survived()], 20))
	v.add_child(_lbl("Preset: %s   •   versão %s" % [G.sandbox["preset"], G.VERSION], 17, Color(1, 1, 1, 0.6)))
	v.add_child(_btn("Continuar", close))
	v.add_child(_btn("Salvar agora", func():
		G.main.save_game(true)))
	v.add_child(_btn("Configurações", func():
		current = "settings"
		refresh()))
	v.add_child(_btn("Salvar e sair para o menu", func():
		G.main.save_game(false)
		close()
		G.main.to_menu()))
	v.add_child(_lbl("O jogo salva sozinho a cada %d minutos e ao sair do aplicativo. Sair do aplicativo não avança o tempo do mundo." % int(G.settings["autosave_min"]), 16, Color(1, 1, 1, 0.55)))


func _slider(parent: Control, label: String, key: String, mn: float, mx: float, step: float) -> void:
	var hb := HBoxContainer.new()
	var l := _lbl(label, 19)
	l.custom_minimum_size.x = 330
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(G.settings[key])
	s.custom_minimum_size = Vector2(330, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := _lbl("%.2f" % float(G.settings[key]), 18)
	val.custom_minimum_size.x = 70
	s.value_changed.connect(func(x: float):
		G.settings[key] = x
		val.text = "%.2f" % x
		G.save_settings())
	hb.add_child(s)
	hb.add_child(val)
	parent.add_child(hb)


func _toggle(parent: Control, label: String, key: String) -> void:
	var b := CheckButton.new()
	b.text = label
	b.button_pressed = bool(G.settings[key])
	b.custom_minimum_size.y = 46
	b.toggled.connect(func(on: bool):
		G.settings[key] = on
		G.save_settings())
	parent.add_child(b)


func settings_into(v: Control) -> void:
	v.add_child(_lbl("Câmera", 22, C_ACC))
	_slider(v, "Sensibilidade da câmera", "cam_sens", 0.3, 2.5, 0.05)
	_slider(v, "Distância da câmera", "cam_dist", 2.0, 6.0, 0.1)
	_slider(v, "Campo de visão", "cam_fov", 50.0, 90.0, 1.0)
	_slider(v, "Suavização da câmera", "cam_smooth", 0.0, 1.5, 0.05)
	_slider(v, "Tremor e balanço", "cam_shake", 0.0, 1.5, 0.05)
	_toggle(v, "Inverter eixo vertical", "invert_y")
	v.add_child(_lbl("Controles", 22, C_ACC))
	_slider(v, "Tamanho dos controles", "hud_scale", 0.75, 1.4, 0.05)
	_slider(v, "Assistência de mira", "aim_assist", 0.0, 1.0, 0.05)
	_toggle(v, "Modo canhoto (espelha os controles)", "left_handed")
	v.add_child(_lbl("Gráficos (não alteram as regras de sobrevivência)", 22, C_ACC))
	var hb := HBoxContainer.new()
	for i in 3:
		var gi: int = i
		var b := _btn(["Leve", "Equilibrado", "Alto"][i], func():
			G.settings["graphics"] = gi
			G.save_settings()
			if current == "settings":
				refresh(), true, 48.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if int(G.settings["graphics"]) == i:
			b.add_theme_color_override("font_color", C_ACC)
		hb.add_child(b)
	v.add_child(hb)
	_toggle(v, "Resolução adaptativa (reduz ao esquentar ou cair o desempenho)", "dyn_res")
	_toggle(v, "Mostrar FPS e zumbis ativos", "show_fps")
	v.add_child(_lbl("Som", 22, C_ACC))
	_slider(v, "Volume geral", "vol_master", 0.0, 1.0, 0.05)
	_slider(v, "Efeitos", "vol_sfx", 0.0, 1.0, 0.05)
	_slider(v, "Ambiente", "vol_amb", 0.0, 1.0, 0.05)
	_slider(v, "Música", "vol_music", 0.0, 1.0, 0.05)
	_toggle(v, "Música ativada", "music_on")
	v.add_child(_lbl("Jogo", 22, C_ACC))
	_slider(v, "Salvamento automático (minutos)", "autosave_min", 1.0, 15.0, 1.0)


func _build_settings() -> void:
	_frame("CONFIGURAÇÕES")
	var v := _scroll(body)
	settings_into(v)


func to_dict() -> Dictionary:
	return {"explored": explored.keys(), "revealed": revealed, "markers": markers}


func from_dict(d: Dictionary) -> void:
	explored = {}
	for k in d.get("explored", []):
		explored[k] = true
	revealed = d.get("revealed", [false, false])
	markers = d.get("markers", [])
	map_center = Vector2.ZERO


## Ajusta rotulos e botoes dentro de linhas horizontais: sem quebra de linha e com largura minima.
func _fix_rows(n: Node) -> void:
	for c in n.get_children():
		if c is Label and c.get_parent() is HBoxContainer and c.custom_minimum_size.x <= 0.0 and (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
		elif c is Button and c.get_parent() is HBoxContainer and c.custom_minimum_size.x <= 0.0 and (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			var fs: int = c.get_theme_font_size("font_size")
			c.custom_minimum_size.x = ThemeDB.fallback_font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
		_fix_rows(c)
