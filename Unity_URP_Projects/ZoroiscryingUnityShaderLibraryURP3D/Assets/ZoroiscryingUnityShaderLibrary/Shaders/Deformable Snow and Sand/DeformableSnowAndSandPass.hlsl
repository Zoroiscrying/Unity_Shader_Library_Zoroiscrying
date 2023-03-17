#ifndef CUSTOM_VEGETATION_PASS_INCLUDED
#define CUSTOM_VEGETATION_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "SampleSnowAndSand.hlsl"

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    
    inputData.positionWS = input.positionWS;
    
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

ControlPoint SnowAndSandPassVertexForTessellation(Attributes input)
{
    ControlPoint output;

    output.normalOS = input.normalOS;
    output.positionOS = input.positionOS;
    output.tangentOS = input.tangentOS;
    output.uv = input.uv;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    return output;    
}


Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // 1. first calculate the displacement
    // - displacement here
    const float3 positionWS_original = TransformObjectToWorld(input.positionOS.xyz);
    float depression_height_ws = 0.0f;
    float foot_height_ws = 0.0f;
    const float sample_dist = 0.1f;

    float3 bitangent = cross(input.normalOS, input.tangentOS.xyz);
    
    // original modified position
    float3 position_ws_modified = positionWS_original;
    SampleSnowAndSandTexture(position_ws_modified, depression_height_ws, foot_height_ws);
    ProcessSnowAndSandDisplacement(position_ws_modified, depression_height_ws, foot_height_ws);
    // modified position - tangent dir
    float3 position_ws_tangent_dir_modified = positionWS_original + TransformObjectToWorldDir(input.tangentOS.xyz) * sample_dist;
    SampleSnowAndSandTexture(position_ws_tangent_dir_modified, depression_height_ws, foot_height_ws);
    ProcessSnowAndSandDisplacement(position_ws_tangent_dir_modified, depression_height_ws, foot_height_ws);
    // modified position - bi-tangent dir
    float3 position_ws_biTangent_dir_modified = positionWS_original + TransformObjectToWorldDir(bitangent) * sample_dist;
    SampleSnowAndSandTexture(position_ws_biTangent_dir_modified, depression_height_ws, foot_height_ws);
    ProcessSnowAndSandDisplacement(position_ws_biTangent_dir_modified, depression_height_ws, foot_height_ws);
    // -- to improve the accuracy, we use even 2 more samples in the neg-tangent and neg-bi-tangent directions
    float3 position_ws_neg_tangent_dir_modified = positionWS_original + TransformObjectToWorldDir(input.tangentOS.xyz) * -sample_dist;
    SampleSnowAndSandTexture(position_ws_neg_tangent_dir_modified, depression_height_ws, foot_height_ws);
    ProcessSnowAndSandDisplacement(position_ws_neg_tangent_dir_modified, depression_height_ws, foot_height_ws);
    // modified position - bi-tangent dir
    float3 position_ws_neg_biTangent_dir_modified = positionWS_original + TransformObjectToWorldDir(bitangent) * -sample_dist;
    SampleSnowAndSandTexture(position_ws_neg_biTangent_dir_modified, depression_height_ws, foot_height_ws);
    ProcessSnowAndSandDisplacement(position_ws_neg_biTangent_dir_modified, depression_height_ws, foot_height_ws);
    
    // 2. Recalculate vertex normal based on near-position tangent and bi-tangent
    const float3 position_os_modified = TransformWorldToObject(position_ws_modified);
    // const float3 positionOS_TangentDir = TransformWorldToObject(position_ws_tangent_dir_modified);
    // const float3 positionOS_BiTangentDir = TransformWorldToObject(position_ws_biTangent_dir_modified);

    float3 normal_ws_recalculated = 0;
    
    //RecalculateVertexNormal_CrossBased_TwoDirection(position_os_modified,
    //positionOS_TangentDir, positionOS_BiTangentDir, input.normalOS);
    RecalculateVertexNormal_CrossBased_FourDirection(position_ws_modified,
        position_ws_tangent_dir_modified, position_ws_biTangent_dir_modified,
        position_ws_neg_tangent_dir_modified, position_ws_neg_biTangent_dir_modified,
        normal_ws_recalculated);
    input.normalOS = TransformWorldToObjectNormal(normal_ws_recalculated);
    
    input.tangentOS.xyz = TransformWorldToObjectDir(position_ws_tangent_dir_modified - position_ws_neg_tangent_dir_modified);
    
    VertexPositionInputs vertexInput = GetVertexPositionInputs(position_os_modified);

    // 2. do normal vertex shading stuffs, we will use ddx ddy to calculate pixel normals afterwards
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
    
    output.positionWS = vertexInput.positionWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;
    return output;
}

Varyings VertexToFragment(Attributes input)
{
    return LitPassVertex(input);    
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
    
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    // surfaceData.albedo = lerp(surfaceData.albedo * 0.2f, surfaceData.albedo * 1.0f, saturate(input.positionWS.y / 2.0f));

    InputData inputData;
    // recalculate normal ws here
    // const float3 ddxPos = ddx(input.positionWS);
    // const float3 ddyPos = ddy(input.positionWS) * _ProjectionParams.x;
    // input.normalWS = normalize(cross(ddxPos, ddyPos));
    
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

    #ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif

    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = 1.0f;

    return color;
}

#endif
