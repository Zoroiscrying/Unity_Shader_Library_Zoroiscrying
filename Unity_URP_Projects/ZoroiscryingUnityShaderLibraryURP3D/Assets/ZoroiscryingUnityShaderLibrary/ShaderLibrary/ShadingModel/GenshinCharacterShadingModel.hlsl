#ifndef CEL_SHADING_MODEL_INCLUDED
#define CEL_SHADING_MODEL_INCLUDED

#include "GenshinCharacterShadingData.hlsl"

half3 Lighting_Cel_Phong_DepthRim(CelShadingData celShadingData,
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
    half3 normalWS, half3 viewDirectionWS, half depthDiff)
{
    // calculate rim light
    half rimLightStrength = smoothstep(0.99, 1.0, depthDiff);
    
    // calculate diffuse
    half3 radiance = lightColor * (lightAttenuation);
#if _FACE_RENDERING
    lightDirectionWS.y = 0;
    lightDirectionWS = normalize(lightDirectionWS);
    float NdotL = saturate(dot(normalWS, lightDirectionWS));
    float shadowWeight = (celShadingData.ShadowWeight + NdotL) * 0.5 + 1.125;
    float shadowFactor = smoothstep(0.95, 1.05, shadowWeight - celShadingData.DiffuseLightCutOff);
    //half3 shallowShadowDiffuseColor = lerp(celShadingData.ShallowShadowColor, celShadingData.Albedo, shadowFactor);
    half2 rampUV = half2(NdotL, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    //half2 rampUV2 = half2(min(NdotL, 0.5) * 2, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    half3 shadowRampedColor = celShadingData.Albedo * SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb  * radiance * 0.5;
    //shallowShadowDiffuseColor *= SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb;
    half3 shallowShadowDiffuseColor = lerp(shadowRampedColor, celShadingData.Albedo, shadowFactor);
    half3 phong = shallowShadowDiffuseColor * celShadingData.DiffuseLightMultiplier;

    // calculate specular
    float3 halfVec = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));
    half NdotH = half(saturate(dot(normalWS, halfVec)));
    half specularStrength = pow(NdotH, celShadingData.smoothness * celShadingData.SpecularStrength);
    
    #if _SMOOTH_STEP_LIGHT_EDGE
    half bandedSpecular = smoothstep(celShadingData.SpecularLightCutOff - 0.05, celShadingData.SpecularLightCutOff + 0.05, specularStrength);
    #else
    half bandedSpecular = step(celShadingData.SpecularLightCutOff, specularStrength);
    #endif
    
    half4 specularColor = half4(1,1,1,1);
    phong += specularColor * bandedSpecular * celShadingData.SpecularLightMultiplier;

    rimLightStrength *= shadowFactor;
    
    return phong * radiance + rimLightStrength * celShadingData.RimLightColor;
#else
    float NdotL = saturate(dot(normalWS, lightDirectionWS));
    float shadowWeight = (celShadingData.ShadowWeight + NdotL) * 0.5 + 1.125;
    float shadowFactor = smoothstep(0.95, 1.05, shadowWeight - celShadingData.DiffuseLightCutOff);
    //half3 shallowShadowDiffuseColor = lerp(celShadingData.ShallowShadowColor, celShadingData.Albedo, shadowFactor);
    //shallowShadowDiffuseColor = shadowFactor * celShadingData.Albedo;
    half2 rampUV = half2(NdotL, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    //half2 rampUV2 = half2(min(NdotL, 0.5) * 2, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    half3 shadowRampedColor = celShadingData.Albedo * SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb * radiance * 0.5;
    //shallowShadowDiffuseColor *= SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb;
    half3 shallowShadowDiffuseColor = lerp(shadowRampedColor, celShadingData.Albedo, shadowFactor);
    
    //#if _SMOOTH_STEP_LIGHT_EDGE
    //half bandedNdotL =
    //    smoothstep(celShadingData.DiffuseLightCutOff - 0.05, celShadingData.DiffuseLightCutOff + 0.05, NdotL);
    //#else
    //half bandedNdotL = 
    //    step(celShadingData.DiffuseLightCutOff, NdotL);
    //#endif
    half3 phong = shallowShadowDiffuseColor * celShadingData.DiffuseLightMultiplier;

    // calculate specular
    float3 halfVec = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));
    half NdotH = half(saturate(dot(normalWS, halfVec)));
    half specularStrength = pow(NdotH, celShadingData.smoothness * celShadingData.SpecularStrength) * celShadingData.SpecularDetailMask;
    
    #if _SMOOTH_STEP_LIGHT_EDGE
    half bandedSpecular = smoothstep(celShadingData.SpecularLightCutOff - 0.05, celShadingData.SpecularLightCutOff + 0.05, specularStrength);
    #else
    half bandedSpecular = step(celShadingData.SpecularLightCutOff, specularStrength);
    #endif
    
    half3 specularColor = lerp(half3(1,1,1), celShadingData.Albedo, celShadingData.SpecularDetailMask);
    phong += specularColor * bandedSpecular * celShadingData.SpecularLightMultiplier;

    rimLightStrength *= shadowFactor;
    //return rimLightStrength * celShadingData.RimLightColor * 1;
    return phong * radiance + celShadingData.Emission * celShadingData.EmissionLightMultiplier + rimLightStrength * celShadingData.RimLightColor;
