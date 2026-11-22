extends Control
## HUD e controles por toque: analogico dinamico, area de camera, botoes de acao com
## multitoque real (cada dedo tem seu papel), toque curto x prolongado, suporte a
## controle fisico e teclado, modo canhoto e escala ajustavel.

const C_BG := Color(0.05, 0.06, 0.07, 0.42)
const C_LINE := Color(1, 1, 1, 0.55)
const C_ON := Color(0.95, 0.72, 0.25, 0.55)
const C_TXT := Color(1, 1, 1, 0.92)
const LVL_COL := [Color(0.85, 0.8, 0.45), Color(0.92, 0.62, 0.25), Color(0.9, 0.38, 0.2), Color(0.85, 0.15, 0.15)]

var font: Font
var touches := {}            # indice -> {role, id, start, t0, moved}
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_active := false
var buttons: Array = []
var bmap := {}
var toasts: Array = []
var prog_label := ""
var prog_frac := 0.0
var dmg_flash := 0.0
var margin := Vector4(0, 0, 0, 0)   # esquerda, topo, direita, baixo
var _fps_acc := 0.0
var _fps_n := 0
var fps := 60.0
var _long_fired := {}
var _pad_prev := {}
var tutorial_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	G.toast.connect(_on_toast)
	for id in ["attack", "aim", "interact", "sprint", "crouch", "reload", "swap", "shoulder", "light",
			"inv", "health", "craft", "map", "pause", "gas", "brake", "exit", "lights", "horn"]:
		var b := {"id": id, "c": Vector2.ZERO, "r": 40.0, "label": "", "show": false, "on": false, "held": false, "rect": false, "sz": Vector2.ZERO}
		buttons.append(b)
		bmap[id] = b
	_safe_area()
	get_viewport().size_changed.connect(_safe_area)


func _safe_area() -> void:
	margin = Vector4(8, 6, 8, 6)
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var vs := get_viewport_rect().size
			var k := vs.x / win.x
			margin.x += maxf(0.0, float(safe.position.x)) * k
			margin.y += maxf(0.0, float(safe.position.y)) * k
			margin.z += maxf(0.0, win.x - float(safe.end.x)) * k
			margin.w += maxf(0.0, win.y - float(safe.end.y)) * k


func _on_toast(msg: String) -> void:
	toasts.append({"m": msg, "t": 4.5})
	if toasts.size() > 5:
		toasts.pop_front()


func set_progress(label: String, f: float) -> void:
	prog_label = label
	prog_frac = clampf(f, 0.0, 1.0)


func flash_damage() -> void:
	dmg_flash = 1.0


func blocked() -> bool:
	return G.paused or not G.in_game or (G.ui != null and G.ui.is_open())


# =====================================================================================
#  LEIAUTE
# =====================================================================================
func _layout() -> void:
	var p: Node = G.player
	if p == null or not is_instance_valid(p):
		return
	var s := float(G.settings["hud_scale"])
	var W := size.x
	var H := size.y
	var left: bool = G.settings["left_handed"]
	var driving: bool = p.vehicle != null
	var gun: bool = p.has_gun()
	for b in buttons:
		b["show"] = false
	var br := Vector2(W - margin.z, H - margin.w)
	if not driving:
		_put("attack", br + Vector2(-112, -150) * s, 60 * s, "ATIRAR" if gun else "ATACAR", left)
		_put("aim", br + Vector2(-238, -92) * s, 42 * s, "MIRAR", left, p.aiming)
		_put("sprint", br + Vector2(-244, -208) * s, 38 * s, "CORRER", left, p.sprinting)
		_put("crouch", br + Vector2(-352, -70) * s, 38 * s, "AGACHAR", left, p.crouching)
		_put("swap", br + Vector2(-348, -168) * s, 34 * s, "TROCAR", left)
		if not p.target.is_empty() or p.sleeping or not p.action.is_empty():
			var lab := "CANCELAR" if not p.action.is_empty() else ("ACORDAR" if p.sleeping else String(p.target.get("label", "USAR")).to_upper())
			_put("interact", br + Vector2(-66, -290) * s, 50 * s, lab, left)
		if gun:
			_put("reload", br + Vector2(-178, -300) * s, 36 * s, "RECARR.", left)
		if p.aiming:
			_put("shoulder", br + Vector2(-56, -52) * s, 30 * s, "OMBRO", left)
		if p.inv.find_tag("lanterna") != null:
			_put("light", br + Vector2(-270, -310) * s, 32 * s, "LUZ", left, p.light_on)
	else:
		_put("gas", br + Vector2(-100, -130) * s, 66 * s, "ACELERAR", left)
		_put("brake", br + Vector2(-250, -100) * s, 54 * s, "FREIO/RÉ", left)
		_put("exit", br + Vector2(-80, -290) * s, 40 * s, "SAIR", left)
		_put("lights", br + Vector2(-190, -250) * s, 36 * s, "FARÓIS", left, p.vehicle.lights_on)
		_put("horn", br + Vector2(-290, -220) * s, 34 * s, "BUZINA", left)
	# barra superior direita
	var names := [["pause", "MENU"], ["map", "MAPA"], ["craft", "FABRICAR"], ["health", "SAÚDE"], ["inv", "MOCHILA"]]
	var x := W - margin.z - 4.0
	for e in names:
		var b: Dictionary = bmap[e[0]]
		var w := 96.0 * s if e[0] != "pause" else 74.0 * s
		b["rect"] = true
		b["sz"] = Vector2(w, 42 * s)
		b["c"] = Vector2(x - w * 0.5, margin.y + 4 + 21 * s)
		b["label"] = e[1]
		b["show"] = true
		b["r"] = w * 0.5
		if left:
			b["c"].x = W - b["c"].x
		x -= w + 6.0


