// MIT License https://godotshaders.com/shader/2d-lightning-electric-arc-plasma/
// Modified

shader_type canvas_item;

group_uniforms line;
uniform sampler2D color_gradient;

group_uniforms noise;
uniform sampler2D noiseTexture;
uniform float speed: hint_range (-5.0,5.0) = 2;
uniform float variation: hint_range (0.0,1.0) = 0.5;
uniform float width: hint_range (0.0,1.0) = 0.15;

group_uniforms fixCorners;
uniform float startFreedom: hint_range (0.0,1.0) = 0.0;
uniform float endFreedom: hint_range (0.0,1.0) = 1.0;

void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 noise_uv = abs(mod(uv + vec2(-TIME, TIME / 4.0) * speed, 2.0) - 1.0);
	float noise_sample = texture(noiseTexture, noise_uv).r;
	float glow_sample = texture(noiseTexture, noise_uv / 3.0).r; // Less inner variation
	
	float centered_line = (uv.y-0.5)/width + 0.5;
	float line_offset = (noise_sample - 0.5) * variation / width;
	
	float sample_at = centered_line + line_offset;
	sample_at = mix(centered_line, sample_at, clamp(uv.x + startFreedom, 0.0, 1.0));
	sample_at = mix(centered_line, sample_at,  clamp((1.0 - uv.x) + endFreedom, 0.0, 1.0));
	
	COLOR = texture(color_gradient, vec2(sample_at, sample_at));
	COLOR.rgb *= 0.7 + mod(TIME, 0.3) + glow_sample;
	COLOR.a = length(COLOR.rgb);
}