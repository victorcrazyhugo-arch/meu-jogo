extends Node
## G - estado global: configuracoes do aparelho, regras de sandbox, relogio e referencias.

const VERSION := "0.1.2"
const SAVE_VERSION := 1
const MIN_PER_DAY := 1440.0
const START_HOUR := 9.0
const MONTHS := ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# Camadas de colisao
const L_WORLD := 1      # paredes, moveis, arvores, chao: bloqueia movimento, visao, tiros e camera
const L_PLAYER := 2
const L_ZOMBIE := 4
const L_VEHICLE := 8
const L_GLASS := 16     # vidro e cercas baixas: bloqueia movimento, nao a visao

signal toast(msg: String)
signal settings_changed
signal sandbox_changed

const SETTINGS_DEFAULT := {
	"cam_sens": 1.0, "cam_dist": 3.4, "cam_fov": 68.0, "cam_shake": 1.0, "cam_smooth": 1.0, "invert_y": false,
	"left_handed": false, "hud_scale": 1.0, "aim_assist": 0.5, "graphics": 1, "dyn_res": true,
	"vol_master": 1.0, "vol_sfx": 1.0, "vol_music": 0.5, "vol_amb": 0.8, "music_on": true,
	"autosave_min": 5, "show_fps": false, "sprint_toggle": true,
}
const SANDBOX_DEFAULT := {
	"preset": "Sobrevivente",
	"zombie_pop": 1.0, "zombie_speed": 1, "zombie_strength": 1, "zombie_tough": 1,
	"zombie_sight": 1, "zombie_hearing": 1, "zombie_memory": 1, "respawn_hours": 72,
	"infection": 0, "infection_days": 2.5, "wound_severity": 1.0,
	"loot": 1.0, "day_minutes": 60, "start_month": 3,
	"water_off_day": 12, "power_off_day": 9,
	"xp_mult": 1.0, "car_spawn": 1.0, "fuel": 1.0, "rain": 1.0, "food_spoil": 1.0, "crop_speed": 1.0,
	"permadeath": true, "tutorial": true,
}
const SANDBOX_PRESETS := {
	"Sobrevivente": {},
	"Aprendiz": {"zombie_pop": 0.5, "zombie_speed": 0, "zombie_strength": 0, "zombie_tough": 0, "loot": 1.6, "infection": 1, "xp_mult": 1.5, "water_off_day": 30, "power_off_day": 30, "respawn_hours": 0},
	"Brutal": {"zombie_pop": 2.0, "zombie_speed": 1, "zombie_strength": 2, "zombie_tough": 2, "zombie_sight": 2, "zombie_hearing": 2, "loot": 0.6, "water_off_day": 3, "power_off_day": 2, "respawn_hours": 36},
	"Construtor": {"zombie_pop": 0.35, "loot": 1.3, "xp_mult": 2.0, "respawn_hours": 0, "crop_speed": 1.5},
	"Seis meses depois": {"zombie_pop": 1.5, "loot": 0.45, "water_off_day": 0, "power_off_day": 0, "start_month": 9, "car_spawn": 0.6, "fuel": 0.5},
}

var settings: Dictionary = SETTINGS_DEFAULT.duplicate(true)
var sandbox: Dictionary = SANDBOX_DEFAULT.duplicate(true)

var world_seed: int = 1
var world_name: String = "Mundo 1"
var slot: String = "mundo1"
var time_min: float = START_HOUR * 60.0      # minutos desde 00:00 do dia 1
var time_mult: float = 1.0                   # aceleracao (dormir/esperar)
var play_seconds: float = 0.0
var in_game := false
var paused := false

# Referencias vivas (preenchidas por main.gd / game_scene)
var main: Node = null
var world: Node3D = null
var player: Node3D = null
var zombies: Node = null
var env: Node = null
var hud: Control = null
var ui: Node = null
var vehicles: Node = null

var rng := RandomNumberGenerator.new()

