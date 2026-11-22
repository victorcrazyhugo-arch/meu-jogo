shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
// Material unico do cenario. A cor vem do vertice e o canal alfa informa o tipo de superficie;
// o padrao (tijolos, tabuas, telhas, pisos, asfalto, grama...) e calculado aqui, em espaco de
// mundo, com relevo, brilho e sombreamento de contato. Nenhuma textura externa e usada.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float sway = 0.0;
uniform float detail = 1.0;
uniform float bump = 1.0;
uniform float wet = 0.0;
uniform float gloss = 0.0;
uniform bool leafy = false;
varying vec3 wpos;
varying vec3 wnor;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// ruido suave calculado (independe da resolucao da textura): rachaduras, folhas, manchas
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

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

// celulas retangulares com juntas (tijolos, tabuas de piso, pedras): retorna mascara da face e id da celula
vec3 cells(vec2 uv, vec2 size, float stagger, float jx, float jy) {
	vec2 b = uv / size;
	float row = floor(b.y);
	b.x += mod(row, 2.0) * stagger;
	vec2 f = fract(b);
	float m = smoothstep(0.0, jx, f.x) * smoothstep(1.0, 1.0 - jx, f.x) * smoothstep(0.0, jy, f.y) * smoothstep(1.0, 1.0 - jy, f.y);
	return vec3(m, hash21(floor(b)), f.y);
}