func _put(id: String, c: Vector2, r: float, label: String, left: bool, on: bool = false) -> void:
	var b: Dictionary = bmap[id]
	if left:
		c.x = size.x - c.x
	b["c"] = c
	b["r"] = r
	b["label"] = label
	b["show"] = true
	b["on"] = on
	b["rect"] = false


func _hit(pos: Vector2) -> Variant:
	for b in buttons:
		if not b["show"]:
			continue
		if b["rect"]:
			var sz: Vector2 = b["sz"]
			if Rect2(b["c"] - sz * 0.5 - Vector2(4, 4), sz + Vector2(8, 8)).has_point(pos):
				return b
		elif pos.distance_to(b["c"]) <= float(b["r"]) * 1.12:
			return b
	return null


# =====================================================================================
#  ENTRADA POR TOQUE
# =====================================================================================
func _input(ev: InputEvent) -> void:
	if blocked():
		if not touches.is_empty():
			_release_all()
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touch_down(ev.index, ev.position)
		else:
			_touch_up(ev.index, ev.position)
	elif ev is InputEventScreenDrag:
		_touch_move(ev.index, ev.position, ev.relative)


func _release_all() -> void:
	for i in touches.keys():
		var t: Dictionary = touches[i]
		if t["role"] == "btn":
			bmap[t["id"]]["held"] = false
	touches.clear()
	joy_active = false
	joy_vec = Vector2.ZERO
	G.held.clear()


func _touch_down(i: int, pos: Vector2) -> void:
	var b = _hit(pos)
	if b != null:
		touches[i] = {"role": "btn", "id": b["id"], "start": pos, "t0": Time.get_ticks_msec(), "moved": 0.0}
		b["held"] = true
		_long_fired.erase(b["id"])
		_btn_down(b["id"])
		return
	var left: bool = G.settings["left_handed"]
	var on_move_side := pos.x < size.x * 0.42 if not left else pos.x > size.x * 0.58
	if on_move_side and not joy_active and pos.y > size.y * 0.22:
		touches[i] = {"role": "joy", "id": "", "start": pos, "t0": Time.get_ticks_msec(), "moved": 0.0}
		joy_active = true
		joy_origin = pos
		joy_vec = Vector2.ZERO
		return
	touches[i] = {"role": "look", "id": "", "start": pos, "t0": Time.get_ticks_msec(), "moved": 0.0}


func _touch_move(i: int, pos: Vector2, rel: Vector2) -> void:
	if not touches.has(i):
		return
	var t: Dictionary = touches[i]
	t["moved"] = float(t["moved"]) + rel.length()
	var sens := float(G.settings["cam_sens"])
	match t["role"]:
		"joy":
			var r := 78.0 * float(G.settings["hud_scale"])
			var d: Vector2 = pos - joy_origin
			if d.length() > r:
				# o centro acompanha o dedo para nao travar o analogico
				joy_origin += d - d.normalized() * r
				d = d.normalized() * r
			joy_vec = d / r
		"look":
			G.look += rel * sens
		"btn":
			# arrastar sobre atacar/mirar continua girando a camera
			if t["id"] in ["attack", "aim", "gas", "brake"]:
				G.look += rel * sens * 0.9


