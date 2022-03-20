#ifndef FRACTAL_BROWNIAN_MOTION
#define FRACTAL_BROWNIAN_MOTION

/* Valuable Resources:
 * - https://thebookofshaders.com/13/
 * - https://www.shadertoy.com/view/MdSXzz
 * - https://www.shadertoy.com/view/tdG3Rd
 * - https://www.shadertoy.com/view/wttXz8
 * - https://www.shadertoy.com/view/4tdSWr
 * - * https://www.shadertoy.com/view/4ttSWf
 * - 
 */
#include "CustomNoise.hlsl"

// 9-step basic noise fbm from https://www.shadertoy.com/view/3sd3Rs by Inigo Quilez
float fbm_bnoise_9step_11( in float x )
{
    float n = 0.0;
    float s = 1.0;
    for( int i=0; i<9; i++ )
    {
    n += s*basic_noise11(x);
    s *= 0.5;
    x *= 2.0;
    x += 0.131;
    }
    return n;
}

// 5-step for faster calculation
float fbm_bnoise_5step_11(in float x)
{
    float n = 0.0;
    float s = 0.5;
    [unroll(5)]
    for (int i = 0; i < 5; i++)
    {
        n += s * basic_noise11(x);
        s *= 0.5;
        x *= 2.0;
        x += 0.131;
    }
    n *= 1.03225806452;
    return n;
}

// 4-step fractal noise, value from 0 to 1 from https://www.shadertoy.com/view/Msf3WH
// modified for range remapping to 01
float fbm_snoise_4step_12(in float2 uv)
{
    float f = 0;
    const float2x2 mat = float2x2(1.6, 1.2, -1.2, 1.6);
    f = 0.5 * simplex_noise12(uv); uv = mul(mat, uv);
    f += 0.25 * simplex_noise12(uv); uv = mul(mat, uv);
    f += 0.125 * simplex_noise12(uv); uv = mul(mat, uv);
    f += 0.0625 * simplex_noise12(uv);
    f = f * 1.06667;
    f = 0.5 * f + 0.5f;
    return f;
}

#endif
