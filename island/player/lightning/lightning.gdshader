// MIT License https://godotshaders.com/shader/2d-lightning-electric-arc-plasma/
// Modified

shader_type spatial;
render_mode cull_disabled;

group_uniforms line;
uniform sampler2D color_gradient : repeat_disable;
uniform vec3 color : source_color = vec3(1.0);
uniform int passes: hint_range(1, 15) = 1;
uniform float pass_angle: hint_range(0, 360) = 60;

group_uniforms noise;
uniform sampler2D noise_texture;
uniform float speed: hint_range (-15.0,15.0) = 3;
uniform float variation: hint_range (0.0,1.0) = 1.0;
uniform float width: hint_range (0.0,10.0) = 0.1;

group_uniforms fixCorners;
uniform float start_freedom: hint_range (0.0,1.0) = 0.0;
uniform float end_freedom: hint_range (0.0,1.0) = 1.0;

vec2 rotateUV(vec2 uv, float rotation) {
    float mid = 0.5;
    return vec2(
        cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
        cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
    );
}

void fragment(){
	ALBEDO = vec3(0.0);
	for (int i = 0; i < passes; i++) {
		float cur_angle = pass_angle * float(i) / 180.0 * PI;
		vec2 uv = UV;
		vec2 rotated_uv = rotateUV(UV, cur_angle);

		vec2 noise_uv = abs(mod(uv + vec2(-TIME + float(i) * 0.123, TIME / 4.0 + float(i) * 0.321) * speed, 2.0) - 1.0);
		float noise_sample = texture(noise_texture, noise_uv).r;
		float glow_sample = texture(noise_texture, noise_uv / 3.0).r; // Less inner variation

		float centered_line = (rotated_uv.y - 0.5) / width + 0.5;
		float line_offset = (noise_sample - 0.5) * variation / width;

		float sample_at = centered_line + line_offset;
		sample_at = mix(centered_line, sample_at, clamp(rotated_uv.x * 2.0 + start_freedom, 0.0, 1.0));
		sample_at = mix(centered_line, sample_at,  clamp((1.0 - rotated_uv.x) * 2.0 + end_freedom, 0.0, 1.0));

		ALBEDO += color * texture(color_gradient, vec2(sample_at, sample_at)).rgb;
		if (length(ALBEDO) > 0.1) {
			ALBEDO *= (3.0 + mod(TIME * speed * 3.0, 2.0) * glow_sample) / length(ALBEDO);
		}
	}
	ALPHA = clamp(length(ALBEDO.rgb), 0.0, 1.0);
}