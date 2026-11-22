class_name Player
extends CharacterBody3D
## Sobrevivente controlado pelo jogador: locomocao, camera em terceira pessoa,
## combate corpo a corpo e com armas de fogo, acoes com duracao e percepcao.

const UNARMED := {"n": "Mãos", "wt": "", "dmg": [1, 4], "rng": 0.95, "spd": 0.55, "sta": 0.03, "brk": 0, "hits": 2, "kb": 1.6, "anim": "push"}

var hum: Humanoid
var sv: Survivor
var inv: Inv

# camera
var cam_rig: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.22
var shoulder := 1.0
var aim_w := 0.0
var _off := 0.3
var _dist := 3.4
var trauma := 0.0
var recoil := 0.0
var _cam_pos := Vector3.ZERO

# estado
var aiming := false
var crouching := false
var sprinting := false
var aim_focus := 0.0
var attack: Dictionary = {}
var fire_cd := 0.0
var action: Dictionary = {}
var vehicle: Node3D = null
var indoors := false
var cur_building = null
var slow_t := 0.0
var vaulting := false
var light_on := false
var flashlight: SpotLight3D
var target: Dictionary = {}       # alvo de interacao atual
var _scan_t := 0.0
var _ctx_t := 0.0
var _threat := 0
var _muzzle_blocked := false
var spread_now := 2.0
var _stat_ctx := {}
var sleeping := false
var _sleep_start := 0.0
var dead_handled := false
var god := false


func _ready() -> void:
	collision_layer = G.L_PLAYER
	collision_mask = G.L_WORLD | G.L_GLASS | G.L_VEHICLE | G.L_ZOMBIE
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.76
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	hum = Humanoid.new()
	add_child(hum)
	hum.step.connect(_on_step)
	if sv == null:
		sv = Survivor.new()
	if inv == null:
		inv = Inv.new()
	# camera
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	arm = SpringArm3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.16
	arm.shape = sp
	arm.collision_mask = G.L_WORLD
	arm.margin = 0.06
	arm.spring_length = _dist
	arm.add_excluded_object(get_rid())
	cam_rig.add_child(arm)
	cam = Camera3D.new()
	cam.near = 0.12
	cam.far = 420.0
	cam.fov = float(G.settings["cam_fov"])
	arm.add_child(cam)
	cam.make_current()
	_cam_pos = global_position + Vector3(0, 1.55, 0)
	# lanterna
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 26.0
	flashlight.spot_angle = 34.0
	flashlight.light_energy = 2.6
	flashlight.light_color = Color(1.0, 0.96, 0.86)
	flashlight.shadow_enabled = false
	flashlight.visible = false
	flashlight.position = Vector3(0.2, 1.3, -0.3)
	add_child(flashlight)
	refresh_look()
	refresh_weapon()


func refresh_look() -> void:
	hum.set_look(Clothes.look_from(sv.body_look, inv.worn))


func weapon_def() -> Dictionary:
	if inv.primary == null:
		return UNARMED
	var d := Items.def(inv.primary["id"])
	if d.has("dmg"):
		return d
	return UNARMED


func has_gun() -> bool:
	return inv.primary != null and Items.def(inv.primary["id"]).has("gun")


func refresh_weapon() -> void:
	var mdl := ""
	hum.hold = 0
	if inv.primary != null:
		var d := Items.def(inv.primary["id"])
		mdl = String(d.get("mdl", "_"))
		if d.has("gun"):
			hum.hold = 4 if d.get("two", 0) == 1 else 3
		elif d.has("dmg"):
			hum.hold = 2 if d.get("two", 0) == 1 else 1
		else:
			hum.hold = 1
	hum.set_weapon(mdl)
	var back := ""
	if inv.secondary != null:
		back = String(Items.def(inv.secondary["id"]).get("mdl", ""))
	hum.set_back_item(back)


