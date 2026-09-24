shader_type canvas_item;
// 스킬트리 화면 전용 아이리스 와이프(중앙에서 원형으로 퍼짐/오므라듦). CanvasGroup 에 걸어
// 그 아래 전체 서브트리(배경·노드·헤더)를 하나의 텍스처로 합친 뒤 원형으로 잘라낸다(ART_BIBLE 손 작성 셰이더 규칙).

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 aspect_center = vec2(0.5, 0.5);
uniform float aspect_ratio = 1.9048; // 640/336
uniform float softness = 0.015;

void fragment() {
	vec2 uv = UV - aspect_center;
	uv.x *= aspect_ratio;
	float dist = length(uv);
	float max_dist = length(vec2(aspect_center.x * aspect_ratio, aspect_center.y)) * 1.02;
	float radius = progress * max_dist;
	float a = 1.0 - smoothstep(radius - softness, radius + softness, dist);
	vec4 col = texture(TEXTURE, UV);
	COLOR = vec4(col.rgb, col.a * a);
}
