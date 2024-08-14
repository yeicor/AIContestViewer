shader_type canvas_item;

// Debugging
uniform bool debug_height = false;

// Modifiable noise parameters
uniform int my_seed = 42;

// Island restrictions
uniform sampler2D distance_to_water_level : hint_roughness_gray;
uniform float water_level_at: hint_range(0.0, 1.0) = 0.44;
uniform float y_level_step: hint_range(0.0, 1.0) = 0.1;

#include "FastNoiseLite.gdshaderinc"

// The raw noise [0, 1] used as a base for the island
highp float noise01(highp vec2 uv) {
	// Setup
	fnl_state state = fnlCreateState(my_seed);
	state.noise_type = FNL_NOISE_OPENSIMPLEX2;
	highp ivec2 texsize = textureSize(distance_to_water_level, 0);
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

// Takes the noisy heightmap and makes sure it matches the input distance to surface constraints
highp float heightmap_island(highp vec2 uv) {
	// This smooth noise will define the shape of the terrain
    highp float terrain_noise = noise01(uv);

	// Retrieve height levels (blocky and smooth versions, to ensure cells are respected
    highp ivec2 distance_to_water_level_size = textureSize(distance_to_water_level, 0);
	highp vec2 floating_sample = uv * vec2(distance_to_water_level_size);
	highp ivec2 block_sample = ivec2(floating_sample);
	highp float hl_block = texelFetchClamp(distance_to_water_level, block_sample, 0, distance_to_water_level_size).r;
	highp float hl = lanczos(distance_to_water_level, uv, LANCZOS_SIZE).r;
	hl = min(hl, 1.0); // Lanczos can exagerate peaks while smoothing...
	
	// Use hl_block to create hl_ramp, which help create perfectly square cells along the coast ;)
	highp float hl_block_tl = texelFetchClamp(distance_to_water_level, block_sample + ivec2(-1, -1), 0, distance_to_water_level_size).r;
	highp float hl_block_tc = texelFetchClamp(distance_to_water_level, block_sample + ivec2(0, -1), 0, distance_to_water_level_size).r;
	highp float hl_block_tr = texelFetchClamp(distance_to_water_level, block_sample + ivec2(1, -1), 0, distance_to_water_level_size).r;
	highp float hl_block_cl = texelFetchClamp(distance_to_water_level, block_sample + ivec2(-1, 0), 0, distance_to_water_level_size).r;
	highp float hl_block_cc = hl_block;
	highp float hl_block_cr = texelFetchClamp(distance_to_water_level, block_sample + ivec2(1, 0), 0, distance_to_water_level_size).r;
	highp float hl_block_bl = texelFetchClamp(distance_to_water_level, block_sample + ivec2(-1, 1), 0, distance_to_water_level_size).r;
	highp float hl_block_bc = texelFetchClamp(distance_to_water_level, block_sample + ivec2(0, 1), 0, distance_to_water_level_size).r;
	highp float hl_block_br = texelFetchClamp(distance_to_water_level, block_sample + ivec2(1, 1), 0, distance_to_water_level_size).r;
	// Gather the shared 2x2 heights with neighboring cells, forcing water_level!
	highp float min_precipice = y_level_step / 25.0; // To clearly differenciate above and below water, at the cost of "realism"
	highp float hl_ramp_tl = (hl_block_tl + hl_block_tc + hl_block_cl + hl_block_cc) / 4.0;
	if (sign(hl_block_tl - water_level_at) != sign(hl_block_tc - water_level_at) ||
		sign(hl_block_tl - water_level_at) != sign(hl_block_cl - water_level_at) ||
		sign(hl_block_tl - water_level_at) != sign(hl_block_cc - water_level_at)) {
		hl_ramp_tl = water_level_at + min_precipice * sign(hl_block_cc - water_level_at);
	}
	highp float hl_ramp_tr = (hl_block_tr + hl_block_tc + hl_block_cr + hl_block_cc) / 4.0;
	if (sign(hl_block_tr - water_level_at) != sign(hl_block_tc - water_level_at) ||
		sign(hl_block_tr - water_level_at) != sign(hl_block_cr - water_level_at) ||
		sign(hl_block_tr - water_level_at) != sign(hl_block_cc - water_level_at)) {
		hl_ramp_tr = water_level_at + min_precipice * sign(hl_block_cc - water_level_at);
	}
	highp float hl_ramp_bl = (hl_block_bl + hl_block_bc + hl_block_cl + hl_block_cc) / 4.0;
	if (sign(hl_block_bl - water_level_at) != sign(hl_block_bc - water_level_at) ||
		sign(hl_block_bl - water_level_at) != sign(hl_block_cl - water_level_at) ||
		sign(hl_block_bl - water_level_at) != sign(hl_block_cc - water_level_at)) {
		hl_ramp_bl = water_level_at + min_precipice * sign(hl_block_cc - water_level_at);
	}
	highp float hl_ramp_br = (hl_block_br + hl_block_bc + hl_block_cr + hl_block_cc) / 4.0;
	if (sign(hl_block_br - water_level_at) != sign(hl_block_bc - water_level_at) ||
		sign(hl_block_br - water_level_at) != sign(hl_block_cr - water_level_at) ||
		sign(hl_block_br - water_level_at) != sign(hl_block_cc - water_level_at)) {
		hl_ramp_br = water_level_at + min_precipice * sign(hl_block_cc - water_level_at);
	}
	// Now just mix the 4 corners to get the final hl_ramp
	highp float hl_ramp = mix(
		mix(hl_ramp_tl, hl_ramp_tr, fract(floating_sample.x)),
		mix(hl_ramp_bl, hl_ramp_br, fract(floating_sample.x)),
		fract(floating_sample.y)
	);
	// Finally perfectly square cells along the coast!
	highp float smooth_y_level = y_level_step / 3.0;
	highp float smooth_strength = max(0.0, 1.0 - (abs(hl_ramp - water_level_at) - min_precipice) / smooth_y_level);
	hl = mix(hl, hl_ramp, pow(smooth_strength, 0.75));
	
	// TODO: Add noise to create some precipices for a more interesting coast, specially for flat areas.

	// Now we must ensure the actual height respects the maximum distance to water level!
	highp float from = water_level_at + min_precipice * sign(hl - water_level_at);
    highp float height = mix(from, hl, terrain_noise);
	//height = terrain_noise;

	return height;
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	//highp float height = noise01(UV);
	//float height = warped_noise01(UV);
	highp float height = heightmap_island(UV);
	
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
		if (height < water_level_at) {
	        COLOR.b += 0.2;
	    } else {
			COLOR.g += 0.2;
		}
	} else {
		// This is a hack to get higher-precision height values (avoid stairs when using lots of vertices)
		const highp float precision = 256.0;
		COLOR.xy = vec2(
			fract(floor(height * precision) / precision), 
			fract(floor(height * precision * precision) / precision)
		);
	}
}