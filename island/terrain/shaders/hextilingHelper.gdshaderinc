// Auto-include textureHextile based on global defines (inherit stochastic ones!)
#ifndef s_common_stochastic_textures // Editor-only, allow setting all uniforms
#define s_common_stochastic_textures true // And default to hextile
#define s_common_stochastic_textures_editor true // Running on editor
#endif
#ifndef s_common_stochastic_textures_editor
#define texture_hextile_enable_df
#endif
#if s_common_stochastic_textures
#include "res://island/terrain/shaders/hextiling.gdshaderinc"
#endif

// Easy-define of optionally hextile textures with automatic fallback if disabled!
#define _textureHextileDefine_enabled(name) \
uniform sampler2D name : filter_linear_mipmap_anisotropic; \
vec3 texture_##name(vec2 uv) { \
	vec4 temp_samp; \
	vec3 weights; \
	hex2colTex(temp_samp, weights, name, uv, 1.0, 0.5); \
	return temp_samp.rgb; \
}

#define _textureHextileDefine_editor(name) _textureHextileDefine_enabled(name)

#define _textureHextileDefine_disabled(name) \
uniform sampler2D name : filter_linear_mipmap_anisotropic; \
vec3 texture_##name(vec2 uv) { \
	return texture(name, uv).rgb; \
}

#if s_common_stochastic_textures_editor // Hextile editor
#define textureHextileDefine(name) _textureHextileDefine_disabled(name)
#elif s_common_stochastic_textures // Hextile enabled
#define textureHextileDefine(name) _textureHextileDefine_enabled(name)
#else // Hextile disabled
#define textureHextileDefine(name) _textureHextileDefine_disabled(name)
#endif