# =====================================================================================
#  QUADRO A QUADRO
# =====================================================================================
func _physics_process(dt: float) -> void:
	if G.paused or not G.in_game:
		return
	if sv.dead:
		_dead_tick(dt)
		return
	fire_cd = maxf(0.0, fire_cd - dt)
	slow_t = maxf(0.0, slow_t - dt)
	_update_action(dt)
	_update_attack(dt)
	if vehicle != null:
		global_position = vehicle.seat_position()
		rotation.y = vehicle.rotation.y
		velocity = Vector3.ZERO
		hum.sit = 1.0
		hum.speed = 0.0
		hum.animate(dt)
		_stats(dt, false, false)
		return
	hum.sit = 0.0
	var mv: Vector2 = G.mv
	var mag := minf(mv.length(), 1.0)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var rgt := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := fwd * mv.y + rgt * mv.x
	if dir.length() > 0.01:
		dir = dir.normalized()
	var locked: bool = vaulting or sleeping or (not action.is_empty() and not action.get("move_ok", false) and mag < 0.35)
	if not action.is_empty() and not action.get("move_ok", false) and mag >= 0.35:
		cancel_action()
	var over := sv.carry / maxf(sv.carry_max, 0.1)
	var can_sprint := sprinting and mag > 0.7 and not crouching and not aiming and sv.endurance > 0.04 and over < 1.25 and attack.is_empty()
	var spd := 0.0
	if mag > 0.1 and not locked:
		if crouching:
			spd = 1.1 if mag < 0.6 else 1.9 + sv.level("furtividade") * 0.04
		elif can_sprint:
			spd = 5.3 + sv.level("corrida") * 0.14
		elif mag < 0.55:
			spd = 1.6
		else:
			spd = 3.3 + sv.level("fitness") * 0.03
		if aiming:
			spd = minf(spd, 1.5 + sv.level("agilidade") * 0.12)
		if not attack.is_empty():
			spd = minf(spd, 1.3 + sv.level("agilidade") * 0.1)
		spd *= speed_mult()
	var tv := dir * spd
	var acc := 22.0 if is_on_floor() else 4.0
	velocity.x = move_toward(velocity.x, tv.x, acc * dt)
	velocity.z = move_toward(velocity.z, tv.z, acc * dt)
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	else:
		velocity.y = -0.5
	if not vaulting:
		move_and_slide()
	# orientacao
	var hv := Vector2(velocity.x, velocity.z)
	var want := rotation.y
	if aiming or not attack.is_empty():
		want = attack.get("face", yaw) if not attack.is_empty() else yaw
	elif hv.length() > 0.3:
		want = atan2(-velocity.x, -velocity.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-(16.0 if aiming else 11.0) * dt))
	# animacao
	hum.speed = hv.length()
	hum.crouch = move_toward(hum.crouch, 1.0 if crouching else 0.0, dt * 5.0)
	var gun := has_gun()
	hum.aim = 0
	if aiming and gun and action.is_empty():
		hum.aim = 2 if Items.def(inv.primary["id"]).get("two", 0) == 1 else 1
	hum.aim_pitch = clampf(pitch, -0.9, 0.9)
	hum.limp = sv.leg_penalty()
	hum.tired = clampf((1.0 - sv.endurance) * 0.8 + maxf(0.0, sv.fatigue - 0.6), 0.0, 1.0)
	hum.animate(dt)
	if hum.aim > 0:
		hum.weapon_node.global_basis = Basis.from_euler(Vector3(pitch + recoil, yaw, 0.0))
	elif gun:
		hum.weapon_node.rotation = Vector3(-1.2, 0, 0)
	# foco de mira: melhora parado, piora em movimento
	if aiming and gun:
		var gain := (0.9 + sv.level("mira") * 0.12) * (0.35 if hv.length() > 0.5 else 1.0)
		aim_focus = minf(1.0, aim_focus + dt * gain)
	else:
		aim_focus = maxf(0.0, aim_focus - dt * 3.0)
	_stats(dt, can_sprint and hv.length() > 3.0, hv.length() > 0.3)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.12
		_scan()


func speed_mult() -> float:
	var m := 1.0 - sv.leg_penalty()
	var over := sv.carry / maxf(sv.carry_max, 0.1)
	if over > 1.0:
		m *= clampf(1.0 - (over - 1.0) * 0.8, 0.4, 1.0)
	if sv.fatigue > 0.8:
		m *= 0.85
	if sv.endurance < 0.1:
		m *= 0.75
	if sv.pain > 0.5:
		m *= 0.9
	if sv.thermal < -0.7:
		m *= 0.85
	if sv.drunk > 0.6:
		m *= 0.9
	if slow_t > 0.0:
		m *= 0.45
	if inv.worn.has("shoes"):
		m *= float(Items.def(inv.worn["shoes"]["id"]).get("run", 1.0))
	else:
		m *= 0.88
	return m


