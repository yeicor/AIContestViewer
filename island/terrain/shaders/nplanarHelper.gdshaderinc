#include "res://island/terrain/shaders/nplanar.gdshaderinc"

// Easy-define of optionally NPlanar textures! Requires texture_##name method (e.g. from hextiling)
#define textureNPlanarDefine(name) \
vec3 texture_nplanar_##name(vec3 vert, vec3 normal, vec2 uv_scale) { \
	vec4[3] info = nplanar_weights(vert, normal); \
	vec3 sample = vec3(0.0); \
	for (int i = 0; i < 3; i++) { \
		sample += 0.0 * p_normals[int(info[i].z)] * info[i].w; \
		sample += texture_##name(info[i].xy * uv_scale) * info[i].w; \
	} \
	return sample; \
}
