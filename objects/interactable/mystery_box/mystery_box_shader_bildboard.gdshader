shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D icon;
uniform float flash_speed : hint_range(0.0, 2.0) = 1.0;
uniform float flash_angle : hint_range(-5.0, 5.0) = 5.0;
uniform vec3 flash_direction = vec3(0.000000, 0.000000, 1.000000);

void vertex() {
	// Billboard Mode: Enabled
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0],
			MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 n_out24p0;
// Texture2D:24
	n_out24p0 = texture(icon, UV);


	float n_out25p0;
// Expression:25
	n_out25p0 = 0.0;
	{
		n_out25p0 = n_out24p0.w;
	}


// Input:15
	float n_out15p0 = TIME;


// FloatParameter:20
	float n_out20p0 = flash_speed;


// FloatOp:22
	float n_out22p0 = n_out15p0 * n_out20p0;


// FloatFunc:17
	float n_out17p0 = cos(n_out22p0);


// FloatOp:19
	float n_in19p1 = 0.00000;
	float n_out19p0 = max(n_out17p0, n_in19p1);


// Input:26
	vec2 n_out26p0 = UV;


// FloatFunc:31
	float n_out31p0 = sign(n_out17p0);


// FloatParameter:33
	float n_out33p0 = flash_angle;


// FloatOp:32
	float n_out32p0 = n_out31p0 * n_out33p0;


// Vector3Parameter:34
	vec3 n_out34p0 = flash_direction;


	vec3 n_out28p0;
	mat4 n_out28p1;
// RotationByAxis:28
	{
		float __angle = n_out32p0;
		vec3 __axis = normalize(n_out34p0);
		mat3 __rot_matrix = mat3(
			vec3( cos(__angle)+__axis.x*__axis.x*(1.0 - cos(__angle)), __axis.x*__axis.y*(1.0-cos(__angle))-__axis.z*sin(__angle), __axis.x*__axis.z*(1.0-cos(__angle))+__axis.y*sin(__angle) ),
			vec3( __axis.y*__axis.x*(1.0-cos(__angle))+__axis.z*sin(__angle), cos(__angle)+__axis.y*__axis.y*(1.0-cos(__angle)), __axis.y*__axis.z*(1.0-cos(__angle))-__axis.x*sin(__angle) ),
			vec3( __axis.z*__axis.x*(1.0-cos(__angle))-__axis.y*sin(__angle), __axis.z*__axis.y*(1.0-cos(__angle))+__axis.x*sin(__angle), cos(__angle)+__axis.z*__axis.z*(1.0-cos(__angle)) )
		);
		n_out28p0 = vec3(n_out26p0, 0.0) * __rot_matrix;
	}


// FloatOp:27
	float n_out27p0 = n_out19p0 * n_out28p0.x;


// VectorOp:13
	vec3 n_out13p0 = vec3(n_out25p0) * vec3(n_out27p0);


// Output:0
	ALBEDO = n_out13p0;
	ALPHA = n_out25p0;
	EMISSION = n_out13p0;


}
