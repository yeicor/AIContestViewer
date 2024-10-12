shader_type spatial;

// Cheap noise: https://www.shadertoy.com/view/Msf3WH MIT License
vec2 __hash( vec2 p ) // replace this by something better
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}
float noise01( in vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x);
    vec2  o = vec2(m,1.0-m);
    vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,__hash(i+0.0)), dot(b,__hash(i+o)), dot(c,__hash(i+1.0)));
    return dot( n, vec3(70.0) );
}

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;
global uniform float setting_island_water_level_step;
global uniform float setting_terrain_max_steepness;

#include "hextilingHelper.gdshaderinc"
#include "nplanarHelper.gdshaderinc"

#ifndef s_terrain_no_textures // Editor
#define s_terrain_no_textures false
#endif
#define texture_define_impl(name, color) \
vec3 texture_##name(vec2 uv) { \
	return color; \
}
#if !s_terrain_no_textures
#undef texture_define_impl
#define texture_define_impl(name, color) textureHextileDefine(name)
#endif

#define texture_define(name, color, strength_def, strength_noise_def, smooth_def) \
group_uniforms name; \
uniform vec2 name##_scale = vec2(1.0, 1.0); \
uniform float name##_strength: hint_range(0.0, 1.0) = strength_def; \
uniform float name##_strength_noise: hint_range(0.0, 10.0) = strength_noise_def; \
uniform float name##_smooth = smooth_def; \
texture_define_impl(name##_albedo, color) \
textureNPlanarDefine(name##_albedo) \
texture_define_impl(name##_normal, vec3(0, 1, 0)) \
textureNPlanarDefine(name##_normal) \
texture_define_impl(name##_ao, vec3(1.0)) \
textureNPlanarDefine(name##_ao) \
texture_define_impl(name##_roughness, vec3(1)) \
textureNPlanarDefine(name##_roughness)

texture_define(grass, vec3(0.3, 1.0, 0.3), 0.85, 0.1, 0.5)
texture_define(rock, vec3(0.5), 0.85, 0.2, 0.05)
texture_define(sand, vec3(0.7, 0.5, 0.0), 1.0, 0.5, 0.5)
uniform float sand_height: hint_range(0.0, 1.0) = 0.01; // Of max theoretical height
texture_define(snow, vec3(1.0), 1.0, 3.0, 1.5)
uniform float snow_height: hint_range(0.0, 1.0) = 0.3; // Of max theoretical height

varying vec3 _vert;
varying vec3 _normal;

void vertex() {
	// Obtain world space vertex and normal values.
	_vert = VERTEX;
	_normal = NORMAL;
}

#define texture_fragment_define(name) \
void fragment_##name(inout vec3 albedo, inout vec3 normal_map, inout float ao, inout float roughness, inout float strength, float strength_raw, vec3 vert, vec3 normal) { \
	float strength_noisy = strength_raw + noise01(vert.xz * vec2(0.1)) * name##_strength_noise; \
	float strength_smooth = 1.0 - smoothstep(0.0, 1.0, ((1.0 - name##_strength) - strength_noisy) / name##_smooth); \
	strength *= strength_smooth; \
	albedo += strength * texture_nplanar_##name##_albedo(vert, normal, name##_scale); \
	normal_map += strength * texture_nplanar_##name##_normal(vert, normal, name##_scale); \
	ao += strength * texture_nplanar_##name##_ao(vert, normal, name##_scale).r; \
	roughness += strength * texture_nplanar_##name##_roughness(vert, normal, name##_scale).r; \
}

texture_fragment_define(grass)
texture_fragment_define(rock)
texture_fragment_define(sand)
texture_fragment_define(snow)

void fragment() {
	// Reset outputs so that smoothing is simpler...
	ALBEDO = vec3(0.0); NORMAL_MAP = vec3(0.0); AO = 0.0; ROUGHNESS = 0.0;

	// Find and apply strength of each texture
	float rockiness_raw = 1.0 - (_normal.y + 1.0) / 2.0; // 0 for XZ plane, 1 for -XZ plane
	float rock_base_strength = 1.0;
	fragment_rock(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, rock_base_strength, rockiness_raw, _vert, _normal);
	float nonrock_strength = 1.0 - rock_base_strength;
	float sand_max_height = sand_height * setting_terrain_cell_side * setting_terrain_max_steepness * min(setting_island_water_level_at, 1.0 - setting_island_water_level_at) / setting_island_water_level_step;
	float sand_strength_v = nonrock_strength;
	fragment_sand(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, sand_strength_v, sand_max_height - _vert.y, _vert, _normal);
	float snow_min_height = snow_height * setting_terrain_cell_side * setting_terrain_max_steepness * min(setting_island_water_level_at, 1.0 - setting_island_water_level_at) / setting_island_water_level_step;
	float snow_strength_v = nonrock_strength;
	fragment_snow(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, snow_strength_v, _vert.y - snow_min_height, _vert, _normal);
	float grass_strength_v = nonrock_strength - snow_strength_v - sand_strength_v;
	fragment_grass(ALBEDO, NORMAL_MAP, AO, ROUGHNESS, grass_strength_v, 1.0, _vert, _normal);

	// HACK: To highlight the game over the decorations...
	ALBEDO *= 0.33;
}
