#ifndef STYLIZED_WATER_PASS_INCLUDED
#define STYLIZED_WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "../../ShaderLibrary/PlanarReflectionTexture.hlsl"
#include "../../ShaderLibrary/WaveCalculation.hlsl"

float SampleSceneDepthCustom(float2 uv)
{
    return SAMPLE_TEXTURE2D_X(_CameraDepthTexture, planar_Trilinear_Clamp_Sampler, UnityStereoTransformScreenSpaceTex(uv)).r;
}

float SchlickFresnelReflectance(float NoV)
{
    // IOR of air = 1.0, water = 1.33
    // Precalculated R = ((na - nw)/(na + nw))^2 = 0.02005931219
    const float R = 0.02005931219f;
    return R + (1 - R) * pow((1.0f - NoV), _FresnelPower);
}

void WaterHeightCalculation(inout float3 positionWS, inout float3 tangentWS, inout float3 normalWS,
    inout float maxHeight, float3 movementAmp = float3(1, 1, 1))
{
    float3 positionWS_Old = positionWS;
    float3 biTangentWS = float3(0, 0, 1);
    tangentWS = float3(1, 0, 0);
    normalWS = float3(0, 1, 0);
    maxHeight = 0;
    
    // prime wave
    float2 waveDirectionXZ = normalize(_WaveProperties.xy);
    float waveLength = _WaveProperties.z;
    float speed = _WaveProperties.w;
    #if _DISPLACEMENT_SINWAVE
    maxHeight += _Amplitude.x;
    positionWS.y += Add_SinWave2D_BiTangent_Tangent_Calculated(
        positionWS_Old.xz, waveDirectionXZ, _Amplitude.x, speed, waveLength, biTangentWS, tangentWS) * movementAmp.y;
    #elif _DISPLACEMENT_GERSTNER
    positionWS += Add_GerstnerWave2D_BiTangent_Tangent_Calculated(positionWS_Old.xz, waveDirectionXZ, _Steepness.x,
        speed, waveLength, biTangentWS, tangentWS, maxHeight) * movementAmp;
    #elif _DISPLACEMENT_TEXTURE
    // nothing here right now
    #endif

    // alpha wave
    #if WAVE_ALPHA
    waveDirectionXZ = normalize(_WaveProperties_A.xy);
    waveLength = _WaveProperties_A.z;
    speed = _WaveProperties_A.w;
    #if _DISPLACEMENT_SINWAVE
    maxHeight += _Amplitude.y;
    positionWS.y += Add_SinWave2D_BiTangent_Tangent_Calculated(
        positionWS_Old.xz, waveDirectionXZ, _Amplitude.y, speed, waveLength, biTangentWS, tangentWS) * movementAmp.y;
    #elif _DISPLACEMENT_GERSTNER
    positionWS += Add_GerstnerWave2D_BiTangent_Tangent_Calculated(positionWS_Old.xz, waveDirectionXZ, _Steepness.y,
        speed, waveLength, biTangentWS, tangentWS, maxHeight) * movementAmp;
    #elif _DISPLACEMENT_TEXTURE
    // nothing here right now
    #endif
    #endif
    // beta wave
    #if WAVE_BETA
    waveDirectionXZ = normalize(_WaveProperties_B.xy);
    waveLength = _WaveProperties_B.z;
    speed = _WaveProperties_B.w;
    #if _DISPLACEMENT_SINWAVE
    maxHeight += _Amplitude.z;
    positionWS.y += Add_SinWave2D_BiTangent_Tangent_Calculated(
        positionWS_Old.xz, waveDirectionXZ, _Amplitude.z, speed, waveLength, biTangentWS, tangentWS) * movementAmp.y;
    #elif _DISPLACEMENT_GERSTNER
    positionWS += Add_GerstnerWave2D_BiTangent_Tangent_Calculated(positionWS_Old.xz, waveDirectionXZ, _Steepness.z,
        speed, waveLength, biTangentWS, tangentWS, maxHeight) * movementAmp;
    #elif _DISPLACEMENT_TEXTURE
    // nothing here right now
    #endif
    #endif
    // c wave
    #if WAVE_C
    waveDirectionXZ = normalize(_WaveProperties_C.xy);
    waveLength = _WaveProperties_C.z;
    speed = _WaveProperties_C.w;
    #if _DISPLACEMENT_SINWAVE
    maxHeight += _Amplitude.w;
    positionWS.y += Add_SinWave2D_BiTangent_Tangent_Calculated(
        positionWS_Old.xz, waveDirectionXZ, _Amplitude.w, speed, waveLength, biTangentWS, tangentWS) * movementAmp.y;
    #elif _DISPLACEMENT_GERSTNER
    positionWS += Add_GerstnerWave2D_BiTangent_Tangent_Calculated(positionWS_Old.xz, waveDirectionXZ, _Steepness.w,
        speed, waveLength, biTangentWS, tangentWS, maxHeight) * movementAmp;
    #elif _DISPLACEMENT_TEXTURE
    // nothing here right now
    #endif
    #endif
    

    normalWS = normalize(cross(biTangentWS, tangentWS));
}

