// 구슬 재질 셰이더(ART_BIBLE 3-2, 9장).
// 템플릿 텍스처(assets/sprites/ui/marble.png 7px, assets/sprites/marbles/marble_10/24.png)는 나무 구슬 5색으로 그린
// "음영 인덱스 맵"이다: wood_d=0 외곽선, wood=1 그림자, wood_l=2 바탕, wood_hl=3 밝은 면, ivory=4 광택.
// 이 셰이더가 인덱스를 재질 5색(c0~c4)과 강조색(a0~a3)으로 바꾸고, 텍셀 단위로 재질별 표면 디테일을 얹는다.
// 출력은 항상 팔레트 색 중 하나(+ 알파)라 픽셀 퍼펙트가 유지된다.
//
// 그리기 색(modulate)으로 인스턴스별 값을 넘긴다:
//   r = 밝기(1 = 그대로, 0 = void 로 덮임), g = 굴림 위상(0~1 = 0~360°), b = 회전 속도 배율(미리보기 1, 정지 0), a = 알파
shader_type canvas_item;

uniform vec4 c0 = vec4(0.23, 0.13, 0.09, 1.0);
uniform vec4 c1 = vec4(0.36, 0.21, 0.14, 1.0);
uniform vec4 c2 = vec4(0.51, 0.31, 0.18, 1.0);
uniform vec4 c3 = vec4(0.66, 0.44, 0.25, 1.0);
uniform vec4 c4 = vec4(0.96, 0.94, 0.91, 1.0);
uniform vec4 a0 = vec4(1.0);
uniform vec4 a1 = vec4(1.0);
uniform vec4 a2 = vec4(1.0);
uniform vec4 a3 = vec4(1.0);
uniform vec4 void_color = vec4(0.043, 0.039, 0.078, 1.0);
// 0 나무 1 돌 2 구리 3 철 4 은 5 금 6 옥 7 루비 8 사파이어 9 에메랄드 10 다이아 11 흑요석 12 별빛 13 공허 14 코스믹
uniform int style = 0;
// 미리보기 회전 속도(rad/s, modulate.b 가 곱해진다)
uniform float spin_rate = 1.6;

const vec3 T0 = vec3(59.0, 34.0, 24.0) / 255.0;
const vec3 T1 = vec3(92.0, 53.0, 36.0) / 255.0;
const vec3 T2 = vec3(131.0, 80.0, 47.0) / 255.0;
const vec3 T3 = vec3(168.0, 112.0, 63.0) / 255.0;
const vec3 T4 = vec3(244.0, 240.0, 232.0) / 255.0;
const vec3 LIGHT_DIR = vec3(-0.5505, -0.6205, 0.5584);
const float TAU_F = 6.28318530718;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

int decode(vec3 c) {
	float best = 9.0;
	int idx = 0;
	float d0 = distance(c, T0); if (d0 < best) { best = d0; idx = 0; }
	float d1 = distance(c, T1); if (d1 < best) { best = d1; idx = 1; }
	float d2 = distance(c, T2); if (d2 < best) { best = d2; idx = 2; }
	float d3 = distance(c, T3); if (d3 < best) { best = d3; idx = 3; }
	float d4 = distance(c, T4); if (d4 < best) { best = d4; idx = 4; }
	return idx;
}

vec4 shade_color(int i) {
	if (i <= 0) return c0;
	if (i == 1) return c1;
	if (i == 2) return c2;
	if (i == 3) return c3;
	return c4;
}

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

// 피보나치 구 위의 k번째 면 방향(n개).
vec3 facet_dir(int k, int n) {
	float fk = float(k) + 0.5;
	float y = 1.0 - 2.0 * fk / float(n);
	float r = sqrt(max(0.0, 1.0 - y * y));
	float phi = fk * 2.39996323;
	return vec3(cos(phi) * r, y, sin(phi) * r);
}

