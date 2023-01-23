#ifndef CUSTOM_VEGETATION_INPUT_INCLUDED
#define CUSTOM_VEGETATION_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/ShadingModel/VegetationShadingData.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS		: NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv          : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    
    float4 positionCS   : SV_POSITION;
    float3 normalWS		: NORMAL;
    float3 positionWS	: TEXCOORD1;
    float4 tangentWS    : TEXCOORD4;

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
    #else
    half  fogFactor                 : TEXCOORD5;
    #endif
    
    half4 vertexColor : TEXCOORD6;
    half3 vertexSH    : TEXCOORD7;

    #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    float4 shadowCoord : TESCOORD8;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// per object material variant data
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _OcclusionStrength;
// vegetation shading properties
// - leaf params
half _ParameterMovementDensity;
half _ParameterMovementScale;
half _ParameterMovementBend;
half _ParameterMovementStretch;
half _ParameterMovementStiffness;
// - sway params
// todo:: SwayInstanceBufferCount
uint _SwayInstanceIndex;
half _SwayMovementSpring;
half _SwayMovementDamping;
// - tree params
half _TreeMovementBend;
half _TreeMovementScale;
half _TreeLeafLag;
CBUFFER_END

// global buffer
StructuredBuffer<float3> InstancesSwayVectorBuffer;
int SwayInstanceTailIndex;

// per shader non-variant data
TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
float4 _BaseMap_TexelSize;      float4 _BaseMap_MipInfo;
TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
TEXTURE2D(_EmissionMap);        SAMPLER(sampler_EmissionMap);
TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_SmoothnessMap);       SAMPLER(sampler_SmoothnessMap);

float4 _CameraDepthTexture_TexelSize;

///////////////////////////////////////////////////////////////////////////////
//                      Material Property Helpers                            //
///////////////////////////////////////////////////////////////////////////////
half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
{
    return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
}

half SampleSmoothness(float2 uv, TEXTURE2D_PARAM(smoothnessMap, samplersmoothnessMap))
{
    return SAMPLE_TEXTURE2D(smoothnessMap, samplersmoothnessMap, uv).r;
}

half Alpha(half albedoAlpha, half4 color, half cutoff)
{
    #if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
    half alpha = albedoAlpha * color.a;
    #else
    half alpha = color.a;
    #endif

    #if defined(_ALPHATEST_ON)
    clip(alpha - cutoff);
    #endif

    return alpha;
}

half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = half(1.0))
{
    #ifdef _NORMALMAP
    half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
    return UnpackNormal(n);
    #else
    return UnpackNormalScale(n, scale);
    #endif
    #else
    return half3(0.0h, 0.0h, 1.0h);
    #endif
}

half3 SampleEmission(float2 uv, half3 emissionColor, TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
{
    #ifndef _EMISSION
    return 0;
    #else
    return SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb * emissionColor;
    #endif
}

half SampleOcclusion(float2 uv)
{
    // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
    #if defined(SHADER_API_GLES)
    return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    #else
    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    return LerpWhiteTo(occ, _OcclusionStrength);
    #endif
}

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
    specGloss = half4(SAMPLE_METALLICSPECULAR(uv));
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    specGloss.a = albedoAlpha * _Smoothness;
    #else
    specGloss.a *= _Smoothness;
    #endif
    #else // _METALLICSPECGLOSSMAP
    #if _SPECULAR_SETUP
    specGloss.rgb = _SpecColor.rgb;
    #else
    specGloss.rgb = _Metallic.rrr;
    #endif

    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    specGloss.a = albedoAlpha * _Smoothness;
    #else
    specGloss.a = _Smoothness;
    #endif
    #endif

    return specGloss;
}
///////////////////////////////////////////////////////////////////////////////
//                      Vertex Data Initialization                           //
///////////////////////////////////////////////////////////////////////////////
void InitializeDisplacementData(Attributes input, out Vegetation_DisplacementData displacementData)
{
    ZERO_INITIALIZE(Vegetation_DisplacementData, displacementData);
    
    const float distToCenter = Length2(input.positionOS)/0.8f;
    const float movementScale = 0.2f * distToCenter;
    // leaf params
    displacementData._ParameterMovementBend = _ParameterMovementBend;
    displacementData._ParameterMovementDensity = _ParameterMovementDensity;
    displacementData._ParameterMovementScale = _ParameterMovementScale * movementScale;
    displacementData._ParameterMovementStiffness = _ParameterMovementStiffness;
    displacementData._ParameterMovementStretch = _ParameterMovementStretch;
    // sway params
    
    // tree params

    // wind params
    displacementData._WindVelocityVector = float3(1, 0, 0);
}


///////////////////////////////////////////////////////////////////////////////
//                      Surface Data Initialization                          //
///////////////////////////////////////////////////////////////////////////////
inline void InitializeVegetationLitSurfaceData(float2 uv, out VegetationSurfaceShadingData outSurfaceData)
{
    ZERO_INITIALIZE(VegetationSurfaceShadingData, outSurfaceData);
    
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    //half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

    // #if _SPECULAR_SETUP
    // outSurfaceData.metallic = half(1.0);
    // outSurfaceData.specular = specGloss.rgb;
    // #else
    // outSurfaceData.metallic = specGloss.r;
    // outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    // #endif
    //outSurfaceData.smoothness = specGloss.a;
    
    outSurfaceData.metallic = 0.0;
    outSurfaceData.smoothness = SampleSmoothness(uv, _SmoothnessMap, sampler_SmoothnessMap) * _Smoothness;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.translucency = half3(0.0, 0.0, 0.0);
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
}

#endif