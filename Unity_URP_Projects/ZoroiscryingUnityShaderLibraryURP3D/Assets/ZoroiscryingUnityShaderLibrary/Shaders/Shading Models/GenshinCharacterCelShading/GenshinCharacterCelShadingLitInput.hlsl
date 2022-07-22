#ifndef CEL_SHADING_LIT_INPUT_INCLUDED
#define CEL_SHADING_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/ShadingModel/GenshinCharacterShadingData.hlsl"

#if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
#define _DETAIL
#endif

// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
half4 _BaseColor;
half4 _SpecColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _ClearCoatMask;
half _ClearCoatSmoothness;
// Cel shading properties
half _DiffuseLightCutOff;
half _SpecularLightCutOff;
half _DiffuseEdgeSmoothness;
half _SpecularEdgeSmoothness;
half _RimLightThickness;
half4 _RimLightColor;
half _DiffuseLightMultiplier;
half _SpecularLightMultiplier;
half _EmissionLightMultiplier;
half4 _CharacterLightParameter;
half _ShadowIntensity;
CBUFFER_END

// NOTE: Do not ifdef the properties for dots instancing, but ifdef the actual usage.
// Otherwise you might break CPU-side as property constant-buffer offsets change per variant.
// NOTE: Dots instancing is orthogonal to the constant buffer above.
#ifdef UNITY_DOTS_INSTANCING_ENABLED
// TODO:: Implement cel shading properties to DOTS_INSTANCING_FIELD
UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _SpecColor)
    UNITY_DOTS_INSTANCED_PROP(float , _Cutoff)
    UNITY_DOTS_INSTANCED_PROP(float , _Smoothness)
    UNITY_DOTS_INSTANCED_PROP(float , _Metallic)
    UNITY_DOTS_INSTANCED_PROP(float , _BumpScale)
    UNITY_DOTS_INSTANCED_PROP(float , _Parallax)
    UNITY_DOTS_INSTANCED_PROP(float , _OcclusionStrength)
    UNITY_DOTS_INSTANCED_PROP(float , _ClearCoatMask)
    UNITY_DOTS_INSTANCED_PROP(float , _ClearCoatSmoothness)
    UNITY_DOTS_INSTANCED_PROP(float , _Surface)
UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

#define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_BaseColor)
#define _SpecColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_SpecColor)
#define _Cutoff                 UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Cutoff)
#define _Smoothness             UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Smoothness)
#define _Metallic               UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Metallic)
#define _BumpScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_BumpScale)
#define _Parallax               UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Parallax)
#define _OcclusionStrength      UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_OcclusionStrength)
#define _ClearCoatMask          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_ClearCoatMask)
#define _ClearCoatSmoothness    UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_ClearCoatSmoothness)
#define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Surface)
#endif

TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
TEXTURE2D(_CharacterLightMap);        SAMPLER(sampler_CharacterLightMap);
TEXTURE2D(_CharacterRampTexture);        SAMPLER(sampler_CharacterRampTexture);
TEXTURE2D(_SmoothnessMap);        SAMPLER(sampler_SmoothnessMap);

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

half SampleSmoothnessMap(float2 uv)
{
    half smoothness = _Smoothness;
    
    smoothness *= SAMPLE_TEXTURE2D(_SmoothnessMap, sampler_SmoothnessMap, uv);
    
    return smoothness;
}

// Returns clear coat parameters
// .x/.r == mask
// .y/.g == smoothness
half2 SampleClearCoat(float2 uv)
{
#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half2 clearCoatMaskSmoothness = half2(_ClearCoatMask, _ClearCoatSmoothness);

#if defined(_CLEARCOATMAP)
    clearCoatMaskSmoothness *= SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
#endif

    return clearCoatMaskSmoothness;
#else
    return half2(0.0, 1.0);
#endif  // _CLEARCOAT
}

half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
{
    return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
}

half4 SampleCharacterLightMap(float2 uv, TEXTURE2D_PARAM(_characterLightMap, sampler_characterLightMap))
{
    return half4(SAMPLE_TEXTURE2D(_characterLightMap, sampler_characterLightMap, uv));
}

half4 SampleCharacterRampTexture(float2 uv, TEXTURE2D_PARAM(characterRampTexture, sampler_characterRampTexture))
{
    return half4(SAMPLE_TEXTURE2D(characterRampTexture, sampler_characterRampTexture, uv));
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

inline void InitializeCelShadingData(float2 uv, out CelShadingData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    half4 lightMapData = SampleCharacterLightMap(uv, TEXTURE2D_ARGS(_CharacterLightMap, sampler_CharacterLightMap));
    // ramp texture data 
    
    outSurfaceData.Albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.Emission = outSurfaceData.Albedo * albedoAlpha.a * 1.0;

    #if USE_CHARACTER_LIGHT_MAP
    outSurfaceData.SpecularStrength = lightMapData.r;
    outSurfaceData.ShadowWeight = lightMapData.g;
    outSurfaceData.SpecularDetailMask = lightMapData.b;
    outSurfaceData.RampTextureAxisAid_Y = lightMapData.a;
    #else
    outSurfaceData.SpecularStrength = _CharacterLightParameter.r;
    outSurfaceData.ShadowWeight = _CharacterLightParameter.g;
    outSurfaceData.SpecularDetailMask = _CharacterLightParameter.b;
    outSurfaceData.RampTextureAxisAid_Y = _CharacterLightParameter.a;
    #endif

    outSurfaceData.metallic = 0.0;
    outSurfaceData.smoothness = SampleSmoothnessMap(uv);

    outSurfaceData.DiffuseLightCutOff = _DiffuseLightCutOff;
    outSurfaceData.SpecularLightCutOff = _SpecularLightCutOff;

    outSurfaceData.RimLightColor = _RimLightColor;
    outSurfaceData.RimSize = _RimLightThickness;

    outSurfaceData.ShallowShadowColor = outSurfaceData.Albedo * 0.0;
    outSurfaceData.DarkShadowColor = outSurfaceData.Albedo * 0.0;

    outSurfaceData.DiffuseLightMultiplier = _DiffuseLightMultiplier;
    outSurfaceData.SpecularLightMultiplier = _SpecularLightMultiplier;

    outSurfaceData.EmissionLightMultiplier = _EmissionLightMultiplier;

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half2 clearCoat = SampleClearCoat(uv);
    outSurfaceData.clearCoatMask       = clearCoat.r;
    outSurfaceData.clearCoatSmoothness = clearCoat.g;
#else
    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
#endif
}

inline void InitializeCelShadingOutlineData(half outlineSize, out CelShadingOutlineData celShadingOutlineData)
{
    celShadingOutlineData.OutlineThickness = outlineSize;
}

#endif