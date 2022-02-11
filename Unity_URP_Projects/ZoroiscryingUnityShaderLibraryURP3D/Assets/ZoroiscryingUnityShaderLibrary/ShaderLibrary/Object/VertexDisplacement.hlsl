#ifndef VERTEX_DISPLACEMENT_INCLUDED
#define VERTEX_DISPLACEMENT_INCLUDED

#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"

float ApplySinVertexDisplacementOS(inout float3 positionOS, float3 displacementDirection, float3 displacementAmplitude, half frequency, half timeScale)
{
    float displaceVector = dot(positionOS, displacementDirection);
    positionOS += displacementAmplitude * sin(displaceVector * frequency + _Time.x * timeScale);
    return displaceVector;
}

float ApplyNoiseVertexDisplacementOS(inout float3 positionOS, float3 displacementDirection, float3 displacementAmplitude, half frequency, half timeScale)
{
    float displaceVector = dot(positionOS, displacementDirection);
    positionOS += displacementAmplitude * value_noise11(displaceVector * frequency + _Time.x * timeScale);
    return displaceVector;
}


#endif