half3 SampleReflections(half3 normalWS, half3 viewDirectionWS, half2 screenUV, half roughness)
{
    half3 reflection = 0;
    half2 refOffset = 0;
    
    #if _REFLECTION_CUBEMAP
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    reflection = GlossyEnvironmentReflection(reflectVector, RoughnessToPerceptualRoughness(roughness), 1.0);
    //reflection = SAMPLE_TEXTURECUBE(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, reflectVector).rgb;
    #elif _REFLECTION_PROBES
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    reflection = GlossyEnvironmentReflection(reflectVector, RoughnessToPerceptualRoughness(roughness), 1);
    #elif _REFLECTION_PLANAR

    // get the perspective projection
    float2 p11_22 = float2(unity_CameraInvProjection._11, unity_CameraInvProjection._22) * 10;
    // convert the uvs into view space by "undoing" projection
    float3 viewDir = -(float3((screenUV * 2 - 1) / p11_22, -1));

    half3 viewNormal = mul(normalWS, (float3x3)GetWorldToViewMatrix()).xyz;
    half3 reflectVector = reflect(-viewDir, viewNormal);

    half2 reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
    reflection += SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, planar_Trilinear_Clamp_Sampler, reflectionUV, 6 * roughness).rgb;//planar reflection

    #endif
    return reflection;
}

/**
 * \brief Used for Tessellation, carry vertex data to the tessellation program.
 * \param 
 * \return 
 */
ControlPoint StylizedWaterPassVertexForTessellation(Attributes input)
{
    ControlPoint output;

    output.normalOS = input.normalOS;
    output.positionOS = input.positionOS;
    output.tangentOS = input.tangentOS;
    output.uv1 = input.uv1;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    return output;    
}

/**
 * \brief Used For Tessellation, same as a vertex program
 * \param 
 * \return 
 */
Varyings VertexToFragment(Attributes input)
{
    Varyings output;
    ZERO_INITIALIZE(Varyings, output);
    //float3 tangentOS = input.tangentOS.xyz;

    // Add Height
    float3 normalWS;
    // float3 tangentOS;
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

    float maxHeight = 0.001f;
    float3 tangentWS;
    float originalPosY = positionWS.y;
    WaterHeightCalculation(positionWS, tangentWS, normalWS, maxHeight);
    // 0 -> 1
    float offsetAmount = saturate((positionWS.y - originalPosY) / max(maxHeight, 0.0001f));
    
    output.positionWS = positionWS;
    output.positionVS = TransformWorldToView(output.positionWS);
    output.positionCS = TransformWViewToHClip(output.positionVS);
    float4 positionSS = ComputeScreenPos(output.positionCS);
    positionSS.xy /= positionSS.w;
    //float rawDepth = SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(positionSS.xy), 0.0).r;
    //float distanceToScene = LinearEyeDepth(rawDepth, _ZBufferParams) * length(positionVS / positionVS.z);
    //float diff = Smootherstep01(saturate((distanceToScene - length(positionVS))));
    output.positionSS = positionSS;
    //output.normalWS = TransformObjectToWorldNormal(SafeNormalize(input.normalOS));
    output.normalWS = normalWS;
    output.tangentWS = float4(tangentWS, input.tangentOS.w);

    half fogFactor = ComputeFogFactor(output.positionCS.z);
    output.fogFactor = fogFactor;
    #if defined(LIGHTMAP_ON)
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.lightmapUV);
    #else
    OUTPUT_SH(output.normalWS, output.vertexSH);
    #endif

    output.vertexData.x = offsetAmount;

    return output;    
}