func _touch_up(i: int, _pos: Vector2) -> void:
	if not touches.has(i):
		return
	var t: Dictionary = touches[i]
	touches.erase(i)
	match t["role"]:
		"joy":
			joy_active = false
			joy_vec = Vector2.ZERO
		"btn":
			var b: Dictionary = bmap[t["id"]]
			b["held"] = false
			_btn_up(t["id"], Time.get_ticks_msec() - int(t["t0"]))


func _btn_down(id: String) -> void:
	var p: Node = G.player
	G.held[id] = true
	match id:
		"attack":
			p.attack_pressed()
		"aim":
			p.aiming = not p.aiming
			if p.aiming:
				p.sprinting = false
		"sprint":
			p.sprinting = not p.sprinting
			if p.sprinting:
				p.crouching = false
				p.aiming = false
		"crouch":
			p.crouching = not p.crouching
			if p.crouching:
				p.sprinting = false
		"reload":
			p.reload_pressed()
		"swap":
			Interact.swap_weapons(p)
		"shoulder":
			p.toggle_shoulder()
		"light":
			p.set_light(not p.light_on)
		"inv":
			G.ui.open("inv")
		"health":
			G.ui.open("health")
		"craft":
			G.ui.open("craft")
		"map":
			G.ui.open("map")
		"pause":
			G.ui.open("pause")
		"exit":
			if p.vehicle != null:
				p.vehicle.exit_player(p)
		"lights":
			if p.vehicle != null:
				p.vehicle.toggle_lights()
		"horn":
			if p.vehicle != null:
				p.vehicle.horn()
	Sfx.ui("ui_click", -14.0)


func _btn_up(id: String, held_ms: int) -> void:
	G.held.erase(id)
	if id == "interact" and not _long_fired.has(id):
		if held_ms < 420:
			G.player.interact_pressed()


# =====================================================================================
#  ATUALIZACAO
# =====================================================================================
func _process(dt: float) -> void:
	_fps_acc += dt
	_fps_n += 1
	if _fps_acc >= 0.5:
		fps = _fps_n / _fps_acc
		_fps_acc = 0.0
		_fps_n = 0
	dmg_flash = maxf(0.0, dmg_flash - dt * 1.5)
	var i := toasts.size() - 1
	while i >= 0:
		toasts[i]["t"] = float(toasts[i]["t"]) - dt
		if float(toasts[i]["t"]) <= 0.0:
			toasts.remove_at(i)
		i -= 1
	if not G.in_game or G.player == null or not is_instance_valid(G.player):
		return
	_layout()
	if not blocked():
		_poll_devices(dt)
		# toque prolongado em interagir abre o menu de contexto
		for ti in touches:
			var t: Dictionary = touches[ti]
			if t["role"] == "btn" and t["id"] == "interact" and not _long_fired.has("interact"):
				if Time.get_ticks_msec() - int(t["t0"]) >= 420:
					_long_fired["interact"] = true
					G.player.interact_menu()
		# disparo continuo enquanto o botao esta pressionado
		if G.held.has("attack") and G.player.has_gun():
			G.player.attack_pressed()
	queue_redraw()


