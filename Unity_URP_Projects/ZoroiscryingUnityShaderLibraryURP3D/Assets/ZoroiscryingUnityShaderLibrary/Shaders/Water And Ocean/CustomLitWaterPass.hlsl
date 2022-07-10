#ifndef CUSTOM_LIT_WATER_PASS_INCLUDED
#define CUSTOM_LIT_WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

float SampleNoiseTexture(
    float2 pos, float4 properties, float2 scale, float2 displacement,
    TEXTURE2D(noise), SAMPLER(sampler_noise))
{
    // noise properties - speed x, speed y, contrast, contribution
    float value = SAMPLE_TEXTURE2D_LOD(noise, sampler_noise, pos * scale + displacement + _Time.y * properties.xy, 0.0);
    value = (saturate(lerp(0.5, value, properties.z)) * 2.0 - 1.0) * properties.w;
    return value;
}

float NoiseOffset(float2 pos)
{
    float2 displacement =
        SAMPLE_TEXTURE2D_LOD(_DisplacementGuide, sampler_DisplacementGuide, pos * _DisplacementGuide_ST.xy + _Time.y * _DisplacementProperties.xy, 0.0).xy;
    displacement = (displacement * 2.0 - 1.0) * _DisplacementProperties.z;
    float noiseA = SampleNoiseTexture(pos, _NoiseAProperties, _NoiseTextureA_ST.xy, displacement, TEXTURE2D_ARGS(_NoiseTextureA, sampler_NoiseTextureA));
    float noiseB = SampleNoiseTexture(pos, _NoiseBProperties, _NoiseTextureB_ST.xy, displacement, TEXTURE2D_ARGS(_NoiseTextureB, sampler_NoiseTextureB));
    return noiseA * noiseB;
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
    // conver the uvs into view space by "undoing" projection
    float3 viewDir = -(float3((screenUV * 2 - 1) / p11_22, -1));

    half3 viewNormal = mul(normalWS, (float3x3)GetWorldToViewMatrix()).xyz;
    half3 reflectVector = reflect(-viewDir, viewNormal);

    half2 reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
    reflection += SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_ScreenTextures_linear_clamp, reflectionUV, 6 * roughness).rgb;//planar reflection

    #endif
    return reflection;
}

ControlPoint LitWaterPassVertexForTessellation(Attributes input)
{
    ControlPoint output;

    output.normalOS = input.normalOS;
    output.positionOS = input.positionOS;
    output.tangentOS = input.tangentOS;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    return output;    
}

Varyings VertexToFragment(Attributes input)
{
    Varyings output;
    ZERO_INITIALIZE(Varyings, output);
    float3 tangentOS = float3(1, 0, 0);
    // float3 biTangentOS = cross(input.normalOS, input.tangentOS);
    float3 biTangentOS = float3(0, 0, 1);

    float4 v0 = input.positionOS;
    float3 v1 = v0.xyz + _VectorLength * tangentOS; // tangent offset
    float3 v2 = v0.xyz + _VectorLength * biTangentOS; // bi-tangent offset

    float4 positionCS = TransformObjectToHClip(v0.xyz);
    float4 positionSS = ComputeScreenPos(positionCS);
    positionSS.xy /= positionSS.w;
    
    float3 positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
    float rawDepth = SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(positionSS.xy), 0.0).r;
    float distanceToScene = LinearEyeDepth(rawDepth, _ZBufferParams) * length(positionVS / positionVS.z);
    float diff = Smootherstep01(saturate((distanceToScene - length(positionVS)) / _ShoreIntersectionThreshold)); // bigger difference -> bigger displacement
    float thresDiff = max(_MinOffset, diff);
    float factor = thresDiff * _OffsetAmount;

    // xz position for sampling textures
    float vertexOffset = NoiseOffset(TransformObjectToWorld(input.positionOS.xyz).xz);

    v0.xyz += float3(0, 1, 0) * vertexOffset * factor;
    v1.xyz += float3(0, 1, 0) * NoiseOffset(TransformObjectToWorld(v1).xz) * factor;
    v2.xyz += float3(0, 1, 0) * NoiseOffset(TransformObjectToWorld(v2).xz) * factor;
    
    output.positionWS = TransformObjectToWorld(v0.xyz);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.positionSS = positionSS.xy;
    output.positionVS = TransformWorldToView(output.positionWS);

    float3 vn = lerp(cross(v2.xyz - v0.xyz, v1.xyz - v0.xyz), float3(0, 1, 0), pow(length(positionVS) / 200.0f, 8));
    output.normalWS = TransformObjectToWorldNormal(vn);
    
    //output.viewDirectionWS = GetWorldSpaceViewDir(output.positionWS);
    output.color = (vertexOffset + 1) / 2;
    //output.debugInfo.x = diff;
    //output.debugInfo.y = distanceToScene - length(positionVS);
    //output.debugInfo.z = distanceToScene;
    //output.debugInfo.w = length(positionVS);
    output.debugInfo.xyz = vn;

    return output;    
}

