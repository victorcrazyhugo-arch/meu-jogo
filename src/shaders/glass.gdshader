shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;
// Vidro de janelas e veiculos: reflete o gradiente do ceu, fica mais opaco em angulo rasante
// e ganha faixas de reflexo e poeira nos cantos. As cores do ceu vem do sistema de clima.
uniform vec3 sky_top = vec3(0.22, 0.42, 0.74);
uniform vec3 sky_hor = vec3(0.62, 0.73, 0.84);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL) * (FRONT_FACING ? 1.0 : -1.0);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec3 rw = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, n), 0.0)).xyz;
	vec3 sky = mix(sky_hor, sky_top, clamp(rw.y * 1.4 + 0.25, 0.0, 1.0));
	sky = mix(sky, sky_hor * 0.55, smoothstep(0.0, -0.35, rw.y));
	float d = wpos.x + wpos.z + wpos.y * 0.55 + rw.x * 0.8;
	float streak = smoothstep(0.80, 1.0, sin(d * 2.6) * 0.5 + 0.5) + 0.5 * smoothstep(0.90, 1.0, sin(d * 6.1 + 1.3) * 0.5 + 0.5);
	ALBEDO = mix(vec3(0.07, 0.11, 0.14), sky, 0.30 + 0.45 * fres);
	EMISSION = sky * (0.16 + 0.34 * fres + 0.10 * streak);
	ALPHA = clamp(0.46 + 0.42 * fres + 0.10 * streak, 0.0, 0.96);
	ROUGHNESS = 0.05;
	SPECULAR = 0.85;
}
