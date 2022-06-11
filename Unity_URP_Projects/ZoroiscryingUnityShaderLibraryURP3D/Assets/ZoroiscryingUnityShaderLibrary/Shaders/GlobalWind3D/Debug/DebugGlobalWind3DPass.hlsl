#ifndef DEBUG_GLOBAL_WIND_3D_PASS_INCLUDED
#define DEBUG_GLOBAL_WIND_3D_PASS_INCLUDED

//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/Shaders/GlobalWind3D/SampleGlobalWind3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial) // Material Properties
    half4 _ColorMinVel;
    half4 _ColorMaxVel;
    float _MinVelClamp;
    float _MaxVelClamp;
CBUFFER_END

// float4 _WindVolumeCenterPosition; // center wind position, set as global vector
#if SHADER_TARGET >= 45
    StructuredBuffer<float4> _PositionOffset; // offset positions based on the wind volume center position
#endif

struct Attributes
{
    float4 positionOS : POSITION;
    //float2 uv : TEXCOORD0;

    //UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    //float2 uv : TEXCOORD0;
    //float fogCoord : TEXCOORD1;
    float4 positionCS : SV_POSITION;
    float4 WindDirectionSpeed : TEXCOORD0;

    #if defined(DEBUG_DISPLAY)
    float3 positionWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float3 viewDirWS : TEXCOORD4;
    #endif

    //UNITY_VERTEX_INPUT_INSTANCE_ID
    //UNITY_VERTEX_OUTPUT_STEREO
};

void Unity_RotateAboutAxis_Radians_float(float3 In, float3 Axis, float Rotation, out float3 Out)
{
    float s = sin(Rotation);
    float c = cos(Rotation);
    float one_minus_c = 1.0 - c;

    Axis = normalize(Axis);
    float3x3 rot_mat = 
    {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
        one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
        one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
    };
    Out = mul(rot_mat,  In);
}

Varyings DebugWindPassVertex(Attributes input, uint instanceID : SV_InstanceID)
{
    Varyings output = (Varyings)0;

    //UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if SHADER_TARGET >= 45
        float4 data = _PositionOffset[instanceID];
    #else
        float4 data = 0;
    #endif

    float4 positionWS = data + _WindVolumeCenterPosition;
    output.WindDirectionSpeed = SampleWindDirectionSpeedVertex(positionWS);

    float3 windDirection = output.WindDirectionSpeed.xyz;
    float3 windMeshPointingDirection = float3(0, 1, 0);
    float3 axis = cross(windMeshPointingDirection, windDirection);
    float angle = FastACos(dot(windDirection, windMeshPointingDirection));
    float3 newPositionOS = 0;
    Unity_RotateAboutAxis_Radians_float(input.positionOS, axis, angle, newPositionOS);
    positionWS.xyz = data.xyz + _WindVolumeCenterPosition.xyz + newPositionOS * 10 * max(output.WindDirectionSpeed.w, 0.25);
    output.positionCS = TransformWorldToHClip(positionWS.xyz);
    
    //output.uv = input.uv;
    //#if defined(_FOG_FRAGMENT)
    //    output.fogCoord = vertexInput.positionVS.z;
    //#else
    //    output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
    //#endif

    return output;
}

half4 DebugWindPassFragment(Varyings input) : SV_Target
{
    //UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    //half2 uv = input.uv;
    //SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
    
    //#if defined(_FOG_FRAGMENT)
    //    #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
    //    float viewZ = -input.fogCoord;
    //    float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
    //    half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
    //    #else
    //    half fogFactor = 0;
    //    #endif
    //#else
    //    half fogFactor = input.fogCoord;
    //#endif
    float lerpMeter = (input.WindDirectionSpeed.w - _MinVelClamp) / (_MaxVelClamp - _MinVelClamp);
    half4 finalColor = lerp(_ColorMinVel, _ColorMaxVel, lerpMeter);
    //finalColor.rgb = MixFog(finalColor.rgb, fogFactor);
    return finalColor;
}

#endif