#endif

    // calculate rim light
    //return specularColor * bandedSpecular;
    //return celShadingData.Albedo * bandedNdotL;
    //return
    //return celShadingData.RampTextureAxisAid_Y;
    //return shallowShadowDiffuseColor * radiance;
    return phong * radiance;
}

half3 Lighting_Cel_Phong(CelShadingData celShadingData,
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
    half3 normalWS, half3 viewDirectionWS)
{
    // calculate rim light
    float NdotV = 1 - dot(normalWS, viewDirectionWS);
    float rimLightStrength = smoothstep(0.7, 0.8, NdotV);
    
    // calculate diffuse
    half3 radiance = lightColor * (lightAttenuation);
#if _FACE_RENDERING
    lightDirectionWS.y = 0;
    lightDirectionWS = normalize(lightDirectionWS);
    float NdotL = saturate(dot(normalWS, lightDirectionWS));
    float shadowWeight = (celShadingData.ShadowWeight + NdotL) * 0.5 + 1.125;
    float shadowFactor = smoothstep(0.95, 1.05, shadowWeight - celShadingData.DiffuseLightCutOff);
    //half3 shallowShadowDiffuseColor = lerp(celShadingData.ShallowShadowColor, celShadingData.Albedo, shadowFactor);
    half2 rampUV = half2(NdotL, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    //half2 rampUV2 = half2(min(NdotL, 0.5) * 2, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    half3 shadowRampedColor = celShadingData.Albedo * SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb  * radiance * 0.5;
    //shallowShadowDiffuseColor *= SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb;
    half3 shallowShadowDiffuseColor = lerp(shadowRampedColor, celShadingData.Albedo, shadowFactor);
    half3 phong = shallowShadowDiffuseColor * celShadingData.DiffuseLightMultiplier;

    // calculate specular
    float3 halfVec = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));
    half NdotH = half(saturate(dot(normalWS, halfVec)));
    half specularStrength = pow(NdotH, celShadingData.smoothness * celShadingData.SpecularStrength);
    
    #if _SMOOTH_STEP_LIGHT_EDGE
    half bandedSpecular = smoothstep(celShadingData.SpecularLightCutOff - 0.05, celShadingData.SpecularLightCutOff + 0.05, specularStrength);
    #else
    half bandedSpecular = step(celShadingData.SpecularLightCutOff, specularStrength);
    #endif
    
    half4 specularColor = half4(1,1,1,1);
    phong += specularColor * bandedSpecular * celShadingData.SpecularLightMultiplier;

    rimLightStrength *= shadowFactor * smoothstep(0.9, 0.95, NdotL);
    
    return phong * radiance + rimLightStrength * celShadingData.RimLightColor;