func _stats(dt: float, sprint_now: bool, moving: bool) -> void:
	sv.activity = 3 if sprint_now else (2 if hum.speed > 2.5 else (1 if moving else (4 if not action.is_empty() else 0)))
	sv.tick_endurance(dt, sprint_now, moving)
	_ctx_t -= dt
	if _ctx_t <= 0.0:
		_ctx_t = 0.5
		sv.carry = inv.weight()
		sv.carry_max = inv.capacity(sv)
		var ins := 0.0
		var wres := 0.0
		for s in inv.worn:
			var d := Items.def(inv.worn[s]["id"])
			ins += float(d.get("ins", 0.0)) * (0.5 + 0.5 * float(inv.worn[s].get("c", 1.0)))
			if s == "over" or s == "hat":
				wres = maxf(wres, float(d.get("water", 0.0)))
		_threat = G.zombies.threat_count(global_position) if G.zombies != null else 0
		var b = G.world.building_at(global_position) if G.world != null else null
		cur_building = b
		indoors = b != null
		Sfx.set_indoor(indoors)
		_stat_ctx = {"indoors": indoors, "temp": G.env.temperature() if G.env != null else 20.0, "insulation": minf(ins, 1.8),
			"rain": G.env.raining() if G.env != null else false, "water_res": wres, "zombies_near": _threat,
			"heat": G.world.heat_near(global_position) if G.world != null else false,
			"small_room": indoors}
		if light_on and inv.find_tag("lanterna") == null:
			set_light(false)
	sv.tick(dt * G.minutes_per_second() * G.time_mult, _stat_ctx)
	if sleeping:
		_sleep_tick()
	if god:
		sv.health = 100.0
		sv.endurance = 1.0
	if sv.dead and not dead_handled:
		_on_death()


func _process(dt: float) -> void:
	if not G.in_game:
		return
	_update_camera(dt)


# =====================================================================================
#  CAMERA
# =====================================================================================
func _update_camera(dt: float) -> void:
	var s: Dictionary = G.settings
	if not G.paused:
		var lk: Vector2 = G.look
		G.look = Vector2.ZERO
		yaw -= lk.x * 0.0052
		pitch -= lk.y * 0.0052 * (-1.0 if s["invert_y"] else 1.0)
		pitch = clampf(pitch, -1.25, 1.05)
	yaw = wrapf(yaw, -PI, PI)
	aim_w = move_toward(aim_w, 1.0 if (aiming and vehicle == null) else 0.0, dt * 6.0)
	var head_h := 1.56 - 0.30 * hum.crouch
	var want_dist := float(s["cam_dist"])
	var want_off := 0.32
	if indoors:
		want_dist = minf(want_dist, 2.5)
	if vehicle != null:
		want_dist = 7.5
		want_off = 0.0
		head_h = 2.1
	want_dist = lerpf(want_dist, 1.35, aim_w)
	want_off = lerpf(want_off, 0.52, aim_w) * shoulder
	if sleeping:
		want_dist = 4.5
	_dist = lerpf(_dist, want_dist, 1.0 - exp(-8.0 * dt))
	_off = lerpf(_off, want_off, 1.0 - exp(-8.0 * dt))
	var pivot := global_position + Vector3(0, head_h, 0)
	var sm := float(s["cam_smooth"])
	if sm > 0.01 and _cam_pos.distance_to(pivot) < 4.0:
		_cam_pos = _cam_pos.lerp(pivot, 1.0 - exp(-dt * (30.0 - 16.0 * clampf(sm, 0.0, 1.5))))
	else:
		_cam_pos = pivot
	# deslocamento de ombro com verificacao de obstaculo
	var rgt := Vector3(cos(yaw), 0, -sin(yaw))
	var off := _off
	if absf(off) > 0.02:
		var q := PhysicsRayQueryParameters3D.create(_cam_pos, _cam_pos + rgt * (off + signf(off) * 0.22), G.L_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var dd: float = _cam_pos.distance_to(hit["position"]) - 0.24
			off = signf(off) * maxf(0.0, dd)
	cam_rig.global_position = _cam_pos + rgt * off
	var rc := recoil
	recoil = move_toward(recoil, 0.0, dt * 0.6)
	arm.rotation = Vector3(pitch + rc, 0, 0)
	cam_rig.rotation = Vector3(0, yaw, 0)
	arm.spring_length = _dist
	var fov := float(s["cam_fov"]) - 14.0 * aim_w
	if sprinting and hum.speed > 4.5:
		fov += 4.0
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-8.0 * dt))
	# tremor
	if trauma > 0.001:
		var k := trauma * trauma * float(s["cam_shake"])
		cam.h_offset = randf_range(-1, 1) * 0.06 * k
		cam.v_offset = randf_range(-1, 1) * 0.06 * k
		trauma = maxf(0.0, trauma - dt * 1.8)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if flashlight.visible:
		flashlight.global_basis = Basis.from_euler(Vector3(clampf(pitch, -0.6, 0.5), yaw if (aiming or hum.speed < 0.3) else rotation.y, 0))
	# precisao exibida na mira
	if has_gun():
		spread_now = current_spread()
		_check_muzzle()


func cam_forward() -> Vector3:
	return -cam.global_basis.z


func toggle_shoulder() -> void:
	shoulder = -shoulder


func set_light(on: bool) -> void:
	if on and inv.find_tag("lanterna") == null:
		G.say("Você não tem uma lanterna.")
		on = false
	light_on = on
	flashlight.visible = on
	Sfx.ui("ui_click")


