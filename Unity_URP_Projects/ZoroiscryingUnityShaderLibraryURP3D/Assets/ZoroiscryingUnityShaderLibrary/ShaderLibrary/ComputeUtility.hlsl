#ifndef COMPUTE_UTILITY_INCLUDED
#define COMPUTE_UTILITY_INCLUDED

// The triangles vertices go by counter-clock wise
float3 ComputeNormalFromTriangle(float3 v0, float3 v1, float3 v2)
{
    return normalize(cross(v1 - v0, v2 - v0));
}

float3 GetCenter(float3 v0, float3 v1, float3 v2)
{
    return (v0 + v1 + v2) / 3.0;
}

float2 GetCenter(float2 uv0, float2 uv1, float2 uv2)
{
    return (uv0 + uv1 + uv2)/3.0;
}

#endif