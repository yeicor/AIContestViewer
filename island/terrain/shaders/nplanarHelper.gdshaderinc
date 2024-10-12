#include "res://island/terrain/shaders/nplanar.gdshaderinc"

uniform bool nplanar_show_weights = false;

// Easy-define of optionally NPlanar textures! Requires texture_##name method (e.g. from hextiling)
#define textureNPlanarDefine(name) \
vec3 texture_nplanar_##name(vec3 vert, vec3 normal, vec2 uv_scale) { \
	vec4[3] info = nplanar_weights(vert, normal); \
	vec3 sample = vec3(0.0); \
	for (int i = 0; i < 3; i++) { \
		if (nplanar_show_weights) { \
			int id = int(info[i].z); \
			vec3 id_color = vec3(float(id % 3) / 2.0, float((id + 1) % 3) / 2.0, float((id + 2) % 3) / 2.0); \
			sample += p_normals[id] * info[i].w; \
		} else { \
			sample += texture_##name(info[i].xy * uv_scale) * info[i].w; \
		} \
	} \
	return sample; \
}
