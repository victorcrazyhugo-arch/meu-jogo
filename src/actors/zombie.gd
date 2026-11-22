class_name Zombie
extends CharacterBody3D
## Zumbi: visao, audicao, memoria do alvo, investigacao de sons, perseguicao com busca de
## caminho, pressao sobre portas/janelas/barricadas, ataques, quedas e reacoes a golpes.

enum { IDLE, WANDER, INVESTIGATE, CHASE, ATTACK, STAGGER, DOWN, THUMP, CLIMB, DEAD }

var state := IDLE
var hum: Humanoid
var hp := 100.0
var dead := false
var look: Dictionary = {}
var profile := "civil"
var seed_v := 0
var speed_walk := 0.75
var speed_chase := 2.0
var strength := 1
var target_pos := Vector3.ZERO
var memory := 0.0
var sees := false
var los := false
var path := PackedVector2Array()
var path_i := 0
var repath_t := 0.0
var think_t := 0.0
var state_t := 0.0
var cd := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var wander_to := Vector3.ZERO
var thump_target: Array = []
var climb_a := Vector3.ZERO
var climb_b := Vector3.ZERO
var groan_t := 0.0
var sep := Vector3.ZERO
var dist_p := 999.0
var hit_done := false
var down_time := 0.0
var alerted := false
var corpse_done := false
var floor_i := 0
var _fi := 0
var _skip_acc := 0.0
var _every := 1


func setup(v: Dictionary) -> void:
	seed_v = int(v["s"])
	profile = String(v.get("pf", "civil"))
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	look = Clothes.zombie_look(r, profile)
	var sb: Dictionary = G.sandbox
	var tough: float = [0.7, 1.0, 1.4][clampi(int(sb["zombie_tough"]), 0, 2)]
	hp = float(v.get("hp", 100.0 * tough * r.randf_range(0.8, 1.2)))
	var sp: float = [1.15, 2.05, 4.5][clampi(int(sb["zombie_speed"]), 0, 2)]
	speed_chase = sp * r.randf_range(0.85, 1.15)
	speed_walk = minf(0.75 * r.randf_range(0.8, 1.2), speed_chase)
	strength = clampi(int(sb["zombie_strength"]), 0, 2)
	groan_t = r.randf_range(2.0, 14.0)
	think_t = r.randf() * 0.3


func _ready() -> void:
	collision_layer = G.L_ZOMBIE
	collision_mask = G.L_WORLD | G.L_GLASS | G.L_VEHICLE | G.L_PLAYER
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	hum = Humanoid.new()
	add_child(hum)
	hum.set_look(look)
	last_pos = global_position


func is_down() -> bool:
	return state == DOWN


func aware_of_player() -> bool:
	return state == CHASE or state == ATTACK or sees


func to_virtual() -> Dictionary:
	return {"p": global_position, "hp": hp, "s": seed_v, "pf": profile}


