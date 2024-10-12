shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "cells.gdshaderinc"

global uniform float setting_island_water_level_at;

uniform float cell_border_scale : hint_range(0.0, 5.0, 0.1) = 1.0f; // Size of the border of each cell
uniform vec4 above_water_color : source_color = vec4(vec3(0.75), 1.0);
uniform vec4 below_water_color : source_color = vec4(0.5, 0.0, 0.0, 0.0);

varying vec3 vert;
void vertex() {
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
	bool cell_above_water =
	texelFetch(setting_island_water_level_distance, cell_to_corner(ivec2(uv_data.xy)), 0).r > setting_island_water_level_at;
	bool oob = uv_data.x < 0.0 || uv_data.x > uv_data.z || uv_data.y < 0.0 || uv_data.y > uv_data.w;
	cell_above_water = cell_above_water && !oob;

	vec4 full_color = cell_above_water ? above_water_color : below_water_color;
    ALBEDO = full_color.rgb;
	ALPHA = lines * full_color.a;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