void fragment() {
	vec3 an = abs(wnor);
	bool up = an.y > 0.6;
	vec2 uv = up ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float n1 = texture(noise_tex, uv * 0.27).r;
	float n2 = texture(noise_tex, uv * 0.033 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, uv * 1.9 + vec2(0.13, 0.71)).r;
	vec3 col = COLOR.rgb;
	float h = 0.5;
	float bs = 0.0;
	float rough = 0.92;
	float spec = 0.18;
	float dist = length(VERTEX);
	float fade = clamp(1.0 - dist / 75.0, 0.0, 1.0);
	float m = (0.91 + 0.15 * n1) * (0.94 + 0.10 * n2);
	int id = leafy ? (COLOR.a < 0.05 ? 16 : 17) : int(COLOR.a * 20.0 + 0.5);
	bool wall = false;
	bool ground = false;
	if (id == 1) {
		// grama: tons variados, fios, trechos secos e terra aparente
		float g = texture(noise_tex, uv * 2.3).r;
		float g2 = texture(noise_tex, uv * 7.5 + vec2(0.5, 0.2)).r;
		float blades = texture(noise_tex, vec2(uv.x * 21.0 + uv.y * 3.0, uv.y * 8.0)).r;
		float patch = vnoise(uv * 0.31);
		float clover = vnoise(uv * 1.7 + 11.0);
		col *= vec3(0.60, 0.64, 0.58);
		col *= mix(0.80, 1.12, n1);
		col = mix(col, col * vec3(0.66, 0.90, 0.60), smoothstep(0.35, 0.75, patch) * 0.65);
		col = mix(col, col * vec3(1.30, 1.14, 0.62), smoothstep(0.60, 0.82, n2) * 0.42);
		col = mix(col, col * vec3(0.78, 1.08, 0.70), smoothstep(0.66, 0.80, clover) * 0.5 * fade);
		col *= 1.0 + ((blades - 0.5) * 0.75 + (g2 - 0.5) * 0.40) * fade;
		col = mix(col, vec3(0.25, 0.20, 0.14), smoothstep(0.27, 0.17, n1 * 0.6 + g * 0.4) * 0.55 * fade);
		h = blades * 0.6 + g2 * 0.4;
		bs = 0.7;
		rough = 0.95;
		spec = 0.10;
		ground = true;
		m = 1.0;
	} else if (id == 2) {
		// asfalto: agregado, remendos, manchas de oleo e rachaduras
		float g = texture(noise_tex, uv * 5.5).r;
		float near = clamp(1.0 - dist / 16.0, 0.0, 1.0);
		float sp = hash21(floor(uv * 60.0));
		col *= 0.88 + 0.20 * g * fade + 0.05 * n3;
		col += vec3(0.07) * step(0.88, sp) * near;
		col *= 1.0 - 0.10 * step(sp, 0.10) * near;
		col = mix(col, col * 1.20, smoothstep(0.60, 0.64, n2) * 0.45);
		col = mix(col, col * 0.72, smoothstep(0.72, 0.9, vnoise(uv * 0.22 + 3.0)) * 0.5);
		float cn = vnoise(uv * 0.8) + 0.30 * vnoise(uv * 3.3);
		float cmask = smoothstep(0.50, 0.68, vnoise(uv * 0.11 + 7.0));
		float crack = (1.0 - smoothstep(0.0, 0.016, abs(cn - 0.66))) * cmask;
		col *= 1.0 - 0.6 * crack * fade;
		h = g * 0.5 + sp * 0.2 * near - crack;
		bs = 0.5;
		rough = 0.82;
		spec = 0.22;
		ground = true;
		m = mix(1.0, m, 0.6);
	} else if (id == 3) {
		// concreto / calcada: placas de 2 m com juntas
		vec3 c = cells(uv, vec2(2.0, 2.0), 0.0, 0.012, 0.012);
		col *= (0.90 + 0.14 * n3) * (0.95 + 0.10 * c.y);
		col *= mix(1.0, 0.62 + 0.38 * c.x, fade);
		h = c.x * 0.6 + n3 * 0.4;
		bs = 0.35;
		rough = 0.88;
		ground = up;
		wall = !up;
	} else if (id == 4) {
		// tijolos aparentes com argamassa
		vec3 c = cells(uv, vec2(0.46, 0.15), 0.5, 0.035, 0.10);
		vec3 brick = col * (0.80 + 0.40 * c.y) * (0.92 + 0.16 * n3);
		vec3 mortar = vec3(0.60, 0.58, 0.54);
		col = mix(col * 0.96, mix(mortar, brick, c.x), fade);
		h = c.x;
		bs = 1.0;
		wall = true;
	} else if (id == 5) {
		// reboco pintado (fachadas): granulado fino, escorridos e manchas de umidade junto ao chao
		float hh5 = mod(wpos.y, 3.0);
		float fine = texture(noise_tex, uv * 6.0).r;
		col *= 0.94 + 0.10 * fine;
		if (!up) {
			float drip = texture(noise_tex, vec2(uv.x * 1.7, uv.y * 0.12)).r;
			col *= 1.0 - 0.16 * smoothstep(0.55, 0.8, drip) * smoothstep(0.3, 2.8, hh5);
			float stain = smoothstep(0.50, 0.75, n2) * smoothstep(1.4, 0.0, hh5);
			col = mix(col, col * vec3(0.74, 0.73, 0.66), stain * 0.6);
		}
		h = fine;
		bs = 0.35;
		wall = true;
		m = mix(1.0, m, 0.5);
	} else if (id == 6) {
		// tabuas horizontais (casas e cabanas de madeira)
		float b = uv.y / 0.22;
		float f = fract(b);
		float row = floor(b);
		float groove = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
		float grain = texture(noise_tex, vec2(uv.x * 0.5 + row * 0.37, uv.y * 7.0)).r;
		col *= (0.84 + 0.22 * hash21(vec2(row, 3.0))) * (0.86 + 0.26 * grain);
		col *= mix(1.0, 0.55 + 0.45 * groove, fade);
		h = groove * (0.8 + 0.2 * grain);
		bs = 0.9;
		wall = true;
	} else if (id == 7) {
		// chapa ondulada com ferrugem
		float s = sin(uv.x * 26.0);
		col *= mix(1.0, 0.88 + 0.14 * s, fade);
		float rust = smoothstep(0.56, 0.72, n1 * 0.5 + n2 * 0.5) * smoothstep(2.2, 0.0, mod(wpos.y, 3.0) * 0.6 + n3);
		col = mix(col, vec3(0.42, 0.22, 0.12) * (0.8 + 0.4 * n3), rust * 0.7);
		h = s * 0.5 + 0.5;
		bs = 0.8;
		rough = 0.55;
		spec = 0.45;
		wall = true;
	} else if (id == 8) {
		// assoalho de madeira: tabuas longas com veios
		vec3 c = cells(uv, vec2(1.7, 0.16), 0.37, 0.006, 0.05);
		float grain = texture(noise_tex, vec2(uv.x * 0.7, uv.y * 9.0)).r;
		col *= (0.82 + 0.30 * c.y) * (0.88 + 0.22 * grain);
		col *= mix(1.0, 0.60 + 0.40 * c.x, fade);
		h = c.x;
		bs = 0.5;
		rough = 0.55;
		spec = 0.35;
	} else if (id == 9) {
		// piso ceramico: placas de 0,5 m com rejunte
		vec3 c = cells(uv, vec2(0.5, 0.5), 0.0, 0.025, 0.025);
		col *= 0.94 + 0.10 * c.y;
		col = mix(col * 0.96, mix(vec3(0.42, 0.42, 0.40), col, c.x), fade);
		h = c.x;
		bs = 0.5;
		rough = 0.30;
		spec = 0.55;
	} else if (id == 10) {
		// telhas em fiadas ao longo da inclinacao
		vec2 dir = length(wnor.xz) > 0.05 ? normalize(wnor.xz) : vec2(0.0, 1.0);
		float sl = dot(wpos.xz, dir) / 0.34;
		float ac = dot(wpos.xz, vec2(-dir.y, dir.x)) / 0.26 + mod(floor(sl), 2.0) * 0.5;
		float fy = fract(sl);
		float fx = fract(ac);
		float tile = smoothstep(0.0, 0.10, fx) * smoothstep(1.0, 0.90, fx);
		float edge = smoothstep(0.0, 0.22, fy);
		col *= (0.80 + 0.36 * hash21(vec2(floor(ac), floor(sl)))) * (0.9 + 0.14 * n3);
		col *= mix(1.0, (0.62 + 0.38 * edge) * (0.78 + 0.22 * tile), fade);
		h = fy * tile;
		bs = 1.0;
		rough = 0.75;
	} else if (id == 11) {
		// terra batida com pedrinhas
		float g = texture(noise_tex, uv * 6.0).r;
		col *= 0.84 + 0.30 * g * fade;
		col = mix(col, col * 0.72, smoothstep(0.55, 0.7, n1) * 0.5);
		h = g;
		bs = 0.5;
		ground = true;
	} else if (id == 12) {
		// tecido
		float wv = texture(noise_tex, uv * 9.0).r;
		col *= 0.88 + 0.22 * wv;
		h = wv;
		bs = 0.3;
		rough = 0.98;
		spec = 0.05;
	} else if (id == 13) {
		// solo arado em sulcos
		float fr = sin(wpos.z * 3.927);
		col *= (0.80 + 0.20 * fr) * (0.88 + 0.22 * n3);
		h = fr * 0.5 + 0.5;
		bs = 0.8;
		ground = true;
	} else if (id == 14) {
		// pedra assentada
		vec3 c = cells(uv, vec2(0.62, 0.30), 0.43, 0.05, 0.09);
		col *= (0.78 + 0.40 * c.y) * (0.9 + 0.16 * n3);
		col *= mix(1.0, 0.55 + 0.45 * c.x, fade);
		h = c.x;
		bs = 1.0;
		wall = true;
	} else if (id == 15) {
		// madeira envernizada dos moveis: veios
		float grain = texture(noise_tex, vec2(uv.x * 1.2, uv.y * 11.0)).r;
		float grain2 = texture(noise_tex, vec2(uv.x * 0.4 + 0.5, uv.y * 3.0)).r;
		float ga = mix(1.0, 0.30, smoothstep(0.40, 0.75, dot(col, vec3(0.333))));
		col *= mix(1.0, (0.80 + 0.26 * grain) * (0.90 + 0.16 * grain2), ga);
		h = grain;
		bs = 0.2;
		rough = 0.45;
		spec = 0.40;
	} else if (id == 16) {
		// casca de arvore e pedra
		float bk = vnoise(vec2(uv.x * 15.0, uv.y * 1.7)) * 0.55 + texture(noise_tex, vec2(uv.x * 2.6, uv.y * 0.6)).r * 0.45;
		float bk2 = texture(noise_tex, uv * vec2(6.0, 1.2)).r;
		col *= (0.66 + 0.5 * bk) * (0.86 + 0.24 * bk2);
		h = bk;
		bs = 1.0;
	} else if (id == 17) {
		// folhagem: massas claras e escuras, folhas e vaos de sombra
		float l1 = texture(noise_tex, wpos.xz * 0.9 + wpos.y * 0.37).r;
		float l2 = texture(noise_tex, wpos.xz * 3.3 + wpos.y * 1.7).r;
		float lf = vnoise(wpos.xz * 8.0 + wpos.y * 4.7) * 0.5 + vnoise(wpos.zy * 10.0 + wpos.x * 3.9) * 0.5;
		float leaf = smoothstep(0.30, 0.70, lf);
		col *= vec3(0.80, 0.82, 0.78);
		col *= (0.66 + 0.5 * l1) * (0.80 + 0.34 * l2);
		col *= mix(1.0, 0.52 + 0.80 * leaf, fade);
		col = mix(col, col * vec3(1.22, 1.16, 0.66), smoothstep(0.58, 0.8, l2) * leaf * 0.45);
		h = leaf * 0.7 + l2 * 0.3;
		bs = 1.0;
		rough = 0.80;
		spec = 0.14;
		m = 1.0;
	} else if (id == 18) {
		// metal e esmalte lisos (eletrodomesticos, ferragens)
		col *= 0.96 + 0.06 * n3;
		rough = 0.30;
		spec = 0.60;
		m = 1.0;
	} else if (id == 19) {
		// parede interna pintada, com rodape
		float fine = texture(noise_tex, uv * 5.0).r;
		col *= 0.955 + 0.07 * fine;
		m = mix(1.0, m, 0.22);
		h = fine * 0.5;
		bs = 0.18;
		if (!up) {
			float hh9 = mod(wpos.y, 3.0);
			float bb = step(hh9, 0.185);
			col *= mix(1.0, 0.80, (1.0 - bb) * smoothstep(0.215, 0.185, hh9));
			col = mix(col, vec3(0.86, 0.84, 0.79) * (0.95 + 0.08 * fine), bb);
			h += bb;
			rough = mix(rough, 0.5, bb);
			spec = mix(spec, 0.35, bb);
			wall = true;
		}
	} else {
		m = mix(1.0, m, detail * 0.45);
		col *= 0.97 + 0.05 * n3;
		rough = mix(0.90, 0.38, gloss);
		spec = mix(0.18, 0.55, gloss);
	}
	// sombreamento de contato nas paredes: rodape e encontro com o teto
	if (wall && !up) {
		float hh = mod(wpos.y + 0.02, 3.0);
		float lo = id == 19 ? 0.86 : 0.70;
		col *= mix(lo, 1.0, smoothstep(0.0, 0.55, hh)) * mix(0.82, 1.0, smoothstep(2.82, 2.40, hh));
	}
	// superficies molhadas pela chuva
	if (ground && wet > 0.01) {
		float puddle = smoothstep(0.45, 0.62, n1 * 0.6 + n2 * 0.4);
		float w = wet * (0.55 + 0.45 * puddle);
		col *= 1.0 - 0.28 * w;
		rough = mix(rough, 0.12, w);
		spec = mix(spec, 0.75, w);
		bs *= 1.0 - 0.7 * w * puddle;
	}
	// relevo a partir do padrao (derivadas em espaco de tela)
	if (bump > 0.0 && bs > 0.0 && fade > 0.05) {
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		float dhx = dFdx(h);
		float dhy = dFdy(h);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - 0.035 * bs * bump * fade * grad);
	}
	ALBEDO = col * m;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