func _poll_devices(dt: float) -> void:
	var mv := joy_vec
	mv.y = -mv.y
	var p: Node = G.player
	# teclado (testes em computador)
	var kx := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var ky := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	if kx != 0.0 or ky != 0.0:
		mv = Vector2(kx, ky).normalized()
	# controle fisico
	if not Input.get_connected_joypads().is_empty():
		var jp: int = Input.get_connected_joypads()[0]
		var lx := Input.get_joy_axis(jp, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(jp, JOY_AXIS_LEFT_Y)
		if Vector2(lx, ly).length() > 0.2:
			mv = Vector2(lx, -ly)
		var rx := Input.get_joy_axis(jp, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(jp, JOY_AXIS_RIGHT_Y)
		if Vector2(rx, ry).length() > 0.15:
			G.look += Vector2(rx, ry) * 620.0 * dt * float(G.settings["cam_sens"])
		_pad(jp, JOY_BUTTON_A, "interact_tap")
		_pad(jp, JOY_BUTTON_X, "reload")
		_pad(jp, JOY_BUTTON_B, "crouch")
		_pad(jp, JOY_BUTTON_Y, "inv")
		_pad(jp, JOY_BUTTON_LEFT_STICK, "sprint")
		_pad(jp, JOY_BUTTON_RIGHT_SHOULDER, "swap")
		_pad(jp, JOY_BUTTON_LEFT_SHOULDER, "light")
		_pad(jp, JOY_BUTTON_START, "pause")
		_pad(jp, JOY_BUTTON_BACK, "map")
		_pad(jp, JOY_BUTTON_DPAD_UP, "health")
		_pad(jp, JOY_BUTTON_DPAD_DOWN, "craft")
		_pad(jp, JOY_BUTTON_DPAD_RIGHT, "shoulder")
		var rt := Input.get_joy_axis(jp, JOY_AXIS_TRIGGER_RIGHT)
		var lt := Input.get_joy_axis(jp, JOY_AXIS_TRIGGER_LEFT)
		if p.vehicle != null:
			_set_held("gas", rt > 0.3)
			_set_held("brake", lt > 0.3)
		else:
			if rt > 0.5 and not _pad_prev.get("rt", false):
				p.attack_pressed()
			_set_held("attack_pad", rt > 0.5)
			if rt > 0.5 and p.has_gun():
				p.attack_pressed()
			var want_aim := lt > 0.4
			if want_aim != _pad_prev.get("lt", false):
				p.aiming = want_aim
			_pad_prev["lt"] = want_aim
		_pad_prev["rt"] = rt > 0.5
	G.mv = mv


func _set_held(id: String, v: bool) -> void:
	if v:
		G.held[id] = true
	elif not bmap.has(id) or not bmap[id]["held"]:
		G.held.erase(id)


func _pad(jp: int, btn: int, id: String) -> void:
	var now := Input.is_joy_button_pressed(jp, btn)
	var key := "b%d" % btn
	if now and not _pad_prev.get(key, false):
		if id == "interact_tap":
			if G.player.vehicle != null:
				G.player.vehicle.exit_player(G.player)
			else:
				G.player.interact_pressed()
		else:
			_btn_down(id)
			G.held.erase(id)
	_pad_prev[key] = now


func _unhandled_key_input(ev: InputEvent) -> void:
	if blocked() or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var p: Node = G.player
	match ev.physical_keycode:
		KEY_SPACE:
			p.attack_pressed()
		KEY_E:
			if p.vehicle != null:
				p.vehicle.exit_player(p)
			else:
				p.interact_pressed()
		KEY_Q:
			p.interact_menu()
		KEY_F:
			_btn_down("aim")
		KEY_SHIFT:
			_btn_down("sprint")
		KEY_C:
			_btn_down("crouch")
		KEY_R:
			p.reload_pressed()
		KEY_X:
			_btn_down("swap")
		KEY_L:
			_btn_down("light")
		KEY_I, KEY_TAB:
			G.ui.open("inv")
		KEY_H:
			G.ui.open("health")
		KEY_B:
			G.ui.open("craft")
		KEY_M:
			G.ui.open("map")
		KEY_ESCAPE:
			G.ui.open("pause")
	G.held.erase("aim")
	G.held.erase("sprint")


# =====================================================================================
#  DESENHO
# =====================================================================================
func _txt(pos: Vector2, text: String, fs: int, col: Color = C_TXT, align: int = HORIZONTAL_ALIGNMENT_CENTER, width: float = -1.0) -> void:
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0.0:
		w = 400.0
		p.x -= 200.0
	draw_string_outline(font, p, text, align, w, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(font, p, text, align, w, fs, col)


func _draw() -> void:
	if not G.in_game or G.player == null or not is_instance_valid(G.player):
		return
	var p: Node = G.player
	var sv: Survivor = p.sv
	var W := size.x
	var H := size.y
	var s := float(G.settings["hud_scale"])
	if p.sleeping:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
		_txt(Vector2(W * 0.5, H * 0.45), "Dormindo...  %s" % G.fmt_clock(), 30)
	if dmg_flash > 0.0 or sv.health < 35.0:
		var a := maxf(dmg_flash * 0.35, (35.0 - sv.health) / 35.0 * 0.22 if sv.health < 35.0 else 0.0)
		draw_rect(Rect2(0, 0, W, H), Color(0.7, 0.0, 0.0, a))
	if G.ui != null and G.ui.is_open():
		return
	# ---- barras de saude e folego
	var x0 := margin.x + 6.0
	var y0 := margin.y + 8.0
	_bar(Rect2(x0, y0, 210 * s, 16 * s), sv.health / 100.0, Color(0.78, 0.2, 0.18), "SAÚDE")
	_bar(Rect2(x0, y0 + 22 * s, 210 * s, 12 * s), sv.endurance, Color(0.3, 0.72, 0.42), "FÔLEGO")
	# ---- indicadores de estado (moodles): sigla + intensidade em pontos
	var my := y0 + 46 * s
	for m in sv.moodles():
		var r := Rect2(x0, my, 132 * s, 26 * s)
		var lc: Color = LVL_COL[int(m["lv"]) - 1]
		draw_rect(r, Color(0.05, 0.05, 0.06, 0.6))
		draw_rect(Rect2(r.position, Vector2(5 * s, r.size.y)), lc)
		draw_string(font, r.position + Vector2(10 * s, 19 * s), String(m["a"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s), lc)
		for k in 4:
			var c := lc if k < int(m["lv"]) else Color(1, 1, 1, 0.18)
			draw_rect(Rect2(r.position + Vector2((66 + k * 15) * s, 9 * s), Vector2(11 * s, 9 * s)), c)
		my += 29 * s
		if my > H * 0.62:
			break
	# ---- relogio
	var clock := "%s  •  %s  •  %d°C" % [G.fmt_clock(), G.fmt_date(), int(round(sv.air_temp))]
	_txt(Vector2(W * 0.5, margin.y + 24 * s), clock, int(19 * s))
	if G.settings["show_fps"]:
		_txt(Vector2(W * 0.5, margin.y + 46 * s), "%d FPS  •  %d zumbis ativos" % [int(round(fps)), G.zombies.active_count() if G.zombies != null else 0], int(15 * s), Color(0.7, 1, 0.7))
	# ---- mensagens
	var ty := margin.y + 78 * s
	for t in toasts:
		var a2 := clampf(float(t["t"]), 0.0, 1.0)
		_txt(Vector2(W * 0.5, ty), String(t["m"]), int(19 * s), Color(1, 0.95, 0.8, a2))
		ty += 25 * s
	if tutorial_text != "":
		var tw := minf(620.0, W * 0.6)
		var tr := Rect2(W * 0.5 - tw * 0.5, H - margin.w - 150 * s, tw, 64 * s)
		draw_rect(tr, Color(0.04, 0.05, 0.06, 0.72))
		draw_rect(tr, Color(0.95, 0.72, 0.25, 0.8), false, 2.0)
		draw_multiline_string(font, tr.position + Vector2(12, 24 * s), tutorial_text, HORIZONTAL_ALIGNMENT_CENTER, tw - 24, int(17 * s), 3, C_TXT)
	# ---- progresso de acao
	if prog_label != "":
		var pw := 340.0 * s
		var pr := Rect2(W * 0.5 - pw * 0.5, H * 0.70, pw, 18 * s)
		draw_rect(pr, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pr.position, Vector2(pw * prog_frac, pr.size.y)), Color(0.95, 0.72, 0.25, 0.9))
		draw_rect(pr, C_LINE, false, 1.5)
		_txt(Vector2(W * 0.5, pr.position.y - 8), prog_label, int(18 * s))
	# ---- mira
	if p.vehicle == null and p.has_gun():
		_crosshair(p, W, H)
	elif p.vehicle == null and p.aiming:
		draw_circle(Vector2(W * 0.5, H * 0.5), 2.5, Color(1, 1, 1, 0.7))
	# ---- alvo de interacao
	if p.vehicle == null and not p.target.is_empty() and p.action.is_empty():
		_txt(Vector2(W * 0.5, H * 0.63), String(p.target.get("name", "")), int(18 * s), Color(1, 1, 1, 0.9))
		if p.target.has("hint"):
			_txt(Vector2(W * 0.5, H * 0.63 + 22 * s), String(p.target["hint"]), int(14 * s), Color(1, 1, 1, 0.65))
	# ---- analogico
	var jc := joy_origin
	var left: bool = G.settings["left_handed"]
	if not joy_active:
		jc = Vector2(margin.x + 150 * s, H - margin.w - 150 * s)
		if left:
			jc.x = W - jc.x
	var jr := 78.0 * s
	draw_circle(jc, jr, Color(0.05, 0.06, 0.07, 0.25 if joy_active else 0.14))
	draw_arc(jc, jr, 0, TAU, 40, Color(1, 1, 1, 0.5 if joy_active else 0.25), 2.0, true)
	draw_circle(jc + joy_vec * jr, 30 * s, Color(1, 1, 1, 0.38 if joy_active else 0.16))
	# ---- botoes
	for b in buttons:
		if not b["show"]:
			continue
		var c: Vector2 = b["c"]
		var fill := C_ON if (b["on"] or b["held"]) else C_BG
		if b["rect"]:
			var sz: Vector2 = b["sz"]
			var rr := Rect2(c - sz * 0.5, sz)
			draw_rect(rr, fill)
			draw_rect(rr, C_LINE, false, 1.5)
			_txt(c + Vector2(0, 6 * s), String(b["label"]), int(15 * s))
		else:
			var r: float = b["r"]
			draw_circle(c, r, fill)
			draw_arc(c, r, 0, TAU, 36, C_LINE, 2.0, true)
			var fs := int(clampf(r * 0.36, 11.0, 19.0))
			var lab := String(b["label"])
			fs = int(minf(fs, r * 3.1 / maxf(4.0, float(lab.length()))))
			_txt(c + Vector2(0, fs * 0.36), lab, fs)
	# ---- municao / arma
	if p.vehicle == null:
		var wname := "Mãos"
		if p.inv.primary != null:
			wname = Items.name_of(p.inv.primary)
			var cnd: float = float(p.inv.primary.get("c", 1.0))
			if cnd < 0.35:
				wname += "  (danificada)"
			if p.has_gun():
				wname += "  +%d" % p.inv.count(Items.def(p.inv.primary["id"])["ammo"])
		var ap: Vector2 = bmap["attack"]["c"] + Vector2(0, 82 * s)
		_txt(ap, wname, int(15 * s), Color(1, 1, 1, 0.85))
	else:
		_vehicle_gauges(p.vehicle, W, H, s)


func _bar(r: Rect2, f: float, col: Color, label: String) -> void:
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, C_LINE, false, 1.5)
	draw_string(font, r.position + Vector2(r.size.x + 8, r.size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.85), Color(1, 1, 1, 0.75))


func _crosshair(p: Node, W: float, H: float) -> void:
	var c := Vector2(W * 0.5, H * 0.5)
	var fov: float = p.cam.fov
	var px := tan(deg_to_rad(p.spread_now)) / tan(deg_to_rad(fov * 0.5)) * H * 0.5
	px = clampf(px, 5.0, 150.0)
	var col := Color(1, 1, 1, 0.9 if p.aiming else 0.5)
	if p.muzzle_blocked():
		col = Color(1, 0.3, 0.25, 0.95)
		draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), col, 2.5)
		draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), col, 2.5)
		_txt(c + Vector2(0, 34), "cano obstruído", 15, col)
		return
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * px, c + d * (px + 10.0), Color(0, 0, 0, 0.6), 4.0)
		draw_line(c + d * px, c + d * (px + 10.0), col, 2.0)
	draw_circle(c, 1.6, col)