# =====================================================================================
#  PASSOS E RUIDO
# =====================================================================================
func _on_step(_foot: int) -> void:
	if vehicle != null or vaulting:
		return
	var surf: String = G.world.surface_at(global_position) if G.world != null else "grass"
	var rad := 4.5
	var vol := -9.0
	if crouching:
		rad = 1.6
		vol = -20.0
	elif hum.speed > 4.5:
		rad = 13.0
		vol = -4.0
	elif hum.speed > 2.5:
		rad = 8.0
		vol = -7.0
	if sv.has("gracioso"):
		rad *= 0.7
	if sv.has("desajeitado"):
		rad *= 1.3
	rad *= 1.0 - sv.level("pe_leve") * 0.05
	if not inv.worn.has("shoes"):
		rad *= 0.7
	Sfx.play3d("step_" + surf, global_position, vol, 1.0, 30.0)
	Sfx.noise(global_position, rad)
	if hum.speed > 4.5:
		sv.add_xp("corrida", 0.35)
		sv.add_xp("fitness", 0.12)
	elif crouching and _threat > 0:
		sv.add_xp("furtividade", 0.4)
		sv.add_xp("pe_leve", 0.3)


# =====================================================================================
#  ACOES COM DURACAO
# =====================================================================================
func busy() -> bool:
	return not action.is_empty() or not attack.is_empty() or vaulting or sleeping


func start_action(label: String, secs: float, anim: String, done: Callable, move_ok: bool = false) -> void:
	if not action.is_empty():
		cancel_action()
	secs *= 1.0 + sv.arm_penalty() * 0.8
	action = {"label": label, "t": 0.0, "dur": maxf(secs, 0.05), "anim": anim, "done": done, "move_ok": move_ok}
	hum.act = anim
	hum.act_t = 0.0


func cancel_action() -> void:
	if action.is_empty():
		return
	action = {}
	hum.act = ""
	if G.hud != null:
		G.hud.set_progress("", 0.0)


func _update_action(dt: float) -> void:
	if action.is_empty():
		return
	action["t"] = float(action["t"]) + dt * G.time_mult
	var f := float(action["t"]) / float(action["dur"])
	hum.act_t = fmod(f * 3.0, 1.0)
	if G.hud != null:
		G.hud.set_progress(action["label"], f)
	if f >= 1.0:
		var cb: Callable = action["done"]
		action = {}
		hum.act = ""
		if G.hud != null:
			G.hud.set_progress("", 0.0)
		if cb.is_valid():
			cb.call()


# =====================================================================================
#  COMBATE CORPO A CORPO
# =====================================================================================
func attack_pressed() -> void:
	if sv.dead or vehicle != null or vaulting or sleeping:
		return
	if not action.is_empty():
		cancel_action()
	if has_gun():
		fire_gun()
	else:
		melee()


func melee() -> void:
	if not attack.is_empty():
		return
	var d := weapon_def()
	var rng: float = float(d["rng"])
	var face := yaw
	var anim: String = d["anim"]
	# assistencia: vira para o zumbi mais proximo dentro do cone da camera
	var best = null
	var best_d := 99.0
	var assist := float(G.settings["aim_assist"])
	if G.zombies != null:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		for z in G.zombies.query(global_position, rng + 1.6):
			if z.dead:
				continue
			var to: Vector3 = z.global_position - global_position
			to.y = 0
			var dist := to.length()
			if dist < 0.05:
				continue
			var dot := to.normalized().dot(fwd)
			if dot < lerpf(0.9, 0.1, assist):
				continue
			if dist < best_d:
				best_d = dist
				best = z
	if best != null:
		var to2: Vector3 = best.global_position - global_position
		face = atan2(-to2.x, -to2.z)
		if best.is_down() and best_d < 1.5:
			anim = "stomp" if inv.primary == null else "swing_over"
	var dur: float = float(d["spd"])
	var sk := _weapon_skill(d)
	dur *= 1.0 - sv.level(sk) * 0.025 if sk != "" else 1.0
	dur *= 1.0 + sv.arm_penalty() * 0.6
	var weak := sv.endurance < 0.12
	if weak:
		dur *= 1.35
	if sv.fatigue > 0.8:
		dur *= 1.15
	attack = {"t": 0.0, "dur": dur, "hit": false, "d": d, "face": face, "anim": anim, "weak": weak, "ground": anim == "stomp" or (best != null and best.is_down())}
	hum.act = anim
	hum.act_t = 0.0
	Sfx.play3d("swing", global_position + Vector3(0, 1.2, 0), -8.0, 1.25 - float(d.get("w", 1.0)) * 0.08, 20.0)


func _weapon_skill(d: Dictionary) -> String:
	return Survivor.WT_SKILL.get(d.get("wt", ""), "")