float4 LitWaterPassFragment(Varyings input) : SV_Target
{
    // don't use GetWorldSpaceViewDirection function!
    float3 viewDirectionWS = SafeNormalize(_WorldSpaceCameraPos - input.positionWS);
    
    // Displacement
    float2 displacement =
        SAMPLE_TEXTURE2D(_DisplacementGuide, sampler_DisplacementGuide,
            input.positionWS * _DisplacementGuide_ST.xy + _Time.y * _DisplacementProperties.xy).xy;
    displacement = (displacement * 2.0 - 1.0) * _DisplacementProperties.z;
    
    // Foam
    float foamTex =
        SAMPLE_TEXTURE2D(_FoamTexture, sampler_FoamTexture,
            input.positionWS.xz * _FoamTexture_ST.xy + displacement + sin(_Time.y) * _FoamProperties.xy);
    float foam = saturate(foamTex - smoothstep(_FoamProperties.z + _FoamProperties.w, _FoamProperties.z, input.color));
    
    // Depth Calculation
    float surfaceDistanceToCam = length(input.positionVS);
    float sceneDepth = SampleSceneDepth(input.positionSS);
    float sceneDistanceToCam = LinearEyeDepth(sceneDepth, _ZBufferParams) * length(input.positionVS/input.positionVS.z);
    float surfaceDistanceToScene = max(sceneDistanceToCam - surfaceDistanceToCam, 0.001f);
    
    float shoreDepth = smoothstep(0.0, _ShoreColorThreshold, surfaceDistanceToScene);
    float foamDiff = Smootherstep01(saturate(surfaceDistanceToScene / _FoamIntersectionProperties.x));
    float shoreDiff = Smootherstep01(saturate(surfaceDistanceToScene / _ShoreIntersectionThreshold));
    float transparencyDiff =
        Smootherstep01(saturate(surfaceDistanceToScene / 2.0f / lerp(_TransparencyIntersectionThresholdMin, _TransparencyIntersectionThresholdMax, (sin(_Time.y + HALF_PI) + 1) /2.0)));
    
    // Shore
    float shoreFoam =
        saturate(foamTex -
            smoothstep(_FoamIntersectionProperties.y - _FoamIntersectionProperties.z, _FoamIntersectionProperties.y, foamDiff)
            + _FoamIntersectionProperties.w * (1.0 - foamDiff));
    float sandWetness = smoothstep(0.0, 0.3 + 0.2 * (sin(_Time.y) + 1 / 2), foamDiff);
    shoreFoam *= sandWetness;
    foam += shoreFoam;

    // Colors, Sand Wetness -> Shore Color // Shore Depth -> Gradient Map
    float3 albedo =
        lerp(
            lerp(half3(0.0, 0.0, 0.0), _ShoreColor.rgb, sandWetness),
            SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap, input.color.xx).rgb, shoreDepth)
    + foam * sandWetness;
    float3 emission = albedo * saturate(_MainLightPosition.y) * _MainLightColor * _Emission;

    // Smoothness
    float roughness = _Roughness * foamDiff;
    float alpha = saturate(lerp(1.0, lerp(0.5, _ShoreColor.a, sandWetness), 1.0 - shoreDiff) * transparencyDiff);

    // Lighting Calculation
    float fresnel = pow(1.0 - saturate(dot(input.normalWS, normalize(viewDirectionWS))), _FresnelPower);
    Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
    half shadow = mainLight.shadowAttenuation;
    half3 GI = SampleSH(input.normalWS);
    half3 directLighting = dot(mainLight.direction, input.normalWS) * mainLight.color * albedo * shadow + GI;
    half3 reflection = SampleReflections(input.normalWS, viewDirectionWS.xyz, input.positionSS.xy, roughness);
    
    BRDFData brdfData = (BRDFData)0;
    InitializeBRDFData(albedo, 0, 0, 1 - roughness, alpha, brdfData);
    half3 spec = DirectBRDF(brdfData, input.normalWS, mainLight.direction, viewDirectionWS, false) * shadow * mainLight.color;

    #ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        spec += LightingPhysicallyBased(brdfData, light, input.normalWS, viewDirectionWS.xyz);
        directLighting += light.distanceAttenuation * light.color;
    }
    #endif

    half3 comp = lerp(0.0, reflection, fresnel) + spec + directLighting + emission;
    return half4(comp, alpha);
}

#endif