# =====================================================================================
#  PERCEPCAO
# =====================================================================================
func _think() -> void:
	var p: Node3D = G.player
	sees = false
	los = false
	if p == null or not is_instance_valid(p) or p.sv.dead:
		return
	var to: Vector3 = p.global_position - global_position
	dist_p = to.length()
	floor_i = int(floor((global_position.y + 0.6) / BPlan.FH))
	var sb: Dictionary = G.sandbox
	var rng_sight: float = [13.0, 21.0, 31.0][clampi(int(sb["zombie_sight"]), 0, 2)]
	var light: float = G.env.light_level() if G.env != null else 1.0
	if p.indoors and not G.power_on():
		light *= 0.6
	rng_sight *= lerpf(0.36, 1.0, light)
	if p.light_on and light < 0.5:
		rng_sight *= 1.5
	if p.crouching:
		rng_sight *= 0.55 - p.sv.level("furtividade") * 0.025
	if p.sv.has("discreto"):
		rng_sight *= 0.8
	if p.sv.has("chamativo"):
		rng_sight *= 1.25
	if p.vehicle != null:
		rng_sight *= 1.3
	if dist_p < maxf(rng_sight, 30.0) + 6.0:
		var from := global_position + Vector3(0, 1.5 if state != DOWN else 0.4, 0)
		var q := PhysicsRayQueryParameters3D.create(from, p.global_position + Vector3(0, 1.25 - 0.3 * p.hum.crouch, 0), G.L_WORLD)
		los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if dist_p < rng_sight and los:
		var fwd := -global_transform.basis.z
		var d2 := Vector3(to.x, 0, to.z).normalized()
		# campo de visao amplo a frente; atras so percebe de muito perto
		if d2.dot(fwd) > -0.25 or dist_p < 2.2 or state == CHASE:
			sees = true
	if dist_p < 1.3 and absf(to.y) < 1.5:
		sees = true
	var mem_t: float = [7.0, 15.0, 32.0][clampi(int(sb["zombie_memory"]), 0, 2)]
	if sees:
		target_pos = p.global_position
		memory = mem_t
		if state == IDLE or state == WANDER or state == INVESTIGATE:
			_set_state(CHASE)
			if not alerted:
				alerted = true
				Sfx.play3d("zombie_growl", global_position + Vector3(0, 1.5, 0), -2.0, 1.0, 45.0)
				G.zombies.alert_group(self)
	# visibilidade: a camera nao revela o que o personagem nao pode ver
	var vis_now := los or dist_p < 2.5
	if vis_now != visible:
		visible = vis_now
	hum.lod_skip = 0 if dist_p < 26.0 else 2


func hear(pos: Vector3, strength_f: float) -> void:
	if dead or sees or state == ATTACK or state == DOWN or state == CLIMB:
		return
	if state == CHASE and memory > 4.0:
		return
	target_pos = pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)) * (1.0 + (1.0 - strength_f) * 2.0)
	memory = 18.0
	path = PackedVector2Array()
	repath_t = 0.0
	if state != CHASE and state != STAGGER and state != THUMP:
		_set_state(INVESTIGATE)


func alert(pos: Vector3) -> void:
	if dead or sees or state == DOWN or state == ATTACK:
		return
	target_pos = pos
	memory = 12.0
	if state == IDLE or state == WANDER or state == INVESTIGATE:
		_set_state(CHASE)


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0
	if s == CHASE or s == INVESTIGATE:
		repath_t = 0.0