func _update_attack(dt: float) -> void:
	if attack.is_empty():
		return
	attack["t"] = float(attack["t"]) + dt
	var f := float(attack["t"]) / float(attack["dur"])
	hum.act_t = f
	if not attack["hit"] and f >= 0.46:
		attack["hit"] = true
		_melee_hit()
	if f >= 1.0:
		attack = {}
		hum.act = ""


func _melee_hit() -> void:
	var d: Dictionary = attack["d"]
	var rng: float = float(d["rng"])
	var origin := global_position + Vector3(0, 1.25, 0)
	var fwd := -global_transform.basis.z
	var sk := _weapon_skill(d)
	var lvl := sv.level(sk) if sk != "" else 0
	var stab: bool = d["anim"] == "stab"
	var arc := 0.80 if stab else 0.35
	var cands: Array = []
	var space := get_world_3d().direct_space_state
	if G.zombies != null:
		for z in G.zombies.query(global_position, rng + 0.7):
			if z.dead:
				continue
			var to: Vector3 = z.global_position - global_position
			to.y = 0
			var dist := to.length()
			if dist > rng + 0.35:
				continue
			if dist > 0.25 and to.normalized().dot(fwd) < arc:
				continue
			# o golpe nao atravessa superficies solidas
			var q := PhysicsRayQueryParameters3D.create(origin, z.global_position + Vector3(0, 0.4 if z.is_down() else 1.2, 0), G.L_WORLD | G.L_GLASS)
			if not space.intersect_ray(q).is_empty():
				continue
			cands.append([dist, z])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var max_hits: int = int(d.get("hits", 1))
	var hit_any := false
	var n := 0
	for c in cands:
		if n >= max_hits:
			break
		var z = c[1]
		var dmg := randf_range(float(d["dmg"][0]), float(d["dmg"][1]))
		dmg *= 0.75 + sv.level("forca") * 0.05
		dmg *= 1.0 + lvl * 0.06
		if attack["weak"]:
			dmg *= 0.5
		if sv.fatigue > 0.8:
			dmg *= 0.75
		if sv.pain > 0.5:
			dmg *= 0.8
		if sv.panic > 0.55:
			dmg *= 0.85
		if n > 0:
			dmg *= 0.6
		if inv.primary != null and inv.primary.has("sh"):
			dmg *= 0.7 + 0.3 * float(inv.primary["sh"])
		var crit := randf() < float(d.get("crit", 0.05)) + lvl * 0.02
		if z.is_down():
			dmg *= 1.8
			crit = crit or randf() < 0.3
		elif not z.aware_of_player() and crouching:
			# ataque furtivo pelas costas
			crit = true
			dmg *= 1.5
		if crit:
			dmg *= 2.2
		var dirv: Vector3 = (z.global_position - global_position)
		dirv.y = 0
		z.take_hit(dmg, dirv.normalized(), float(d.get("kb", 0.5)) * (0.8 + sv.level("forca") * 0.04), crit, d["anim"] == "push")
		hit_any = true
		n += 1
		if sk != "":
			sv.add_xp(sk, 2.5 + dmg * 0.03)
		sv.add_xp("forca", 0.4)
	var hp := global_position + fwd * 0.9 + Vector3(0, 1.1, 0)
	if hit_any:
		var sharp: bool = d.has("sharp") or stab
		Sfx.play3d("hit_blade" if sharp else "hit_blunt", hp, -3.0, 1.0, 30.0)
		Sfx.noise(global_position, 7.0)
		trauma = minf(1.0, trauma + 0.25)
		_wear_weapon(d, lvl)
	else:
		# acertou parede, porta ou arvore?
		var q2 := PhysicsRayQueryParameters3D.create(origin, origin + fwd * (rng + 0.2), G.L_WORLD | G.L_GLASS)
		var h := space.intersect_ray(q2)
		if not h.is_empty():
			Sfx.play3d("hit_wood", h["position"], -6.0, 1.0, 30.0)
			Sfx.noise(global_position, 9.0)
			if G.world != null:
				G.world.melee_hit_world(h, d, self)
			_wear_weapon(d, lvl)
	var cost: float = float(d["sta"]) * (1.0 - lvl * 0.03)
	if sv.carry > sv.carry_max:
		cost *= 1.4
	sv.spend(cost)
	sv.muscle_strain = minf(1.0, sv.muscle_strain + 0.004)


func _wear_weapon(d: Dictionary, lvl: int) -> void:
	if inv.primary == null or int(d.get("brk", 0)) <= 0:
		return
	var it: Dictionary = inv.primary
	var ch := 1.0 / (float(d["brk"]) * (1.0 + sv.level("manutencao") * 0.25 + lvl * 0.08))
	if it.has("sh"):
		it["sh"] = maxf(0.0, float(it["sh"]) - 0.012)
	if randf() < ch:
		it["c"] = float(it.get("c", 1.0)) - 0.1
		sv.add_xp("manutencao", 2.0)
		if float(it["c"]) <= 0.001:
			G.say("%s quebrou!" % d["n"])
			Sfx.play3d("hit_metal", global_position, -3.0)
			if int(it.get("n", 1)) > 1:
				it["n"] = int(it["n"]) - 1
				it["c"] = 1.0
			else:
				inv.primary = null
			refresh_weapon()


