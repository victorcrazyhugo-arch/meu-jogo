shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
// Personagens: cor por vertice; o alfa separa pele (0.2), cabelo (0.4) e tecido (demais).
// Os padroes ficam presos a pose de repouso (UV/UV2) para nao escorregar na animacao.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 rp;

void vertex() {
	rp = vec3(UV.x, UV.y, UV2.x);
}

void fragment() {
	float n1 = texture(noise_tex, rp.xy * 5.0 + rp.z * 2.3).r;
	float n2 = texture(noise_tex, rp.zy * 1.6 + rp.x * 0.7).r;
	float n3 = texture(noise_tex, vec2(rp.x + rp.z, rp.y) * 14.0).r;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.0);
	vec3 col = COLOR.rgb;
	float hgt = 0.0;
	float bk = 0.004;
	if (COLOR.a < 0.3) {
		// pele: lisa, com leve variacao de tom e calor nas bordas
		col *= (0.95 + 0.07 * n2) * (0.98 + 0.03 * n3);
		col = mix(col, col * vec3(1.10, 0.90, 0.86), rim * 0.5);
		ROUGHNESS = 0.58;
		SPECULAR = 0.30;
		EMISSION = col * vec3(1.0, 0.72, 0.62) * rim * 0.20;
		hgt = n3;
		bk = 0.0012;
	} else if (COLOR.a < 0.5) {
		// cabelo: fios ao longo do comprimento e brilho em faixa
		float strand = texture(noise_tex, vec2((rp.x + rp.z * 0.7) * 26.0, rp.y * 1.3)).r;
		float strand2 = texture(noise_tex, vec2((rp.x - rp.z) * 55.0, rp.y * 2.1 + 0.4)).r;
		col = (col * 0.85 + vec3(0.040, 0.035, 0.032)) * (0.50 + 0.85 * strand) * (0.82 + 0.36 * strand2);
		float band = smoothstep(0.55, 0.95, ndv) * smoothstep(0.35, 0.7, strand);
		ROUGHNESS = 0.42;
		SPECULAR = 0.45;
		EMISSION = (col * 0.9 + vec3(0.05, 0.045, 0.04)) * (rim * 0.55 + band * 0.10);
		hgt = strand * 0.7 + strand2 * 0.3;
		bk = 0.010;
	} else {
		// tecido: trama fina, dobras suaves e desgaste
		float weave = sin(rp.x * 520.0 + rp.z * 380.0) * sin(rp.y * 520.0);
		col *= (0.86 + 0.20 * n1) * (0.90 + 0.16 * n2) * (0.95 + 0.08 * n3) * (1.0 + 0.045 * weave);
		ROUGHNESS = 0.86;
		SPECULAR = 0.16;
		EMISSION = col * rim * 0.16;
		hgt = n3 * 0.5 + n1 * 0.5;
	}
	ALBEDO = col;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2);
	NORMAL = normalize(abs(det) * NORMAL - bk * grad);
}
