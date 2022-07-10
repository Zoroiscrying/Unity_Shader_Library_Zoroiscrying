#ifndef VERTEX_DISPLACEMENT_INCLUDED
#define VERTEX_DISPLACEMENT_INCLUDED

#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Mapping/Math.hlsl"

float SampleTime1D(half timeScale, int seed = 0)
{
    return _Time.x * timeScale + seed;
}

float2 SampleTime2D(half2 timeScale, int2 seed = 0)
{
    return _Time.xx * timeScale + seed;
}

float3 SampleTime3D(half3 timeScale, int3 seed = 0)
{
    return _Time.xxx * timeScale + seed;
}

// Sine wave displacements
float ApplySinVertexDisplacement_VectorDotProjection
(inout float3 position, float3 displacementDirection, float3 displacementAmplitude,
    half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(position, displacementDirection);
    float displaceStrength = sin(displaceVector * frequency + SampleTime1D(timeScale, seed));;
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplySinVertexDisplacement_VectorDotProjection_DisplaceVectorAmplitudeMultiplied
(inout float3 position, float3 displacementDirection, float3 displacementAmplitude,
    half frequency, half timeScale, half multiplyScaler, int seed = 0)
{
    float displaceVector = dot(position, displacementDirection);
    float displaceStrength = displacementAmplitude * sin(displaceVector * frequency + SampleTime1D(timeScale, seed)) * displaceVector * multiplyScaler;
    position += displaceStrength;
    return length(displaceStrength);
}

float ApplySinVertexDisplacement_DistanceBasedProjection
(inout float3 position, float3 referencePos,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = distance(position, referencePos);
    float displaceStrength = sin(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

// Noise wave displacements
float ApplyValueNoiseVertexDisplacement_VectorDotProjection
(inout float3 position, float3 displacementDirection,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(position, displacementDirection);
    float displaceStrength = value_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyGradientNoiseVertexDisplacement_VectorDotProjection
(inout float3 position, float3 displacementDirection,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(position, displacementDirection);
    float displaceStrength = gradient_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyGradientNoiseVertexDisplacement_VectorDotProjection_Test
(inout float3 position, float3 normalWS, float3 displacementDirection,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(position, displacementDirection);
    //float displaceStrength = value_noise31(position + displaceVector * frequency + _Time.x * timeScale) *
    //    Remap(value_noise31(position + _Time.xxx), float2(0,1), float2(0.5,1.5));;
    // (0.5, 1.0, 0.5)
    // (1.0, 0.25, 1.0)
    float displaceStrength = sin(
        dot(normalWS * 0.5,
            normalize(displacementDirection) +
            float3(0.5 * dot(normalWS.xz, float2(1 + value_noise11(SampleTime1D(timeScale * 0.1, seed)),1)), 0, 0.5 * dot(normalWS.xz, float2(-1,-1))))
        * frequency
        * Remap(value_noise13(normalWS * float3(.1, .1, .1) + _Time.xyx), float2(0, 1), float2(0.5, 1.5))
        * dot(normalWS * 0.5,
            normalize(displacementDirection).yzx +
            float3(1.0 * dot(normalWS.xz, float2(1 + value_noise11( normalWS.x + SampleTime1D(timeScale * 10, seed)),1)),
                0,
                1.0 * dot(normalWS.xz, float2(1 + value_noise11(normalWS.x + SampleTime1D(timeScale * 10, seed)),1))))
            + SampleTime1D(timeScale, seed));
    //+ dot(normalWS, float3(1, 1, 0)) * 0 + dot(normalWS, float3(1, 0, 1)) * 0 + dot(normalWS, float3(0, 1, 1)) * 0);
    //displaceStrength = value_noise13(position * float3(3, 6, 1) + _Time.xyx);
    displaceStrength = pow(displaceStrength, 4);
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_1DNoiseProjection
(inout float3 position, float sampleCoord,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displacementVector = value_noise11(sampleCoord * frequency + SampleTime1D(timeScale, seed));
    float displaceStrength = displacementVector;
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_2DNoiseProjection
(inout float3 position, float2 sampleCoord,
    float3 displacementAmplitude, half2 frequency, half2 timeScale, int2 seed = 0)
{
    float displacementVector = value_noise21(sampleCoord * frequency + SampleTime2D(timeScale, seed));
    float displaceStrength = displacementVector;
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_3DNoiseProjection
(inout float3 position, float3 sampleCoord,
    float3 displacementAmplitude, half3 frequency, half3 timeScale, int3 seed = 0)
{
    float displacementVector = value_noise31(sampleCoord * frequency + SampleTime3D(timeScale, seed));
    float displaceStrength = displacementVector;
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

// Sophisticated Displacement Calculations
float ApplyValueNoiseVertexDisplacement_TwoVectorCosDotProjection
(inout float3 position, float3 vector1, float3 vector2,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(vector1, vector2);
    float displaceStrength = value_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_TwoVectorSinDotProjection
(inout float3 position, float3 vector1, float3 vector2,
    float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = 1 - dot(vector1, vector2);
    float displaceStrength = value_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));;
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_TwoByTwoVectorCosDotProjection
(inout float3 position, float3 vector1, float3 vector2,
    float3 vector3, float3 vector4, float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = dot(vector1, vector2) * dot(vector3, vector4);
    float displaceStrength = value_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float ApplyValueNoiseVertexDisplacement_TwoByTwoVectorSinDotProjection
(inout float3 position, float3 vector1, float3 vector2,
    float3 vector3, float3 vector4, float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceVector = (1 - dot(vector1, vector2)) * (1 - dot(vector3, vector4));
    float displaceStrength = value_noise11(displaceVector * frequency + SampleTime1D(timeScale, seed));
    position += displaceStrength * displacementAmplitude;
    return length(displaceStrength);
}

float InverseLerp_Saturate(float A, float B, float T)
{
    return saturate((T - A)/(B - A));
}

float ApplyValueNoiseVertexDisplacement_SweepProjection
(inout float3 position, float3 cosDot1, float3 cosDot2,
    float3 sinDot1, float3 sinDot2, float2 sweepClamp,
    half stepStrength, float3 displacementAmplitude, half frequency, half timeScale, int seed = 0)
{
    float displaceStrength = (1 - dot(cosDot1, cosDot2));
    float sweepVector = saturate(dot(sinDot1, sinDot2));
    float sweepVectorStepped = step(sweepVector, sweepClamp.y) - step(sweepVector, sweepClamp.x);
    
    float midPoint = (sweepClamp.x + sweepClamp.y) * 0.5;
    float sweepVectorInterpolated = saturate(InverseLerp_Saturate(sweepClamp.x, midPoint, sweepVector) - InverseLerp_Saturate(midPoint, sweepClamp.y, sweepVector));
    
    sweepVector *= lerp(sweepVectorInterpolated, sweepVectorStepped, stepStrength);
    float displaceVector = value_noise11((position.x+position.y+position.z) * frequency + SampleTime1D(timeScale, seed)) * displaceStrength * sweepVector;
    position += displaceVector * displacementAmplitude;
    return length(displaceVector);
}

#endif