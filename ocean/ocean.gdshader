shader_type spatial;

// Originally based on (marcelb, MIT License):
// https://godotshaders.com/shader/transparent-water-shader-supporting-ssr/

//#define depth_and_screen

#define PI 3.14159265359
#define PI_2 6.28318530718

#ifdef depth_and_screen
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
#endif

uniform vec3 albedo : source_color = vec3(0.02, 0.45, 0.8);
uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform vec2 surface_normals_move_direction_a = vec2(-1.0, 0.0);
uniform vec2 surface_normals_move_direction_b = vec2(0.0, 1.0);
uniform float surface_texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float surface_texture_scale : hint_range(0.001, 2.0, 0.001) = 0.1;
uniform float surface_texture_time_scale : hint_range(0.001, 2.0, 0.001) = 0.06;

uniform float ssr_resolution   : hint_range(0.1, 10.0, 0.1)		= 2.0;
uniform float ssr_max_travel   : hint_range(0.1, 200.0, 0.1) 	= 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;

const vec4 wave_dir_amp_period[4] = {
    vec4(1.0, 0.05, 0.2, 1.0),
    vec4(1.0, -0.2, 0.25, 2.0),
    vec4(1.0, -0.3, -0.3, 4.0),
    vec4(1.0, 0.4, 0.5, 8.0)
};
uniform float wave_uv_scale = 30.0;
uniform float wave_height_scale = 0.25;
uniform float wave_time_scale = 1.0;
uniform float wave_normal_flatness : hint_range(0.1, 100.0, 0.1) = 30.0;
uniform sampler2D wave_noise;
uniform float wave_noise_strength = 0.1;

uniform vec3  border_color : source_color = vec3(1.0);
uniform float border_scale : hint_range(0.0, 5.0, 0.01) = 0.5;
uniform float border_near = 0.5;
uniform float border_far = 3000.0;

uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.4;

uniform float max_visible_depth : hint_range(0.0, 100.0, 0.1) = 10.0;
uniform vec3 color_deep : source_color = vec3(0.0, 0.1, 0.4);

uniform sampler2D surface_normals_a;
uniform sampler2D surface_normals_b;

varying vec2 vertex_uv;

float get_wave_height(vec2 uv) {
	float final_height = 0.0;
	// Add some variation to the main wave direction.
	uv.x = pow(abs(uv.x), 1.0 + 0.2 * cos(TIME / 10.0)) * sign(uv.x);
	uv.y = pow(abs(uv.y), 1.0 + 0.2 * sin(TIME / 10.0)) * sign(uv.y);
	// Sin/cos-based waves instead of textures for more performance and less resources
	for (int i = 0; i < wave_dir_amp_period.length(); i++) {
        vec4 wave = wave_dir_amp_period[i];
        // Gather parameters
        vec2 wave_dir = normalize(wave.xy);
		float wave_amp = wave.z;
		float wave_period = wave.w;
		float wave_time = TIME * wave_time_scale;
		// Compute the phase
		float wave_phase = dot(wave_dir, uv) * wave_period + wave_time;
		// Add noise to the waves
		float noise_sample = texture(wave_noise, uv / 3.0 + (wave_dir * 100.0)).r * wave_noise_strength;
		wave_phase += noise_sample * PI_2;
		wave_amp += noise_sample * wave_amp;
		// Add the wave to the final height
		final_height += sin(wave_phase) * wave_amp;
    }
	return final_height;
}

void vertex() {
	// Disable most water features at long distances, and push edge vertices!
	// TODO: Read global shader parameters for island and settings!
    // Get the vertex position in world space
	vertex_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	if (abs(VERTEX.x) >= 100.0 || abs(VERTEX.z) > 100.0) {
		VERTEX.xz *= 100.0;
		vertex_uv *= 100.0;
		NORMAL = vec3(0.0, 1.0, 0.0);
	} else if (abs(VERTEX.x) >= 90.0 || abs(VERTEX.z) > 90.0) {
		NORMAL = vec3(0.0, 1.0, 0.0);
	} else {
		// Waves go from right to left, so hack the uv coordinates to make them circular towards the middle
		vec2 uv = vertex_uv / wave_uv_scale;
		float radius = length(uv);
		float angle = atan(uv.y, uv.x);
		// Hide the seam
		float angle_tileable = (angle > 0.0) ? angle : -angle;
		// Even smoother transition
		angle_tileable = angle_tileable * 0.5 + 0.5;
		uv = vec2(radius, angle_tileable);

		// Move the vertex along the normal to simulate waves
		VERTEX.y += get_wave_height(uv) * wave_height_scale;

		float normal_height_scale = wave_height_scale / wave_normal_flatness;
		vec2 e = vec2(0.01, 0.0);
		vec3 normal = normalize(vec3(
			get_wave_height(uv - e) * normal_height_scale - get_wave_height(uv + e) * normal_height_scale,
			2.0 * e.x,
			get_wave_height(uv - e.yx) * normal_height_scale - get_wave_height(uv + e.yx) * normal_height_scale
			));
		NORMAL = normal;
	}
}

