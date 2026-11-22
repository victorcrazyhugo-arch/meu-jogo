class_name Mats
extends RefCounted
## Materiais compartilhados (criados uma unica vez na thread principal).

static var world: ShaderMaterial
static var foliage: ShaderMaterial
static var flat: ShaderMaterial
static var water: ShaderMaterial
static var chara: StandardMaterial3D
static var glass: StandardMaterial3D
static var glow: StandardMaterial3D
static var ghost_ok: StandardMaterial3D
static var ghost_bad: StandardMaterial3D
static var blood: StandardMaterial3D
static var noise: NoiseTexture2D
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
	foliage = ShaderMaterial.new()
	foliage.shader = sh
	foliage.set_shader_parameter("noise_tex", noise)
	foliage.set_shader_parameter("sway", 1.0)
	flat = ShaderMaterial.new()
	flat.shader = sh
	flat.set_shader_parameter("noise_tex", noise)
	flat.set_shader_parameter("detail", 0.35)
	water = ShaderMaterial.new()
	water.shader = load("res://src/shaders/water.gdshader")
	water.set_shader_parameter("noise_tex", noise)
	chara = StandardMaterial3D.new()
	chara.vertex_color_use_as_albedo = true
	chara.vertex_color_is_srgb = true
	chara.roughness = 0.9
	chara.metallic_specular = 0.15
	glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.62, 0.78, 0.86, 0.28)
	glass.roughness = 0.08
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
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
