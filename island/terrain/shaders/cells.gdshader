shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "cells.gdshaderinc"

global uniform float setting_island_water_level_at;
global uniform sampler2D setting_island_energymap : hint_roughness_gray, filter_linear;

uniform float cell_border_scale : hint_range(0.0, 5.0, 0.1) = 2.0f; // Size of the border of each cell
uniform vec4 above_water_color : source_color = vec4(vec3(0.75), 1.0);
uniform vec4 below_water_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

uniform vec3 bb_half = vec3(10.0); // Assume centered on 0 (except for max height being y)

varying vec3 vert;
void vertex() {
	// Push corner vertices to "infinity" to avoid ocean transparency weirdness
	if (abs(VERTEX.x) + 1e-2 >= bb_half.x || abs(VERTEX.z) + 1e-2 > bb_half.z) {
		VERTEX.xz *= 100.0;
	}
	if (abs(VERTEX.x) + 1e-2 >= bb_half.x*0.95 || abs(VERTEX.z) + 1e-2 > bb_half.z*0.95) {
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
	vert = VERTEX;
}

void fragment() {
	// FIXME: Automatic line width based on distance? Won't work on web, but may fix aliasing...
	// Use the cells to override the color of the terrain and draw the square borders
	vec4 uv_data = _terrain_uv_common(vert.xz);

	// Compute anti-aliased world-space grid lines using screen-space derivatives!
	vec2 grid = abs(fract(uv_data.xy - 0.5) - 0.5) / fwidth(uv_data.xy) / cell_border_scale;
	float lines = clamp(1.0 - min(grid.x, grid.y), 0.0, 1.0);

	// Is the line boundary above water o at water level?
	bool cell_above_water = texelFetch(setting_island_water_level_distance, 
	cell_to_corner(ivec2(uv_data.xy)), 0).r > setting_island_water_level_at;
	bool oob = uv_data.x < 0.0 || uv_data.x > uv_data.z || uv_data.y < 0.0 || uv_data.y > uv_data.w;
	cell_above_water = cell_above_water && !oob;
	
	// Edit edge_color and lines based on conditions
	vec4 edge_color = above_water_color * float(cell_above_water) + below_water_color * float(!cell_above_water);
	lines = lines * float(!oob);

	// Get the energy of the cell to highlight the ones with more
	float energy = texelFetch(setting_island_energymap, ivec2(uv_data.xy), 0).r;

	// Compute final color
    ALBEDO = lines * edge_color.rgb + (1.0 - lines) * vec3(0.0);
	if (lines > 0.1) {
		ALPHA = (lines - 0.1) / 0.9;
	} else {
		ALPHA = 0.75 * (1.0 - energy);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
