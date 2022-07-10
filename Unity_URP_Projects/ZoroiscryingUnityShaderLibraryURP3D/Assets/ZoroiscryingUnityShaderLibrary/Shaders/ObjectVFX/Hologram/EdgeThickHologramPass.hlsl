#ifndef EDGE_THICK_HOLOGRAM_PASS
#define EDGE_THICK_HOLOGRAM_PASS


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif



// Inputs of Hologram shader
// - Scanline 1
float _ScanlineThickness1;
float _ScanlineSpeed1;
float4 _ScanlineDirection1;
float _ScanlineSampleScale1;
half4 _ScanlineColor1;
// - Scanline 2
float _ScanlineThickness2;
float _ScanlineSpeed2;
float4 _ScanlineDirection2;
float _ScanlineSampleScale2;
half4 _ScanlineColor2;
// - Rim Light
float _RimLightThickness;
half4 _RimLightColor;
// - Vertex Displacement
float _DisplacementStrength;
float _DisplacementAmount;
float _DisplacementSpeed;
float4 _DisplacementDirection;

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

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
#endif

    half3 normalWS                 : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
#endif
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

#if _SCREEN_SPACE_TRANSPARENT || _SCREEN_SPACE_SCANLINE
    float4 positionSS : TEXCOORD10;
#endif
    
    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    inputData.normalWS = input.normalWS;
#endif

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

    // Apply vertex displacement here
    float glitchStep = 0.99 - 0.01 * (_DisplacementAmount - 0.5) * 2.0;
    // sudden glitch
    float glitchStrength = step(glitchStep, value_noise11(input.positionOS.z * 10.0 + _Time.x * -1000.0)) * _DisplacementStrength;
    // slow distortion
    float distortionStrength = step(0.6, pow(value_noise11(input.positionOS.z * 10.0 + _Time.x * 10.0 * _DisplacementSpeed), 2)) * _DisplacementStrength * value_noise11(input.positionOS.z * 5.0);
    input.positionOS.xyz += _DisplacementDirection.xyz * float3(value_noise11(_Time.x), value_noise11(_Time.y), value_noise11(_Time.x + 1955.5)) * (glitchStrength + distortionStrength);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

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

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;
#if _SCREEN_SPACE_TRANSPARENT || _SCREEN_SPACE_SCANLINE
    output.positionSS = ComputeScreenPos(output.positionCS);
#endif

    return output;
}

float ScanLine_Strength_WS(float3 positionWS, float3 scanDirection, half timeScale, half scanlineThickness, half scanlineSampleScale)
{
    float strength = 0.0;
    float scanVector = (dot(positionWS, scanDirection) + 1)/2;
    
    //strength = step(1.0 - scanlineThickness, frac(scanVector * scanlineSampleScale + timeScale * _Time.x));
    
    strength = pow(Smoothstep01(abs(frac(scanVector * scanlineSampleScale + timeScale * _Time.x * 0.5) * 2 - 1)), scanlineThickness);
    
    return strength;
}

float ScanLine_Strength_WS_Noise(float3 positionWS, float3 scanDirection, half timeScale, half scanlineThickness, half scanlineSampleScale)
{
    float strength = 0.0;
    float scanVector = (dot(positionWS, scanDirection) + 1)/2;
    
    //strength = step(1.0 - scanlineThickness, frac(scanVector * scanlineSampleScale + timeScale * _Time.x));
    
    strength = pow(Smoothstep01(abs(value_noise11(scanVector * scanlineSampleScale + timeScale * _Time.x * 0.5) * 2 - 1)), scanlineThickness);
    
    return strength;
}

float ScanLine_Strength_SS(float3 positionSS, float3 scanDirection, half timeScale, half scanlineThickness, half scanlineSampleScale)
{
    float strength = 0.0;
    float scanVector = (dot(positionSS, scanDirection) + 1)/2;

    strength = pow(Smoothstep01(abs(frac(scanVector * scanlineSampleScale + timeScale * _Time.x * 0.5) * 2 - 1)), scanlineThickness);
    
    return strength;
}

float Rim_Light_Strength(float3 normalWS, float3 viewDirectionWS, float rimLightThickness)
{
    float strength = 0.0;

    strength = pow(1 - saturate(dot(normalWS, viewDirectionWS)), rimLightThickness);
    
    return strength;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // Scanline Emission

    float noiseV = value_noise11(input.positionWS.z * 0.1);
    noiseV = lerp(0.5, 1.0, noiseV);

    float rimLightStrength = Rim_Light_Strength(input.normalWS, viewDirWS, _RimLightThickness);
    float scanlineEdgeStrength = Rim_Light_Strength(input.normalWS, viewDirWS, 1.0);
    float edgeFactor = clamp(1 - scanlineEdgeStrength, 0.1, 1.0);

    #if _SCREEN_SPACE_SCANLINE
    float scanlineEmissionStrength1 =
    ScanLine_Strength_SS(input.positionSS, _ScanlineDirection1.xyz,
        _ScanlineSpeed1, _ScanlineThickness1, _ScanlineSampleScale1 * noiseV);
    float scanlineEmissionStrength2 =
    ScanLine_Strength_SS(input.positionSS, _ScanlineDirection2.xyz,
        _ScanlineSpeed2, _ScanlineThickness2, _ScanlineSampleScale2 * noiseV);
    
    #else
    float scanlineEmissionStrength1 =
        ScanLine_Strength_WS(input.positionWS, _ScanlineDirection1.xyz,
            _ScanlineSpeed1, _ScanlineThickness1 * edgeFactor, _ScanlineSampleScale1 * noiseV);
    float scanlineEmissionStrength2 =
        ScanLine_Strength_WS_Noise(input.positionWS, _ScanlineDirection2.xyz,
            _ScanlineSpeed2, _ScanlineThickness2 * edgeFactor, _ScanlineSampleScale2 * noiseV);
    
    #endif
    
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    surfaceData.emission += _ScanlineColor1 * scanlineEmissionStrength1;
    surfaceData.emission += _ScanlineColor2 * scanlineEmissionStrength2;
    surfaceData.emission += _RimLightColor * rimLightStrength;
    
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

    #if _SCREEN_SPACE_TRANSPARENT
    half3 sceneColor = SampleSceneColor(input.positionSS.xy / input.positionSS.w);
    half4 color = half4(surfaceData.emission + sceneColor, 1.0);
    #else
    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    #endif
    //half4 color = UniversalFragmentPBR(inputData, surfaceData);
    //half4 color = half4(surfaceData.emission + sceneColor, 1.0);

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);
    
    return color;
}

#endif