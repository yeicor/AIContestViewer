global uniform sampler2D setting_island_water_level_distance; // Used to get the count of cells (to figure out the center)
global uniform float setting_terrain_cell_side;

vec4 _terrain_uv_common(vec2 vert_xz) {
	ivec2 cell_corner_count = textureSize(setting_island_water_level_distance, 0);
	vec2 cell_count = vec2(cell_corner_count) / 2.0 - 0.5;
	vec2 vert_00 = vert_xz + setting_terrain_cell_side * cell_count / 2.0;
	vec2 cell_uv = vert_00 / setting_terrain_cell_side;
	return vec4(cell_uv, cell_count);
}

vec2 terrain_uv(vec2 vert_xz) {
	vec4 common = _terrain_uv_common(vert_xz);
	return common.xy / common.zw;
}

vec2 terrain_cell_uv(vec2 vert_xz) {
	return fract(_terrain_uv_common(vert_xz).xy);
}

ivec2 cell_to_corner(ivec2 cell) {
	return 2 * cell + 1;
}
