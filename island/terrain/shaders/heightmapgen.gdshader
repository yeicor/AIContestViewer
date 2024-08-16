shader_type canvas_item;

// Debugging
uniform bool debug_height = false;

// Modifiable noise parameters
uniform int my_seed = 42;

// Island restrictions
uniform sampler2D distance_to_water_level : hint_roughness_gray;
uniform float water_level_at: hint_range(0.0, 1.0) = 0.44;
uniform float y_level_step: hint_range(0.0, 1.0) = 0.1;
uniform vec2 min_precipice_range = vec2(0.01, 0.2);

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

// Gets the custom non-smooth ramp-like max height. Useful for a proper blocky coastline!
highp float max_height_ramp(highp vec2 uv, highp sampler2D distance_to_water_level_, highp ivec2 distance_to_water_level_size, highp ivec2 block_sample, highp vec2 floating_sample) {
	// Use mh_block to create mh_ramp, which help create perfectly square cells along the coast ;)
	highp float mh_block_tl = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(-1, -1), 0, distance_to_water_level_size).r;
	highp float mh_block_tc = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(0, -1), 0, distance_to_water_level_size).r;
	highp float mh_block_tr = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(1, -1), 0, distance_to_water_level_size).r;
	highp float mh_block_cl = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(-1, 0), 0, distance_to_water_level_size).r;
	highp float mh_block_cc = texelFetchClamp(distance_to_water_level_, block_sample, 0, distance_to_water_level_size).r;
	highp float mh_block_cr = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(1, 0), 0, distance_to_water_level_size).r;
	highp float mh_block_bl = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(-1, 1), 0, distance_to_water_level_size).r;
	highp float mh_block_bc = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(0, 1), 0, distance_to_water_level_size).r;
	highp float mh_block_br = texelFetchClamp(distance_to_water_level_, block_sample + ivec2(1, 1), 0, distance_to_water_level_size).r;
	// Gather the shared 2x2 heights with neighboring cells, forcing water_level!
	highp float min_precipice = y_level_step / 25.0; // To clearly differenciate above and below water, at the cost of "realism"
	highp float mh_ramp_tl = (mh_block_tl + mh_block_tc + mh_block_cl + mh_block_cc) / 4.0;
	if (sign(mh_block_tl - water_level_at) != sign(mh_block_tc - water_level_at) ||
		sign(mh_block_tl - water_level_at) != sign(mh_block_cl - water_level_at) ||
		sign(mh_block_tl - water_level_at) != sign(mh_block_cc - water_level_at)) {
		mh_ramp_tl = water_level_at + min_precipice * sign(mh_block_cc - water_level_at);
	}
	highp float mh_ramp_tr = (mh_block_tr + mh_block_tc + mh_block_cr + mh_block_cc) / 4.0;
	if (sign(mh_block_tr - water_level_at) != sign(mh_block_tc - water_level_at) ||
		sign(mh_block_tr - water_level_at) != sign(mh_block_cr - water_level_at) ||
		sign(mh_block_tr - water_level_at) != sign(mh_block_cc - water_level_at)) {
		mh_ramp_tr = water_level_at + min_precipice * sign(mh_block_cc - water_level_at);
	}
	highp float mh_ramp_bl = (mh_block_bl + mh_block_bc + mh_block_cl + mh_block_cc) / 4.0;
	if (sign(mh_block_bl - water_level_at) != sign(mh_block_bc - water_level_at) ||
		sign(mh_block_bl - water_level_at) != sign(mh_block_cl - water_level_at) ||
		sign(mh_block_bl - water_level_at) != sign(mh_block_cc - water_level_at)) {
		mh_ramp_bl = water_level_at + min_precipice * sign(mh_block_cc - water_level_at);
	}
	highp float mh_ramp_br = (mh_block_br + mh_block_bc + mh_block_cr + mh_block_cc) / 4.0;
	if (sign(mh_block_br - water_level_at) != sign(mh_block_bc - water_level_at) ||
		sign(mh_block_br - water_level_at) != sign(mh_block_cr - water_level_at) ||
		sign(mh_block_br - water_level_at) != sign(mh_block_cc - water_level_at)) {
		mh_ramp_br = water_level_at + min_precipice * sign(mh_block_cc - water_level_at);
	}
	// Now just mix the 4 corners to get the final mh_ramp
	highp float mh_ramp = mix(
		mix(mh_ramp_tl, mh_ramp_tr, fract(floating_sample.x)),
		mix(mh_ramp_bl, mh_ramp_br, fract(floating_sample.x)),
		fract(floating_sample.y)
	);
	// Edge case: raise centers by a bit on some close to surface cells (including islands)
	if (mh_block_cc - water_level_at > 0.0 &&
		(int(sign(mh_block_tc - water_level_at) != sign(mh_block_cc - water_level_at)) +
		int(sign(mh_block_bc - water_level_at) != sign(mh_block_cc - water_level_at)) +
		int(sign(mh_block_cl - water_level_at) != sign(mh_block_cc - water_level_at)) +
		int(sign(mh_block_cr - water_level_at) != sign(mh_block_cc - water_level_at)) >= 2)) {
		highp float raise_x = 1.0 - pow(2.0 * abs(0.5 - fract(floating_sample.x)), 1.5);
		highp float raise_y = 1.0 - pow(2.0 * abs(0.5 - fract(floating_sample.y)), 1.5);
		mh_ramp += mix(0.0, y_level_step / 2.0, min(raise_x, raise_y));
	}
	return mh_ramp;
}

