#ifndef PLANE_HOLOFIELD_PASS
#define PLANE_HOLOFIELD_PASS

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Mapping/Math.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Reconstruction.hlsl"

// Shader properties
// Texture emission
TEXTURE2D(_AnimatedEmissionMap); SAMPLER(sampler_AnimatedEmissionMap);
half4 _AnimatedEmissionColor;
half4 _EdgeEmissionColor;
float _AnimatedEmissionSpeed;
// Texture displacement
TEXTURE2D(_DisplacementParallaxMap); SAMPLER(sampler_DisplacementParallaxMap);
float2  _DisplacementParallaxMap_TexelSize;
float _ParallaxStrength;
// Shield hit effect - Distance, Min, Max, Null
half4 _ScanParameter;
// Depth awareness - Depthstrength, Min, Max, Power
half4 _DepthParameter;
// Refraction / Distortion xyxy
half4 _SceneColorParameter;
// Rim light - Rim light intensity, Rim light power, null, null
half4 _RimLightParameters;
// Back face rendering - Backface emission strength, Backface edge color strength, Null, Null
half4 _BackfaceRenderingParameters;

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

half3 SampleRefraction(half2 positionSS, half2 refractionStrength, half3 normalVS, half depth)
{
    return SampleSceneColor(positionSS + half2(normalVS.x, normalVS.z) * 0.1);
}

void ApplyPerPixelDisplacement(half3 viewDirTS, inout float2 uv)
{
    uv += ParallaxMapping(TEXTURE2D_ARGS(_DisplacementParallaxMap, sampler_DisplacementParallaxMap), viewDirTS, _ParallaxStrength, uv);
}

half4 UnlitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float2 positionSS = GetNormalizedScreenSpaceUV(input.positionCS);
    //float smoothstepControlValue = saturate(smoothstep(0.0, 0.5, frac(_Time.x)) - smoothstep(0.5, 1.0, frac(_Time.x))); 
    half2 uv = input.uv + half2(_Time.x * 2, _Time.x * 0.1);
    
// -- Parallax mapping
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
    ApplyPerPixelDisplacement(viewDirTS, uv);
    
    half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    half3 emissionColor = (SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb) * _EmissionColor.rgb;

// -- Edge Emission Control
    // Calculate distance from surface to scene
    float surfaceDistanceToCam = length(GetCameraPositionWS().xyz - input.positionWS);
    surfaceDistanceToCam = length(input.positionVS);
    float sceneDepth = SampleSceneDepth(positionSS);
    float sceneDistanceToCam = LinearEyeDepth(sceneDepth, _ZBufferParams) * length(input.positionVS/input.positionVS.z);
    float surfaceDistanceToScene = sceneDistanceToCam - surfaceDistanceToCam;

    // Edge strength by surface-scene distance detection
    float uvNoise = (value_noise12(uv * 12 + _Time.x * 8) - 0.5) * 2;
    float2 edgeDetectionBoundary = float2(_DepthParameter.y, _DepthParameter.z) + uvNoise * 0.25;
    float edgeStrength = pow(saturate(1 - clamp((surfaceDistanceToScene - edgeDetectionBoundary.x)/ edgeDetectionBoundary.y, 0, 1)), _DepthParameter.w);
    // Edge strength by plane uv (unTransformed via BaseMap_ST)
    float uvEdgeStrength = step(0.5, step(0.49, abs(input.uvUntransformed.x + uvNoise * 0.001 - 0.5)) + step(0.49, input.uvUntransformed.y + uvNoise * 0.001 - 0.5));
    
    edgeStrength = saturate(edgeStrength + uvEdgeStrength);
    