# =====================================================================================
#  QUADRO A QUADRO
# =====================================================================================
func _physics_process(dt: float) -> void:
	if G.paused or not G.in_game:
		return
	if dead:
		_dead_tick(dt)
		return
	# zumbis distantes seguem as mesmas regras com passo de tempo maior (menos custo de CPU);
	# perto do jogador, inclusive fora da camera, a atualizacao e completa
	_fi += 1
	_every = 1
	if state != ATTACK and state != CLIMB and state != DOWN:
		if dist_p > 46.0:
			_every = 4
		elif dist_p > 22.0:
			_every = 2
	if _every > 1:
		_skip_acc += dt
		if (_fi + seed_v) % _every != 0:
			return
		dt = _skip_acc
	_skip_acc = 0.0
	state_t += dt
	cd = maxf(0.0, cd - dt)
	think_t -= dt
	if think_t <= 0.0:
		think_t = 0.28 if dist_p < 30.0 else 0.6
		_think()
	if not sees and memory > 0.0:
		memory -= dt
	var want := Vector3.ZERO
	var spd := 0.0
	hum.reach = move_toward(hum.reach, 1.0 if (state == CHASE or state == ATTACK or state == THUMP) else 0.0, dt * 2.5)
	match state:
		IDLE:
			if state_t > 3.0 and randf() < dt * 0.25:
				wander_to = global_position + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
				_set_state(WANDER)
		WANDER:
			var tw := wander_to - global_position
			tw.y = 0
			if tw.length() < 0.6 or state_t > 9.0:
				_set_state(IDLE)
			else:
				want = tw.normalized()
				spd = speed_walk
		INVESTIGATE, CHASE:
			var tt := target_pos - global_position
			var flat := Vector3(tt.x, 0, tt.z)
			if state == CHASE and sees and flat.length() < 1.0 and absf(tt.y) < 1.2 and cd <= 0.0:
				_set_state(ATTACK)
				hit_done = false
				hum.act = "lunge"
				Sfx.play3d("zombie_attack", global_position + Vector3(0, 1.5, 0), -3.0, 1.0, 30.0)
			elif memory <= 0.0 or (not sees and flat.length() < 1.2 and absf(tt.y) < 1.5):
				alerted = false
				_set_state(IDLE)
			else:
				want = _steer(flat, dt)
				spd = speed_chase if state == CHASE else minf(speed_chase, speed_walk * 1.5)
		ATTACK:
			var tp: Vector3 = G.player.global_position - global_position
			tp.y = 0
			if tp.length() > 0.1:
				_face(tp.normalized(), dt, 10.0)
			hum.act_t = state_t / 0.75
			if not hit_done and state_t >= 0.36:
				hit_done = true
				var p: Node3D = G.player
				var d3: Vector3 = p.global_position - global_position
				if Vector2(d3.x, d3.z).length() < 1.3 and absf(d3.y) < 1.3 and not p.sv.dead:
					if p.vehicle != null:
						p.vehicle.zombie_hit(self)
					else:
						p.on_zombie_attack(self, strength)
			if state_t >= 0.75:
				hum.act = ""
				cd = 0.45
				_set_state(CHASE)
		STAGGER:
			if state_t >= 0.5:
				_set_state(CHASE if memory > 0.0 else IDLE)
		DOWN:
			hum.down = minf(1.0, hum.down + dt * 3.5)
			if state_t >= down_time:
				hum.down = maxf(0.0, hum.down - dt * 6.0)
				if hum.down <= 0.02:
					hum.down = 0.0
					_set_state(CHASE if memory > 0.0 else IDLE)
		THUMP:
			_thump_tick(dt)
		CLIMB:
			var f := clampf(state_t / 1.7, 0.0, 1.0)
			global_position = climb_a.lerp(climb_b, f) + Vector3(0, sin(f * PI) * 0.95, 0)
			hum.act = "vault"
			hum.act_t = f
			if f >= 1.0:
				hum.act = ""
				path = PackedVector2Array()
				repath_t = 0.0
				_set_state(CHASE if memory > 0.0 else INVESTIGATE)
	if state == CLIMB:
		hum.speed = 0.0
		if visible:
			hum.animate(dt)
		return
	# movimento
	var tv := want * spd + sep
	sep = sep.lerp(Vector3.ZERO, dt * 6.0)
	velocity.x = move_toward(velocity.x, tv.x, 9.0 * dt)
	velocity.z = move_toward(velocity.z, tv.z, 9.0 * dt)
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	else:
		velocity.y = -0.5
	if _every > 1:
		velocity = Vector3(velocity.x * _every, velocity.y, velocity.z * _every)
		move_and_slide()
		velocity = Vector3(velocity.x / _every, velocity.y, velocity.z / _every)
	else:
		move_and_slide()
	if want.length() > 0.1:
		_face(want, dt, 6.0)
		# deteccao de bloqueio
		var moved := Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
		if moved < spd * dt * 0.25:
			stuck_t += dt
		else:
			stuck_t = maxf(0.0, stuck_t - dt * 2.0)
		if stuck_t > 0.55:
			_on_stuck()
	last_pos = global_position
	hum.speed = Vector2(velocity.x, velocity.z).length()
	if visible:
		hum.animate(dt)
	groan_t -= dt
	if groan_t <= 0.0:
		groan_t = randf_range(7.0, 22.0)
		if dist_p < 34.0:
			Sfx.play3d("zombie_groan", global_position + Vector3(0, 1.5, 0), -9.0 if state != CHASE else -4.0, randf_range(0.85, 1.1), 34.0)


func _face(dir: Vector3, dt: float, rate: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * dt))


