#ifndef CEL_SHADING_MODEL_INCLUDED
#define CEL_SHADING_MODEL_INCLUDED

#include "NPRShadingData.hlsl"

inline void InitializeShadingData(out NPRShadingData nprShadingData)
{
    nprShadingData.DiffuseBandNumber = 1;
    nprShadingData.SpecularBandNumber = 1;
    nprShadingData.DiffuseLightCutOff = 0.5;
    nprShadingData.SpecularLightCutOff = 0.5;
    nprShadingData.RimLightColor = 0;
    nprShadingData.RimLightSize = 0.5;
}

inline void InitializeShadingData(
    half diffuseLightCutoff, half specularLightCutoff, half diffuseBandNumber, half specularBandNumber,
    half diffuseEdgeSmoothness, half specularEdgeSmoothness, half specularStrengthMultiplier,
    half rimLightSize, half3 rimLightColor, half halfToneValue,
    half3 specularColor, half3 shadowColor,
    out NPRShadingData nprShadingData)
{
    nprShadingData.DiffuseBandNumber = max(floor(diffuseBandNumber), 1);
    nprShadingData.DiffuseEdgeSmoothness = diffuseEdgeSmoothness;
    nprShadingData.SpecularBandNumber = max(floor(specularBandNumber), 1);
    nprShadingData.SpecularEdgeSmoothness = specularEdgeSmoothness;
    nprShadingData.SpecularStrengthMultiplier = specularStrengthMultiplier;
    nprShadingData.DiffuseLightCutOff = diffuseLightCutoff;
    nprShadingData.SpecularLightCutOff = specularLightCutoff;

    nprShadingData.SpecularColor = specularColor;
    nprShadingData.ShadowColor = shadowColor;
    
    nprShadingData.RimLightColor = rimLightColor;
    nprShadingData.RimLightSize = rimLightSize;
    nprShadingData.HalfToneValue = halfToneValue;
}


inline void InitializeShadingOutlineData(half outlineSize, out NPRShadingOutlineData nprShadingOutlineData)
{
    nprShadingOutlineData.OutlineThickness = outlineSize;
}

half3 LightingPhysicallyBased_NPR(BRDFData brdfData, BRDFData brdfDataClearCoat,
    half3 lightColor, half3 lightDirectionWS, half lightDistAttenuation, half lightShadowAttenuation,
    half3 normalWS, half3 viewDirectionWS,
    half clearCoatMask, bool specularHighlightsOff, NPRShadingData nprShadingData)
{
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half nprNdotL = 1.0;
    
    // Diffuse Calculation
#if _DIFFUSESHADEMODE_SHARP
    nprNdotL =
        smoothstep(nprShadingData.DiffuseLightCutOff - 0.01, nprShadingData.DiffuseLightCutOff + 0.01, NdotL);
#elif _DIFFUSESHADEMODE_SOFT
    nprNdotL =
        smoothstep(nprShadingData.DiffuseLightCutOff - nprShadingData.DiffuseEdgeSmoothness, nprShadingData.DiffuseLightCutOff + nprShadingData.DiffuseEdgeSmoothness, NdotL);
#elif _DIFFUSESHADEMODE_BANDED
    nprNdotL = 
        round(saturate(NdotL / nprShadingData.DiffuseLightCutOff) * nprShadingData.DiffuseBandNumber)/ nprShadingData.DiffuseBandNumber;
#elif _DIFFUSESHADEMODE_HALFTONE
    nprNdotL = smoothstep(nprShadingData.HalfToneValue - 0.01, nprShadingData.HalfToneValue + 0.01, NdotL);
#endif

    half lightAttenuation = lightDistAttenuation * lightShadowAttenuation;
    half3 radiance = lightColor * (lightAttenuation * nprNdotL);
    half3 brdf = brdfData.diffuse * lightColor * lightDistAttenuation * lerp(nprShadingData.ShadowColor, 1.0, nprNdotL * lightShadowAttenuation);

    // Specular Calculation
#ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        // modified to fit the 0-1 range as much as possible
        half specularStrength = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
        half nprSpecularStrength = 1.0;
        
        #if _SPECULARSHADEMODE_SHARP
        nprSpecularStrength =
            smoothstep(nprShadingData.SpecularLightCutOff - 0.01, nprShadingData.SpecularLightCutOff + 0.01, specularStrength);
        #elif _SPECULARSHADEMODE_SOFT
        nprSpecularStrength =
            smoothstep(nprShadingData.SpecularLightCutOff - nprShadingData.SpecularEdgeSmoothness, nprShadingData.SpecularLightCutOff + nprShadingData.SpecularEdgeSmoothness, specularStrength);
        #elif _SPECULARSHADEMODE_BANDED
        nprSpecularStrength = 
            round(saturate(specularStrength / nprShadingData.SpecularLightCutOff) * nprShadingData.SpecularBandNumber)/ nprShadingData.SpecularBandNumber;
        #elif _SPECULARSHADEMODE_HALFTONE
        nprSpecularStrength =
            smoothstep(nprShadingData.HalfToneValue - 0.01, nprShadingData.HalfToneValue + 0.01, specularStrength);
        #endif
        
        brdf += brdfData.specular * nprSpecularStrength * nprShadingData.SpecularStrengthMultiplier * _SpecularColor * radiance;

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half coatSpecularStrength = DirectBRDFSpecular(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);


        half bandedCoatSpecular = round(saturate(coatSpecularStrength / nprShadingData.SpecularLightCutOff) * nprShadingData.SpecularBandNumber) / nprShadingData.SpecularBandNumber;


        half brdfCoat = kDielectricSpec.r * bandedCoatSpecular;

            // Mix clear coat and base layer using khronos glTF recommended formula
            // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
            // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
            half NoV = saturate(dot(normalWS, viewDirectionWS));
            // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
            // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
            half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask * radiance;
#endif // _CLEARCOAT
    }
#endif // _SPECULARHIGHLIGHTS_OFF

    // Rim Light Calculation (Fresnel)
    half fresnel = pow(saturate(1.0h - dot(normalWS, viewDirectionWS)), 1.0f);
    half rimLightThresholdBegin = 1.0f - nprShadingData.RimLightSize / 64.0f;
    half rimLightStrength = smoothstep(rimLightThresholdBegin, rimLightThresholdBegin + 0.05h, fresnel);
    half dirToLight = saturate(dot(normalWS, lightDirectionWS));
    brdf += rimLightStrength * nprShadingData.RimLightColor * dirToLight;

    return brdf;
}

////////////////////////////////////////////////////////////////////////////////
/// Cel lighting
////////////////////////////////////////////////////////////////////////////////
half4 CelShadingPBR(InputData inputData, SurfaceData surfaceData, NPRShadingData nprShadingData)
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
        lightingData.mainLightColor = LightingPhysicallyBased_NPR(brdfData, brdfDataClearCoat,
                                                              mainLight.color, mainLight.direction, mainLight.distanceAttenuation, mainLight.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, nprShadingData);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_NPR(brdfData, brdfDataClearCoat,
                                                              light.color, light.direction, light.distanceAttenuation, light.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, nprShadingData);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_NPR(brdfData, brdfDataClearCoat,
                                                              light.color, light.direction, light.distanceAttenuation, light.shadowAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff, nprShadingData);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

#endif