// 공허 구슬 주변 왜곡(ART_BIBLE 9장): 둘레 픽셀이 소용돌이치며 구슬 쪽으로 빨려 드는 것처럼 화면을 다시 읽는다.
// 화면 텍스처를 정수 픽셀 단위로 옮겨 읽으므로 픽셀 퍼펙트가 유지된다(새 색을 만들지 않는다).
// VoidLens 노드가 구슬마다 반지름 radius 의 사각형(UV 0~1)을 그린다.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float radius = 10.0;
uniform float twist = 1.8;
uniform float pull = 0.55;
uniform float swirl_speed = 1.4;

void fragment() {
	vec2 off = (UV - 0.5) * 2.0 * radius;
	float d = length(off);
	if (d > radius) {
		discard;
	}
	vec2 screen_px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + 0.5;
	vec2 center = screen_px - off;
	float k = 1.0 - d / radius;
	float ang = k * k * twist + TIME * swirl_speed * k;
	float c = cos(ang);
	float s = sin(ang);
	vec2 rotated = vec2(c * off.x - s * off.y, s * off.x + c * off.y);
	vec2 src = floor(center + rotated * (1.0 + pull * k)) + 0.5;
	COLOR = vec4(texture(screen_tex, src * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