# =====================================================================================
#  ARMAS DE FOGO
# =====================================================================================
func current_spread() -> float:
	if not has_gun():
		return 0.0
	var d := Items.def(inv.primary["id"])
	var s: float = float(d["spr"])
	var lvl := sv.level("mira")
	s *= 1.6 - lvl * 0.09
	s *= lerpf(2.6, 1.0, aim_focus) if aiming else 3.4
	s *= 1.0 + clampf(hum.speed / 3.0, 0.0, 1.0) * (1.4 - sv.level("agilidade") * 0.08)
	s *= 1.0 + sv.panic * 0.9 + sv.pain * 0.6 + sv.drunk * 0.8 + (1.0 - sv.endurance) * 0.5 + sv.arm_penalty()
	s *= 1.0 + (1.0 - float(inv.primary.get("c", 1.0))) * 0.6
	var light := G.daylight()
	if light < 0.3 and not light_on and not indoors:
		s *= 1.5 if not sv.has("coruja") else 1.2
	return s


func _muzzle_pos() -> Vector3:
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	return global_position + Vector3(0, 1.42 - 0.28 * hum.crouch, 0) + f * 0.55 + r * 0.14


func _check_muzzle() -> void:
	var from := global_position + Vector3(0, 1.4 - 0.28 * hum.crouch, 0)
	var q := PhysicsRayQueryParameters3D.create(from, _muzzle_pos() + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.25, G.L_WORLD)
	_muzzle_blocked = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func muzzle_blocked() -> bool:
	return _muzzle_blocked


func fire_gun() -> void:
	if fire_cd > 0.0 or not attack.is_empty():
		return
	var it: Dictionary = inv.primary
	var d := Items.def(it["id"])
	if it.get("jam", false):
		G.say("Arma travada: recarregue para destravar.")
		Sfx.play3d("gun_empty", global_position)
		fire_cd = 0.3
		return
	var rl: String = d["rl"]
	if rl == "cyl":
		if int(it["mag"]) <= 0:
			Sfx.play3d("gun_empty", global_position)
			G.say("Sem munição.")
			fire_cd = 0.3
			return
		it["mag"] = int(it["mag"]) - 1
	else:
		if int(it.get("ch", 0)) == 0:
			if int(it["mag"]) > 0:
				it["mag"] = int(it["mag"]) - 1
				it["ch"] = 1
				Sfx.play3d("rack", global_position, -4.0)
				fire_cd = 0.45
				return
			Sfx.play3d("gun_empty", global_position)
			G.say("Sem munição.")
			fire_cd = 0.3
			return
		it["ch"] = 0
		if int(it["mag"]) > 0:
			it["mag"] = int(it["mag"]) - 1
			it["ch"] = 1
	fire_cd = float(d["rof"]) * (1.0 - sv.level("recarga") * 0.02)
	var space := get_world_3d().direct_space_state
	var cam_from := cam.global_position
	var base_dir := cam_forward()
	var spread := deg_to_rad(current_spread())
	var pellets: int = int(d.get("pellets", 1))
	var muzzle := _muzzle_pos()
	var hits := 0
	for p in pellets:
		var dir := base_dir
		var sp := spread + (deg_to_rad(float(d["spr"])) * 0.6 if pellets > 1 else 0.0)
		dir = (dir + cam.global_basis.x * randfn(0.0, sp * 0.5) + cam.global_basis.y * randfn(0.0, sp * 0.5)).normalized()
		# 1) o que a camera aponta
		var far := cam_from + dir * (float(d["rng"]) + _dist + 2.0)
		var q := PhysicsRayQueryParameters3D.create(cam_from + dir * (_dist * 0.8), far, G.L_WORLD | G.L_ZOMBIE | G.L_GLASS)
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		var aim_pt: Vector3 = h["position"] if not h.is_empty() else far
		# 2) caminho real a partir do cano
		var mdir := (aim_pt - muzzle).normalized()
		var q2 := PhysicsRayQueryParameters3D.create(muzzle - mdir * 0.5, muzzle + mdir * float(d["rng"]), G.L_WORLD | G.L_ZOMBIE | G.L_GLASS)
		q2.exclude = [get_rid()]
		var guard := 0
		while guard < 3:
			guard += 1
			var h2 := space.intersect_ray(q2)
			if h2.is_empty():
				break
			var col = h2["collider"]
			if col is Zombie:
				var z: Zombie = col
				var rel_y: float = h2["position"].y - z.global_position.y
				var head := rel_y > 1.42 and not z.is_down()
				var dmg := randf_range(float(d["dmg"][0]), float(d["dmg"][1])) * (1.0 + sv.level("mira") * 0.03)
				var dist: float = muzzle.distance_to(h2["position"])
				dmg *= clampf(1.25 - dist / float(d["rng"]), 0.35, 1.0)
				if head:
					dmg *= 3.0
				z.take_hit(dmg, mdir, 0.6 if pellets == 1 else 0.9, head, false)
				hits += 1
				break
			if G.world != null and G.world.bullet_hit_world(h2):
				# vidro quebrado: o projetil continua
				q2 = PhysicsRayQueryParameters3D.create(h2["position"] + mdir * 0.1, muzzle + mdir * float(d["rng"]), G.L_WORLD | G.L_ZOMBIE | G.L_GLASS)
				q2.exclude = [get_rid()]
				continue
			break
	if hits > 0:
		sv.add_xp("mira", 3.0 * hits)
	Sfx.play3d(String(d["snd"]), muzzle, 4.0, 1.0, 400.0)
	Sfx.noise(global_position, float(d["noise"]) * (0.6 if indoors else 1.0))
	recoil += 0.03 + 0.012 * float(d["dmg"][1]) / 60.0
	trauma = minf(1.0, trauma + 0.3)
	aim_focus *= 0.45
	_muzzle_flash(muzzle)
	if rl == "bolt" or rl == "shell":
		Sfx.play3d("rack", global_position, -5.0)
	# desgaste e travamento
	if randf() < 1.0 / float(d.get("brk", 100)):
		it["c"] = maxf(0.0, float(it.get("c", 1.0)) - 0.05)
	if randf() < (1.0 - float(it.get("c", 1.0))) * 0.07:
		it["jam"] = true
		G.say("A arma travou!")


