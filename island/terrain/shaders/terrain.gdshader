shader_type spatial;

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;

#include "hextilingHelper.gdshaderinc"
group_uniforms Grass;
uniform vec2 grass1_scale = vec2(1.0, 1.0);
textureHextileDefine(grass1_albedo)
textureHextileDefine(grass1_normal)
textureHextileDefine(grass1_ao)
textureHextileDefine(grass1_roughness)
//textureHextileDefine(grass1_displacement) // Not enough vertices for this to be worth it

varying vec3 vert;

void vertex() {
	vert = VERTEX;
}

void fragment() {
	ALBEDO = texture_grass1_albedo(vert.xz * grass1_scale);
	NORMAL_MAP = texture_grass1_normal(vert.xz * grass1_scale);
	AO = texture_grass1_ao(vert.xz * grass1_scale).r;
	ROUGHNESS = texture_grass1_roughness(vert.xz * grass1_scale).r;
	//ALBEDO.xz += fract(vert.xz * grass1_scale) - 0.5;

	if (vert.y < 0.0) ALBEDO *= 0.25;
}
