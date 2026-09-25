shader_type canvas_item;
// 비네트: void 색에 알파만 준다(팔레트 규칙). 알파는 단계로 나누고 4×4 Bayer 디더링(픽셀아트 느낌).
uniform vec4 tint : source_color = vec4(0.043, 0.039, 0.078, 1.0);
uniform vec2 rect_size = vec2(640.0, 360.0);
uniform vec2 center = vec2(262.0, 192.0);
uniform float inner = 0.45;
uniform float outer = 1.05;
uniform float max_alpha = 0.75;
uniform float steps = 5.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int index = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor(UV * rect_size);
	vec2 d = (p + 0.5 - center) / (rect_size * 0.5);
	float v = smoothstep(inner, outer, length(d * vec2(1.0, 1.15)));
	float level = floor(v * steps + bayer4(p));
	COLOR = vec4(tint.rgb, clamp(level / steps, 0.0, 1.0) * max_alpha);
}
