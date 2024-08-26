global uniform sampler2D setting_island_water_level_distance; // Used to get the count of cells (to figure out the center)
global uniform float setting_terrain_cell_side;

vec4 _terrain_uv_common(vec2 vert_xz) {
	vec2 cell_count = vec2(textureSize(setting_island_water_level_distance, 0));
	vec2 vert_00 = vert_xz + setting_terrain_cell_side * cell_count / 2.0;
	vec2 cell_uv = vert_00 / setting_terrain_cell_side;
	return vec4(cell_uv, cell_count);
}

vec2 terrain_uv(vec2 vert_xz) {
	return _terrain_uv_common(vert_xz).xy / _terrain_uv_common(vert_xz).zw;
}

vec2 terrain_cell_uv(vec2 vert_xz) {
	return fract(_terrain_uv_common(vert_xz).xy);
}