// -- Animated emission control
    float animatedEmissionControlValue = (sin(_Time.x * 20) + 1)/2;
    animatedEmissionControlValue = 0.95 - Smoothstep01((sin(_Time.x * 10)+1)*0.5) + 0.1;
    
    // Antialiasing based on distance
    float controlValueInterval = 0.05 * pow(length(input.positionVS), 0.5);
    //float animatedEmissionStrength =
    //    step(animatedEmissionControlValue - controlValueInterval, SAMPLE_TEXTURE2D(_AnimatedEmissionMap, sampler_AnimatedEmissionMap, uv).r) -
    //        step(animatedEmissionControlValue, SAMPLE_TEXTURE2D(_AnimatedEmissionMap, sampler_AnimatedEmissionMap, uv).r);
    float animatedEmissionStrength =
        smoothstep(
            animatedEmissionControlValue - controlValueInterval,
            animatedEmissionControlValue,SAMPLE_TEXTURE2D(_AnimatedEmissionMap, sampler_AnimatedEmissionMap, uv).r) -
                smoothstep(
            animatedEmissionControlValue,
            animatedEmissionControlValue + controlValueInterval,SAMPLE_TEXTURE2D(_AnimatedEmissionMap, sampler_AnimatedEmissionMap, uv).r);

    //animatedEmissionStrength = smoothstep(
    //        animatedEmissionControlValue - controlValueInterval,
    //        animatedEmissionControlValue, SAMPLE_TEXTURE2D(_AnimatedEmissionMap, sampler_AnimatedEmissionMap, uv).r) - 0.3;
        
    half3 animatedEmissionColor = saturate(animatedEmissionStrength) * _AnimatedEmissionColor;

// -- Hit ring emission control
    float hitRingTimer = _Time.y/1;
    float2 randomNoisePosOffset = value_noise21(floor(hitRingTimer) * 100 * 2) * 2 - 1;
    float3 hitPointPos = float3(11.8, 1.0, 27.5) + float3(randomNoisePosOffset.x, randomNoisePosOffset.y, 0) * 2;
    half hitRingInterval = 0.05;
    //hitPointPos = TransformObjectToWorld(hitPointPos);
    float surfaceDistanceFromHitPoint = distance(input.positionWS, hitPointPos);
    float hitRingAppearDistance = hitRingInterval + (frac(hitRingTimer)) * 6 + uvNoise * 0.06;
    float hitRingStrength =
        smoothstep(hitRingAppearDistance - hitRingInterval, hitRingAppearDistance, surfaceDistanceFromHitPoint) -
            smoothstep(hitRingAppearDistance, hitRingAppearDistance + hitRingInterval, surfaceDistanceFromHitPoint);
    //hitRingStrength = step(surfaceDistanceFromHitPoint, hitRingAppearDistance + hitRingInterval) - step(surfaceDistanceFromHitPoint, hitRingAppearDistance - hitRingInterval);
    // hitRingInterval = 0.3;
    hitRingStrength *= Smootherstep01(1 - frac(hitRingTimer));
    half3 hitRingEmissionColor = saturate(hitRingStrength) * _AnimatedEmissionColor;
    
// -- Edge Alpha Control Pow4(edgeStrength)
    half alphaEdge = 1 - abs(input.uvUntransformed - 0.5);
    
    half3 color = texColor.rgb * _BaseColor.rgb + emissionColor.rgb + animatedEmissionColor + hitRingEmissionColor;
    color = lerp(color, _EdgeEmissionColor, edgeStrength);

// -- Refraction sample
    //float3 normalVS =
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    float3 normalFromHeight = ReconstructNormalFromGrayScaleHeightTexture(
        TEXTURE2D_ARGS(_DisplacementParallaxMap, sampler_DisplacementParallaxMap), 
        _DisplacementParallaxMap_TexelSize.xy, uv, 6);
    float3 normalWSFromHeight = TransformTangentToWorld(normalFromHeight, tangentToWorld);
    
    half3 refractionColor = SampleRefraction(positionSS, half2(1,1), TransformWorldToViewDir(normalWSFromHeight), surfaceDistanceToScene);
    
    half alpha = texColor.a * _BaseColor.a * alphaEdge;
    half refractionAlpha = alpha;
    alpha = 1.0;

    AlphaDiscard(alpha, _Cutoff);

    InputData inputData;
    InitializeInputData(input, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

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
    half4 finalColor = UniversalFragmentUnlit(inputData, color, alpha);
    finalColor.rgb = lerp(finalColor.rgb, refractionColor, refractionAlpha);
    //finalColor.rgb = normalWSFromHeight;

#if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(normalizedScreenSpaceUV);
    finalColor.rgb *= aoFactor.directAmbientOcclusion;
#endif

    finalColor.rgb = MixFog(finalColor.rgb, fogFactor);

    return finalColor;
}

#endif
