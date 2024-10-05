shader_type canvas_item;

// Debugging
uniform bool debug_height = false;

// Modifiable noise parameters
uniform int my_seed = 42;

// Island restrictions
global uniform sampler2D setting_island_water_level_distance : hint_roughness_gray, filter_linear;
global uniform float setting_island_water_level_at: hint_range(0.0, 1.0);
global uniform float setting_island_water_level_step: hint_range(0.0, 1.0);
uniform vec2 min_precipice_range = vec2(1e-3, 0.2);

#include "FastNoiseLite.gdshaderinc"

// The raw noise [0, 1] used as a base for the island
highp float noise01(highp vec2 uv) {
	// Setup
	fnl_state state = fnlCreateState(my_seed);
	state.noise_type = FNL_NOISE_OPENSIMPLEX2;
	highp ivec2 texsize = textureSize(setting_island_water_level_distance, 0);
	state.frequency = float(texsize.x) * 0.01;
	highp float uv_y_scale = float(texsize.x) / float(texsize.y);
	state.octaves = 15;
	state.fractal_type = FNL_FRACTAL_PINGPONG;
	state.domain_warp_type = FNL_DOMAIN_WARP_OPENSIMPLEX2;
	state.domain_warp_amp = 1.0;
	// Run
	highp float x = uv.x;
	highp float y = uv.y * uv_y_scale;
	fnlDomainWarp2D(state, x, y);
	return fnlGetNoise2D(state, x, y) * 0.5 + 0.5;
}

#include "lanczos.gdshaderinc"
#define LANCZOS_SIZE 30

// Takes the noisy heightmap and makes sure it matches the input distance to surface constraints
highp float heightmap_island(highp vec2 uv_raw, highp vec2 pixel_size) {
	// Working with corners, not centers: UV requires fixing
	highp ivec2 num_cell_corners = textureSize(setting_island_water_level_distance, 0);
	highp vec2 uv_rescale_factor = vec2(num_cell_corners) / vec2(num_cell_corners + 1);
	highp vec2 uv_fix = uv_raw * uv_rescale_factor + 0.5 / vec2(num_cell_corners);
	// Displace (0,0) and the end by resolution-dependant amounts (don't ask my why)
	uv_fix = uv_fix * (1.0 + 0.5 * pixel_size) - 0.5 * pixel_size;
	//uv_fix = (uv_fix - vec2(0.5, 0.5)) * uv_rescale_factor + vec2(0.5, 0.5);
	highp vec2 uv_cell_float = uv_fix * vec2(num_cell_corners);
	highp ivec2 uv_cell = ivec2(uv_cell_float);

	// Get the most extreme heights allowed for this UV (above or below water level)
	highp float extreme_height_ramp = texture(setting_island_water_level_distance, uv_fix).r;
	highp float extreme_height_smooth = lanczos(setting_island_water_level_distance, uv_fix, LANCZOS_SIZE).r;

	// Lanczos is better at smoothing and hiding seams, but linear defines clear water-level boundaries, so mix them.
	highp float extreme_height_ramp_factor = max(0.0, 1.0 - abs(extreme_height_ramp - setting_island_water_level_at) / (0.5 * setting_island_water_level_step));
	highp float extreme_height = extreme_height_ramp * extreme_height_ramp_factor + extreme_height_smooth * (1.0 - extreme_height_ramp_factor);

	// Apply some natural looking noise for realism, that is enforced to stay between water level and extreme_height
	highp float noise_val = noise01(uv_fix);
	highp float height = (extreme_height - setting_island_water_level_at) * noise_val + setting_island_water_level_at;

	// Add some cliffs to break the coastline by overlapping more noise
	highp float cliff_noise_val = noise01(uv_fix * vec2(2., 2.) + vec2(54.23491, -12.45356));
	highp float cliff_max_height = setting_island_water_level_step;
	highp float cliff_cutoff = 0.6;
	height += sign(extreme_height - setting_island_water_level_at) * cliff_max_height * max(0.0, cliff_noise_val - cliff_cutoff) / (1.0 - cliff_cutoff);

	return height;
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	//highp float height = noise01(uv);
	//float height = warped_noise01(uv);
	highp float height = heightmap_island(UV, SCREEN_PIXEL_SIZE);

	if (debug_height) {
		COLOR = vec4(height, height, height, 1.0);
		// Notify of any errors (compatible with only reading the red channel for heightmap)
		if (height > 1.0) {
	        COLOR = vec4(1.0, 0.0, 0.0, 1.0);
	    }
		if (height < 0.0) {
	        COLOR = vec4(0.0, 0.0, 1.0, 1.0);
	    }
		// Help see water and land (compatible with only reading the red channel for heightmap)
		if (height < setting_island_water_level_at) {
	        COLOR.b += 0.2;
	    } else {
			COLOR.g += 0.2;
		}
	} else {
		// This is a hack to get higher-precision height values (avoid stairs when using lots of vertices)
		const highp float precision = 255.99999;
		COLOR.xy = vec2(
			fract(floor(height * precision) / precision),
			fract(floor(height * precision * precision) / precision)
		);
	}
}