#ifndef CUSTOM_NOISE
#define CUSTOM_NOISE

#include "./HashWithoutSine.hlsl"

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
// Value    Noise 2D, Derivatives: https://www.shadertoy.com/view/4dXBRH
// Gradient Noise 2D, Derivatives: https://www.shadertoy.com/view/XdXBRH
// Value    Noise 3D, Derivatives: https://www.shadertoy.com/view/XsXfRH
// Gradient Noise 3D, Derivatives: https://www.shadertoy.com/view/4dffRH
// Value    Noise 2D             : https://www.shadertoy.com/view/lsf3WH
// Value    Noise 3D             : https://www.shadertoy.com/view/4sfGzS
// Gradient Noise 2D             : https://www.shadertoy.com/view/XdXGW8
// Gradient Noise 3D             : https://www.shadertoy.com/view/Xsl3Dl
// Simplex  Noise 2D             : https://www.shadertoy.com/view/Msf3WH
// Wave     Noise 2D             : https://www.shadertoy.com/view/tldSRj
// https://www.shadertoy.com/view/4dS3Wd 1D,2D and 3D noise
// 
// Worley & Perlin noise : https://www.shadertoy.com/view/3dVXDc

// Value noise 1D [0, 1]
float value_noise11(float x) {
	float i = floor(x);
	float f = frac(x);
	float u = f * f * (3.0 - 2.0 * f);
	return lerp(hash11(i), hash11(i + 1.0), u);
}

// Modified value noise 21 for outputting 2D vectors
float2 value_noise21(float x)
{
	float i = floor(x);
	float f = frac(x);
	float u = f * f * (3.0 - 2.0 * f);
	return lerp(hash21(i), hash21(i + 1.0), u);
}

// Modified value noise 31 for outputting 2D vectors
float3 value_noise31(float x)
{
	float i = floor(x);
	float f = frac(x);
	float u = f * f * (3.0 - 2.0 * f);
	return lerp(hash31(i), hash31(i + 1.0), u);
}

// Basic noise 1D https://www.shadertoy.com/view/3sd3Rs from Inigo Quilez.
float basic_noise11(float x)
{
	// setup    
	float i = floor(x);
	float f = frac(x);
	float s = sign(frac(x/2.0)-0.5);
    
	// use some hash to create a random value k in [0..1] from i
	//float k = hash(uint(i));
	//float k = 0.5+0.5*sin(i);
	float k = frac(i*.1731);

	// quartic polynomial
	return s*f*(f-1.0)*((16.0*k-4.0)*f*(f-1.0)-1.0);
}

// Gradient Noise 1D 
float gradient_noise11(float p)
{
	uint  i = uint(floor(p));
	float f = frac(p);
	float u = f*f*(3.0-2.0*f);

	float g0 = hash11(i+0u)*2.0-1.0;
	float g1 = hash11(i+1u)*2.0-1.0;
	return 2.4*lerp( g0*(f-0.0), g1*(f-1.0), u);
}


// Value Noise 2D
float value_noise12( in float2 p )
{
    float2 i = floor( p );
    float2 f = frac( p );
	
    float2 u = f*f*(3.0-2.0*f);

    return lerp( lerp( hash12( i + float2(0.0,0.0) ), 
                     hash12( i + float2(1.0,0.0) ), u.x),
                lerp( hash12( i + float2(0.0,1.0) ), 
                     hash12( i + float2(1.0,1.0) ), u.x), u.y);
}

// return Value noise 2D (in x) and its derivatives (in yz)
float3 value_noise_12_d( in float2 p )
{
    float2 i = floor( p );
    float2 f = frac( p );
	
    #if 1
    // quintic interpolation
    float2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
    float2 du = 30.0*f*f*(f*(f-2.0)+1.0);
    #else
    // cubic interpolation
    vec2 u = f*f*(3.0-2.0*f);
    vec2 du = 6.0*f*(1.0-f);
    #endif    
    
    float va = hash12( i + float2(0.0,0.0) );
    float vb = hash12( i + float2(1.0,0.0) );
    float vc = hash12( i + float2(0.0,1.0) );
    float vd = hash12( i + float2(1.0,1.0) );
    
    float k0 = va;
    float k1 = vb - va;
    float k2 = vc - va;
    float k4 = va - vb - vc + vd;

    return float3( va+(vb-va)*u.x+(vc-va)*u.y+(va-vb-vc+vd)*u.x*u.y, // value
                 du*(u.yx*(va-vb-vc+vd) + float2(vb,vc) - va) );     // derivative                
}

