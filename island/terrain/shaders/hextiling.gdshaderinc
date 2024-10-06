//MIT License
//
//Copyright (c) 2022 mmikk, yaelatletl
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

//Hextiling terrain shader for Godot Engine, based on: https://github.com/mmikk/hextile-demo
//ported from HLSL by Yael Atletl

const float hextiling_M_PI = 3.141592;

group_uniforms Hextiling;
uniform float hextiling_fallOffContrast = 0.6;
uniform float hextiling_exp = 7;

vec2 frac(vec2 texin){
	return vec2(texin.x - floor(texin.x), texin.y-floor(texin.y));
}

// Input: vM is tangent space normal in [-1;1].
// Output: convert vM to a derivative.
vec2 TspaceNormalToDerivative(vec3 vM)
{
	const float scale = 1.0/128.0;

	// Ensure vM delivers a positive third component using abs() and
	// constrain vM.z so the range of the derivative is [-128; 128].
	vec3 vMa = abs(vM);
	float z_ma = max(vMa.z, scale*max(vMa.x, vMa.y));

	// Set to match positive vertical texture coordinate axis.
	const bool gFlipVertDeriv = true;
	const float s = gFlipVertDeriv ? -1.0 : 1.0;
	return -vec2(vM.x, s*vM.y)/z_ma;
}

// Output:\ weights associated with each hex tile and integer centers
void TriangleGrid(out float w1, out float w2, out float w3,
				  out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3,
				  vec2 st)
{
	// Scaling of the input
	st *= 2.0 * sqrt(3);

	// Skew input space into simplex triangle grid
	const mat2 gridToSkewedGrid =
		mat2(vec2(1.0, -0.57735027), vec2( 0.0, 1.15470054));
	vec2 skewedCoord = gridToSkewedGrid*st;

	ivec2 baseId = ivec2( floor ( skewedCoord ));
	vec3 temp = vec3( frac( skewedCoord ), 0);
	temp.z = 1.0 - temp.x - temp.y;

	float s = step(0.0, -temp.z);
	float s2 = 2.0*s-1.0;

	w1 = -temp.z*s2;
	w2 = s - temp.y*s2;
	w3 = s - temp.x*s2;

	vertex1 = baseId + ivec2(int(s));
	vertex2 = baseId + ivec2(int(s),int(1.0-s));
	vertex3 = baseId + ivec2(int(1.0-s),int(s));
}

float fmod(float x, float y){
	return x - y * trunc(x/y);
}

vec2 hash(ivec2 p)
{
	vec2 r = mat2(vec2(127.1, 311.7),vec2(269.5, 183.3))*vec2(p);

	return frac( sin( r )*43758.5453 );
}

vec2 sampleDeriv(sampler2D samp, vec2 st, vec2 dSTdx, vec2 dSTdy)
{
	// sample
	vec3 vM = 2.0*textureGrad(samp, st, dSTdx, dSTdy).rgb-1.0;
	return TspaceNormalToDerivative(vM);
}

mat2 LoadRot2x2(ivec2 idx, float rotStrength)
{
	float angle = float(abs(idx.x*idx.y)) + float(abs(idx.x+idx.y)) + hextiling_M_PI;

	// remap to +/-pi
	angle = fmod(angle, 2.0*hextiling_M_PI);
	if(angle<0.0) angle += 2.0*hextiling_M_PI;
	if(angle>hextiling_M_PI) angle -= 2.0*hextiling_M_PI;

	angle *= rotStrength;

	float cs = cos(angle), si = sin(angle);

	return mat2(vec2(cs, -si),vec2(si, cs));
}

vec2 MakeCenST(ivec2 Vertex)
{
	mat2 invSkewMat = mat2(vec2(1.0, 0.5), vec2(0.0, 1.0/1.15470054));

	return (invSkewMat * vec2(Vertex)) / (2.0 * sqrt(3.0));
}

vec3 Gain3(vec3 x, float r)
{
	// increase contrast when r>0.5 and
	// reduce contrast if less
	float k = log(1.0-r) / log(0.5);

	vec3 s = 2.0*step(0.5, x);
	vec3 m = 2.0*(1.0 - s);

	vec3 res = 0.5*s + 0.25*m * pow(max(vec3(0.0), s + x*m), vec3(k));

	return res.xyz / (res.x+res.y+res.z);
}

