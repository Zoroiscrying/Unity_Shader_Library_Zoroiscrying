#ifndef CUSTOM_RECONSTRUCTION_INCLUDED
#define CUSTOM_RECONSTRUCTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Reconstruct the tangent-space normal from the gray scale texture
float3 ReconstructNormalFromGrayScaleHeightTexture_VertexStage(TEXTURE2D_PARAM(heightMap, sampler_heightMap), float2 heightMap_TexelSize, float2 uv, half strengthMultiplier)
{
    float3 outNormal = 0;
    //Calculate Normal from Grayscale
    float3 graynorm = float3(0, 0, 1);
    float heightSampleCenter = (SAMPLE_TEXTURE2D_LOD(heightMap, sampler_heightMap, float2(uv), 0).r);
    float heightSampleRight = (SAMPLE_TEXTURE2D_LOD(heightMap, sampler_heightMap,float2(uv + float2(heightMap_TexelSize.x, 0)),0).r);
    float heightSampleUp = (SAMPLE_TEXTURE2D_LOD(heightMap, sampler_heightMap,float2(uv + float2(0, heightMap_TexelSize.y)),0).r);
    float sampleDeltaRight = heightSampleRight - heightSampleCenter;
    float sampleDeltaUp = heightSampleUp - heightSampleCenter;
    graynorm = cross(
    float3(1, 0, sampleDeltaRight * strengthMultiplier),
    float3(0, 1, sampleDeltaUp * strengthMultiplier));
	 
    outNormal = normalize(graynorm);
    return outNormal;
}

float3 ReconstructNormalFromGrayScaleHeightTexture(TEXTURE2D_PARAM(heightMap, sampler_heightMap), float2 heightMap_TexelSize, float2 uv, half strengthMultiplier)
{
    float3 outNormal = 0;
    //Calculate Normal from Grayscale
    float3 graynorm = float3(0, 0, 1);
    float heightSampleCenter = (SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, float2(uv)).r);
    float heightSampleRight = (SAMPLE_TEXTURE2D(heightMap, sampler_heightMap,float2(uv + float2(heightMap_TexelSize.x, 0))).r);
    float heightSampleUp = (SAMPLE_TEXTURE2D(heightMap, sampler_heightMap,float2(uv + float2(0, heightMap_TexelSize.y))).r);
    float sampleDeltaRight = heightSampleRight - heightSampleCenter;
    float sampleDeltaUp = heightSampleUp - heightSampleCenter;
    graynorm = cross(
    float3(1, 0, sampleDeltaRight * strengthMultiplier),
    float3(0, 1, sampleDeltaUp * strengthMultiplier));
	 
    outNormal = normalize(graynorm);
    return outNormal;
}

#endif