## Direcao de deslocamento ate o alvo: direta quando ha visao, senao por caminho.
func _steer(flat: Vector3, dt: float) -> Vector3:
	var dist := flat.length()
	if (sees and los) or dist < 1.6:
		path = PackedVector2Array()
		return flat.normalized()
	repath_t -= dt
	if repath_t <= 0.0 or path.is_empty():
		repath_t = randf_range(0.9, 1.6)
		if absf(target_pos.y - global_position.y) < 1.5 and floor_i == 0 and G.zombies.path_budget():
			path = G.world.find_path(global_position, target_pos)
			path_i = 1 if path.size() > 1 else 0
		else:
			path = PackedVector2Array()
	if path.is_empty() or path_i >= path.size():
		return flat.normalized()
	var wp: Vector2 = path[path_i]
	var to := Vector3(wp.x - global_position.x, 0, wp.y - global_position.z)
	if to.length() < 0.45:
		path_i += 1
		if path_i >= path.size():
			return flat.normalized()
		wp = path[path_i]
		to = Vector3(wp.x - global_position.x, 0, wp.y - global_position.z)
	# porta ou janela no proximo passo?
	var cell := Vector2i(floori(wp.x), floori(wp.y))
	var spc = G.world.nav_special.get(cell, null)
	if spc != null and to.length() < 1.15:
		var b: Building = spc[1]
		if is_instance_valid(b):
			if spc[0] == "porta" and b.door_blocks(spc[2]):
				thump_target = spc
				_set_state(THUMP)
				return Vector3.ZERO
			if spc[0] == "janela":
				if b.win_passable(spc[2]):
					_start_climb(b, spc[2])
				else:
					thump_target = spc
					_set_state(THUMP)
				return Vector3.ZERO
	return to.normalized()


func _start_climb(b: Building, wi: int) -> void:
	var wp := b.win_world_pos(wi)
	var dir := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z).normalized()
	# eixo perpendicular a parede
	var wn: Dictionary = b.plan.windows[wi]
	var nloc := Vector3(0, 0, 1) if wn["h"] else Vector3(1, 0, 0)
	var nw := (b.global_transform.basis * nloc).normalized()
	if nw.dot(dir) < 0.0:
		nw = -nw
	climb_a = Vector3(wp.x, b.global_position.y + wn["f"] * BPlan.FH, wp.z) - nw * 0.85
	climb_b = Vector3(wp.x, b.global_position.y + wn["f"] * BPlan.FH, wp.z) + nw * 0.95
	velocity = Vector3.ZERO
	_set_state(CLIMB)
	rotation.y = atan2(-nw.x, -nw.z)


func _thump_tick(dt: float) -> void:
	if thump_target.is_empty() or not is_instance_valid(thump_target[1]):
		_set_state(CHASE if memory > 0.0 else IDLE)
		return
	var b: Building = thump_target[1]
	var i: int = thump_target[2]
	var is_door: bool = thump_target[0] == "porta"
	var pos := b.door_world_pos(i) if is_door else b.win_world_pos(i)
	var to := Vector3(pos.x - global_position.x, 0, pos.z - global_position.z)
	if to.length() > 0.1:
		_face(to.normalized(), dt, 8.0)
	if (is_door and not b.door_blocks(i)) or (not is_door and b.win_passable(i)):
		if not is_door:
			_start_climb(b, i)
		else:
			path = PackedVector2Array()
			_set_state(CHASE if memory > 0.0 else INVESTIGATE)
		return
	if memory <= 0.0 and state_t > 6.0:
		_set_state(IDLE)
		return
	if cd <= 0.0:
		cd = randf_range(0.8, 1.3)
		hum.act = "lunge"
		hum.act_t = 0.0
		var dmg: float = [6.0, 10.0, 16.0][strength] * randf_range(0.7, 1.3)
		if is_door:
			b.damage_door(i, dmg)
			Sfx.play3d("zombie_thump", pos, -2.0, 1.0, 40.0)
			Sfx.noise(pos, 9.0)
		else:
			b.damage_window(i, dmg)
			Sfx.play3d("zombie_thump", pos, -4.0, 1.2, 40.0)
	hum.act_t = minf(1.0, hum.act_t + dt * 2.2)
	if hum.act_t >= 1.0:
		hum.act = ""


