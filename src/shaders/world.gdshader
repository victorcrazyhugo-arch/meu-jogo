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
uniform bool blade = false;
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

// folhas: cada celula tem uma folha pontuda com orientacao propria; retorna (mascara, tom)
vec2 leafcell(vec2 p, float wd) {
	vec2 i = floor(p);
	vec2 f = fract(p) - 0.5;
	float a = hash21(i) * 6.2832;
	f -= (vec2(hash21(i + 1.7), hash21(i + 9.2)) - 0.5) * 0.3;
	vec2 d = vec2(cos(a), sin(a));
	float al = dot(f, d);
	float ac = dot(f, vec2(-d.y, d.x));
	float w = wd * (1.0 - pow(min(abs(al) / 0.46, 1.0), 1.7));
	float mask = smoothstep(0.0, 0.035, w - abs(ac));
	float rib = 1.0 - 0.25 * smoothstep(0.035, 0.0, abs(ac));
	return vec2(mask, (0.70 + 0.52 * hash21(i + 4.4)) * rib * (0.86 + 0.28 * (al + 0.46)));
}

// fios de grama: tracos curtos com direcao aleatoria por celula
float bladecell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p) - 0.5;
	float a = hash21(i) * 6.2832;
	vec2 d = vec2(cos(a), sin(a));
	float al = dot(f, d);
	float ac = dot(f, vec2(-d.y, d.x)) + (hash21(i + 7.3) - 0.5) * 0.5;
	float m = smoothstep(0.11, 0.02, abs(ac)) * smoothstep(0.5, 0.25, abs(al));
	return m * (hash21(i + 3.1) - 0.38);
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
	int id = blade ? 21 : (leafy ? (COLOR.a < 0.05 ? 16 : 17) : int(COLOR.a * 20.0 + 0.5));
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
		col *= 1.0 + ((blades - 0.5) * 0.55 + (g2 - 0.5) * 0.35) * fade;
		float nearg = clamp(1.0 - dist / 20.0, 0.0, 1.0);
		float bl = bladecell(uv * 15.0) + bladecell(uv.yx * 23.0 + 4.7) + 0.8 * bladecell((uv + uv.yx * 0.35) * 34.0 + 9.1);
		col *= 1.0 + bl * 1.05 * nearg;
		float flw = step(0.994, hash21(floor(uv * 11.0))) * nearg * step(0.5, patch);
		col = mix(col, vec3(0.78, 0.76, 0.50), flw * smoothstep(0.38, 0.2, length(fract(uv * 11.0) - 0.5)));
		col = mix(col, vec3(0.25, 0.20, 0.14), smoothstep(0.27, 0.17, n1 * 0.6 + g * 0.4) * 0.55 * fade);
		h = blades * 0.5 + g2 * 0.3 + bl * nearg;
		bs = 0.8;
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
		// tecido: trama, manchas suaves de uso e brilho aveludado nas bordas
		float wv = texture(noise_tex, uv * 9.0).r;
		float nearf = clamp(1.0 - dist / 9.0, 0.0, 1.0);
		float weave = sin(uv.x * 250.0) * sin(uv.y * 250.0);
		float rimf = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
		col *= (0.86 + 0.20 * wv) * (0.93 + 0.12 * n1) * (1.0 + 0.08 * weave * nearf);
		col += col * rimf * 0.38;
		h = wv * 0.6 + weave * 0.2 * nearf;
		bs = 0.35;
		rough = 0.98;
		spec = 0.05;
		m = mix(1.0, m, 0.5);
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
		// madeira envernizada: veios ao longo do comprimento, aneis de crescimento, poros e nos
		vec2 gu = up ? uv : uv.yx;
		float warp = vnoise(gu * vec2(0.9, 4.0));
		float grain = texture(noise_tex, vec2(gu.x * 1.2, gu.y * 11.0)).r;
		float grain2 = texture(noise_tex, vec2(gu.x * 0.4 + 0.5, gu.y * 3.0)).r;
		float ring = sin(gu.y * 44.0 + warp * 9.0 + grain * 3.0) * 0.5 + 0.5;
		float pore = texture(noise_tex, vec2(gu.x * 3.0, gu.y * 37.0)).r;
		vec2 kc = floor(gu * vec2(0.9, 2.6));
		vec2 kf = fract(gu * vec2(0.9, 2.6)) - vec2(hash21(kc + 2.0), hash21(kc + 5.0)) * 0.6 - 0.2;
		float knot = step(0.86, hash21(kc)) * smoothstep(0.10, 0.02, length(kf * vec2(0.6, 1.0)));
		float ga = mix(1.0, 0.30, smoothstep(0.40, 0.75, dot(col, vec3(0.333))));
		float wf = clamp(1.0 - dist / 30.0, 0.0, 1.0);
		col *= mix(1.0, (0.80 + 0.24 * grain) * (0.90 + 0.16 * grain2) * (0.90 + 0.14 * ring * wf) * (0.94 + 0.10 * pore * wf), ga);
		col *= 1.0 - 0.45 * knot * ga * wf;
		h = grain * 0.6 + ring * 0.25 * wf - knot;
		bs = 0.28;
		rough = 0.40;
		spec = 0.42;
		m = mix(1.0, m, 0.5);
	} else if (id == 16) {
		// casca de arvore e pedra
		float bk = vnoise(vec2(uv.x * 15.0, uv.y * 1.7)) * 0.55 + texture(noise_tex, vec2(uv.x * 2.6, uv.y * 0.6)).r * 0.45;
		float bk2 = texture(noise_tex, uv * vec2(6.0, 1.2)).r;
		col *= (0.66 + 0.5 * bk) * (0.86 + 0.24 * bk2);
		h = bk;
		bs = 1.0;
	} else if (id == 17) {
		// folhagem: folhas individuais em tres camadas, massas claras e escuras e vaos de sombra
		bool conifer = COLOR.b > COLOR.r * 1.2;
		float lsc = conifer ? 9.0 : 5.2;
		float lwd = conifer ? 0.10 : 0.25;
		vec2 la = leafcell(uv * lsc, lwd);
		vec2 lb = leafcell(uv * lsc * 1.37 + vec2(3.3, 7.1), lwd);
		vec2 lc = leafcell(uv.yx * lsc * 0.83 + vec2(5.9, 1.3), lwd);
		float lmask = max(la.x, max(lb.x, lc.x));
		float ltone = la.x > 0.5 ? la.y : (lb.x > 0.5 ? lb.y * 0.90 : lc.y * 0.80);
		float lfade = clamp(1.0 - (dist - 12.0) / 22.0, 0.0, 1.0);
		float l1 = texture(noise_tex, wpos.xz * 0.9 + wpos.y * 0.37).r;
		float l2 = texture(noise_tex, wpos.xz * 3.3 + wpos.y * 1.7).r;
		col *= vec3(0.86, 0.88, 0.84) * (0.66 + 0.5 * l1) * (0.80 + 0.34 * l2);
		col *= mix(0.84, mix(conifer ? 0.58 : 0.40, ltone * 1.12, lmask), lfade);
		col = mix(col, col * vec3(1.24, 1.16, 0.64), smoothstep(0.56, 0.8, l2) * lmask * 0.42);
		// @CUT if (lfade > 0.3 && lmask < 0.35 && abs(dot(NORMAL, VIEW)) < 0.52) discard;
		h = lmask * (0.5 + 0.5 * ltone);
		bs = 1.0 * lfade;
		rough = 0.78;
		spec = 0.16;
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
	} else if (id == 21) {
		// tufos de grama e capim alto: acompanham os tons do chao e ganham fibras ao longo do fio
		float patch = vnoise(wpos.xz * 0.31);
		float fib = texture(noise_tex, vec2(wpos.x * 9.0 + wpos.z * 7.0, wpos.y * 0.8)).r;
		col *= mix(0.80, 1.12, n2);
		col = mix(col, col * vec3(0.66, 0.90, 0.60), smoothstep(0.35, 0.75, patch) * 0.65);
		col *= 0.80 + 0.40 * fib;
		rough = 0.9;
		spec = 0.12;
		m = 1.0;
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
