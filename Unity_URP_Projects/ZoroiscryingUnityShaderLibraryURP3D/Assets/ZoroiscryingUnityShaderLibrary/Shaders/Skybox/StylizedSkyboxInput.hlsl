#ifndef STYLIZED_SKYBOX_INPUT_INCLUDED
#define STYLIZED_SKYBOX_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 uv : TEXCOORD0;
};
 
struct Varyings
{
    float3 uv : TEXCOORD0;
    float4 positionVS : SV_POSITION;
};

CBUFFER_START(UnityPerMaterial)
half4 _ColorBottom;
half4 _ColorMiddle;
half4 _ColorTop;

float _MiddleSmoothness;
float _MiddleOffset;
float _TopSmoothness;
float _TopOffset;

half4 _SunColor;
float _SunSize;

float _MoonSize;
half4 _MoonColor;
float _MoonPhase;

// sampler2D _Stars;
float4 _Stars_ST;
float _StarsIntensity;

//sampler2D _CloudsTexture;
float4 _CloudsTexture_ST;
half4 _CloudsColor;
float _CloudsSmoothness;
float _CloudsThreshold;
float _SunCloudIntensity;
float _PanningSpeedX;
float _PanningSpeedY;
CBUFFER_END

TEXTURE2D(_Stars); SAMPLER(sampler_Stars);
TEXTURE2D(_CloudsTexture); SAMPLER(sampler_CloudsTexture);

#endif