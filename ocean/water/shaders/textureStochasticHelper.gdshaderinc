// Auto-include textureStochastic based on global defines
#ifndef s_common_stochastic_textures // Editor-only, allow setting all uniforms
#define s_common_stochastic_textures true // And default to stochastic
#define s_common_stochastic_textures_editor true // Running on editor
#endif
#ifndef s_common_stochastic_textures_editor
#define texture_stochastic_enable_df
#endif
#if s_common_stochastic_textures
#include "res://ocean/water/shaders/textureStochastic.gdshaderinc"
#endif

// Easy-define of optionally stochastic textures with automatic fallback if disabled!
#define _textureStochasticDefine_enabled(name) \
uniform sampler2D name##_t : filter_linear_mipmap_anisotropic; \
uniform sampler2D name##_inv_t : filter_linear_mipmap_anisotropic; \
uniform vec3 name##_color_space_origin; \
uniform vec3 name##_color_space_vector1; \
uniform vec3 name##_color_space_vector2; \
uniform vec3 name##_color_space_vector3; \
vec3 texture_##name(vec2 uv) { \
	return textureStochastic(name##_t, name##_inv_t, uv, \
	name##_color_space_origin, name##_color_space_vector1, \
	name##_color_space_vector2, name##_color_space_vector3); \
}

#define _textureStochasticDefine_editor(name) \
uniform sampler2D name : filter_linear_mipmap_anisotropic; \
_textureStochasticDefine_enabled(name)

#define _textureStochasticDefine_disabled(name) \
uniform sampler2D name : filter_linear_mipmap_anisotropic; \
vec3 texture_##name(vec2 uv) { \
	return texture(name, uv).rgb; \
}

#if s_common_stochastic_textures_editor // Stochastic editor
#define textureStochasticDefine(name) _textureStochasticDefine_editor(name)
#elif s_common_stochastic_textures // Stochastic enabled
#define textureStochasticDefine(name) _textureStochasticDefine_enabled(name)
#else // Stochastic disabled
#define textureStochasticDefine(name) _textureStochasticDefine_disabled(name)
#endif
