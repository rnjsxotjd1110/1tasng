shader_type canvas_item;
// JACKPOT 회전 금빛 광선. 색은 팔레트 색 하나, 알파만 바꾼다. 거리 감쇠는 단계로 나눈다.
uniform vec4 ray_color : source_color = vec4(1.0, 0.851, 0.353, 1.0);
uniform vec2 rect_size = vec2(640.0, 360.0);
uniform vec2 center = vec2(320.0, 140.0);
uniform float ray_count = 18.0;
uniform float speed = 0.06;
uniform float strength = 0.14;
uniform float radius = 320.0;

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5 - center;
	float angle = atan(p.y, p.x) / 6.28318 + 0.5;
	float band = fract(angle * ray_count + TIME * speed * ray_count);
	float ray = step(0.72, band);
	float falloff = 1.0 - clamp(length(p) / radius, 0.0, 1.0);
	falloff = floor(falloff * 4.0) / 4.0;
	COLOR = vec4(ray_color.rgb, ray * falloff * strength);
}