vec3 ProduceHexWeights(vec3 W, ivec2 vertex1, ivec2 vertex2, ivec2 vertex3)
{
	vec3 res = vec3(0.0);

	int v1 = (vertex1.x-vertex1.y)%3;
	if(v1<0) v1+=3;

	int vh = v1<2 ? (v1+1) : 0;
	int vl = v1>0 ? (v1-1) : 2;
	int v2 = vertex1.x<vertex3.x ? vl : vh;
	int v3 = vertex1.x<vertex3.x ? vh : vl;

	res.x = v3==0 ? W.z : (v2==0 ? W.y : W.x);
	res.y = v3==1 ? W.z : (v2==1 ? W.y : W.x);
	res.z = v3==2 ? W.z : (v2==2 ? W.y : W.x);

	return res;
}

// Input:\ nmap is a normal map
// Input:\ r increase contrast when r>0.5
// Output:\ deriv is a derivative dHduv wrt units in pixels
// Output:\ weights shows the weight of each hex tile
void bumphex2derivNMap(out vec2 deriv, out vec3 weights,
						sampler2D samp, vec2 st,
					   float rotStrength, float r) //=0.5
{
#ifdef texture_stochastic_enable_df
	vec2 dSTdx = dFdx(st);
	vec2 dSTdy = dFdy(st);
#else
	vec2 dSTdx = vec2(0.0);
	vec2 dSTdy = vec2(0.0);
#endif

	// Get triangle info
	float w1, w2, w3;
	ivec2 vertex1, vertex2, vertex3;
	TriangleGrid(w1, w2, w3, vertex1, vertex2, vertex3, st);

	mat2 rot1 = LoadRot2x2(vertex1, rotStrength);
	mat2 rot2 = LoadRot2x2(vertex2, rotStrength);
	mat2 rot3 = LoadRot2x2(vertex3, rotStrength);

	vec2 cen1 = MakeCenST(vertex1);
	vec2 cen2 = MakeCenST(vertex2);
	vec2 cen3 = MakeCenST(vertex3);

	vec2 st1 = (st - cen1)* rot1 + cen1 + hash(vertex1);
	vec2 st2 = (st - cen2)* rot2 + cen2 + hash(vertex2);
	vec2 st3 = (st - cen3)* rot3 + cen3 + hash(vertex3);

	// Fetch input
	vec2 d1 = sampleDeriv(samp, st1,
							(dSTdx* rot1), (dSTdy* rot1));
	vec2 d2 = sampleDeriv(samp, st2,
							(dSTdx* rot2), (dSTdy* rot2));
	vec2 d3 = sampleDeriv(samp, st3,
							(dSTdx* rot3), (dSTdy* rot3));

	d1 = (rot1* d1); d2 = (rot2* d2); d3 = (rot3* d3);

	// produce sine to the angle between the conceptual normal
	// in tangent space and the Z-axis
	vec3 D = vec3( dot(d1,d1), dot(d2,d2), dot(d3,d3));
	vec3 Dw = sqrt(D/(1.0+D));

	Dw = mix(vec3(1.0), Dw, hextiling_fallOffContrast);	// 0.6
	vec3 W = Dw*vec3(pow(w1,hextiling_exp), pow(w2,hextiling_exp), pow(w3, hextiling_exp));	// 7
	W /= (W.x+W.y+W.z);
	if(r!=0.5) W = Gain3(W, r);

	deriv = W.x * d1 + W.y * d2 + W.z * d3;
	weights = ProduceHexWeights(W.xyz, vertex1, vertex2, vertex3);
}