func _muzzle_flash(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.5)
	l.light_energy = 3.5
	l.omni_range = 7.0
	l.shadow_enabled = false
	get_parent().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.07)
	tw.tween_callback(l.queue_free)


func reload_pressed() -> void:
	if not has_gun() or busy():
		return
	var it: Dictionary = inv.primary
	var d := Items.def(it["id"])
	if it.get("jam", false):
		var unjam := func():
			it["jam"] = false
			Sfx.play3d("rack", global_position)
			G.say("Arma destravada.")
		start_action("Destravando arma", 1.4 - sv.level("recarga") * 0.08, "reload", unjam, true)
		return
	var cap: int = int(d["mag"])
	if int(it["mag"]) >= cap:
		G.say("Arma já carregada.")
		return
	var ammo: String = d["ammo"]
	if inv.count(ammo) <= 0:
		G.say("Sem %s." % Items.def(ammo)["n"])
		return
	var lvl := sv.level("recarga")
	if d["rl"] == "mag":
		var fill := func():
			var need := cap - int(it["mag"])
			var got := inv.remove(ammo, need)
			it["mag"] = int(it["mag"]) + got
			Sfx.play3d("reload_mag", global_position)
			sv.add_xp("recarga", 3.0)
			if int(it.get("ch", 0)) == 0 and int(it["mag"]) > 0:
				it["mag"] = int(it["mag"]) - 1
				it["ch"] = 1
		start_action("Recarregando", 2.3 - lvl * 0.12, "reload", fill, true)
	else:
		_reload_one(it, d, ammo, cap, lvl)


func _reload_one(it: Dictionary, d: Dictionary, ammo: String, cap: int, lvl: int) -> void:
	var one := func():
		if inv.remove(ammo, 1) == 1:
			it["mag"] = int(it["mag"]) + 1
			Sfx.play3d("reload_shell", global_position, -3.0)
			sv.add_xp("recarga", 1.0)
		if int(it["mag"]) < cap and inv.count(ammo) > 0 and inv.primary == it:
			_reload_one(it, d, ammo, cap, lvl)
		elif d["rl"] != "cyl" and int(it.get("ch", 0)) == 0 and int(it["mag"]) > 0:
			it["mag"] = int(it["mag"]) - 1
			it["ch"] = 1
			Sfx.play3d("rack", global_position, -4.0)
	start_action("Recarregando (%d/%d)" % [int(it["mag"]), cap], 0.62 - lvl * 0.03, "reload", one, true)


