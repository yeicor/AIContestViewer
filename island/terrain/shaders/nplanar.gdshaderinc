// Inspired by https://godotshaders.com/shader/dodecahedral-multi-planar-projection/
//   MIT License Copyright 2024 Emerson Rowland

group_uniforms NPlanar;
uniform vec3 p_normals[10];
uniform int p_normals_count;
uniform float blend_sharpness: hint_range(0.00001, 10.0) = 1.0;

#ifndef rendering_method
#define rendering_method "gl_compatibility"
#endif
#if rendering_method == "gl_compatibility"
#define fma(a, b, c) a * b + c
#endif

// Derived from https://iquilezles.org/articles/noacos/ MIT license - Inigo Quilez 2013
mat3 p_align(vec3 normal) {
	const vec3 up = vec3(0., 1., 0.);
	if (dot(up, normal) < -0.999) {
		normal *= -1.0;
	}
	vec3 v = cross(up, normal);
	float c = dot(up, normal);
	float k = 1.0 / (1.0 + c);

	float vxy = v.x * v.y;
	float vxz = v.x * v.z;
	float vyz = v.y * v.z;

	return mat3(
		vec3(fma(v.x * v.x, k, c), fma(vxy, k, -v.z), fma(vxz, k, v.y)),
		vec3(fma(vxy, k, v.z), fma(v.y * v.y, k, c), fma(vyz, k, -v.x)),
		vec3(fma(vxz, k, -v.y), fma(vyz, k, v.x), fma(v.z * v.z, k, c))
	);
}

// Returns tuples of UV, plane index and normalized weight to apply
vec4[3] nplanar_weights(vec3 vert, vec3 normal) {
	vec4[3] res = { vec4(0.0), vec4(0.0), vec4(0.0) };
	// Determine 1st, 2nd & 3rd Nearest Faces, and their unnormalized weights
    for (int i = 0; i < p_normals_count; i++) {
		float alignment = abs(dot(normal, p_normals[i]));
		if (alignment > res[0].w) {
			res[2] = res[1];
			res[1] = res[0];
			res[0] = vec4(0.0, 0.0, float(i), alignment);
		} else if (alignment > res[1].w) {
			res[2] = res[1];
			res[1] = vec4(0.0, 0.0, float(i), alignment);
		} else if (alignment > res[2].w) {
			res[2] = vec4(0.0, 0.0, float(i), alignment);
		}
	}

	// Compute the UVs for the selected faces
	for (int i = 0; i < 3; i++) {
		res[i].xy = (p_align(p_normals[int(res[i].z)]) * vert).xz;
	}

	// Post-process weights to ensure they sum to 1 and follow the blend sharpness
	float sum = 0.0;
	for (int i = 0; i < 3; i++) {
		res[i].w = max(0.0, pow(res[i].w, blend_sharpness));
		sum += res[i].w;
	}
	if (sum > 0.0) {
		for (int i = 0; i < 3; i++) {
			res[i].w /= sum;
		}
	}

	return res;
}
