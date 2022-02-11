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


#endif
