#ifndef CEL_SHADING_MODEL_INCLUDED
#define CEL_SHADING_MODEL_INCLUDED

#include "CelShadingData.hlsl"

inline void InitializeCelShadingData(out CelShadingData celShadingData)
{
    celShadingData.DiffuseBandNumber = 1;
    celShadingData.SpecularBandNumber = 1;
    celShadingData.DiffuseLightCutOff = 0.5;
    celShadingData.SpecularLightCutOff = 0.5;
    celShadingData.RimLightColor = 0;
    celShadingData.RimLightSize = 0.5;
}

inline void InitializeCelShadingData(half diffuseLightCutoff, half specularLightCutoff, half diffuseBandNumber, half specularBandNumber,out CelShadingData celShadingData)
{
    celShadingData.DiffuseBandNumber = diffuseBandNumber;
    celShadingData.SpecularBandNumber = specularBandNumber;
    celShadingData.DiffuseLightCutOff = diffuseLightCutoff;
    celShadingData.SpecularLightCutOff = specularLightCutoff;
    celShadingData.RimLightColor = 0;
    celShadingData.RimLightSize = 0.5;
}

inline void InitializeCelShadingData(half diffuseLightCutoff, half specularLightCutoff, half diffuseBandNumber, half specularBandNumber, half rimLightSize, half3 rimLightColor, out CelShadingData celShadingData)
{
    celShadingData.DiffuseBandNumber = diffuseBandNumber;
    celShadingData.SpecularBandNumber = specularBandNumber;
    celShadingData.DiffuseLightCutOff = diffuseLightCutoff;
    celShadingData.SpecularLightCutOff = specularLightCutoff;
    celShadingData.RimLightColor = rimLightSize;
    celShadingData.RimLightSize = rimLightColor;
}

inline void InitializeCelShadingCharacterData(half diffuseLightCutoff, half specularLightCutoff, half diffuseBandNumber, half specularBandNumber, half rimLightSize, half3 rimLightColor, out CelShadingCharacterData celShadingData)
{
    celShadingData.DiffuseBandNumber = diffuseBandNumber;
    celShadingData.SpecularBandNumber = specularBandNumber;
    celShadingData.DiffuseLightCutOff = diffuseLightCutoff;
    celShadingData.SpecularLightCutOff = specularLightCutoff;
    celShadingData.RimLightColor = rimLightSize;
    celShadingData.RimSize = rimLightColor;
}

inline void InitializeCelShadingOutlineData(half outlineSize, out CelShadingOutlineData celShadingOutlineData)
{
    celShadingOutlineData.OutlineThickness = outlineSize;
}

half3 LightingPhysicallyBased_Cel(BRDFData brdfData, BRDFData brdfDataClearCoat,
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
    half3 normalWS, half3 viewDirectionWS,
    half clearCoatMask, bool specularHighlightsOff, CelShadingData celShadingData)
{
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    #if _SMOOTH_STEP_LIGHT_EDGE
    half bandedNdotL =
        smoothstep(celShadingData.DiffuseLightCutOff - 0.05, celShadingData.DiffuseLightCutOff + 0.05, NdotL);
    #else
    half bandedNdotL = 
        floor(saturate(NdotL / celShadingData.DiffuseLightCutOff) * celShadingData.DiffuseBandNumber)/ celShadingData.DiffuseBandNumber;
    #endif

    half3 radiance = lightColor * (lightAttenuation * bandedNdotL);

    half3 brdf = brdfData.diffuse;
#ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        half specularStrength = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
        #if _SMOOTH_STEP_LIGHT_EDGE
        half bandedSpecular = smoothstep(celShadingData.SpecularLightCutOff - 0.25, celShadingData.SpecularLightCutOff + 0.25, specularStrength);
        #else
        half bandedSpecular = floor(saturate(specularStrength / celShadingData.SpecularLightCutOff) * celShadingData.SpecularBandNumber) / celShadingData.SpecularBandNumber;
        #endif
        brdf += brdfData.specular * bandedSpecular;

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half coatSpecularStrength = DirectBRDFSpecular(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);
        half bandedCoatSpecular = round(saturate(coatSpecularStrength / celShadingData.SpecularLightCutOff) * celShadingData.SpecularBandNumber) / celShadingData.SpecularBandNumber;
        half brdfCoat = kDielectricSpec.r * bandedCoatSpecular;

            // Mix clear coat and base layer using khronos glTF recommended formula
            // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
            // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
            half NoV = saturate(dot(normalWS, viewDirectionWS));
            // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
            // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
            half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask;
#endif // _CLEARCOAT
    }
#endif // _SPECULARHIGHLIGHTS_OFF

    return brdf * radiance;
}

////////////////////////////////////////////////////////////////////////////////
/// Cel lighting
////////////////////////////////////////////////////////////////////////////////
half4 CelShadingPBR(InputData inputData, SurfaceData surfaceData, CelShadingData celShadingData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased_Cel(brdfData, brdfDataClearCoat,
                                                              mainLight.color, mainLight.direction, mainLight.distanceAttenuation * mainLight.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, celShadingData);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Cel(brdfData, brdfDataClearCoat,
                                                              light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, celShadingData);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

half4 CelShadingBase(InputData inputData, SurfaceData surfaceData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

////////////////////////////////////////////////////////////////////////////////
/// Cel lighting Character Modified
////////////////////////////////////////////////////////////////////////////////
half4 CelShading_CharacterModified(InputData inputData, SurfaceData surfaceData, CelShadingData celShadingData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased_Cel(brdfData, brdfDataClearCoat,
                                                              mainLight.color, mainLight.direction, mainLight.distanceAttenuation * mainLight.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, celShadingData);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Cel(brdfData, brdfDataClearCoat,
                                                              light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, celShadingData);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

#endif