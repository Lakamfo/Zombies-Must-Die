shader_type canvas_item;

uniform float alpha_treshold = 0.0;
uniform float visibility = 1.0;

void fragment() {
	if (COLOR.a > alpha_treshold) {
		COLOR.a = -visibility + UV.y;
	}
}