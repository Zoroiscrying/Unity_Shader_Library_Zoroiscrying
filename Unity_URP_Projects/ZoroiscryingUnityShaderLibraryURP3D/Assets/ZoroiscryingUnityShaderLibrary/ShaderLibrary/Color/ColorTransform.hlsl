#ifndef COLOR_TRANSFORM_INCLUDED
#define COLOR_TRANSFORM_INCLUDED

// hsv 2 rgb transform, from https://www.shadertoy.com/view/wtlcDj by @marcelliino
float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}



#endif