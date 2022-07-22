#ifndef PLANAR_REFLECTION_PASS_INCLUDED
#define PLANAR_REFLECTION_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "../../../ShaderLibrary/PlanarReflectionTexture.hlsl"

float4 _ReflectionTint;
float _Roughness;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv : TEXCOORD0;

    #if defined(DEBUG_DISPLAY)
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float fogCoord : TEXCOORD1;
    float4 positionCS : SV_POSITION;
    float3 positionVS : TEXCOORD5;
    float3 positionWS : TEXCOORD6;
    float2 uvUntransformed : TEXCOORD7;
    float4 tangentWS  : TEXCOORD8;
    float3 normalWS   : TEXCOORD9;

    #if defined(DEBUG_DISPLAY)
    float3 positionWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float3 viewDirWS : TEXCOORD4;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, out InputData inputData)
{
    inputData = (InputData)0;

    #if defined(DEBUG_DISPLAY)
    inputData.positionWS = input.positionWS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = input.viewDirWS;
    #else
    inputData.positionWS = float3(0, 0, 0);
    inputData.normalWS = half3(0, 0, 1);
    inputData.viewDirectionWS = half3(0, 0, 1);
    #endif
    inputData.shadowCoord = 0;
    inputData.fogCoord = 0;
    inputData.vertexLighting = half3(0, 0, 0);
    inputData.bakedGI = half3(0, 0, 0);
    inputData.normalizedScreenSpaceUV = 0;
    inputData.shadowMask = half4(1, 1, 1, 1);
}

Varyings UnlitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = vertexInput.positionCS;
    output.positionVS = vertexInput.positionVS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS   = normalInput.normalWS;
    
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.tangentWS = tangentWS;

    //float sgn = tangentWS.w;      // should be either +1 or -1
    //float3 bitangent = sgn * cross(output.normalWS.xyz, output.tangentWS.xyz);
    //half3x3 tangentToWorld = half3x3(output.tangentWS.xyz, bitangent.xyz, output.normalWS.xyz);
    //float3 normalFromHeight = ReconstructNormalFromGrayScaleHeightTexture(animat)

    //output.normalWS = TransformTangentToWorld()
    
    output.uvUntransformed = input.uv;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    
    #if defined(_FOG_FRAGMENT)
    output.fogCoord = vertexInput.positionVS.z;
    #else
    output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    #if defined(DEBUG_DISPLAY)
    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

    // already normalized from normal transform to WS.
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
    #endif

    return output;
}

half4 UnlitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float2 positionSS = GetNormalizedScreenSpaceUV(input.positionCS);
    half2 uv = input.uv + half2(_Time.x * 2, _Time.x * 0.1);

    InputData inputData;
    InitializeInputData(input, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
    half3 color = SAMPLE_TEXTURE2D_LOD(
        _PlanarReflectionTexture, planar_Trilinear_Clamp_Sampler, positionSS +
        half2(0.0h, 0.0h), 6 * _Roughness).rgb * LerpWhiteTo(_ReflectionTint.rgb, _ReflectionTint.a);
    
#ifdef _DBUFFER
    ApplyDecalToBaseColor(input.positionCS, color);
#endif

    #if defined(_FOG_FRAGMENT)
        #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
        float viewZ = -input.fogCoord;
        float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
        half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
        #else
        half fogFactor = 0;
        #endif
    #else
    half fogFactor = input.fogCoord;
    #endif
    half4 finalColor = UniversalFragmentUnlit(inputData, color, 1.0);

#if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(normalizedScreenSpaceUV);
    finalColor.rgb *= aoFactor.directAmbientOcclusion;
#endif

    finalColor.rgb = MixFog(finalColor.rgb, fogFactor);
    //finalColor.rgb = lerp(finalColor.rgb, refractionColor, refractionAlpha);
    //finalColor.rgb = fresnelStrength * _AnimatedEmissionColor.rgb;

    return finalColor;
}


#endif