// Input:\ tex is a texture with color
// Input:\ r increase contrast when r>0.5
// Output:\ color is the blended result
// Output:\ weights shows the weight of each hex tile
void hex2colTex(out vec4 color, out vec3 weights,
				sampler2D samp, vec2 st,
				float rotStrength, float r)//=0.5
{
#ifdef texture_stochastic_enable_df
	vec2 dSTdx = dFdx(st);
	vec2 dSTdy = dFdy(st);
#else
	vec2 dSTdx = vec2(0.0);
	vec2 dSTdy = vec2(0.0);
#endif

	// Get triangle info
	float w1, w2, w3;
	ivec2 vertex1, vertex2, vertex3;
	TriangleGrid(w1, w2, w3, vertex1, vertex2, vertex3, st);

	mat2 rot1 = LoadRot2x2(vertex1, rotStrength);
	mat2 rot2 = LoadRot2x2(vertex2, rotStrength);
	mat2 rot3 = LoadRot2x2(vertex3, rotStrength);

	vec2 cen1 = MakeCenST(vertex1);
	vec2 cen2 = MakeCenST(vertex2);
	vec2 cen3 = MakeCenST(vertex3);

	vec2 st1 = (st - cen1 * rot1) + cen1 + hash(vertex1);
	vec2 st2 = (st - cen2 * rot2) + cen2 + hash(vertex2);
	vec2 st3 = (st - cen3 * rot3) + cen3 + hash(vertex3);

	// Fetch input
	// Select which method will be sampled based on LOD
	vec4 c1, c2, c3;
#ifndef rendering_method
#define rendering_method "gl_compatibility"
#endif
#if rendering_method == "gl_compatibility"
	if(false) { // Close-up detection not (easily) supported
#else
	if(textureQueryLod(samp, st).x < 0.01) { // Close-ups!
#endif
	    // - The original code avoid triangle edge seams, but does not support LOD/mipmap
		c1 = textureGrad(samp, st1,
								   (dSTdx* rot1), (dSTdy* rot1));
		c2 = textureGrad(samp, st2,
								   (dSTdx* rot2), (dSTdy* rot2));
		c3 = textureGrad(samp, st3,
								   (dSTdx* rot3), (dSTdy* rot3));
	} else {
		// To support LOD/mipmap, we need normal texture accesses :(
		c1 = texture(samp, st1);
		c2 = texture(samp, st2);
		c3 = texture(samp, st3);
	}

	// use luminance as weight
	vec3 Lw = vec3(0.299, 0.587, 0.114);
	vec3 Dw = vec3(dot(c1.xyz,Lw),dot(c2.xyz,Lw),dot(c3.xyz,Lw));

	Dw = mix(vec3(1.0), Dw, hextiling_fallOffContrast);	// 0.6
	vec3 W = Dw*pow(vec3(w1, w2, w3), vec3(hextiling_exp));	// 7
	W /= (W.x+W.y+W.z);
	if(r!=0.5) W = Gain3(W, r);

	color = W.x * c1 + W.y * c2 + W.z * c3;
	weights = ProduceHexWeights(W.xyz, vertex1, vertex2, vertex3);
}


// EXAMPLE USAGE with triplanar mapping
//uniform sampler2D top_base_color : hint_default_white;
//uniform sampler2D top_normal_map : hint_normal;
//uniform sampler2D top_ORM : hint_default_white;
////uniform sampler2D top_displace: hint_white;
//uniform sampler2D side_base_color : hint_default_white;
//uniform sampler2D side_normal_map : hint_normal;
//uniform sampler2D side_ORM : hint_default_white;
////uniform sampler2D side_displace : hint_white;
//uniform float metallic = 0.0;
//uniform float roughness = 0.0;
//uniform float light_affect = 0.0;
//uniform float uv1_blend_sharpness;
//uniform vec3 uv1_scale;
//uniform vec3 uv1_offset;
//uniform vec3 uv2_scale;
//uniform vec3 uv2_offset;
//uniform float sides_smoothing = 0.25;
//uniform float top_smoothing = 0.35;
//vec4 triplanar_texture(sampler2D top_sampler,sampler2D side_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	//// the following variables are left for reference
	////vec3 sp =  uv1_triplanar_pos; //bit of a headache, but much better than the previous method.
	////vec2 st0 = vec2(sp.x, sp.z);	//top coordinates
	////vec2 st1 = vec2(sp.x, sp.y);	//side1 coordinates
	////vec2 st2 = vec2(sp.z, sp.y);	//side2 coordinates
	//vec4 samp=vec4(0.0);
	//vec4 temp_samp = vec4(0.0);
	//vec3 weights;
	//hex2colTex(temp_samp, weights, top_sampler, uv1_triplanar_pos.xz, 1.0, 0.5);
	////temp_samp.rgb = weights;
	//samp+= temp_samp* smoothstep((p_weights.z +p_weights.x-p_weights.y), 1.0, top_smoothing);
	//hex2colTex(temp_samp, weights, side_sampler, uv1_triplanar_pos.zy, 1.0, 0.5);
	////temp_samp.rgb = weights;
	//samp += temp_samp *smoothstep((-p_weights.x+p_weights.z+p_weights.y), 1.0, sides_smoothing);
	//float eh = 10.0*(-(-p_weights.x+p_weights.z+p_weights.y)*-(p_weights.x-p_weights.z+p_weights.y))*-(p_weights.z +p_weights.x-p_weights.y);
	//eh = eh*float(eh<0.02); //weighting blind spots, 3d math why
	//hex2colTex(temp_samp, weights, side_sampler, uv1_triplanar_pos.xy, 1.0, 0.5);
	////temp_samp.rgb = weights;
	//samp += temp_samp * smoothstep((p_weights.x-p_weights.z+p_weights.y)+eh, 1.0, sides_smoothing);
	//samp = normalize(samp); //normalize this additive mess
	//return samp;
//}