shader_type canvas_item;

uniform float blur_amount : hint_range(-2.0, 10.0);
uniform float mix_amount : hint_range(0.0, 1.0);
uniform vec4 color_over : source_color;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float modulate_alpha = COLOR.a; 

	vec4 texture_color = texture(TEXTURE, UV);

	vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);

	vec4 base = mix(blurred, color_over, mix_amount);

	float final_alpha = texture_color.a * modulate_alpha;

	COLOR = vec4(base.rgb, final_alpha);
}