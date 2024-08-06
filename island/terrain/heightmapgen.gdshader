shader_type canvas_item;

// Noise parameters
uniform sampler2D noise : source_color;

// Island restrictions
uniform sampler2D distance_to_water_level : hint_roughness_gray;
uniform float water_level_at : hint_range(0.0, 1.0, 0.1) = 0.44;

// Takes the noisy heightmap and makes sure it matches the input distance to surface constraints
float heightmap_island(vec2 uv) {
	float height = texture(noise, uv).r;
	float height_limit_or = texture(distance_to_water_level, uv).r;
	float height_limit = height_limit_or;
	// FIXME: Smooth out crazy peaks by smoothing the height_limit with neighboring ones?
	height_limit += texture(distance_to_water_level, uv + vec2(0.1, 0)).r;
	height_limit += texture(distance_to_water_level, uv + vec2(-0.1, 0)).r;
	height_limit += texture(distance_to_water_level, uv + vec2(0, 0.1)).r;
	height_limit += texture(distance_to_water_level, uv + vec2(0, -0.1)).r;
	height_limit /= 5.0;
	if (sign(height_limit_or - water_level_at) != sign(height_limit - water_level_at)) {
		height_limit = water_level_at + 0.05 * sign(height_limit_or - water_level_at);
	}
	return water_level_at + height * (height_limit - water_level_at);
}

// Generates the output texture, that defines the heightmap for the terrain
void fragment() {
	float height = heightmap_island(UV);
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