#ifndef BASIC_DISPLACEMENT_SHADOW_CASTER_PASS_INCLUDED
#define BASIC_DISPLACEMENT_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Object/VertexDisplacement.hlsl"

// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _LightDirection;
float3 _LightPosition;

// Inputs of Displacement Shader
float4 _DisplacementDirection;
float4 _DisplacementAmplitude;
half _SampleFrequency;
half _SampleSpeed;


struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    float4 tangentOS    : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
};

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

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    #if _SAMPLE_SINE
    
    float displaceVector = ApplySinVertexDisplacement_VectorDotProjection(
        input.positionOS.xyz, _DisplacementDirection, _DisplacementAmplitude, _SampleFrequency, _SampleSpeed);
    
    #elif _SAMPLE_NOISE

    float displaceVector = ApplyValueNoiseVertexDisplacement_VectorDotProjection(
    input.positionOS.xyz, _DisplacementDirection, _DisplacementAmplitude, _SampleFrequency, _SampleSpeed);

    #elif _SAMPLE_OTHER

    //VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    //// normalWS and tangentWS already normalize.
    //// this is required to avoid skewing the direction during interpolation
    //// also required for per-vertex lighting and SH evaluation
    //VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    //half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    //float displaceVector = ApplyValueNoiseVertexDisplacement_SweepProjection(
    //vertexInput.positionWS.xyz,
    //normalInput.normalWS, viewDirWS,
    //input.positionOS.xyz, float3(0, 0, 1),
    //float2(0.0, 0.01) + frac(_Time.x * 5.0) * 2, 0.5f,
    // normalize(normalInput.normalWS) * 1.0 * step(dot(viewDirWS, half3(-1, 0, 0)), 0),
    //_SampleFrequency, _SampleSpeed);
    //input.positionOS.xyz = TransformWorldToObject(vertexInput.positionWS);
    //vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    #endif

    
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

#endif
