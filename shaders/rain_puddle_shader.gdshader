// Rain puddles with ripples using SSR
// CC0, shadecore_dev, 2025.
// Includes parts of the SSR implementation created by marcelb: https://godotshaders.com/shader/transparent-water-shader-supporting-ssr/
// Includes the rain ripple effect created by Zavie: https://www.shadertoy.com/view/ldfyzl

shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms PuddleEffect;

/** Fallback color for puddles when SSR reflection is absent. */
uniform vec4 puddle_color : source_color = vec4(0.01, 0.3, 0.28, 0.7);

/** Puddle mask multiplier. Affected by "Puddle Mask Threshold" value. */
uniform float puddle_reflectivness = 2.0;

/** Scale for perlin noise #1 used to create a mask for puddles. */
uniform float puddle_micro_mask_size = 5.0;

/** Scale for perlin noise #2 used to create a mask for puddles. */
uniform float puddle_macro_mask_size = 25.0;

/** The threshold value used to form a mask from two noises. */
uniform float puddle_mask_threshold = 0.33;

group_uniforms ScreenSpaceReflection;

/**
* The distance the ray-marching algorithm moves per step. Smaller values are better but slower.
* [color=yellow]Moderate performance impact.[/color]
**/
uniform float ssr_resolution : hint_range(0.1, 10.0, 0.1) = 1.0;

/** Max SSR travel distance. 0 deactivates SSR. [color=red]High performance impact.[/color] */
uniform float ssr_max_travel : hint_range(0.0, 200.0, 0.1)  = 30.0;

/**
* The maximum diff from geometry that is counted as a ray-march hit.
* Low values might miss geometry, high values might create false positives.
* No performance impact. Aim for good looks.
**/
uniform float ssr_max_diff : hint_range(0.1, 10.0, 0.1) = 4.0;

/** Strength of fade-out effect on reflections close to the screen borders */
uniform float ssr_screen_border_fadeout : hint_range(0.0, 1.0, 0.01) = 0.3;

group_uniforms RippleEffect;

/** Max ripple travel distance. Integer. [color=red]High performance impact.[/color] */
uniform float ripple_max_radius : hint_range(0.0, 5.0, 1.0) = 2.0;

/** Ripple scale modifier. */
uniform float ripple_scale : hint_range(0.1, 10.0, 0.1) = 1.0;

/** Ripple travel speed. */
uniform float ripple_speed : hint_range(0.1, 2.0, 0.01) = 0.5;

const float HASHSCALE1 = 0.1031; // Seed #1 for ripple effect generation.
const vec3 HASHSCALE3 = vec3(0.1031, 0.1030, 0.0973); // Seed #2 for ripple effect generation.

const float EPSILON = 1e-5; // Don't change.

float hash12(vec2 p) {
 vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
 p3 += dot(p3, p3.yzx + 19.19);
 return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
 vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
 p3 += dot(p3, p3.yzx+19.19);
 return fract((p3.xx+p3.yz)*p3.zy);
}

vec2 get_ripple_offset(vec2 input_uv) {
	float resolution = 10.0 * exp2(-3.0);
	vec2 uv = input_uv / ripple_scale * resolution;
	vec2 p0 = floor(uv);

	vec2 circles = vec2(0.0);
	for (float j = -ripple_max_radius; j <= ripple_max_radius; ++j)
	{
		for (float i = -ripple_max_radius; i <= ripple_max_radius; ++i)
		{
			vec2 pi = p0 + vec2(i, j);

			vec2 hsh = hash22(pi);

			vec2 p = pi + hash22(hsh);

			float t = fract(ripple_speed * TIME + hash12(hsh));
			vec2 v = p - uv;
			float d = length(v) - (float(ripple_max_radius) + 1.)*t;

			float h = 1e-3;
			float d1 = d - h;
			float d2 = d + h;
			float p1 = sin(31.*d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
			float p2 = sin(31.*d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
			circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * (1. - t) * (1. - t));
		}
	}
	
	circles /= float((ripple_max_radius * 2.0 + 1.0) * (ripple_max_radius * 2.0 + 1.0));

	float intensity = mix(0.01, 0.15, smoothstep(0.1, 0.6, abs(fract(0.05 * TIME + 0.5) * 2.0 -1.0)));
	vec3 n = vec3(circles, sqrt(1.0 - dot(circles, circles)));
	return (intensity * n.xy) + 5.0 * pow(clamp(dot(n, normalize(vec3(1.0, 0.7, 0.5))), 0.0, 1.0), 6.0);
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

bool is_within_screen_boundaries(vec2 position) 
{
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

bool is_zero(float value) 
{
    return abs(value) < EPSILON;
}

vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 uv_index = floor(uv);
    vec2 uv_fract = fract(uv);

    vec2 blur = smoothstep(0.0, 1.0, uv_fract);

    return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
                     dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
                mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
                     dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) + 0.5;
}


float get_screen_border_alpha(vec2 screen_position)
{
    vec2 shifted_screen_position = 4.0 * screen_position * (1.0 - screen_position);
	float mask = shifted_screen_position.x * shifted_screen_position.y;
	
	float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0)-0.75) / 0.25);
	float alpha = clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);

	return is_zero(ssr_screen_border_fadeout) ? 1.0 : alpha;
}