/**
 * \brief Used for non-tessellation version, vertex to fragment program
 * \param 
 * \return 
 */
Varyings StylizedWaterPassVertex(Attributes input)
{
    Varyings output;
    ZERO_INITIALIZE(Varyings, output);
    float3 tangentOS = input.tangentOS.xyz;

    // Normally without tessellation, the mesh would be in low resolution, so no height modification is needed
    // Or could use Custom LODing of water plane, make near planes high-res and their heights changed.
    // WaterHeightCalculation(input.positionOS.xyz);
    
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.positionVS = TransformWorldToView(output.positionWS);
    output.positionCS = TransformWViewToHClip(output.positionVS);
    float4 positionSS = ComputeScreenPos(output.positionCS);
    positionSS.xy /= positionSS.w;
    //float rawDepth = SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(positionSS.xy), 0.0).r;
    //float distanceToScene = LinearEyeDepth(rawDepth, _ZBufferParams) * length(positionVS / positionVS.z);
    //float diff = Smootherstep01(saturate((distanceToScene - length(positionVS))));
    output.positionSS = positionSS;
    output.normalWS = TransformObjectToWorldNormal((input.normalOS));
    output.tangentWS = float4(TransformObjectToWorldDir(tangentOS), input.tangentOS.w);

    half fogFactor = ComputeFogFactor(output.positionCS.z);
    output.fogFactor = fogFactor;
    #if defined(LIGHTMAP_ON)
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.lightmapUV);
    #else
    OUTPUT_SH(output.normalWS, output.vertexSH);
    #endif

    return output;    
}

// At distance 0, scattering can happen already, so tend to be non black (depend on the style)
// At max distance, scattering tends to fade into diffuse scattering, this will be handled by the SSS term & the Diffuse term
// But as a texture, the ramp represents the added result of the scattering term, so it will only become greater, rather than nearly black
half3 ScatteringColor(float surface_to_scene_distance, float rampThreshold = 20.0f, float fogThreshold = 40.0)
{
    // 0 - 1 -> texture sample
    // > 1 -> fog
    half3 scatteringCol = SAMPLE_TEXTURE2D(_ScatteringRamp, ramp_Linear_Clamp_Sampler, surface_to_scene_distance / rampThreshold);
    //half3 fogCol = SAMPLE_TEXTURE2D(_ScatteringRamp, sampler_ScatteringRamp, surface_to_scene_distance / rampThreshold);
    //return lerp(scatteringCol, fogCol, saturate(surface_to_scene_distance / (fogThreshold)));
    return scatteringCol;
}

// At distance 0, absorption nearly happens, so tend to be white (not affecting the scene color)
// At max distance, absorption would make less light appear back to the eye, thus turning to near black.
// NOTE:: Remember to disable ramp texture mipmapping. 
half3 AbsorptionColor(float surface_to_scene_distance, float rampThreshold = 20.0f)
{
    return SAMPLE_TEXTURE2D(_AbsorptionRamp, ramp_Linear_Clamp_Sampler, surface_to_scene_distance / rampThreshold);
}

half3 CalculateRefraction(float2 sampleUV, float surface_to_scene_distance, out half3 absorptionColor, float rampThreshold = 20.0f, float fogThreshold = 40.0f)
{
    //half3 sceneColor = SampleSceneColor(sampleUV);
    surface_to_scene_distance = min(surface_to_scene_distance, _ProjectionParams.z);
    half3 sceneColor = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, UnityStereoTransformScreenSpaceTex(sampleUV),
        surface_to_scene_distance / 20.0f * 6).rgb;
    absorptionColor = AbsorptionColor(surface_to_scene_distance, rampThreshold);
    //absorptionColor = lerp(float3(0.2f, 0.2f, 0.6f), float3(0.3f, 0.3f, 0.9f), saturate(surface_to_scene_distance / rampThreshold));
    //half3 fogCol = SAMPLE_TEXTURE2D(_AbsorptionRamp, ramp_Bilinear_Clamp_Sampler, surface_to_scene_distance / rampThreshold);
    half3 fogCol = absorptionColor;
    //fogCol = half3(1,1,1);
    // bigger distance, more fog.
    return lerp(sceneColor * absorptionColor, fogCol, saturate(surface_to_scene_distance / fogThreshold));
}

