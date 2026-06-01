shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 0.6);
uniform vec4 progress_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);

void fragment() {
	float alpha = COLOR.a;
	
	float dist = abs(UV.x - 0.5);
	
	float t = step(dist, progress * 0.5);
	
	COLOR = mix(background_color, progress_color, t);
	COLOR.a *= alpha; 
}