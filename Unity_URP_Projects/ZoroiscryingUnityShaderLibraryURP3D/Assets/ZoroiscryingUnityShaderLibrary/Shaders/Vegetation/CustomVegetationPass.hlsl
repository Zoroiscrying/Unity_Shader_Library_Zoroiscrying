#ifndef CUSTOM_VEGETATION_PASS_INCLUDED
#define CUSTOM_VEGETATION_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/ShadingModel/VegetationShadingData.hlsl"
#include "../../ShaderLibrary/ShadingModel/VegetationShadingModel.hlsl"

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
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // 1. first calculate the displacement
    
    // - get the tangent dir displaced positionOS
    float3 positionOS_TangentDir = input.positionOS.xyz + input.tangentOS.xyz * 0.01f;
    
    // - get the bi-tangent dir displaced positionOS
    real sign = real(input.tangentOS.w) * GetOddNegativeScale();
    float3 bitangent = cross(input.normalOS, input.tangentOS.xyz);
    float3 positionOS_BiTangentDir = input.positionOS.xyz + bitangent * 0.01f;

    // - displacement here
    Vegetation_DisplacementData displacement_data;
    InitializeDisplacementData(input, displacement_data);
    ApplyVertexDisplacementForVegetation_NonPersistentData(
        input.positionOS.xyz, input.positionOS.xyz, displacement_data);
    ApplyVertexDisplacementForVegetation_NonPersistentData(
        positionOS_TangentDir, input.positionOS.xyz, displacement_data);
    ApplyVertexDisplacementForVegetation_NonPersistentData(
        positionOS_BiTangentDir, input.positionOS.xyz, displacement_data);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // 2. then recalculate the vertex normal
    RecalculateVertexNormal_CrossBased(input.positionOS.xyz,
        positionOS_TangentDir, positionOS_BiTangentDir, input.normalOS);
    
    // 3. do normal vertex shading stuffs

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.tangentWS = tangentWS;
    // output.tangentWS = normalInput.tangentWS;

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

    output.positionCS = vertexInput.positionCS;
    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    VegetationSurfaceShadingData vegetationSurfaceData;
    InitializeVegetationLitSurfaceData(input.uv, vegetationSurfaceData);
    
    InputData inputData;
    InitializeInputData(input, vegetationSurfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

    half4 color = UniversalVegetationFragmentPBR(inputData, vegetationSurfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = 1.0;
    return color;
}

#endif