func _vehicle_gauges(v: Node, W: float, H: float, s: float) -> void:
	var c := Vector2(W * 0.5, H - margin.w - 64 * s)
	var r := Rect2(c - Vector2(190, 46) * s, Vector2(380, 92) * s)
	draw_rect(r, Color(0.04, 0.05, 0.06, 0.62))
	draw_rect(r, C_LINE, false, 1.5)
	_txt(c + Vector2(-110 * s, 8 * s), "%d" % int(absf(v.speed) * 3.6), int(40 * s))
	_txt(c + Vector2(-110 * s, 30 * s), "km/h%s" % ("  (RÉ)" if v.speed < -0.3 else ""), int(14 * s), Color(1, 1, 1, 0.7))
	var fr := Rect2(c + Vector2(-20, -30) * s, Vector2(190, 14) * s)
	_bar(Rect2(fr.position, Vector2(130 * s, fr.size.y)), v.fuel / v.fuel_cap, Color(0.85, 0.65, 0.2), "COMB.")
	_bar(Rect2(fr.position + Vector2(0, 22 * s), Vector2(130 * s, fr.size.y)), v.part_cond("motor"), Color(0.5, 0.65, 0.85), "MOTOR")
	_bar(Rect2(fr.position + Vector2(0, 44 * s), Vector2(130 * s, fr.size.y)), v.battery, Color(0.6, 0.8, 0.4), "BATERIA")
	var st := "motor ligado" if v.engine_on else "motor desligado"
	_txt(c + Vector2(0, -52 * s), "%s  •  %s" % [v.display_name, st], int(15 * s), Color(1, 1, 1, 0.8))