# Entrada unificada (toque, controle fisico e teclado), preenchida pelo HUD
var mv := Vector2.ZERO          # x = direita, y = frente
var look := Vector2.ZERO        # delta de camera acumulado no quadro
var held := {}                  # botoes mantidos pressionados


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	load_settings()


func _process(delta: float) -> void:
	if in_game and not paused:
		time_min += delta * minutes_per_second() * time_mult
		play_seconds += delta


func minutes_per_second() -> float:
	return MIN_PER_DAY / (float(sandbox.get("day_minutes", 60)) * 60.0)


func day() -> int:
	return int(time_min / MIN_PER_DAY)


func hour() -> float:
	return fmod(time_min, MIN_PER_DAY) / 60.0


func hours_total() -> float:
	return time_min / 60.0


## Data do calendario: [dia_do_mes, indice_do_mes, ano_relativo]
func date() -> Array:
	var d := day()
	var m := int(sandbox.get("start_month", 3)) - 1
	var y := 0
	while d >= MONTH_DAYS[m]:
		d -= MONTH_DAYS[m]
		m += 1
		if m > 11:
			m = 0
			y += 1
	return [d + 1, m, y]


## Fracao do ano 0..1 (0 = 1 de janeiro). Hemisferio sul: janeiro e verao.
func year_frac() -> float:
	var dt := date()
	var acc := 0
	for i in dt[1]:
		acc += MONTH_DAYS[i]
	return float(acc + dt[0]) / 365.0


func season_name() -> String:
	var m: int = date()[1]
	if m == 11 or m <= 1:
		return "verão"
	if m <= 4:
		return "outono"
	if m <= 7:
		return "inverno"
	return "primavera"


func fmt_clock() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


func fmt_date() -> String:
	var dt := date()
	return "%d de %s" % [dt[0], MONTHS[dt[1]]]


func fmt_survived() -> String:
	var mins := time_min - START_HOUR * 60.0
	var d := int(mins / MIN_PER_DAY)
	var h := int(fmod(mins, MIN_PER_DAY) / 60.0)
	if d >= 30:
		return "%d meses, %d dias" % [d / 30, d % 30]
	return "%d dias, %d horas" % [d, h]


func is_night() -> bool:
	var h := hour()
	return h < 5.5 or h > 19.5


## Luz ambiente 0 (noite fechada) .. 1 (dia claro)
func daylight() -> float:
	var h := hour()
	if h < 4.5 or h > 20.5:
		return 0.0
	if h < 7.0:
		return (h - 4.5) / 2.5
	if h > 18.0:
		return (20.5 - h) / 2.5
	return 1.0


func power_on() -> bool:
	return day() < int(sandbox.get("power_off_day", 9))


func water_on() -> bool:
	return day() < int(sandbox.get("water_off_day", 12))


func say(msg: String) -> void:
	toast.emit(msg)


func apply_preset(pname: String) -> void:
	sandbox = SANDBOX_DEFAULT.duplicate(true)
	var p: Dictionary = SANDBOX_PRESETS.get(pname, {})
	for k in p:
		sandbox[k] = p[k]
	sandbox["preset"] = pname
	sandbox_changed.emit()


# ---------------------------------------------------------------- configuracoes do aparelho
func load_settings() -> void:
	if not FileAccess.file_exists("user://config.dat"):
		return
	var f := FileAccess.open("user://config.dat", FileAccess.READ)
	if f == null:
		return
	var d = f.get_var()
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			if settings.has(k):
				settings[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open("user://config.dat", FileAccess.WRITE)
	if f:
		f.store_var(settings)
		f.close()
	settings_changed.emit()


# ---------------------------------------------------------------- utilidades
static func hash2(x: int, z: int, s: int = 0) -> int:
	var h: int = (x * 73856093) ^ (z * 19349663) ^ (s * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


static func frand(x: int, z: int, s: int = 0) -> float:
	return float(hash2(x, z, s) % 100000) / 100000.0


static func clampf01(v: float) -> float:
	return clampf(v, 0.0, 1.0)
