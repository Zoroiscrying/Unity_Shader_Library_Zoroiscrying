#ifndef CUSTOM_VEGETATION_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_VEGETATION_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _LightDirection;
float3 _LightPosition;

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif
    
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

ControlPoint SnowAndSandPassVertexForTessellation(Attributes input)
{
    ControlPoint output;

    output.normalOS = input.normalOS;
    output.positionOS = input.positionOS;
    output.tangentOS = input.tangentOS;
    output.uv = input.uv;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    return output;    
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    const float3 positionWS_original = TransformObjectToWorld(input.positionOS.xyz);
    float depression_height_ws;
    float foot_height_ws;
    SampleSnowAndSandTexture_float(positionWS_original, depression_height_ws, foot_height_ws);
    
    float3 position_ws_modified = positionWS_original;
    ProcessSnowAndSandDisplacement(position_ws_modified, depression_height_ws, foot_height_ws);
    
    const float3 position_os_modified = TransformWorldToObject(position_ws_modified);
    input.positionOS.xyz = position_os_modified;
    
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    const float3 positionWS_original = TransformObjectToWorld(input.positionOS.xyz);
    float depression_height_ws;
    float foot_height_ws;
    SampleSnowAndSandTexture_float(positionWS_original, depression_height_ws, foot_height_ws);
    
    float3 position_ws_modified = positionWS_original;
    ProcessSnowAndSandDisplacement(position_ws_modified, depression_height_ws, foot_height_ws);
    
    const float3 position_os_modified = TransformWorldToObject(position_ws_modified);
    input.positionOS.xyz = position_os_modified;
    
    output.positionCS = TransformObjectToHClip(position_os_modified);
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

Varyings VertexToFragment(Attributes input)
{
    return ShadowPassVertex(input);    
}

#endif