// 면 음영: 가장 가까운 면 방향으로 빛을 계산하고, 두 면의 경계는 edge=true.
// 반환 x = 면 밝기(-1..1), y = 경계 여부, z = 면 번호
vec3 facets(vec3 q, float roll, int n, float edge_w, vec3 stretch) {
	vec3 qs = normalize(q * stretch);
	float best = -2.0;
	float second = -2.0;
	int best_k = 0;
	for (int k = 0; k < 40; k++) {
		if (k >= n) break;
		float d = dot(qs, facet_dir(k, n));
		if (d > best) { second = best; best = d; best_k = k; }
		else if (d > second) { second = d; }
	}
	vec3 f = facet_dir(best_k, n);
	vec3 fv = rot_x(rot_y(f, -roll), 0.0);
	float lit = dot(fv, LIGHT_DIR);
	float edge = (best - second) < edge_w ? 1.0 : 0.0;
	return vec3(lit, edge, float(best_k));
}

// fragment 의 COLOR 는 텍스처 색이 이미 곱해져 있으므로 인스턴스 값은 vertex 에서 받아 둔다.
varying vec4 inst_color;

void vertex() {
	inst_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.5) {
		discard;
	}
	vec4 inst = inst_color;
	int idx = decode(tex.rgb);
	vec2 tsize = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV * tsize);
	vec2 p = (texel + 0.5) / tsize * 2.0 - 1.0;
	float r2 = dot(p, p);
	float z = sqrt(max(0.0, 1.0 - r2));
	vec3 n = vec3(p, z);
	float texel_w = 2.0 / tsize.x;
	// 0(7px) … 1(24px): 작은 구슬일수록 디테일을 줄인다
	float detail = clamp((tsize.x - 7.0) / 17.0, 0.0, 1.0);
	bool small = tsize.x < 9.0;
	bool gem = style >= 6 && style <= 10;
	float idle_spin = gem ? 0.55 : (style >= 12 ? 0.35 : 0.0);
	float roll = inst.g * TAU_F + TIME * (inst.b * spin_rate + idle_spin);
	vec3 q = rot_x(rot_y(n, roll), 0.35);
	int s = idx;
	vec4 col;
	bool fixed_color = false;

	if (style == 0) {
		// 나무: 굴러가는 나뭇결(어두운 줄) + 옹이 반점
		float freq = mix(1.3, 3.6, detail);
		float w = q.x * freq + sin(q.y * 3.1 + q.z * 1.7) * 0.45;
		float band = fract(w);
		if (idx >= 2 && band < 0.24) s = idx - 1;
		if (idx == 1 && band > 0.82 && !small) s = 2;
		float knot = length(q.xy - vec2(0.35, 0.2));
		if (detail > 0.5 && idx >= 2 && abs(knot - 0.22) < texel_w * 0.6) s = 1;
	} else if (style == 1) {
		// 돌: 어두운·밝은 반점
		vec3 cell = floor(q * mix(3.0, 7.5, detail) + 20.0);
		float h = hash13(cell);
		if (idx >= 1) {
			if (h < 0.17) s = max(idx - 1, 1);
			else if (h > 0.9 && idx < 4) s = idx + 1;
		}
		float h2 = hash13(cell * 1.7 + 3.0);
		if (!small && idx >= 2 && h2 > 0.96) s = 1;
	} else if (style >= 2 && style <= 4) {
		// 금속: 화면 공간 환경 반사(하늘·수평선·바닥) + 결
		float env = n.y + 0.18 * n.x;
		if (idx >= 1 && idx <= 3) {
			if (env > 0.02 && env < 0.02 + mix(0.35, 0.26, detail)) s = max(1, idx - 1);
			else if (env < -0.45) s = min(idx + 1, 3);
		}
		if (!small && idx >= 1 && idx <= 3) {
			float line_h = hash12(vec2(texel.y, floor((texel.x + roll * 3.0) / 3.0)));
			if (style == 2 && mod(texel.y, 3.0) < 1.0 && line_h > 0.55) s = max(1, s - 1);
			if (style == 3 && line_h > 0.93) s = min(3, s + 1);
			if (style == 3 && hash13(floor(q * 6.0 + 9.0)) > 0.9) s = max(1, s - 1);
			if (style == 4 && mod(texel.y, 2.0) < 1.0 && s == 2 && line_h > 0.7) s = 3;
		}
	} else if (style == 5) {
		// 금: 한 단계 밝게(바탕 = 밝은 금) + 어두운 수평선 반사 띠 + 아래 반사광
		float env = n.y + 0.15 * n.x;
		if (idx >= 1 && idx <= 3) {
			s = min(idx + 1, 3);
			if (env > 0.08 && env < 0.34) s = max(1, idx - 1);
			if (env > 0.6 && z < 0.6) s = 3;
			if (env < -0.55 && dot(n, LIGHT_DIR) > 0.8) s = 4;
		}
	} else if (gem) {
		int count = 8;
		float edge_w = 0.05;
		vec3 stretch = vec3(1.0);
		if (style == 7) { count = 12; edge_w = 0.05; }
		if (style == 8) { count = 16; edge_w = 0.045; }
		if (style == 9) { count = 10; edge_w = 0.06; stretch = vec3(1.0, 1.8, 1.0); }
		if (style == 10) { count = 24; edge_w = 0.04; }
		if (small) { count = max(5, count / 3); edge_w = 0.0; }
		vec3 fct = facets(q, roll, count, edge_w * mix(1.6, 1.0, detail), stretch);
		int fs = fct.x > 0.78 ? 4 : (fct.x > 0.42 ? 3 : (fct.x > 0.05 ? 2 : 1));
		if (idx >= 1 && idx <= 3) {
			if (idx == 1) s = clamp(fs - 1, 1, 2);
			else if (idx == 2) s = clamp(fs, 1, 3);
			else s = clamp(fs + 1, 2, 3);
			if (style == 10) {
				// 다이아: 흰 얼음빛(mist·ivory) 면 + 하늘색 그림자 면, 광택(cyan)은 면 경계에만
				s = fs >= 3 ? 3 : (fs == 2 ? 2 : 1);
				if (idx == 1 && s == 3) s = 2;
				if (idx >= 3 && s == 2) s = 3;
			}
			if (style == 6) {
				// 옥: 면은 은은하게, 뿌연 구름이 밝게 비친다(우윳빛)
				s = clamp(idx + (fs >= 3 ? 1 : 0) - (fs == 1 ? 1 : 0), 1, 3);
				float cloud = noise3(q * 2.2 + 5.0) * 0.7 + noise3(q * 4.6 + 1.0) * 0.3;
				if (cloud > 0.46 && s == 2) s = 3;
				if (cloud > 0.62 && s == 1) s = 2;
			}
			if (fct.y > 0.5 && style != 6) s = style == 10 ? (dot(n, LIGHT_DIR) > 0.35 ? 4 : 1) : max(1, s - 2);
			// 광택: 빛을 정면으로 받는 좁은 영역의 밝은 면만
			if (fs == 4 && dot(n, LIGHT_DIR) > 0.86 && style != 10 && style != 6) s = 4;
			if (idx == 4) s = 4;
			if (style == 10 && fs == 4 && dot(n, LIGHT_DIR) > 0.9) s = 4;
		}
		if (style == 10 && idx >= 1 && !small) {
			// 다이아: 무지개 스파클 — 면 중심 한 점이 번갈아 무지개색으로 빛난다
			vec3 fv = rot_y(facet_dir(int(fct.z), count), -roll);
			fv = rot_x(fv, -0.35);
			float h = hash12(vec2(fct.z, 7.0));
			float tw = fract(TIME * 0.8 + h);
			if (fv.z > 0.2 && tw < 0.3 && distance(p, fv.xy) < texel_w * 1.1) {
				int ci = int(mod(fct.z + floor(TIME * 2.0), 4.0));
				col = ci == 0 ? a0 : (ci == 1 ? a1 : (ci == 2 ? a2 : a3));
				fixed_color = true;
			}
		}
	} else if (style == 11) {
		// 흑요석: 검은 유리 + 조개껍질 물결 + 날카로운 반사 줄 + 보라빛 테두리
		if (idx >= 1) {
			s = idx >= 3 ? 2 : 1;
			float ripple = fract(length(q.xy - vec2(-0.3, 0.4)) * mix(2.0, 4.5, detail));
			if (!small && ripple < 0.18) s = 2;
			float streak = abs(dot(q, normalize(vec3(0.8, -0.4, 0.45))));
			if (streak < mix(0.16, 0.1, detail) && dot(n, LIGHT_DIR) > 0.05) s = 3;
			if (streak < mix(0.07, 0.04, detail) && dot(n, LIGHT_DIR) > 0.3) s = 4;
			if (idx == 4) s = 4;
		}
		if (idx == 0) {
			float pulse = 0.5 + 0.5 * sin(TIME * 2.4 + atan(p.y, p.x) * 2.0);
			if (pulse > 0.7) { col = a0; fixed_color = true; }
			else if (pulse > 0.35) { col = a1; fixed_color = true; }
		}
	} else if (style == 12) {
		// 별빛: 깊은 밤하늘 + 반짝이는 별(구슬과 함께 돈다)
		if (idx >= 1) {
			s = idx >= 3 ? 2 : 1;
			if (idx == 4) s = 4;
			float k = mix(2.2, 4.2, detail);
			vec3 cq = q * k + 30.0;
			vec3 cell = floor(cq);
			float h = hash13(cell);
			vec3 star = normalize((cell + 0.5 - 30.0) / k);
			bool on_star = distance(q, star) < texel_w * (small ? 1.6 : 0.75);
			if (h > 0.55 && on_star) {
				float tw = sin(TIME * (1.6 + h * 4.0) + h * 40.0);
				if (tw > 0.2) { s = 4; }
				else if (tw > -0.5) { s = 3; }
			}
		}
	} else if (style == 13) {
		// 공허: 가운데 검은 구멍 + 빨려드는 소용돌이 팔 + 사건의 지평선 고리
		if (idx >= 1) {
			float r = sqrt(r2);
			float a = atan(p.y, p.x);
			float arm = sin(a * 2.0 + r * 7.0 - TIME * 3.2);
			if (r < 0.3) {
				col = void_color; fixed_color = true;
			} else if (r < 0.3 + texel_w * 1.1 && !small) {
				s = 3;
			} else {
				s = arm > 0.55 ? 2 : (arm > 0.1 ? 1 : 0);
				if (arm > 0.88 && r > 0.45) s = 3;
				if (s == 0) { col = void_color; fixed_color = true; }
			}
			if (idx == 4) { s = 4; fixed_color = false; }
		}
	} else if (style == 14) {
		// 코스믹: 흐르는 성운(4색) + 별가루
		if (idx >= 1) {
			vec3 flow = q * mix(1.1, 1.7, detail) + vec3(TIME * 0.2, -TIME * 0.12, TIME * 0.08);
			float neb = noise3(flow) * 0.75 + noise3(flow * 2.1 + 11.0) * 0.25;
			neb += (float(idx) - 2.0) * 0.1;
			if (neb < 0.42) { col = a0; }
			else if (neb < 0.54) { col = c1; }
			else if (neb < 0.66) { col = c2; }
			else { col = c3; }
			fixed_color = true;
			float h = hash13(floor(q * mix(3.5, 7.0, detail) + 40.0));
			if (h > 0.87 && sin(TIME * 4.0 + h * 50.0) > 0.2) { col = c4; }
			if (idx == 4) { col = c4; }
		}
	}

	// 번쩍임(glint): 금속·금·보석은 주기적으로 대각선 빛이 스친다
	if (style >= 2 && style <= 10 && idx >= 1) {
		float period = style == 5 ? 2.4 : 3.2;
		float t = fract(TIME / period);
		if (t < 0.4) {
			float sweep = mix(-1.9, 1.9, t / 0.4);
			float d = abs((p.x + p.y) * 0.7071 - sweep);
			if (d < texel_w * mix(0.8, 1.2, detail)) { s = 4; fixed_color = false; }
		}
	}

	if (!fixed_color) {
		col = shade_color(s);
	}
	col.rgb = mix(void_color.rgb, col.rgb, clamp(inst.r, 0.0, 1.0));
	col.a = inst.a;
	COLOR = col;
}
