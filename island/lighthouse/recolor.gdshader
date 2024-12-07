shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex: filter_linear_mipmap_anisotropic;
uniform vec3 color_from: source_color = vec3(1.0);
uniform float sensitivity: hint_range(0.0, 1.0, 0.1) = 0.3;
uniform float sharpness: hint_range(0.0, 5.0, 0.1) = 0.5;
uniform vec3 color_to: source_color = vec3(1.0);

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
	float dist = 1.0 - dot(normalize(ALBEDO), normalize(color_from));  // Ugly :)
	float effect_strength_raw = (1.0 - dist) - (1.0 - sensitivity); // Can be negative
	float effect_strength_01 = smoothstep(0.0, 1.0, effect_strength_raw * 4.0);
	float effect_strength = pow(effect_strength_01, 1.0/sharpness);
	ALBEDO = ALBEDO * (1.0 - effect_strength) + color_to * effect_strength;
}