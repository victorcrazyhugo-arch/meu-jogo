shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
// Material unico do cenario: cor por vertice + ruido procedural em espaco de mundo (textura propria gerada em tempo de execucao).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float sway = 0.0;
uniform float detail = 1.0;
varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sway > 0.0) {
		float k = clamp(VERTEX.y * 0.22, 0.0, 1.5) * sway * COLOR.a;
		VERTEX.x += sin(TIME * 1.1 + wp.x * 0.35 + wp.z * 0.21) * 0.07 * k;
		VERTEX.z += cos(TIME * 0.9 + wp.x * 0.27 - wp.z * 0.31) * 0.05 * k;
	}
	wpos = wp;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnor);
	vec2 uv = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float n1 = texture(noise_tex, uv * 0.27).r;
	float n2 = texture(noise_tex, uv * 0.033 + vec2(0.37, 0.11)).r;
	// no renderizador Compatibility a cor do vertice ja chega convertida para o espaco linear
	vec3 col = COLOR.rgb;
	float m = mix(1.0, (0.91 + 0.15 * n1) * (0.94 + 0.10 * n2), detail);
	ALBEDO = col * m;
	ROUGHNESS = 0.95;
}
