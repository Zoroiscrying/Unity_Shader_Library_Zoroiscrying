#ifndef BASE_LOOT_ORB_PASS
#define BASE_LOOT_ORB_PASS

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/CustomNoise.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Mapping/Math.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Color/ColorTransform.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Reconstruction.hlsl"

// Shader properties
// Animated emission
half4 _AnimatedEmissionColor;
float _AnimatedEmissionSpeed;
// Fresnel emission
// Fresnel parameters - Fresnel power, fresnel control pos, fresnel control interval, fresnel noise strength
float4 _FresnelParameters;
//float _FresnelPower;
//float _FresnelControlThreshold = 0.9;
half4 _FresnelEmissionColor;
// Center texture display
TEXTURE2D(_CenterTexture); SAMPLER(sampler_CenterTexture);
half4 _CenterTextureColor;
half4 _CenterTextureParameters; // - Center texture size, Center texture Distortion X, Center texture Distortion Y, Center texture illumination falloff
// Animate emission parameters - Distance, Min, Max, Null
half4 _ScanParameter;
// Glitter control
TEXTURE2D(_GlitterNoiseTexture); SAMPLER(sampler_GlitterNoiseTexture);
half4 _GlitterNoiseControl;

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

half4 UnlitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float2 positionSS = GetNormalizedScreenSpaceUV(input.positionCS);
    //float smoothstepControlValue = saturate(smoothstep(0.0, 0.5, frac(_Time.x)) - smoothstep(0.5, 1.0, frac(_Time.x))); 
    half2 uv = input.uv + half2(_Time.x * 2, _Time.x * 0.1);
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    //half3 emissionColor = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;

// -- Animated emission control
    float animatedEmissionControlValue = (sin(_Time.x * 20) + 1)/2;
    animatedEmissionControlValue = 0.95 - Smoothstep01((sin(_Time.x * 10)+1)*0.5) + 0.1;
    
    float hitRingTimer = _Time.x * 5;
    float uvNoise = (value_noise12(uv * 12 + _Time.x * 8) - 0.5) * 2;
    
    float3 hitPointPos = TransformObjectToWorld(float3(100,0,0));
    half hitRingInterval = 0.001;
    float surfaceDistanceFromHitPoint = distance(input.positionWS, hitPointPos);
    float hitRingAppearDistance = hitRingInterval + (frac(hitRingTimer)) * 6 + uvNoise * 0.06;
    float hitRingStrength =
        smoothstep(hitRingAppearDistance - hitRingInterval, hitRingAppearDistance, surfaceDistanceFromHitPoint) -
            smoothstep(hitRingAppearDistance, hitRingAppearDistance + hitRingInterval, surfaceDistanceFromHitPoint);
    hitRingStrength *= Smootherstep01(1 - frac(hitRingTimer));
    half3 hitRingEmissionColor = saturate(hitRingStrength) * _AnimatedEmissionColor;
    
// -- Screen Space Texture Emission
    float3 centerPosition = TransformObjectToWorld(float3(0,0,0));
    float3 upDirSS = mul(unity_CameraToWorld, float4(0,1,0,0)).xyz;
    float3 rightDirSS = normalize(cross(upDirSS, viewDirWS));
    upDirSS = normalize(cross(viewDirWS ,rightDirSS));

    float3x3 relativeSSMatrix = transpose(float3x3(rightDirSS,
                                         upDirSS,
                                         viewDirWS));
    float3 relativeDistances = mul(input.positionWS - centerPosition, relativeSSMatrix);
    float2 uvDistance = float2(_CenterTextureParameters.x, _CenterTextureParameters.x);
    float2 builtUV = float2((relativeDistances.x + uvDistance.x) / uvDistance.x, (relativeDistances.y + uvDistance.y) / uvDistance.y) * 0.5;
    builtUV.x = 1 - builtUV.x;
    float distanceToCenter = length(relativeDistances);
    float centerTexFallOffStrength = lerp(1.0, _CenterTextureParameters.w, distanceToCenter);
    // texture distortion using 2D noise
    float textureEmissionStrength =
        (value_noise11(_Time.y * 6)+0.5/1.5) * SAMPLE_TEXTURE2D(
            _CenterTexture,
            sampler_CenterTexture,
            builtUV + (custom_value_noise22(builtUV * 5 + _Time.xy)-0.5) * _CenterTextureParameters.yz) * centerTexFallOffStrength;

    half3 glitterDirection =normalize(Unity_Hue_Radians_float(
            SAMPLE_TEXTURE2D(_GlitterNoiseTexture, sampler_GlitterNoiseTexture,
                input.uv * _GlitterNoiseControl.xy).xyz
            , _Time.y * .3) - 0.5);
    float screenSpaceGlitterStrength = saturate(dot(1 - viewDirWS, glitterDirection));
    
// -- Fresnel Emission
    _FresnelParameters.y += value_noise11((builtUV.x - builtUV.y) * 6 + _Time.y * 2) * _FresnelParameters.w;
    float fresnelStrength =
        smoothstep(_FresnelParameters.y - _FresnelParameters.z,
            _FresnelParameters.y + _FresnelParameters.z,
            1 - dot(input.normalWS, viewDirWS));
    
    
// -- Color Combination
    half3 color = texColor.rgb * _BaseColor.rgb +
        fresnelStrength * _FresnelEmissionColor +
            hitRingEmissionColor +
                textureEmissionStrength * _CenterTextureColor +
                    screenSpaceGlitterStrength * _FresnelEmissionColor * 2;
    
    half alpha = texColor.a * _BaseColor.a;
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

#if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(normalizedScreenSpaceUV);
    finalColor.rgb *= aoFactor.directAmbientOcclusion;
#endif

    finalColor.rgb = MixFog(finalColor.rgb, fogFactor);

    return finalColor;
}

#endif