bool is_within_screen_boundaries(vec2 position) {
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m) {
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

vec3 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));

	vec2 current_screen_position = vec2(0.0);

	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

#ifdef depth_and_screen
		float depth_texture_probe_raw = texture(DEPTH_TEXTURE, current_screen_position).x;
#else
		float depth_texture_probe_raw = 1.;
#endif
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);

		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;

#ifdef depth_and_screen
		if (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) {
			resulting_color = texture(SCREEN_TEXTURE, current_screen_position.xy).rgb;
		} else {
#endif
			resulting_color =  vec3(-1.0);
#ifdef depth_and_screen
		}
#endif
	}
	return resulting_color;
}

float normalize_float(float min_v, float max_v, float value) {
	float clamped_value = clamp(value, min_v, max_v);
	return  (clamped_value - min_v) / (max_v - min_v);
}

vec2 get_refracted_uv(vec2 raw_screen_uv, float screen_depth_raw, vec3 view, vec3 normal, mat4 proj_m, mat4 inv_proj_m)
{
		vec3 screen_view_position_original = get_view_position_from_uv(raw_screen_uv, screen_depth_raw, inv_proj_m);
		float screen_center_distance = clamp(abs(length(raw_screen_uv - vec2(0.5, 0.5))) * 2.0, 0.0, 1.0);
		float refraction_intensity_deglitched = mix(1.0 - refraction_intensity, 1.0, screen_center_distance);
		vec3 refraction_position_view_space = screen_view_position_original + normalize(refract(view, -normal, refraction_intensity_deglitched));
		vec2 refraction_uv = get_uv_from_view_position(refraction_position_view_space, proj_m);
		return refraction_uv;
}

void fragment() {
#ifdef depth_and_screen
	float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;
#else
	float screen_depth_raw = 1.;
#endif

	vec2 refraction_uv = refraction_intensity > 0.0 ? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, NORMAL, PROJECTION_MATRIX, INV_PROJECTION_MATRIX) : SCREEN_UV;

#ifdef depth_and_screen
	float screen_depth_refraction = texture(DEPTH_TEXTURE, refraction_uv).x;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, screen_depth_refraction);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float water_depth = -view.z + VERTEX.z;
#else
	float screen_depth_refraction = 1.;
    float water_depth = 9999.0;
#endif
	float surface_depth = FRAGCOORD.z;

	vec2 time_vector = (TIME * surface_normals_move_direction_a) * surface_texture_time_scale;
	vec2 time_vector2 = (TIME * surface_normals_move_direction_b) * surface_texture_time_scale;

	vec3 normal_texture_blend 	= mix(texture(surface_normals_a, vertex_uv * surface_texture_scale + time_vector).xyz, texture(surface_normals_b, vertex_uv * surface_texture_scale + time_vector2).xyz, 0.5);
	vec3 normal_blend 			= mix(NORMAL, normal_texture_blend, surface_texture_roughness);

	vec3 screen_view_position 	= get_view_position_from_uv(refraction_uv, screen_depth_refraction, INV_PROJECTION_MATRIX);
	vec3 surface_view_position 	= get_view_position_from_uv(refraction_uv, surface_depth, INV_PROJECTION_MATRIX);
	float depth_opacity = 1.0 - normalize_float(0.0, max_visible_depth, length(surface_view_position - screen_view_position));

#ifdef depth_and_screen
	vec3 screen_color 				= texture(SCREEN_TEXTURE, refraction_uv).rgb;
#else
	vec3 screen_color = vec3(0.0);
#endif
	vec3 surface_color 				= albedo;
	vec3 ssr_color 					= get_ssr_color(surface_view_position, NORMAL, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	vec3 color_with_transparency 	= mix(surface_color, screen_color, transparency);
	vec3 depth_color 				= mix(color_deep.rgb, color_with_transparency, depth_opacity);
	vec3 water_color 				= (ssr_color.x >= 0.0) ? mix(depth_color, ssr_color, ssr_mix_strength) : depth_color;
	vec3 final_color				= mix(water_color, border_color, 1.0 - min(water_depth/border_scale, 1.0));

	ALBEDO.rgb = final_color;
#ifndef depth_and_screen // Force basic transparency without refraction when screen can't be read.
	ALPHA = transparency;
#endif
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_blend;
}