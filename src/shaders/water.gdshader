shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, depth_draw_opaque;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.07, 0.16, 0.19);
uniform vec3 shallow : source_color = vec3(0.16, 0.30, 0.30);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.05 + vec2(TIME * 0.012, TIME * 0.035)).r;
	float n2 = texture(noise_tex, wpos.xz * 0.13 - vec2(TIME * 0.02, -TIME * 0.05)).r;
	float k = n1 * 0.6 + n2 * 0.4;
	ALBEDO = mix(deep, shallow, k);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = 0.9;
}
