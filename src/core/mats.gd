class_name Mats
extends RefCounted
## Materiais compartilhados (criados uma unica vez na thread principal).

static var world: ShaderMaterial
static var foliage: ShaderMaterial
static var flat: ShaderMaterial
static var water: ShaderMaterial
static var chara: ShaderMaterial
static var glass: ShaderMaterial
static var glow: StandardMaterial3D
static var ghost_ok: StandardMaterial3D
static var ghost_bad: StandardMaterial3D
static var blood: StandardMaterial3D
static var noise: NoiseTexture2D
static var grass: ShaderMaterial
static var pool: StandardMaterial3D
static var ready := false


static func init() -> void:
	if ready:
		return
	ready = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.045
	fn.fractal_octaves = 4
	fn.seed = 1337
	noise = NoiseTexture2D.new()
	noise.width = 128
	noise.height = 128
	noise.seamless = true
	noise.generate_mipmaps = true
	noise.noise = fn
	var sh: Shader = load("res://src/shaders/world.gdshader")
	world = ShaderMaterial.new()
	world.shader = sh
	world.set_shader_parameter("noise_tex", noise)
	# folhagem: mesma logica, com recorte das folhas na silhueta das copas
	var sh3 := Shader.new()
	sh3.code = sh.code.replace("// @CUT ", "")
	foliage = ShaderMaterial.new()
	foliage.shader = sh3
	foliage.set_shader_parameter("noise_tex", noise)
	foliage.set_shader_parameter("sway", 1.0)
	foliage.set_shader_parameter("leafy", true)
	flat = ShaderMaterial.new()
	flat.shader = sh
	flat.set_shader_parameter("noise_tex", noise)
	flat.set_shader_parameter("detail", 0.35)
	flat.set_shader_parameter("gloss", 0.65)
	# grama: mesma logica, sem descarte de faces
	var sh2 := Shader.new()
	sh2.code = sh.code.replace("cull_back", "cull_disabled")
	grass = ShaderMaterial.new()
	grass.shader = sh2
	grass.set_shader_parameter("noise_tex", noise)
	grass.set_shader_parameter("sway", 2.2)
	grass.set_shader_parameter("detail", 0.4)
	grass.set_shader_parameter("blade", true)
	grass.set_shader_parameter("bump", 0.0)
	# poca de luz dos postes (aditiva)
	pool = StandardMaterial3D.new()
	pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool.vertex_color_use_as_albedo = true
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool.no_depth_test = false
	pool.disable_receive_shadows = true
	water = ShaderMaterial.new()
	water.shader = load("res://src/shaders/water.gdshader")
	water.set_shader_parameter("noise_tex", noise)
	chara = ShaderMaterial.new()
	chara.shader = load("res://src/shaders/chara.gdshader")
	chara.set_shader_parameter("noise_tex", noise)
	glass = ShaderMaterial.new()
	glass.shader = load("res://src/shaders/glass.gdshader")
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	ghost_ok = StandardMaterial3D.new()
	ghost_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_ok.albedo_color = Color(0.4, 1.0, 0.5, 0.45)
	ghost_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_bad = StandardMaterial3D.new()
	ghost_bad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_bad.albedo_color = Color(1.0, 0.3, 0.25, 0.45)
	ghost_bad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blood = StandardMaterial3D.new()
	blood.albedo_color = Color(0.32, 0.03, 0.03)
	blood.roughness = 0.5
