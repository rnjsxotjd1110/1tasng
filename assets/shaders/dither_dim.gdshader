shader_type canvas_item;
// 일시정지 오버레이: 화면 전체를 4×4 Bayer 디더링으로 균일하게 어둡게 덮는다(vignette.gdshader 와 같은 기법, 반지름 감쇠 없음).
uniform vec4 tint : source_color = vec4(0.043, 0.039, 0.078, 1.0);
uniform vec2 rect_size = vec2(640.0, 360.0);
uniform float darkness = 0.7;
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
	float level = floor(darkness * steps + bayer4(p));
	COLOR = vec4(tint.rgb, clamp(level / steps, 0.0, 1.0));
}
