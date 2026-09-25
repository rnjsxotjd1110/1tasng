shader_type canvas_item;
// 스킬트리 화면 전용 아이리스 와이프(중앙에서 원형으로 퍼짐/오므라듦). CanvasGroup 에 걸어
// 그 아래 전체 서브트리(배경·노드·헤더)를 하나의 텍스처로 합친 뒤 원형으로 잘라낸다(ART_BIBLE 손 작성 셰이더 규칙).
// CanvasGroup 은 자기 텍스처가 없어(TEXTURE/COLOR 내장 변수가 채워지지 않는다) 합성된 화면은
// hint_screen_texture + SCREEN_UV 로만 읽을 수 있다(진단: TEXTURE/UV 로 읽으면 흰 화면만 나온다).

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 aspect_center = vec2(0.5, 0.5);
uniform float aspect_ratio = 1.9048; // 640/336
uniform float softness = 0.015;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 uv = UV - aspect_center;
	uv.x *= aspect_ratio;
	float dist = length(uv);
	float max_dist = length(vec2(aspect_center.x * aspect_ratio, aspect_center.y)) * 1.02;
	float radius = progress * max_dist;
	float a = 1.0 - smoothstep(radius - softness, radius + softness, dist);
	vec4 col = texture(screen_tex, SCREEN_UV);
	COLOR = vec4(col.rgb, col.a * a);
}
