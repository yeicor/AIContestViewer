shader_type spatial;

uniform vec3 grass : source_color;
uniform vec3 sand : source_color;

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;

varying vec3 vert;

void vertex() {
	vert = VERTEX;
}

void fragment() {
	vec4 uv_data = _terrain_uv_common(vert.xz);
	float cell_above_water_by = texelFetch(setting_island_water_level_distance, ivec2(uv_data.xy), 0).r - setting_island_water_level_at;

	// Called for every pixel the material is visible on.
	if (cell_above_water_by >= 0.0) {
	    ALBEDO = grass;
	} else {
		ALBEDO = sand;
	}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
