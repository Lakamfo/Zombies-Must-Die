shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

uniform vec4  scratch_color     : source_color = vec4(1.0, 0.55, 0.1, 1.0);
uniform float scratch_scale     : hint_range(1.0, 30.0) = 8.0;
uniform float scratch_width     : hint_range(0.01, 0.2)  = 0.04;
uniform float scratch_density   : hint_range(1.0, 10.0)  = 4.0;
uniform float glow_width        : hint_range(0.01, 0.3)  = 0.12;
uniform float glow_intensity    : hint_range(0.0, 2.0)   = 0.8;
uniform float pulse_speed       : hint_range(0.0, 3.0)   = 0.8;
uniform float rim_power         : hint_range(0.5, 8.0)   = 4.0;
uniform float rim_intensity     : hint_range(0.0, 1.0)   = 0.3;
uniform float intensity         : hint_range(0.0, 1.0)   = 1.0;

uniform bool  use_z_clip_scale = false;
uniform float z_clip_scale     : hint_range(0.01, 1.0, 0.01) = 0.1;
uniform bool  use_fov_override = false;
uniform float fov_override     : hint_range(1.0, 179.0, 0.1) = 75.0;

varying vec3 vertex_pos;

float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),                hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}


float scratch_noise(vec2 p) {
    vec2 stretched = vec2(p.x * 4.0, p.y * 0.3);
    float n = noise(stretched);
    n += noise(stretched * vec2(1.0, 8.0)) * 0.2;
    return n;
}

void vertex() {
    vertex_pos = VERTEX;
    if (use_z_clip_scale) Z_CLIP_SCALE = z_clip_scale;
    if (use_fov_override && !IN_SHADOW_PASS) {
        float flip_y = sign(PROJECTION_MATRIX[1][1]);
        float aspect = PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0];
        float f      = flip_y / tan(fov_override * PI / 360.0);
        PROJECTION_MATRIX[0][0] = f / aspect;
        PROJECTION_MATRIX[1][1] = f;
    }
}

void fragment() {
    vec3 blend = pow(abs(NORMAL), vec3(4.0));
    blend /= dot(blend, vec3(1.0));

    float s = scratch_scale;

    float n1 = scratch_noise(vertex_pos.xz * s);
    float n2 = scratch_noise(vertex_pos.xy * s * vec2(0.7, 1.3) + vec2(3.7, 1.2));
    float n3 = scratch_noise(vertex_pos.yz * s * vec2(1.2, 0.8) + vec2(7.3, 4.1));

    float n = n1 * blend.y + n2 * blend.z + n3 * blend.x;

    float tiled  = fract(n * scratch_density);
    float ridge  = abs(tiled - 0.5) * 2.0;

    float scratch = 1.0 - smoothstep(0.0, scratch_width, 1.0 - ridge);

    float glow    = 1.0 - smoothstep(0.0, glow_width, 1.0 - ridge);
    float pulse   = 0.5 + 0.5 * sin(TIME * pulse_speed);
    glow *= pulse * glow_intensity;

    float rim = pow(1.0 - dot(NORMAL, VIEW), rim_power) * rim_intensity;

    float final = clamp(scratch + glow + rim, 0.0, 1.0) * intensity;

    ALBEDO = scratch_color.rgb;
    ALPHA  = final * scratch_color.a;
}