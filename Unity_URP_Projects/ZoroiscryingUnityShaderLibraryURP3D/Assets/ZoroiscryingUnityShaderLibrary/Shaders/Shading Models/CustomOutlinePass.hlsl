#ifndef CUSTOM_OUTLINE_PASS_INCLUDED
#define CUSTOM_OUTLINE_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
half _OutlinePixelWidth;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
    float2 uv : TEXCOORD0;

    #if defined(DEBUG_DISPLAY)
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;

    #if defined(DEBUG_DISPLAY)
    float3 positionWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float3 viewDirWS : TEXCOORD4;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings OutlinePassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    input.positionOS.xyz += input.normalOS.xyz * _OutlinePixelWidth;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInput.positionCS;

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

Varyings OutlinePass_ScreenSpace_Vertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // screen space normal
    float3 normalVS = TransformWorldToHClipDir(TransformObjectToWorldNormal(input.normalOS)).xyz;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    vertexInput.positionCS.xy += normalize(normalVS.xy) / _ScreenParams.xy * _OutlinePixelWidth * vertexInput.positionCS.w;
    output.positionCS = vertexInput.positionCS;

    return output;
}

half4 OutlinePassFragment(Varyings input) : SV_Target
{
    return half4(0,0,0,1);
}

#endif
