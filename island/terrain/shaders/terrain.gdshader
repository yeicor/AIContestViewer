shader_type spatial;

#include "cells.gdshaderinc"
global uniform float setting_island_water_level_at;

#include "hextilingHelper.gdshaderinc"
#include "nplanarHelper.gdshaderinc"
group_uniforms Grass;
uniform vec2 grass1_scale = vec2(1.0, 1.0);
textureHextileDefine(grass1_albedo)
textureNPlanarDefine(grass1_albedo)
textureHextileDefine(grass1_normal)
textureNPlanarDefine(grass1_normal)
textureHextileDefine(grass1_ao)
textureNPlanarDefine(grass1_ao)
textureHextileDefine(grass1_roughness)
textureNPlanarDefine(grass1_roughness)

varying vec3 vert;
varying vec3 normal;

void vertex() {
	// Obtain world space vertex and normal values.
	vert = VERTEX;
	normal = NORMAL;
}

void fragment() {
	ALBEDO = texture_nplanar_grass1_albedo(vert, normal, grass1_scale);
	NORMAL_MAP = texture_nplanar_grass1_normal(vert, normal, grass1_scale);
	AO = texture_nplanar_grass1_ao(vert, normal, grass1_scale).r;
	ROUGHNESS = texture_nplanar_grass1_roughness(vert, normal, grass1_scale).r;

	if (vert.y < 0.0) ALBEDO *= 0.25;
}
