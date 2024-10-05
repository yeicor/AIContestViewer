shader_type spatial;

uniform vec3 grass : source_color;
uniform vec3 sand : source_color;

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;

#include "res://island/terrain/shaders/textureStochasticHelper.gdshaderinc"
group_uniforms Grass;
uniform vec2 grass1_scale = vec2(1.0, 1.0);
textureStochasticDefine(grass1_albedo)
textureStochasticDefine(grass1_normal)
textureStochasticDefine(grass1_ao)
textureStochasticDefine(grass1_roughness)
//textureStochasticDefine(grass1_displacement) // Not enough vertices for this to be worth it

varying vec3 vert;

void vertex() {
	vert = VERTEX;
}

void fragment() {
	ALBEDO = texture_grass1_albedo(vert.xz * grass1_scale);
	NORMAL_MAP = texture_grass1_normal(vert.xz * grass1_scale);
	AO = texture_grass1_ao(vert.xz * grass1_scale).r;
	ROUGHNESS = texture_grass1_roughness(vert.xz * grass1_scale).r;
}
