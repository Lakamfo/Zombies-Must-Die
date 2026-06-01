shader_type canvas_item;

uniform vec4  color          : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4  outline_color  : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width  = 2.0;  
uniform float width          = 4.0;   
uniform float lenght         = 20.0;   
uniform float spread         = 10.0;   
uniform bool  show_dot       = true;
uniform float dot_size       = 3.0;
uniform float dynamic_spread = 0.0;  

uniform vec2 node_size = vec2(100.0, 100.0);


float shape_rect(vec2 px, vec2 center, float rot, vec2 half_size, float soft) {
	vec2 d = px - center;
	float c = cos(rot), s = sin(rot);
	vec2 r = vec2(c*d.x + s*d.y, -s*d.x + c*d.y);
	vec2 q = abs(r) - half_size;
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	return 1.0 - smoothstep(-soft, soft, dist);
}

void fragment() {
	vec2 px = (UV - 0.5) * node_size;

	float s  = spread + dynamic_spread;
	vec2 hs  = vec2(width * 0.5, lenght * 0.5);
	vec2 hso = hs + vec2(outline_width * 0.5);

	float right = shape_rect(px, vec2( s,  0.0), 0.0,           hs,  0.5);
	float left  = shape_rect(px, vec2(-s,  0.0), 0.0,           hs,  0.5);
	float up    = shape_rect(px, vec2( 0.0,  s), radians(90.0), hs,  0.5);
	float down  = shape_rect(px, vec2( 0.0, -s), radians(90.0), hs,  0.5);
	float fill  = max(max(right, left), max(up, down));

	float r_o = shape_rect(px, vec2( s,  0.0), 0.0,           hso, 0.5);
	float l_o = shape_rect(px, vec2(-s,  0.0), 0.0,           hso, 0.5);
	float u_o = shape_rect(px, vec2( 0.0,  s), radians(90.0), hso, 0.5);
	float d_o = shape_rect(px, vec2( 0.0, -s), radians(90.0), hso, 0.5);
	float outline = max(max(r_o, l_o), max(u_o, d_o));

	float dot = 0.0;
	if (show_dot) {
		dot = 1.0 - smoothstep(dot_size - 0.5, dot_size + 0.5, length(px));
	}

	float outline_mask = clamp(outline - fill, 0.0, 1.0);
	vec4 result = vec4(0.0);
	result = mix(result, vec4(outline_color.rgb, outline_color.a), outline_mask);
	result = mix(result, vec4(color.rgb, color.a), fill);
	result = mix(result, vec4(color.rgb, color.a), dot);
	COLOR = result;
}