// Define to use procedural calculation or texture calculation
#define USE_PROCEDURAL

#ifdef USE_PROCEDURAL

// Value Noise 3D
float value_noise13( in float3 x )
{
	float3 i = floor(x);
	float3 f = frac(x);
	f = f*f*(3.0-2.0*f);
	
	return lerp(lerp(lerp( hash13(i+float3(0,0,0)), 
						hash13(i+float3(1,0,0)),f.x),
				lerp( hash13(i+float3(0,1,0)), 
						hash13(i+float3(1,1,0)),f.x),f.y),
			lerp(lerp( hash13(i+float3(0,0,1)), 
						hash13(i+float3(1,0,1)),f.x),
				lerp( hash13(i+float3(0,1,1)), 
						hash13(i+float3(1,1,1)),f.x),f.y),f.z);
}
#else
float value_noise13( in float3 x )
{
	#if 1
    
	float3 i = floor(x);
	float3 f = frac(x);
	f = f*f*(3.0-2.0*f);
	float2 uv = (i.xy+float2(37.0,17.0)*i.z) + f.xy;
	float2 rg = tex2Dlod( noiseHelperTexture3D, (uv+0.5)/256.0, 0.0).yx;
	return lerp( rg.x, rg.y, f.z );
    
	#else
    
	int3 i = floor(x);
	float3 f = frac(x);
	f = f*f*(3.0-2.0*f);
	int2 uv = i.xy + int2(37,17)*i.z;
	float2 rgA = tex2D( noiseHelperTexture3D, (uv+int2(0,0))&255, 0 ).yx;
	float2 rgB = tex2D( noiseHelperTexture3D, (uv+int2(1,0))&255, 0 ).yx;
	float2 rgC = tex2D( noiseHelperTexture3D, (uv+int2(0,1))&255, 0 ).yx;
	float2 rgD = tex2D( noiseHelperTexture3D, (uv+int2(1,1))&255, 0 ).yx;
	float2 rg = lerp( lerp( rgA, rgB, f.x ),
				lerp( rgC, rgD, f.x ), f.y );
	return lerp( rg.x, rg.y, f.z );
    
	#endif
}
#endif

// 2D output 2D input noise
float2 custom_value_noise22(in float2 p)
{
	return float2(value_noise12(p), value_noise12(p + float2(928, 1785)));
}

// 1D output 2D input simplex noise, range from -1 - 1
float simplex_noise12(in float2 p)
{
	const float K1 = 0.366025404; // (sqrt(3)-1)/2;
	const float K2 = 0.211324865; // (3-sqrt(3))/6;

	float2  i = floor( p + (p.x+p.y)*K1 );
	float2  a = p - i + (i.x+i.y)*K2;
	float m = step(a.y,a.x); 
	float2  o = float2(m,1.0-m);
	float2  b = a - o + K2;
	float2  c = a - 1.0 + 2.0*K2;
	float3  h = max( 0.5-float3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	float3  n = h*h*h*h*float3( dot(a,hash22(i+0.0)), dot(b,hash22(i+o)), dot(c,hash22(i+1.0)));
	return dot(n, float3(70.0, 70.0, 70.0));
}

// Spherical Noise https://stackoverflow.com/questions/17095571/coherent-spherical-noise
float3 spherical_noise33(in float3 input)
{
	float3 result = 0;
	result.x = simplex_noise12(input.xy);
	result.y = simplex_noise12(input.yz);
	result.z = simplex_noise12(input.zx);
	return result;
}


#endif