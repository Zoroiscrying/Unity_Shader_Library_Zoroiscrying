#ifndef VEGETATION_SHADING_MODEL_INCLUDED
#define VEGETATION_SHADING_MODEL_INCLUDED

#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/ShadingModel/VegetationShadingData.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomHash.hlsl"

// VERTEX SHADING FUNCTIONS
void ComputeMovementScale(inout float movementScale, float3 positionOS, float normalizedDistance)
{
    
}

void ApplyVertexDisplacementForVegetation_NonPersistentData(
    inout float3 positionOS,
    float3 pivotPositionOS,
    Vegetation_DisplacementData displacementData)
{
    // two layers of noise here, when wind is at high speed, high density noise will appear more
    
    const float3 positionWS_ObjectCenter = TransformObjectToWorld(float3(0, 0, 0));
    const float3 positionWS_preModify = TransformObjectToWorld(positionOS);
    const float vertexLengthWS = length(positionWS_preModify - positionWS_ObjectCenter);
    
    float3 positionDeltaWS = 0;
    // leaf movement - parameterized, controlled purely by time, pure local noise
    float3 lowDensityNoise = spherical_noise33(
        positionWS_preModify.xyz * displacementData._ParameterMovementDensity * rcp(max(.1f, displacementData._ParameterMovementStiffness))
        + _Time.y * float3(1.6f, .2f, 1.6f));
    float3 highDensityNoise = spherical_noise33(
        positionWS_preModify.xyz * displacementData._ParameterMovementDensity * rcp(max(.1f, displacementData._ParameterMovementStiffness)) * 4.0f
        + _Time.y * float3(6.4f, .8f, 6.4f));

    // directional wind contribution
    const float oneDimensionalCoord = (positionWS_preModify.x + positionWS_preModify.y + positionWS_preModify.z)
    * displacementData._ParameterMovementDensity;
    const float windSpeed = length(displacementData._WindVelocityVector);
    const float3 windDirection = displacementData._WindVelocityVector * rcp(windSpeed);
    const float3 windContributionLowFreq = windDirection * 16.0f * windSpeed;
    const float3 windContributionHighFreq = windDirection * (sin(oneDimensionalCoord + _Time.y * 16.0f) + 1.2) * 4.0f * windSpeed;
    
    // additive wind displacements
    positionDeltaWS += lerp(lowDensityNoise, highDensityNoise, 0.2f);
    positionDeltaWS += lerp(windContributionLowFreq, windContributionHighFreq, 0.2f);
    
    // branch movement - stateful, controlled by compute parameters
    if (_SwayInstanceIndex < SwayInstanceTailIndex)
    {
        positionDeltaWS += InstancesSwayVectorBuffer[_SwayInstanceIndex] * 0.5f;
    }

    #if STATEFUL_BRANCH
    
    #endif
    
    // tree movement

    #if STATEFUL_TREE
    
    #endif

    // composite
    displacementData._ParameterMovementScale *= pow(saturate(displacementData._ParameterMovementScale), displacementData._ParameterMovementBend);
    positionDeltaWS *= displacementData._ParameterMovementScale;
    
    const float3 modifiedCenterOffsetWS = (positionWS_preModify + positionDeltaWS) - positionWS_ObjectCenter;
    const float magnitude = length(modifiedCenterOffsetWS);
    real safeMag = sqrt(max(REAL_MIN, dot(modifiedCenterOffsetWS, modifiedCenterOffsetWS)));
    positionOS =
        TransformWorldToObject(modifiedCenterOffsetWS * rcp(safeMag) // normalize
            * lerp(vertexLengthWS, magnitude, displacementData._ParameterMovementStretch) // magnitude affected by stretch
            + positionWS_ObjectCenter); // add the position center back
}

// Persistant data relates to instance-specific data describing movement-related variables
// such as bent strength (for tree branch, flag, etc.)
// Tree branch's bent direction can be stored otherwise in low-res textures also.
// The result won't reflect realistic physics, but with fluent noises, it can perform well.
void ApplyVertexDisplacementForVegetation_PersistentData()
{
    
}

void RecalculateVertexNormal_DerivativeBased_PixelShaderOnly(float3 positionOS, inout float3 normalOS)
{
    const float3 ddxPos = ddx(positionOS);
    const float3 ddyPos = ddy(positionOS)*_ProjectionParams.x;
    normalOS = normalize(cross(ddxPos, ddyPos));
}

void RecalculateVertexNormal_CrossBased(float3 positionOS, float3 positionOS_Tangent_Direction, float3 positionOS_BiTangent_Direction, inout float3 normalOS)
{
    float3 tangent = SafeNormalize(positionOS_Tangent_Direction - positionOS);
    float3 biTangent = SafeNormalize(positionOS_BiTangent_Direction - positionOS);
    normalOS = normalize(cross(tangent, biTangent));
}

// PIXEL SHADING FUNCTIONS
half3 LightingPhysicallyBased_Vegetation(BRDFData brdfData,
                                         half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
                                         half3 normalWS, half3 viewDirectionWS, VegetationSurfaceShadingData vegetationShadingData)
{
    // Diffuse Calculation
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * lightAttenuation * NdotL;
    half3 brdf = brdfData.diffuse;

    // Specular Calculation
    half specularStrength = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
    brdf += brdfData.specular * specularStrength;
    
    return brdf * radiance;
}

half3 LightingPhysicallyBased_Vegetation(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, VegetationSurfaceShadingData vegetationData)
{
    return LightingPhysicallyBased_Vegetation(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, vegetationData);
}

inline void InitializeBRDFData(inout VegetationSurfaceShadingData vegetationData, out BRDFData brdfData)
{
    InitializeBRDFData(vegetationData.albedo, vegetationData.metallic, vegetationData.specular, vegetationData.smoothness, vegetationData.alpha, brdfData);
}

AmbientOcclusionFactor CreateAmbientOcclusionFactor(InputData inputData, VegetationSurfaceShadingData vegetationData)
{
    return CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, vegetationData.occlusion);
}

LightingData CreateLightingData(InputData inputData, VegetationSurfaceShadingData vegetationData)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = vegetationData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

half4 UniversalVegetationFragmentPBR(InputData inputData, VegetationSurfaceShadingData vegetationData)
{
    BRDFData brdfData;
    InitializeBRDFData(vegetationData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, vegetationData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, vegetationData);
    lightingData.giColor = GlobalIllumination(brdfData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased_Vegetation(brdfData, mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS, vegetationData);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Vegetation(brdfData, light,
                                                              inputData.normalWS, inputData.viewDirectionWS, vegetationData);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Vegetation(brdfData, light,
                                                              inputData.normalWS, inputData.viewDirectionWS, vegetationData);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, vegetationData.alpha);
}

#endif