func _on_stuck() -> void:
	stuck_t = 0.0
	# algo bloqueia: tenta pressionar porta/janela/estrutura a frente; senao desvia
	var ahead := global_position - global_transform.basis.z * 0.8
	var cell := Vector2i(floori(ahead.x), floori(ahead.z))
	var spc = G.world.nav_special.get(cell, null)
	if spc == null:
		spc = G.world.nav_special.get(Vector2i(floori(global_position.x), floori(global_position.z)), null)
	if spc != null and is_instance_valid(spc[1]) and (state == CHASE or state == INVESTIGATE):
		var b: Building = spc[1]
		if (spc[0] == "porta" and b.door_blocks(spc[2])) or (spc[0] == "janela" and not b.win_passable(spc[2])):
			thump_target = spc
			_set_state(THUMP)
			return
		if spc[0] == "janela" and b.win_passable(spc[2]):
			_start_climb(b, spc[2])
			return
	if (state == CHASE or state == INVESTIGATE) and Base.zombie_thump(G.world, self):
		cd = 1.0
		return
	var side := global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
	sep += side * 2.4
	path = PackedVector2Array()
	repath_t = 0.0
	if state == WANDER:
		_set_state(IDLE)


# =====================================================================================
#  DANO
# =====================================================================================
func take_hit(dmg: float, dir: Vector3, kb: float, crit: bool, push: bool) -> void:
	if dead:
		return
	hp -= dmg
	hum.flinch = 1.0
	memory = maxf(memory, 12.0)
	if G.player != null:
		target_pos = G.player.global_position
	visible = true
	if hp <= 0.0:
		_die(dir)
		return
	velocity += dir * kb * 3.2
	var down_ch := 0.08 + kb * 0.12
	if push:
		down_ch = 0.22 + kb * 0.1
	if crit:
		down_ch += 0.4
	if state == DOWN:
		return
	if randf() < down_ch:
		state = DOWN
		state_t = 0.0
		down_time = randf_range(2.2, 4.0)
		hum.down_back = true
		hum.act = ""
	else:
		state = STAGGER
		state_t = 0.0
		hum.act = ""


func _die(dir: Vector3) -> void:
	dead = true
	state = DEAD
	state_t = 0.0
	hum.act = ""
	hum.down_back = dir.dot(-global_transform.basis.z) < 0.0
	collision_layer = 0
	collision_mask = G.L_WORLD
	Sfx.play3d("zombie_death", global_position + Vector3(0, 1.2, 0), -2.0, 1.0, 40.0)
	if G.player != null:
		G.player.sv.kills += 1
	G.zombies.on_death(self)


func _dead_tick(dt: float) -> void:
	state_t += dt
	hum.down = minf(1.0, hum.down + dt * 3.0)
	hum.speed = 0.0
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * dt)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * dt)
	move_and_slide()
	hum.animate(dt)
	if state_t > 1.2 and not corpse_done:
		corpse_done = true
		var items := Items.roll_loot("zumbi", seed_v)
		var extra := {"policia": "zumbi_policia", "saude": "zumbi_medico", "obra": "zumbi_obra"}
		if extra.has(profile):
			items.append_array(Items.roll_loot(extra[profile], seed_v + 1))
		# parte das roupas pode ser recuperada do cadaver
		for wid in look.get("worn_ids", []):
			if randf() < 0.35:
				var it := Items.make(wid)
				it["c"] = randf_range(0.2, 0.7)
				it["dirt"] = 1.0
				it["bl"] = randf_range(0.3, 1.0)
				items.append(it)
		var lk := look.duplicate()
		G.world.add_corpse(global_position, rotation.y, lk, items)
		queue_free()
