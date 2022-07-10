#ifndef CUSTOM_LIT_WATER_INPUT_INCLUDED
#define CUSTOM_LIT_WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct ControlPoint
{
    float4 positionOS : INTERNALTESSPOS;
    float3 positionWS : TEXCOORD0;
    float4 tangentOS : TEXCOORD1;
    float3 normalOS : NORMAL;
};

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS		: NORMAL;
    float4 tangentOS    : TANGENT;
    //float2 uv0          : TEXCOORD0;
    //float2 uv1          : TEXCOORD1;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float3 positionWS	: TEXCOORD2;
    float3 positionVS : TEXCOORD5;
    float2 positionSS   : TEXCOORD3;
    float3 normalWS		: NORMAL;
    //float3 viewDirectionWS : TEXCOORD4;
    //float4 tangentWS    : TEXCOORD5;
    //float4 fogFactorAndVertexLight : TEXCOORD1;
    //float2 uv           : TEXCOORD9;
    half color : TEXCOORD6;
    float4 debugInfo : TEXCOORD1;

    //float4 additionalData : TEXCOORD10;
    
    //#if defined(LIGHTMAP_ON)
    //float2 lightmapUV : TEXCOORD6;
    //#endif
    
    //#if !defined(LIGHTMAP_ON)
    //float3 sh : TEXCOORD7;
    //#endif

    //float2 uv_WaterWave : TEXCOORD8;
};

// per object data
CBUFFER_START(UnityPerMaterial)
// smoothness
half _Roughness;
float _FresnelPower;
// color
TEXTURE2D(_GradientMap); SAMPLER(sampler_GradientMap);
half4 _ShoreColor;
float _ShoreColorThreshold;
half4 _Emission;
// tessellation
float _VectorLength;
//float _TessellationMinDistance;
//float _TessellationMaxDistance;
//float _TessellationFactor;
// vertex offset
TEXTURE2D(_NoiseTextureA); SAMPLER(sampler_NoiseTextureA);
float4 _NoiseTextureA_ST;
float4 _NoiseAProperties;
TEXTURE2D(_NoiseTextureB); SAMPLER(sampler_NoiseTextureB);
float4 _NoiseTextureB_ST;
float4 _NoiseBProperties;
float _OffsetAmount;
float _MinOffset;
// Displacement
float4 _DisplacementProperties;
TEXTURE2D(_DisplacementGuide); SAMPLER(sampler_DisplacementGuide);
float4 _DisplacementGuide_ST;
// Shore and Foam
float _ShoreIntersectionThreshold;
TEXTURE2D(_FoamTexture); SAMPLER(sampler_FoamTexture);
float4 _FoamProperties;
float4 _FoamTexture_ST;
float4 _FoamIntersectionProperties;
// transparency
float _TransparencyIntersectionThresholdMax;
float _TransparencyIntersectionThresholdMin;
CBUFFER_END

// shared data

#endif