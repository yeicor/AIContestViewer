shader_type spatial;

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;
global uniform float setting_terrain_max_steepness;

#include "FastNoiseLite.gdshaderinc"
global uniform int setting_common_seed;

// The raw noise [0, 1]
highp float noise01(highp vec2 uv) {
	// Setup
	fnl_state state = fnlCreateState(setting_common_seed);
	state.noise_type = FNL_NOISE_OPENSIMPLEX2;
	highp ivec2 texsize = textureSize(setting_island_water_level_distance, 0);
	state.frequency = float(texsize.x) * 0.01;
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

#include "hextilingHelper.gdshaderinc"
#include "nplanarHelper.gdshaderinc"

#define texture_define(name) \
group_uniforms name; \
uniform vec2 name##_scale = vec2(1.0, 1.0); \
textureHextileDefine(name##_albedo) \
textureNPlanarDefine(name##_albedo) \
textureHextileDefine(name##_normal) \
textureNPlanarDefine(name##_normal) \
textureHextileDefine(name##_ao) \
textureNPlanarDefine(name##_ao) \
textureHextileDefine(name##_roughness) \
textureNPlanarDefine(name##_roughness)

texture_define(grass1)
texture_define(rock1)
texture_define(sand1)
texture_define(snow1)

varying vec3 _vert;
varying vec3 _normal;

void vertex() {
	// Obtain world space vertex and normal values.
	_vert = VERTEX;
	_normal = NORMAL;
}

#define texture_fragment_define(name) \
void fragment_##name(inout vec3 albedo, inout vec3 normal_map, inout float ao, inout float roughness, vec3 vert, vec3 normal, float power) { \
	albedo += power * texture_nplanar_##name##_albedo(vert, normal, name##_scale); \
	normal_map += power * texture_nplanar_##name##_normal(vert, normal, name##_scale); \
	ao += power * texture_nplanar_##name##_ao(vert, normal, name##_scale).r; \
	roughness += power * texture_nplanar_##name##_roughness(vert, normal, name##_scale).r; \
}

texture_fragment_define(grass1)
texture_fragment_define(rock1)
texture_fragment_define(sand1)
texture_fragment_define(snow1)

void fragment() {
	// Reset outputs so that smoothing is simpler...
	ALBEDO = vec3(0.0); NORMAL_MAP = vec3(0.0); AO = 0.0; ROUGHNESS = 0.0;
	// TODO: Smoothing and noise in transitions
	if (_normal.y < 0.9) {
		fragment_rock1(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, _vert, _normal, 1.0);
	} else if (_vert.y < 0.0) {
		fragment_sand1(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, _vert, _normal, 1.0);
	} else if (_vert.y > setting_terrain_cell_side * setting_terrain_max_steepness) {
		fragment_snow1(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, _vert, _normal, 1.0);
	} else {
		fragment_grass1(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, _vert, _normal, 1.0);
	}
	// HACK: To highlight the game over the decorations...
	ALBEDO *= 0.5;
}
