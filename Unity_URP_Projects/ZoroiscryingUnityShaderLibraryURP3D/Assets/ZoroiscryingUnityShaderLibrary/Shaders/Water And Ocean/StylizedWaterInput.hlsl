#ifndef STYLIZED_WATER_INPUT_INCLUDED
#define STYLIZED_WATER_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct ControlPoint
{
    float4 positionOS : INTERNALTESSPOS;
    float3 positionWS : TEXCOORD0;
    float4 tangentOS : TEXCOORD1;
    float3 normalOS : NORMAL;
    float2 uv1 : TEXCOORD2;
};

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS		: NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv1          : TEXCOORD1;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float3 positionWS	: TEXCOORD1;
    float3 positionVS : TEXCOORD2;
    float4 positionSS   : TEXCOORD3;
    float3 normalWS		: NORMAL;
    float4 tangentWS    : TEXCOORD4;
    float fogFactor : TEXCOORD5;
    //half color : TEXCOORD6;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 8);
    // Offset Y Distance, 
    float4 vertexData : TEXCOORD6;
};

// per object data
CBUFFER_START(UnityPerMaterial)
float _ReflectionIntensity;
// smoothness
half _Roughness;
float _FresnelPower;
// textures
SamplerState ramp_Linear_Clamp_Sampler;
TEXTURE2D(_AbsorptionRamp); float4 _AbsorptionRamp_ST;
TEXTURE2D(_ScatteringRamp); float4 _ScatteringRamp_ST;
float _NormalAlphaStrength;
TEXTURE2D(_NormalMapAlpha); SAMPLER(sampler_NormalMapAlpha); float4 _NormalMapAlpha_ST;
float _NormalBetaStrength;
TEXTURE2D(_NormalMapBeta); SAMPLER(sampler_NormalMapBeta); float4 _NormalMapBeta_ST;
// displacement
float4 _WaveProperties;
float4 _WaveProperties_A;
float4 _WaveProperties_B;
float4 _WaveProperties_C;
float4 _Amplitude;
float4 _Steepness;
// Foam Control
half4 _FoamColor;
float _FoamDistance;
TEXTURE2D(_FoamTexture); SAMPLER(sampler_FoamTexture); float4 _FoamTexture_ST;
// Color Control
float _RefractionStrength;
float _AbsorptionIntensity;
float _AbsorptionDistance;
float _AbsorptionFogDistance;
float4 _ScatteringIntensityControl;
float _ScatteringDistance;
float _ScatteringFogDistance;

CBUFFER_END

// shared data
float4 _CameraDepthTexture_TexelSize;

#endif