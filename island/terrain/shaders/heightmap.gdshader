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
	state.frequency = float(texsize.x) * 0.02;
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

//highp float warped_noise01(highp vec2 p) { // https://iquilezles.org/articles/warp/
//	highp vec2 q = vec2(noise01(p + vec2(0.0, 0.0)),
//	noise01(p + vec2(5.2, 1.3)));
//	highp vec2 r = vec2(noise01(p + 0.25* q + vec2(1.7, 9.2)),
//	noise01(p + 0.25 * q + vec2(8.3, 2.8)));
//	return noise01(p + 0.25 * r);
//}

#include "lanczos.gdshaderinc"
#define LANCZOS_SIZE 5

// Gets the custom non-smooth ramp-like max height. Useful for a proper blocky coastline!
highp float max_height_ramp(highp vec2 uv, highp sampler2D setting_island_water_level_distance_, highp ivec2 setting_island_water_level_distance_size, highp ivec2 block_sample, highp vec2 floating_sample, highp float mh_block) {
	// Use mh_block to create mh_ramp, which help create perfectly square cells along the coast ;)
	highp float mh_block_tl = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(-1, -1), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_tc = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(0, -1), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_tr = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(1, -1), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_cl = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(-1, 0), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_cc = mh_block;
	highp float mh_block_cr = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(1, 0), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_bl = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(-1, 1), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_bc = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(0, 1), 0, setting_island_water_level_distance_size).r;
	highp float mh_block_br = texelFetchClamp(setting_island_water_level_distance_, block_sample + ivec2(1, 1), 0, setting_island_water_level_distance_size).r;
	// Gather the shared 2x2 heights with neighboring cells, forcing water_level!
	highp float min_precipice = min_precipice_range.x; // To clearly differenciate above and below water, at the cost of "realism"
	highp float mh_ramp_tl = (mh_block_tl + mh_block_tc + mh_block_cl + mh_block_cc) / 4.0;
	if (sign(mh_block_tl - setting_island_water_level_at) != sign(mh_block_tc - setting_island_water_level_at) ||
		sign(mh_block_tl - setting_island_water_level_at) != sign(mh_block_cl - setting_island_water_level_at) ||
		sign(mh_block_tl - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) {
		mh_ramp_tl = setting_island_water_level_at + min_precipice * sign(mh_block_cc - setting_island_water_level_at);
	}
	highp float mh_ramp_tr = (mh_block_tr + mh_block_tc + mh_block_cr + mh_block_cc) / 4.0;
	if (sign(mh_block_tr - setting_island_water_level_at) != sign(mh_block_tc - setting_island_water_level_at) ||
		sign(mh_block_tr - setting_island_water_level_at) != sign(mh_block_cr - setting_island_water_level_at) ||
		sign(mh_block_tr - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) {
		mh_ramp_tr = setting_island_water_level_at + min_precipice * sign(mh_block_cc - setting_island_water_level_at);
	}
	highp float mh_ramp_bl = (mh_block_bl + mh_block_bc + mh_block_cl + mh_block_cc) / 4.0;
	if (sign(mh_block_bl - setting_island_water_level_at) != sign(mh_block_bc - setting_island_water_level_at) ||
		sign(mh_block_bl - setting_island_water_level_at) != sign(mh_block_cl - setting_island_water_level_at) ||
		sign(mh_block_bl - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) {
		mh_ramp_bl = setting_island_water_level_at + min_precipice * sign(mh_block_cc - setting_island_water_level_at);
	}
	highp float mh_ramp_br = (mh_block_br + mh_block_bc + mh_block_cr + mh_block_cc) / 4.0;
	if (sign(mh_block_br - setting_island_water_level_at) != sign(mh_block_bc - setting_island_water_level_at) ||
		sign(mh_block_br - setting_island_water_level_at) != sign(mh_block_cr - setting_island_water_level_at) ||
		sign(mh_block_br - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) {
		mh_ramp_br = setting_island_water_level_at + min_precipice * sign(mh_block_cc - setting_island_water_level_at);
	}
	// Now just mix the 4 corners to get the final mh_ramp
	highp float mh_ramp = mix(
		mix(mh_ramp_tl, mh_ramp_tr, fract(floating_sample.x)),
		mix(mh_ramp_bl, mh_ramp_br, fract(floating_sample.x)),
		fract(floating_sample.y)
	);
	// Edge case: raise centers by a bit on some close to surface cells (including islands)
	if (mh_block_cc - setting_island_water_level_at > 0.0 &&
		(int(sign(mh_block_tc - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) +
		int(sign(mh_block_bc - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) +
		int(sign(mh_block_cl - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) +
		int(sign(mh_block_cr - setting_island_water_level_at) != sign(mh_block_cc - setting_island_water_level_at)) >= 2)) {
		highp float raise_x = 1.0 - pow(2.0 * abs(0.5 - fract(floating_sample.x)), 1.5);
		highp float raise_y = 1.0 - pow(2.0 * abs(0.5 - fract(floating_sample.y)), 1.5);
		mh_ramp += mix(0.0, setting_island_water_level_step / 2.0, min(raise_x, raise_y));
	}
	return mh_ramp;
}

// Takes the noisy heightmap and makes sure it matches the input distance to surface constraints
highp float heightmap_island(highp vec2 uv_raw, highp vec2 pixel_size) {
	// Working with corners, not centers: UV requires fixing
	highp ivec2 num_cell_corners = textureSize(setting_island_water_level_distance, 0);
	highp vec2 uv_fix = uv_raw * vec2(num_cell_corners) / (vec2(num_cell_corners + 1)) + (pixel_size / 2.0) / vec2(num_cell_corners);
	highp vec2 uv_cell_float = uv_fix * vec2(num_cell_corners);
	highp ivec2 uv_cell = ivec2(uv_cell_float);

	// Get the most extreme heights allowed for this UV (above or below water level)
	highp float extreme_height_ramp = texture(setting_island_water_level_distance, uv_fix).r;


	return clamp(extreme_height_ramp, 0.0, 1.0);
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	//highp float height = noise01(uv);
	//float height = warped_noise01(uv);
	highp float height = heightmap_island(UV, TEXTURE_PIXEL_SIZE);

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