vec4 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	if (ssr_max_travel < EPSILON)
	{
		return vec4(0);
	}
	
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));
	
	vec2 current_screen_position = vec2(0.0);
	
	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

		float depth_texture_probe_raw = texture(depth_texture, current_screen_position).x;
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);
		
		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;
		
		vec3 ssr_screen_color = texture(screen_texture, current_screen_position.xy).rgb;
		resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? ssr_screen_color : vec3(-1.0);
	}

	float alpha = get_screen_border_alpha(current_screen_position);
	return vec4(resulting_color,alpha);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 reconstruct_world_position(vec2 uv, float depth, mat4 inv_proj_matrix, mat4 inv_view_matrix) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif

	vec4 view = inv_proj_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;

	vec4 world = inv_view_matrix * inv_proj_matrix * vec4(ndc, 1.0);
	return world.xyz / world.w;
}

void fragment() {
	if (effect_strength <= 0.001) {
		ALBEDO = texture(screen_texture, SCREEN_UV).rgb;
		ALPHA = 1.0;
	} else{
		vec2 uv_center = SCREEN_UV;
			float depth_center = texture(depth_texture, uv_center).x;
			
			if (depth_center <= EPSILON)
				discard;

			vec2 uv_right = SCREEN_UV + vec2(1, 0) / VIEWPORT_SIZE;
			vec2 uv_top = SCREEN_UV + vec2(0, 1) / VIEWPORT_SIZE;

			float depth_right = texture(depth_texture, uv_right).x;
			float depth_top = texture(depth_texture, uv_top).x;

			vec3 pixel_world_position_center = reconstruct_world_position(uv_center, depth_center, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
			vec3 pixel_world_position_right = reconstruct_world_position(uv_right, depth_right, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
			vec3 pixel_world_position_top = reconstruct_world_position(uv_top, depth_top, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

			vec3 normal = normalize(
				cross(
					pixel_world_position_top - pixel_world_position_center,
					pixel_world_position_right - pixel_world_position_center
				)
			);
			
			vec2 ripple_offset = get_ripple_offset(pixel_world_position_center.xz);

			vec3 ripple_vector = vec3(ripple_offset.x * CAMERA_DIRECTION_WORLD.x, 0.0, ripple_offset.y * CAMERA_DIRECTION_WORLD.z);
			
			normal -= ripple_vector;
			
			vec3 normal_view_space = (VIEW_MATRIX * vec4(normal, 0.0)).xyz;
			
			vec3 view_view_space = normalize(-get_view_position_from_uv(SCREEN_UV, 1.0, INV_PROJECTION_MATRIX));
			
			vec3 surface_view_position = get_view_position_from_uv(SCREEN_UV, depth_center, INV_PROJECTION_MATRIX);
			
			float puddle_mask_micro = noise(pixel_world_position_center.xz / puddle_micro_mask_size);
			float puddle_mask_macro = noise(pixel_world_position_center.xz / puddle_macro_mask_size);
			
			float final_puddle_mask = clamp(puddle_reflectivness * puddle_mask_micro * clamp(puddle_mask_macro, 0.0, 1.0) * normal.y - puddle_mask_threshold, 0.0, 1.0);

			vec4 ssr_color = get_ssr_color(surface_view_position, normal_view_space, view_view_space, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);

			// vec3 surface_color_ssr_mix = (ssr_max_travel > EPSILON) ? mix(vec3(0.0), ssr_color.rgb, ssr_color.a) : vec3(0);

		float mask = final_puddle_mask * smoothstep(0.0, 1.0, effect_strength);

		vec3 effect_color = mix(
		    puddle_color.rgb,
		    ssr_color.x < 0.0 ? puddle_color.rgb : ssr_color.rgb,
		    ssr_color.a
		);

		float effect_alpha = mix(
		    0.0,
		    ssr_color.x < 0.0 ? puddle_color.a : max(ssr_color.a, puddle_color.a), 
		    final_puddle_mask
		);

		vec3 base_color = texture(screen_texture, SCREEN_UV).rgb;

		ALBEDO = mix(base_color, effect_color, mask);
		ALPHA = mix(1.0, effect_alpha, mask);
	}
}