// Takes the noisy heightmap and makes sure it matches the input distance to surface constraints
highp float heightmap_island(highp vec2 uv) {
	// This smooth noise will define the shape of the terrain
    highp float terrain_noise = noise01(uv);

	// Basics about the 
    highp ivec2 distance_to_water_level_size = textureSize(distance_to_water_level, 0);
	highp vec2 floating_sample = uv * vec2(distance_to_water_level_size);
	highp ivec2 block_sample = ivec2(floating_sample);

	// Retrieve height levels (blocky and smooth versions, to ensure cells are respected
	highp float mh = lanczos(distance_to_water_level, uv, LANCZOS_SIZE).r;
	mh = min(mh, 1.0); // Lanczos can exagerate peaks while smoothing...
	highp float mh_ramp = max_height_ramp(uv, distance_to_water_level, distance_to_water_level_size, block_sample, floating_sample);
	
	// Perfectly square cells along the coast thanks to mh_ramp!
	highp float smooth_y_level = y_level_step / 2.0;
	highp float smooth_strength = max(0.0, 1.0 - (abs(mh_ramp - water_level_at) - min_precipice_range.x) / smooth_y_level);
	mh = mix(mh, mh_ramp, pow(smooth_strength, 0.75));
	
	// Add noise to create some precipices for a more interesting coast, specially for flat areas.
	highp float precipice_noise = noise01(uv + vec2(16.4, -45.2)); // Different noise
	const highp float precipice_min_noise_value = 0.6; // Avoid constant precipices
	precipice_noise = max(precipice_noise - precipice_min_noise_value, 0.0) / (1.0 - precipice_min_noise_value);
	highp float minh = water_level_at + 
	(precipice_noise * (min_precipice_range.y - min_precipice_range.x) + min_precipice_range.x) 
	* sign(mh_ramp - water_level_at);
	//mh = clamp(minh + mh * sign(mh_ramp - water_level_at), 0.0, 1.0);

	// Now we must ensure the actual height respects the maximum distance to water level!
    highp float height = mix(minh, mh, terrain_noise);
	height = mod(max(uv.x * 21.0, uv.y * 18.0), 1.0)*y_level_step;

	return height;
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	// Displace the island based on the screen pixel size...
	highp vec2 uv = UV;// - vec2(SCREEN_PIXEL_SIZE.x/2.0, SCREEN_PIXEL_SIZE.y/4.0);
	//highp float height = noise01(UV);
	//float height = warped_noise01(UV);
	highp float height = heightmap_island(uv);
	
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