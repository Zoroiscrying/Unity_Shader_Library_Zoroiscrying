﻿#ifndef ADVANCED_DISPLACEMENT_PASS
#define ADVANCED_DISPLACEMENT_PASS

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Object/VertexDisplacement.hlsl"

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// Inputs of Displacement Shader
float4 _DisplacementDirection;
float4 _DisplacementAmplitude;
half _SampleFrequency;
half _SampleSpeed;
half _DisplaceColorBlendStrength;
float _DisplaceStrengthPower;
half4 _DisplaceColor;
TEXTURE2D(_DisplaceColorRamp);        SAMPLER(sampler_DisplaceColorRamp);

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float3 positionWS               : TEXCOORD1;
    half3 normalWS                 : TEXCOORD2;
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
    float3 viewDirWS                : TEXCOORD4;

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
#else
    half  fogFactor                 : TEXCOORD5;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD6;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                : TEXCOORD7;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
#endif

    float4 positionCS               : SV_POSITION;
    float displacementStrength : TEXCOORD10;
    float3 originalPositionWS : TEXCOORD11;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    
    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    inputData.tangentToWorld = tangentToWorld;
    
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
    
    
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.originalPositionWS = TransformObjectToWorld(input.positionOS.xyz);

    float3 originalPositionWS = output.originalPositionWS;
    float3 originalNormalWS = TransformObjectToWorldNormal(input.normalOS);
    //VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    float displacementStrength = 0.0;
    float3 displacementAmplitude = originalNormalWS * _DisplacementAmplitude * (1 - abs(dot(output.normalWS, float3(0, 1, 0))));
    float3 displacementDirection = float3(-0.5 * value_noise11(originalPositionWS.y * 0.5 + _Time.x * 1.0), 1, 0.2);

    #if _SAMPLE_SINE
    
    displacementStrength = ApplySinVertexDisplacement_VectorDotProjection(
        originalPositionWS, displacementDirection, displacementAmplitude, _SampleFrequency, _SampleSpeed);
    //originalPositionWS += float3(1,0,0);
    
    #elif _SAMPLE_NOISE

    displacementStrength = ApplyGradientNoiseVertexDisplacement_VectorDotProjection_Test(
        originalPositionWS, originalNormalWS, displacementDirection, displacementAmplitude, _SampleFrequency, _SampleSpeed);

    #endif
    
    // Re update the value after the tweak
    input.positionOS.xyz = TransformWorldToObject(originalPositionWS);
    
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.tangentWS = tangentWS;
    //half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    //output.viewDirTS = viewDirTS;
    
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif
    
    output.positionWS = vertexInput.positionWS;
    
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.displacementStrength = displacementStrength;
    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    float emissionFactor = 0;
    float3 displacementAmplitude = input.normalWS * _DisplacementAmplitude * (1 - abs(dot(input.normalWS, float3(0,1,0))));
    float3 displacementDirection = float3(-0.5 * value_noise11(input.originalPositionWS.y * 0.5 + _Time.x * 1.0), 1, 0.2);
    
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    //clip(dissolveFactor);
    
#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif
    
    //float3 positionWS = TransformObjectToWorld(input.originalPositionWS);
    float displacementStrength = ApplyGradientNoiseVertexDisplacement_VectorDotProjection_Test(
        input.originalPositionWS, input.normalWS, displacementDirection, displacementAmplitude, _SampleFrequency, _SampleSpeed);
    surfaceData.emission += _DisplaceColor.xyz * pow(clamp(displacementStrength, 0.01, 1.0), _DisplaceStrengthPower) * _DisplaceColorBlendStrength;

    surfaceData.albedo = lerp(surfaceData.albedo, _DisplaceColor.xyz, pow(clamp(displacementStrength, 0.01, 1.0), _DisplaceStrengthPower) * _DisplaceColorBlendStrength);
    surfaceData.albedo = 0;
    surfaceData.emission = SAMPLE_TEXTURE2D(_DisplaceColorRamp, sampler_DisplaceColorRamp, float2(displacementStrength ,0)).xyz * 4;
    
    //half4 color = UniversalFragmentPBR(inputData, surfaceData);
    half4 color = half4(1,1,1,1);
    color.rgb = surfaceData.albedo + surfaceData.emission;
    
    //color.rgb = MixFog(color.rgb, inputData.fogCoord);
    //color.a = OutputAlpha(color.a, _Surface);
    
    return color;
}

#endif