shader_type spatial;

uniform vec3 grass : source_color;
uniform vec3 sand : source_color;

uniform ivec2 cells = ivec2(21, 18); // Number of cells in the terrain TODO: Texture with more cell info!
uniform vec2 cell_size = vec2(10, 10); // Size of each cells in the terrain
uniform float cell_border = 0.1f; // Size of the border of each cell

varying vec3 vert;

vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 uv_index = floor(uv);
    vec2 uv_fract = fract(uv);

    vec2 blur = smoothstep(0.0, 1.0, uv_fract);

    return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
                     dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
                mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
                     dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) + 0.5;
}

void vertex() {
	vert = VERTEX;
}

void fragment() {
	// Called for every pixel the material is visible on.
	if (vert.y >= 0.0) {
	    ALBEDO = grass;
	} else {
		ALBEDO = sand;
	}
	ALBEDO += vec3(noise(vert.yz*10.0), noise(vert.xz*10.0), noise(vert.xy*10.0)) * 0.1;

	// Use the cells to override the color of the terrain and draw the square borders
	vec2 cell_uv_fract = fract(vert.xz / cell_size - mod(vec2(cells), vec2(2.0)) / 2.0);
	float border_factor = 1.0 - step(cell_border, cell_uv_fract.x) * step(cell_border, cell_uv_fract.y) * step(cell_uv_fract.x, 1.0 - cell_border) * step(cell_uv_fract.y, 1.0 - cell_border);
    ALBEDO = mix(ALBEDO, vec3(0.0, 0.0, 0.0), border_factor);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}

