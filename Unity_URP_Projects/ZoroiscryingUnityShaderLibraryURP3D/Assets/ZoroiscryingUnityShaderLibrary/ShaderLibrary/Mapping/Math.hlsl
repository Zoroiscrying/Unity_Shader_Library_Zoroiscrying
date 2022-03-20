#ifndef CUSTOM_MATH_INCLUDED
#define CUSTOM_MATH_INCLUDED

float Remap(float In, float2 InMinMax, float2 OutMinMax)
{
    return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
}

//from Ronja https://www.ronja-tutorials.com/post/047-invlerp_remap/
real InvLerp(real from, real to, real value){
    return (value - from) / (to - from);
}

#endif