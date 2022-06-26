#ifndef SAMPLE_GLOBAL_WIND_3D_INCLUDED
#define SAMPLE_GLOBAL_WIND_3D_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"

float4 _WindVolumeCenterPosition;
float _WindVolumeVoxelSize;
TEXTURE3D(_GlobalWindVolume3D); SAMPLER(sampler_GlobalWindVolume3D);

float3 CalculateWindTextureUVW(float3 positionWS)
{
    float3 uvw = 0;
    // can be optimized
    float3 windPosMinWS = _WindVolumeCenterPosition - float3(15.5, 7.5, 15.5) * _WindVolumeVoxelSize;
    // can be optimized
    float3 windVolumeSize = float3(32, 16, 32) * _WindVolumeVoxelSize;
    
    uvw = (positionWS - windPosMinWS) / windVolumeSize;
    return uvw;
}

float4 RetrieveWindVolumeTextureDataVertex(float3 uvw)
{
    return SAMPLE_TEXTURE3D_LOD(_GlobalWindVolume3D, sampler_GlobalWindVolume3D, uvw, 0);
}

float3 RetrieveWindVelocityVertex(float3 uvw)
{
    float4 windDirectionAndSpeed = RetrieveWindVolumeTextureDataVertex(uvw);
    return windDirectionAndSpeed.xyz * windDirectionAndSpeed.w;
}

float4 SampleWindDirectionSpeedVertex(float3 positionWS)
{
    return RetrieveWindVolumeTextureDataVertex(CalculateWindTextureUVW(positionWS));
}

float3 SampleWindDirectionVelocityVertex(float3 positionWS)
{
    return RetrieveWindVelocityVertex(CalculateWindTextureUVW(positionWS));
}

float4 RetrieveWindDirectionSpeedFragment(float3 uvw)
{
    return SAMPLE_TEXTURE3D_LOD(_GlobalWindVolume3D, sampler_GlobalWindVolume3D, uvw, 0);
}

float3 RetrieveWindVelocityFragment(float3 uvw)
{
    float4 rawData = RetrieveWindDirectionSpeedFragment(uvw);
    return rawData.xyz * rawData.w;
}

float4 SampleWindDirectionSpeedFragment(float3 positionWS)
{
    return RetrieveWindDirectionSpeedFragment(CalculateWindTextureUVW(positionWS));
}

float3 SampleWindDirectionVelocityFragment(float3 positionWS)
{
    return RetrieveWindVelocityFragment(CalculateWindTextureUVW(positionWS));
}

#endif