# =====================================================================================
#  DANO RECEBIDO
# =====================================================================================
func on_zombie_attack(z: Node3D, strength: int) -> void:
	if sv.dead or god:
		return
	var to: Vector3 = z.global_position - global_position
	to.y = 0
	var behind := to.normalized().dot(-global_transform.basis.z) < -0.2
	if vehicle != null:
		return
	var res := sv.zombie_hit(inv.worn, behind, strength)
	hum.flinch = 1.0
	slow_t = 0.5
	trauma = minf(1.0, trauma + 0.5)
	cancel_action()
	if sleeping:
		wake("Você foi atacado!")
	if res != "":
		G.say(res)
		Sfx.play3d("hurt", global_position, 0.0)
		if G.hud != null:
			G.hud.flash_damage()
		refresh_look()
	else:
		Sfx.play3d("hit_blunt", global_position, -8.0)


func hurt(amount: float, cause: String = "") -> void:
	if god:
		return
	sv.health -= amount
	trauma = minf(1.0, trauma + 0.4)
	if G.hud != null:
		G.hud.flash_damage()
	if sv.health <= 0.0:
		sv.dead = true
		sv.death_cause = cause


# =====================================================================================
#  INTERACAO
# =====================================================================================
func _scan() -> void:
	if vehicle != null or busy():
		if vehicle != null:
			target = {"kind": "veiculo_dentro", "obj": vehicle, "pos": global_position}
		return
	target = Interact.scan(self)


func interact_pressed() -> void:
	if sv.dead:
		return
	if sleeping:
		wake("")
		return
	if not action.is_empty():
		cancel_action()
		return
	if target.is_empty():
		return
	var acts := Interact.actions(self, target)
	for a in acts:
		if a.get("ok", true):
			Interact.run(self, target, a["id"])
			return
	if not acts.is_empty():
		G.say(String(acts[0].get("why", "Não é possível.")))


func interact_menu() -> void:
	if target.is_empty() or sv.dead:
		return
	var acts := Interact.actions(self, target)
	if G.ui != null and not acts.is_empty():
		G.ui.show_context(target, acts)


# =====================================================================================
#  DORMIR
# =====================================================================================
func sleep_start(quality: float) -> void:
	if _threat > 0:
		G.say("Perigo por perto: impossível dormir.")
		return
	if sv.fatigue < 0.3 and sv.sleep_pill <= 0.0:
		G.say("Você não está cansado o bastante para dormir.")
		return
	if sv.pain > 0.6 and sv.painkiller <= 0.0:
		G.say("A dor não deixa você dormir.")
		return
	sleeping = true
	sv.asleep = true
	sv.bed_quality = quality
	_sleep_start = G.time_min
	G.time_mult = 60.0
	hum.down = 1.0
	hum.down_back = true
	G.say("Dormindo... toque em Interagir para acordar.")


func _sleep_tick() -> void:
	var slept := (G.time_min - _sleep_start) / 60.0
	if G.zombies != null and G.zombies.danger_near(global_position, 9.0):
		wake("Um barulho acordou você!")
	elif sv.fatigue <= 0.01 and slept > 1.0:
		wake("Você acordou descansado.")
	elif slept > 12.0:
		wake("Você acordou.")
	elif sv.hunger > 0.9 or sv.thirst > 0.9:
		wake("Fome e sede acordaram você.")


func wake(msg: String) -> void:
	if not sleeping:
		return
	sleeping = false
	sv.asleep = false
	G.time_mult = 1.0
	hum.down = 0.0
	if msg != "":
		G.say(msg)


# =====================================================================================
#  MORTE
# =====================================================================================
func _on_death() -> void:
	dead_handled = true
	wake("")
	cancel_action()
	attack = {}
	hum.act = ""
	aiming = false
	G.time_mult = 1.0
	if vehicle != null:
		vehicle.exit_player(self)
	Sfx.play3d("zombie_death", global_position)
	if G.main != null:
		G.main.on_player_death()


func _dead_tick(dt: float) -> void:
	hum.down = minf(1.0, hum.down + dt * 1.6)
	hum.speed = 0.0
	hum.animate(dt)


# =====================================================================================
#  SALVAMENTO
# =====================================================================================
func to_dict() -> Dictionary:
	return {"pos": global_position, "rot": rotation.y, "yaw": yaw, "pitch": pitch, "sv": sv.to_dict(), "inv": inv.to_dict(),
		"crouch": crouching, "light": light_on, "shoulder": shoulder}


func from_dict(d: Dictionary) -> void:
	global_position = d.get("pos", global_position)
	rotation.y = d.get("rot", 0.0)
	yaw = d.get("yaw", 0.0)
	pitch = d.get("pitch", -0.2)
	sv.from_dict(d.get("sv", {}))
	inv.from_dict(d.get("inv", {}))
	crouching = d.get("crouch", false)
	shoulder = d.get("shoulder", 1.0)
	_cam_pos = global_position + Vector3(0, 1.55, 0)
	refresh_look()
	refresh_weapon()
	set_light(d.get("light", false) and inv.find_tag("lanterna") != null)
