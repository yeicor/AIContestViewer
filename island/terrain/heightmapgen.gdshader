shader_type canvas_item;

// Generic parameters
uniform float freq = 1.0;
uniform float seed = 42.0;

// Island restrictions
uniform sampler2D distance_to_water_level : hint_roughness_gray;
uniform float water_level_at : hint_range(0.0, 1.0, 0.1) = 0.44;

// Returns a pseudo-random value between 0.0 and 1.0
float noise (vec3 p) {
	return fract(sin(dot(p, vec3(95.43583, 93.323197, 94.993431))) * 43758.5453);
}

// Returns a pseudo-random value between 0.0 and 1.0, using smooth perlin noise
float perlin_a (vec3 p) {
    vec3 base = floor(p * 64.0) * 0.015625;
    vec3 dd = vec3(0.015625, 0.0, 0.0);
    float a = noise(base);
    float b = noise(base + dd.xyy);
    float c = noise(base + dd.yxy);
    float d = noise(base + dd.xxy);
    vec3 dp = (p - base) * 64.0;
    float t = mix(a, b, dp.x);
    float tt = mix(c, d, dp.x);
    return mix(t, tt, dp.y);
}

// Returns a pseudo-random value between 0.0 and 1.0, using smooth perlin noise
float perlin_b (vec3 p) {
    vec3 base = vec3(p.x, p.y, floor(p.z * 64.0) * 0.015625);
    vec3 dd = vec3(0.015625, 0.0, 0.0);
    vec3 dp = (p - base) *  64.0;
    float front = perlin_a(base + dd.yyy);
    float back = perlin_a(base + dd.yyx);
    return mix(front, back, dp.z);
}

// Returns a pseudo-random value between 0.0 and 1.0, using octaves for a more natural look with more detail
float fbm(vec3 p) {
#define OCTAVES 5
    float total = 0.0;
    float m1 = 1.0;
    float m2 = 1.0 / pow(OCTAVES, 2.1);  // Precision issue?
    for (int i = 0; i < OCTAVES; i++) {
        total += perlin_b(p * m1) * m2;
        m2 *= 2.0;
        m1 *= 0.5;
    }
    return total;
}

// Returns a pseudo-random value between 0.0 and 1.0, using domain-warping for an even more natural look
float heightmap_raw (vec3 p) { // p is the position (x, y) and the seed (z)
	// First dimension of domain warping
    vec3 q = vec3(fbm(p), 
		fbm(p + vec3(fbm(vec3(p.z + 1.0)) * 10.0, fbm(vec3(p.z + 2.0)) * 10.0, fbm(vec3(p.z + 3.0)) * 10.0)),
		fbm(p + vec3(fbm(vec3(p.z + 4.0)) * 10.0, fbm(vec3(p.z + 5.0)) * 10.0, fbm(vec3(p.z + 6.0)) * 10.0)));
	// Second dimension of domain warping
    vec3 r = vec3(fbm(p + 4.0*q),
        fbm(p + 4.0*q + vec3(fbm(vec3(p.z + 7.0)) * 10.0, fbm(vec3(p.z + 8.0)) * 10.0, fbm(vec3(p.z + 9.0)) * 10.0)),
        fbm(p + 4.0*q + vec3(fbm(vec3(p.z + 10.0)) * 10.0, fbm(vec3(p.z + 11.0)) * 10.0, fbm(vec3(p.z + 12.0)) * 10.0)));
    return fbm( p + 4.0*q );
}

// Takes heightmap_raw and makes sure it matches the input distance to surface constraints
float heightmap_island(vec3 p, vec2 uv) {
	float raw = heightmap_raw(p);
	float height_limit = textureLod(distance_to_water_level, uv, 0).r;
    // Now ensure that the raw heightmap falls above or below the water level and within the height limit
    float limit_above_by = height_limit - water_level_at;
    return water_level_at + raw * limit_above_by;
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	vec2 pos_ratio = UV * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	float height = heightmap_island(vec3(pos_ratio.xy * freq, seed / 1000.0), UV);
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
}