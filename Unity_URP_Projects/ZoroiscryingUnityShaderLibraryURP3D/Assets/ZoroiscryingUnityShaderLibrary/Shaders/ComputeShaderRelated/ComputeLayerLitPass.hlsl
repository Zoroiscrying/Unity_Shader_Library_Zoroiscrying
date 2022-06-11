#ifndef COMPUTE_LAYER_LIT_INCLUDED
#define COMPUTE_LAYER_LIT_INCLUDED

// --- Custom Modifications ---
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// Properties via material
half4 _BottomColor;
half4 _TopColor;
TEXTURE2D(_DetailNoiseTexture); SAMPLER(sampler_DetailNoiseTexture); float4 _DetailNoiseTexture_ST;
TEXTURE2D(_SmoothNoiseTexture); SAMPLER(sampler_SmoothNoiseTexture); float4 _SmoothNoiseTexture_ST;
float _DetailNoiseScale;
float _SmoothNoiseScale;
TEXTURE2D(_WindNoiseTexture); SAMPLER(sampler_WindNoiseTexture); float4 _WindNoiseTexture_ST;
float _WindTimeMult;
float _WindAmplitude;

// Structs aligned with compute shader
struct OutputVertex
{
    float3 positionWS;
    float3 normalWS;
    float2 uv;
};

struct DrawTriangle
{
    float2 height;
    OutputVertex vertices[3];
};

StructuredBuffer<DrawTriangle> _OutputTriangles;

struct Varyings
{
    float4 uvAndHeight              : TEXCOORD0;
    float3 positionWS               : TEXCOORD1;
    half3 normalWS                 : TEXCOORD2;
    float4 positionCS               : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

Varyings ComputeVertex(uint vertexID : SV_VertexID)
{
    Varyings output = (Varyings)0;

    DrawTriangle tri = _OutputTriangles[vertexID / 3];
    OutputVertex input = tri.vertices[vertexID % 3];

    output.positionWS = input.positionWS;
    output.normalWS = input.normalWS;
    output.uvAndHeight = float4(input.uv, tri.height);

    output.positionCS = TransformWorldToHClip(output.positionWS);
    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    // Layer cutout calculation
    float2 uv = input.uvAndHeight.xy;
    float height = input.uvAndHeight.z;
    //  Wind Calculation
    float2 windUV = TRANSFORM_TEX(uv, _WindNoiseTexture) + _Time.y * _WindTimeMult;
    float2 windNoise = SAMPLE_TEXTURE2D(_WindNoiseTexture, sampler_WindNoiseTexture, windUV) * 2 - 1;
    uv = uv + windNoise * _WindAmplitude * height; // multiply by the height so that higher layers are offset more

    float detailNoise = SAMPLE_TEXTURE2D(_DetailNoiseTexture, sampler_DetailNoiseTexture, TRANSFORM_TEX(uv, _DetailNoiseTexture)).r;
    float smoothNoise = SAMPLE_TEXTURE2D(_SmoothNoiseTexture, sampler_SmoothNoiseTexture, TRANSFORM_TEX(uv, _SmoothNoiseTexture)).r;
    // combine the noise
    detailNoise = 1 - (1 - detailNoise) * _DetailNoiseScale;
    smoothNoise = 1 - (1 - smoothNoise) * _SmoothNoiseScale;
    float combineNoise = min(0.95, (detailNoise + smoothNoise) / 2);
    clip(combineNoise - height); // higher height, more clipping
    
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData_Smoothness_Split(input.uvAndHeight.xy, surfaceData);

    surfaceData.albedo = lerp(_BottomColor, _TopColor, input.uvAndHeight.w);

    InputData inputData = (InputData)0;
    //InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

    half4 color = UniversalFragmentPBR(inputData, surfaceData);

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);

    return color;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment2(Varyings input) : SV_Target
{
    
    float2 uv = input.uvAndHeight.xy;
    float height = input.uvAndHeight.z;

    // Calculate wind
    // Get the wind noise texture uv by applying scale and offset and then adding a time offset
    float2 windUV = TRANSFORM_TEX(uv, _WindNoiseTexture) + _Time.y * _WindTimeMult;
    // Sample the wind noise texture and remap to range from -1 to 1
    float2 windNoise = SAMPLE_TEXTURE2D(_WindNoiseTexture, sampler_WindNoiseTexture, windUV).xy * 2 - 1;
    // Offset the grass UV by the wind. Higher layers are affected more
    uv = uv + windNoise * (_WindAmplitude * height);

    // Sample the two noise textures, applying their scale and offset
    float detailNoise = SAMPLE_TEXTURE2D(_DetailNoiseTexture, sampler_DetailNoiseTexture, TRANSFORM_TEX(uv, _DetailNoiseTexture)).r;
    float smoothNoise = SAMPLE_TEXTURE2D(_SmoothNoiseTexture, sampler_SmoothNoiseTexture, TRANSFORM_TEX(uv, _SmoothNoiseTexture)).r;
    // Combine the textures together using these scale variables. Lower values will reduce a texture's influence
    detailNoise = 1 - (1 - detailNoise) * _DetailNoiseScale;
    smoothNoise = 1 - (1 - smoothNoise) * _SmoothNoiseScale;
    // If detailNoise * smoothNoise is less than height, this pixel will be discarded by the renderer
    // I.E. this pixel will not render. The fragment function returns as well
    clip(detailNoise * smoothNoise - height);

    // Gather some data for the lighting algorithm
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = NormalizeNormalPerPixel(input.normalWS); // Renormalize the normal to reduce interpolation errors
    lightingInput.viewDirectionWS = GetWorldSpaceViewDir(input.positionWS);
    lightingInput.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    
    // Lerp between the two grass colors based on layer height
    float colorLerp = input.uvAndHeight.w;
    float3 albedo = lerp(_BaseColor, _TopColor, colorLerp).rgb;
    
    SurfaceData surfaceData = (SurfaceData)0;
    surfaceData.albedo = albedo;
    surfaceData.smoothness = 0.5f;

    // The URP simple lit algorithm
    // The arguments are lighting input data, albedo color, specular color, smoothness, emission color, and alpha
    return UniversalFragmentBlinnPhong(lightingInput, surfaceData);
}

#endif
