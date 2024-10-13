shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex: filter_linear_mipmap_anisotropic;
uniform vec3 color: source_color = vec3(1.0);

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
	float sensitivity = 0.7;
	if (ALBEDO.r > 1.0 - sensitivity && ALBEDO.g + ALBEDO.b < sensitivity * 2.0) {
		ALBEDO = ALBEDO - vec3(1., 0.0, 0.0) + color; // Remove original redness with our custom color while keeping texture detail
	}
}