shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "cells.gdshaderinc"

uniform float cell_border = 0.01f; // Size of the border of each cell
uniform vec3 above_water_color : source_color = vec3(0.75);
uniform vec3 below_water_color : source_color = vec3(0.0);

varying vec3 vert;
void vertex() {
	vert = VERTEX;
}

void fragment() {
	// FIXME: Automatic line width based on distance? Won't work on web, but may fix aliasing...
	// Use the cells to override the color of the terrain and draw the square borders
	vec2 cell_uv_fract = terrain_cell_uv(vert.xz);
	float not_border_factor = 1.0 - step(cell_border / 2.0, cell_uv_fract.x) * step(cell_border / 2.0, cell_uv_fract.y) * step(cell_uv_fract.x, 1.0 - cell_border / 2.0) * step(cell_uv_fract.y, 1.0 - cell_border / 2.0);
    ALBEDO = step(0.0, vert.y) * above_water_color + (1.0 - step(0.0, vert.y)) * below_water_color;
	ALPHA = not_border_factor;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