float4 StylizedWaterPassFragment(Varyings input) : SV_Target
{
    // --- Parameters Used For Shading
    // Don't use GetWorldSpaceViewDirection function!
    float3 viewDirectionWS = SafeNormalize(_WorldSpaceCameraPos - input.positionWS);
    input.positionSS.xy = ComputeNormalizedDeviceCoordinates(input.positionWS, unity_MatrixVP);

    // --- Normal Calculation
    // Interpolated directions need to be normalized again.
    input.normalWS = SafeNormalize(input.normalWS);
    input.tangentWS.xyz = SafeNormalize(input.tangentWS.xyz);
    float3x3 tangentToWorld = CreateTangentToWorld(input.normalWS, input.tangentWS.xyz, input.tangentWS.w);
    float4 normalAlphaTS = SAMPLE_TEXTURE2D(_NormalMapAlpha, sampler_NormalMapAlpha,
        input.positionWS.xz * _NormalMapAlpha_ST.xy + _Time.yy * _NormalMapAlpha_ST.zw);
    normalAlphaTS.rgb = UnpackNormalScale(normalAlphaTS, _NormalAlphaStrength);
    float4 normalBetaTS = SAMPLE_TEXTURE2D(_NormalMapBeta, sampler_NormalMapBeta,
        input.positionWS.xz * _NormalMapBeta_ST.xy + _Time.yy * _NormalMapBeta_ST.zw);
    normalBetaTS.rgb = UnpackNormalScale(normalBetaTS, _NormalBetaStrength);
    float3 normalTS = BlendNormal(normalAlphaTS.rgb, normalBetaTS.rgb);
    float3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

    // --- Refraction and Depth Calculation via Distorted Screen UV
    float surfaceDistanceToCam = length(input.positionVS);
    float sceneDistanceToCam = LinearEyeDepth(SampleSceneDepth(input.positionSS), _ZBufferParams) * length(input.positionVS/input.positionVS.z);
    float surfaceDistanceToSceneOrig = sceneDistanceToCam - surfaceDistanceToCam;
    normalWS = lerp(normalWS, float3(0, 1, 0), saturate(surfaceDistanceToCam / 500.0f));
    
    // --- Foam Calculation
    half3 foamControl = SAMPLE_TEXTURE2D(_FoamTexture, sampler_FoamTexture,
        input.positionWS.xz * _FoamTexture_ST.xy + _Time.yy * _FoamTexture_ST.zw) * _FoamColor.xyz * _FoamColor.a;
    float foamRoughness = 1.0f;
    // Foam Should be calculated before distorted (because foam exists above water surface)
    // smoothstep(distance/slider, distance/slider2, foamColor.r)
    float foamLine = 1.0f - saturate(surfaceDistanceToSceneOrig / _FoamDistance);
    float foamStrength = (1.0f - saturate(surfaceDistanceToSceneOrig / _FoamDistance)) * pow(foamControl.r, 1.0f);
    foamStrength = lerp(foamStrength, foamLine, 0.5f);
    foamStrength = saturate(smoothstep(0.3f, 0.31f, foamStrength));
    
    float2 refractUVOffset = mul((float3x3)GetWorldToHClipMatrix(), -normalWS).xz;
    //refractUVOffset = normalTS.xy;
    refractUVOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y); // squaring the offset
    float2 positionSSDistorted = input.positionSS + refractUVOffset.xy * saturate(surfaceDistanceToSceneOrig / 10.0f) * _RefractionStrength;
    
    // --- Depth Calculation via Distorted UV
    float sceneDepth = SampleSceneDepth(positionSSDistorted);
    sceneDistanceToCam = LinearEyeDepth(sceneDepth, _ZBufferParams) * length(input.positionVS / input.positionVS.z);
    float surfaceDistanceToSceneDistorted = sceneDistanceToCam - surfaceDistanceToCam;
    // If distorted uv samples at a point where the scene is ahead of the water, the distortion should be canceled (thus no distortion).
    float waterAheadOfScene = max(sign(surfaceDistanceToSceneDistorted) + 1 / 2, 0.0f); // 0 if scene ahead of water
    surfaceDistanceToSceneDistorted = lerp(surfaceDistanceToSceneOrig, surfaceDistanceToSceneDistorted, waterAheadOfScene);
    positionSSDistorted = lerp(input.positionSS.xy, positionSSDistorted, waterAheadOfScene);
    surfaceDistanceToSceneDistorted = max(surfaceDistanceToSceneDistorted, 0.0f);

    // --- Refraction Calculation
    half3 absorptionColor = 0;
    half3 refraction = CalculateRefraction(positionSSDistorted,
        surfaceDistanceToSceneDistorted, absorptionColor, _AbsorptionDistance, _AbsorptionFogDistance);
    //refraction = AbsorptionColor(surfaceDistanceToSceneOrig);
    //refraction = lerp(refraction, 0, foamStrength) * _AbsorptionIntensity;
    
    // --- Colors, Sand Wetness -> Shore Color // Shore Depth -> Gradient Map
    float3 albedo = lerp(0, _FoamColor.rgb, foamStrength);
    float3 emission = 0;

    // --- Smoothness
    float roughness = lerp(_Roughness, foamRoughness, foamStrength);
    roughness = lerp(roughness, 0.8f, saturate(surfaceDistanceToCam / 500.0f));
    float alpha = 1.0;

    // --- Lighting Calculation
    float fresnel = pow(1.0 - saturate(dot(normalWS, viewDirectionWS)), _FresnelPower);
    fresnel = SchlickFresnelReflectance(saturate(dot(normalWS, viewDirectionWS)));
    
    half3 GI = 0;
    half4 shadowMask = 1;
    #if defined(LIGHTMAP_ON)
    shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV)
    #else
    GI = input.vertexSH;
    #endif
    
    Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS), input.positionWS, shadowMask);
    half shadow = mainLight.shadowAttenuation;

    // direct lighting == diffuse lighting
    half3 directLighting = dot(mainLight.direction, normalWS) * mainLight.color * shadow * _ScatteringIntensityControl.z;
    half3 sss = directLighting;
    // disable sss for foam
    half3 scatteringCol = ScatteringColor(surfaceDistanceToSceneDistorted, _ScatteringDistance, _ScatteringFogDistance);
    float scatteringTerm =
        _ScatteringIntensityControl.x * input.vertexData.x *
            Pow4(saturate(dot(viewDirectionWS, -mainLight.direction))) * (0.5f - 0.5f * dot(mainLight.direction, normalWS))
     + _ScatteringIntensityControl.y * pow(saturate(dot(viewDirectionWS, normalWS)), 2);
    sss +=
        saturate(lerp(scatteringCol, GI, foamStrength)) * mainLight.color * scatteringTerm * (Smoothstep01(saturate(surfaceDistanceToSceneOrig / _FoamDistance)));
    // + _ScatteringIntensityControl.w * bubble color * bubble density * sun color; // this is for controlling the color of the bubble
    // sss += saturate(pow(saturate(dot(viewDirectionWS, -mainLight.direction)) * input.vertexData.x, 4)) * mainLight.color * absorptionColor;
    
    half3 reflection = SampleReflections(normalWS, viewDirectionWS.xyz, input.positionSS.xy, roughness) * _ReflectionIntensity;
    
    BRDFData brdfData = (BRDFData)0;
    InitializeBRDFData(albedo, 0, 0, 1 - roughness, alpha, brdfData);
    half3 spec = 0;
    #if STYLIZED_SPECULAR
    half specularCheck = 1.0f - roughness/2.0f;
    spec =
        smoothstep(specularCheck, specularCheck+0.05f, DirectBRDF(brdfData, normalWS, mainLight.direction, viewDirectionWS, false))
    * shadow * mainLight.color;
    #else
    spec =
        DirectBRDF(brdfData, normalWS, mainLight.direction, viewDirectionWS, false)
    * shadow * mainLight.color;
    #endif

    #ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        spec += LightingPhysicallyBased(brdfData, light, input.normalWS, viewDirectionWS.xyz);
        sss += light.distanceAttenuation * light.color * light.shadowAttenuation;
    }
    #endif

    // refraction = environment lighting that hit the surface below and travels backward to the eye
    // reflection = environment lighting that travels from the scene directly reflects to the eye
    // spec = light source's direct reflected radiance
    // sss = light source's radiance that goes below the water surface but came out before hitting the surface below
    // emission = artistic control (simulates effects like glowing ocean caused by algae)
    half3 comp = lerp(refraction, reflection, fresnel * _ReflectionIntensity) + spec + sss + emission;
    //half3 color = refraction;
    //return half4(color, 1.0);
    //return smoothstep(1000, 100000, surfaceDistanceToSceneDistorted);
    return half4(comp, alpha);
}


#endif