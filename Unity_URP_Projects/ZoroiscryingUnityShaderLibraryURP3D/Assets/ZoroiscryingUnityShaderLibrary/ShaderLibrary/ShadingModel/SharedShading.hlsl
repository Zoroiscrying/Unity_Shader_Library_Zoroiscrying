#ifndef SHARED_SHADING_INCLUDED
#define SHARED_SHADING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

/// RIM LIGHT
// Screen-space Rim Light
half CalculateScreenSpaceDepthDifference_EyeDepth(half linearOriginalDepth, half2 positionSS, half2 normalSS, half2 offsetSS)
{
    half diff = 0.0;
    half rawDepth = SampleSceneDepth(positionSS + normalSS * offsetSS);
    half linearEyeDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
    diff = linearOriginalDepth - linearEyeDepth;
    return -diff;
}

half CalculateScreenSpaceDepthDifference_RawDepth(half linearOriginalDepth, half2 positionSS, half2 normalSS, half2 offsetSS)
{
    half diff = 0.0;
    half rawDepth = SampleSceneDepth(positionSS + normalSS * offsetSS);
    diff = linearOriginalDepth - rawDepth;
    return -diff;
}

half CalculateScreenSpaceDepthDifference_01Depth(half linearOriginalDepth, half2 positionSS, half2 normalSS, half2 offsetSS)
{
    half diff = 0.0;
    half rawDepth = SampleSceneDepth(positionSS + normalSS * offsetSS);
    half linear01Depth = Linear01Depth(rawDepth, _ZBufferParams);
    diff = linear01Depth - linearOriginalDepth;
    return diff;
}

/// OUTLINE RELEVANT
// Clip Space Outline Strength


// World Space Outline Strength


/// Mat Cap shading
// Traditional Mat Cap UV calculation
float2 CalculateMatCapUV(float3 normalVS, float3 positionOS)
{
    return normalVS.xy * 0.5 + 0.5;
}
// Perspective fixed mat cap uv calculation: https://forum.unity.com/threads/getting-normals-relative-to-camera-view.452631/
float2 CalculateMatCapUV_PerspectiveStill(float3 normalVS, float3 positionOS)
{
    float3 positionVS = TransformWorldToView(TransformObjectToWorld(positionOS));
    float3 viewDir = normalize(positionVS);
    float3 viewCross = cross(viewDir, normalVS);
    normalVS = float3(-viewCross.y, viewCross.x, 0);
    return normalVS.xy * 0.5 + 0.5;
}

/// Subsurface Scattering ///
//
// Fast Subsurface Scattering Calculation from
// https://www.slideshare.net/colinbb/colin-barrebrisebois-gdc-2011-approximating-translucency-for-a-fast-cheap-and-convincing-subsurfacescattering-look-7170855
/// 
/// - The object translucency is the inverse thickness of the object, its value will grow if the object is thinner.
half3 Fast_SSS_Calculation(half3 lightDirWS, half3 normalWS, half3 viewDirWS, half3 lightColor,
    half lightAttenuation, half scatteringScale = 1.0, half lightPower = 2.0, half normalDistortion = 1.0,
    half ambientScatteringStrength = 0.05, half objectTranslucency = 1.0, half overallStrength = 1.0)
{
    half3 midVector = lightDirWS + normalWS * normalDistortion;
    half fLTdot = pow(saturate(dot(viewDirWS, -midVector)), lightPower) * scatteringScale;
    half3 fLT = lightAttenuation * (fLTdot + ambientScatteringStrength) * objectTranslucency;
    return lightColor * fLT;
}

#endif