#else
    float NdotL = saturate(dot(normalWS, lightDirectionWS));
    float shadowWeight = (celShadingData.ShadowWeight + NdotL) * 0.5 + 1.125;
    float shadowFactor = smoothstep(0.95, 1.05, shadowWeight - celShadingData.DiffuseLightCutOff);
    //half3 shallowShadowDiffuseColor = lerp(celShadingData.ShallowShadowColor, celShadingData.Albedo, shadowFactor);
    //shallowShadowDiffuseColor = shadowFactor * celShadingData.Albedo;
    half2 rampUV = half2(NdotL, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    //half2 rampUV2 = half2(min(NdotL, 0.5) * 2, (celShadingData.RampTextureAxisAid_Y + 0.5) * 0.5);
    half3 shadowRampedColor = celShadingData.Albedo * SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb * radiance * 0.5;
    //shallowShadowDiffuseColor *= SAMPLE_TEXTURE2D(_CharacterRampTexture, sampler_CharacterRampTexture, rampUV).rgb;
    half3 shallowShadowDiffuseColor = lerp(shadowRampedColor, celShadingData.Albedo, shadowFactor);
    
    //#if _SMOOTH_STEP_LIGHT_EDGE
    //half bandedNdotL =
    //    smoothstep(celShadingData.DiffuseLightCutOff - 0.05, celShadingData.DiffuseLightCutOff + 0.05, NdotL);
    //#else
    //half bandedNdotL = 
    //    step(celShadingData.DiffuseLightCutOff, NdotL);
    //#endif
    half3 phong = shallowShadowDiffuseColor * celShadingData.DiffuseLightMultiplier;

    // calculate specular
    float3 halfVec = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));
    half NdotH = half(saturate(dot(normalWS, halfVec)));
    half specularStrength = pow(NdotH, celShadingData.smoothness * celShadingData.SpecularStrength) * celShadingData.SpecularDetailMask;
    
    #if _SMOOTH_STEP_LIGHT_EDGE
    half bandedSpecular = smoothstep(celShadingData.SpecularLightCutOff - 0.05, celShadingData.SpecularLightCutOff + 0.05, specularStrength);
    #else
    half bandedSpecular = step(celShadingData.SpecularLightCutOff, specularStrength);
    #endif
    
    half3 specularColor = lerp(half3(1,1,1), celShadingData.Albedo, celShadingData.SpecularDetailMask);
    phong += specularColor * bandedSpecular * celShadingData.SpecularLightMultiplier;

    rimLightStrength *= shadowFactor * smoothstep(0.9, 0.95, NdotL);
    //return rimLightStrength * celShadingData.RimLightColor * 1;
    return phong * radiance + celShadingData.Emission * celShadingData.EmissionLightMultiplier + rimLightStrength * celShadingData.RimLightColor;
#endif

    // calculate rim light
    //return specularColor * bandedSpecular;
    //return celShadingData.Albedo * bandedNdotL;
    //return
    //return celShadingData.RampTextureAxisAid_Y;
    //return shallowShadowDiffuseColor * radiance;
    return phong * radiance;
}


////////////////////////////////////////////////////////////////////////////////
/// Cel lighting
////////////////////////////////////////////////////////////////////////////////
///
///

half4 CelShadingCharacter_NdotL_Rim(InputData inputData, CelShadingData celShadingData)
{
    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif
    
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, 1.0);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData;
    lightingData.giColor = inputData.bakedGI * celShadingData.Albedo * 0.6;
    lightingData.emissionColor = 0;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    //lightingData.giColor = inputData.bakedGI;

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = Lighting_Cel_Phong(celShadingData,
                                                              mainLight.color, mainLight.direction, mainLight.distanceAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS);
    }

    //return half4(lightingData.mainLightColor, 1.0);
    
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += Lighting_Cel_Phong(celShadingData, light.color, light.direction, light.distanceAttenuation,
                                                                          inputData.normalWS, inputData.viewDirectionWS);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += Lighting_Cel_Phong(celShadingData,
                                                              light.color, light.direction, light.distanceAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS);
        }
    LIGHT_LOOP_END
    #endif

    //return half4(lightingData.mainLightColor, 1.0);
    return CalculateFinalColor(lightingData, 1.0);
}

half4 CelShadingCharacter_ScreenSpaceDepthRim(InputData inputData, CelShadingData celShadingData, half depthDiff)
{
    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif
    
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, 1.0);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData;
    lightingData.giColor = inputData.bakedGI * celShadingData.Albedo * 0.6;
    lightingData.emissionColor = 0;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    //lightingData.giColor = inputData.bakedGI;

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = Lighting_Cel_Phong_DepthRim(celShadingData,
                                                              mainLight.color, mainLight.direction, mainLight.distanceAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS, depthDiff);
    }

    //return half4(lightingData.mainLightColor, 1.0);
    
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += Lighting_Cel_Phong_DepthRim(celShadingData, light.color, light.direction, light.distanceAttenuation,
                                                                          inputData.normalWS, inputData.viewDirectionWS, depthDiff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += Lighting_Cel_Phong_DepthRim(celShadingData,
                                                              light.color, light.direction, light.distanceAttenuation,
                                                              inputData.normalWS, inputData.viewDirectionWS, depthDiff);
        }
    LIGHT_LOOP_END
    #endif

    //return half4(lightingData.mainLightColor, 1.0);
    return CalculateFinalColor(lightingData, 1.0);
}


#endif