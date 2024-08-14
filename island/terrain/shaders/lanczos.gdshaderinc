// https://www.shadertoy.com/view/flVGRd
#define _LANCZOS_PI    3.1415926535897932384626433
#define _LANCZOS_PI_SQ 9.8696044010893586188344910
float _lanczos_weight(float x, float r) {
    if (x == 0.0) return 1.;
    return (r * sin(_LANCZOS_PI * x) * sin(_LANCZOS_PI * (x / r) )) / (_LANCZOS_PI_SQ * x*x);
}
float _lanczos_weight_v2(vec2 x, float r) {
    return _lanczos_weight(x.x, r) * _lanczos_weight(x.y, r);
}
vec4 texelFetchClamp(sampler2D sampler, ivec2 coord, int lod, ivec2 sizeOptional) {
	if (sizeOptional.x == 0) sizeOptional = textureSize(sampler, lod);
	if (coord.x < 0) coord.x = 0;
	if (coord.y < 0) coord.y = 0;
	if (coord.x >= sizeOptional.x) coord.x = sizeOptional.x - 1;
	if (coord.y >= sizeOptional.y) coord.y = sizeOptional.y - 1;
	return texelFetch(sampler, coord, lod);
}
vec3 lanczos(sampler2D sampler, vec2 coord, int r) {
	ivec2 size = textureSize(sampler, 0);
    vec2 res    = vec2(size);
    coord      += -0.5 / res;
    vec2 ccoord = floor(coord * res) / res;

    vec3  total  = vec3(0);    
    for (int x = -r; x <= r; x++) {
        for (int y = -r; y <= r; y++) {
            vec2  offs = vec2(float(x), float(y));
            
            vec2  sco  = (offs / res) + ccoord;
            vec2  d    = clamp((sco - coord) * res, vec2(float(-r)), vec2(float(r)));
            vec3  val  = texelFetchClamp(sampler, ivec2(sco * res), 0, size).rgb;
            
            float weight = _lanczos_weight_v2(d, float(r));
            
            total     += val * weight;
        }
    }

    return total;
}
