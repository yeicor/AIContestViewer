shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform ivec2 cells = ivec2(21, 18); // Number of cells in the terrain TODO: Texture with more cell info!
uniform vec2 cell_size = vec2(10, 10); // Size of each cells in the terrain
uniform float cell_border = 0.01f; // Size of the border of each cell

uniform vec3 above_water_color : source_color = vec3(0.75);
uniform vec3 below_water_color : source_color = vec3(0.0);

varying vec3 vert;
void vertex() {
	vert = VERTEX;
}

void fragment() {
	// Use the cells to override the color of the terrain and draw the square borders
	vec2 cell_uv_fract = fract(vert.xz / cell_size - mod(vec2(cells), vec2(2.0)) / 2.0);
	float not_border_factor = 1.0 - step(cell_border / 2.0, cell_uv_fract.x) * step(cell_border / 2.0, cell_uv_fract.y) * step(cell_uv_fract.x, 1.0 - cell_border / 2.0) * step(cell_uv_fract.y, 1.0 - cell_border / 2.0);
    ALBEDO = step(0.0, vert.y) * above_water_color + (1.0 - step(0.0, vert.y)) * below_water_color;
	ALPHA = not_border_factor;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
