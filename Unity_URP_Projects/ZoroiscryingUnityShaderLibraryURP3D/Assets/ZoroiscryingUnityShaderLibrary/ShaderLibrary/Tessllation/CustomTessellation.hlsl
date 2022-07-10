#ifndef CUSTOM_TESSELLATION_INCLUDED
#define CUSTOM_TESSELLATION_INCLUDED

// Tessellation programs based on this article by Catlike Coding:
// https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/

// Usage:
// Minimum shader model - 4.6:
// #pragma target 4.6
// Declare hull, tess, domain functions:
// #pragma hull hull
// #pragma domain domain
// Customization:
// #define PATCH_FUNCTION "..."
// #define PARTITION_METHOD "..."

// * Remember to define before this file does.

#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
#define UNITY_CAN_COMPILE_TESSELLATION 1
#   define UNITY_domain                 domain
#   define UNITY_partitioning           partitioning
#   define UNITY_outputtopology         outputtopology
#   define UNITY_patchconstantfunc      patchconstantfunc
#   define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

#ifndef PATCH_FUNCTION
    #define PATCH_FUNCTION "patchConstantFunction"
#endif

#ifndef PARTITION_METHOD
    #define PARTITION_METHOD "fractional_odd"
#endif

#include "TessellationUtility.hlsl"

// float _TessellationUniform;
float _TessellationMinDistance;
float _TessellationMaxDistance;
float _TessellationFactor;

// --- Tessellation Functions ---
// --- Constant Function
TessellationFactors patchConstantFunction (InputPatch<ControlPoint, 3> patch)
{
    TessellationFactors f;
    f.edge[0] = _TessellationFactor;
    f.edge[1] = _TessellationFactor;
    f.edge[2] = _TessellationFactor;
    f.inside = _TessellationFactor;
    return f;
}

// --- Distance Function
TessellationFactors patchDistanceFunction(InputPatch<ControlPoint, 3> patch)
{
    //return patchConstantFunction(patch);
    return UnityDistanceBasedTess_WS(patch[0].positionWS, patch[1].positionWS, patch[2].positionWS, 50.0, 250.0, 6);
}

TessellationFactors patchDistanceFunction_Variable_WS(InputPatch<ControlPoint, 3> patch)
{
    //return patchConstantFunction(patch);
    return UnityDistanceBasedTess_WS(patch[0].positionWS, patch[1].positionWS, patch[2].positionWS, _TessellationMinDistance, _TessellationMaxDistance + _TessellationMinDistance, _TessellationFactor);
}

// --- Hull And Domain Functions ---
[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning(PARTITION_METHOD)] //fractional_odd integer fractional_even pow2
[UNITY_patchconstantfunc(PATCH_FUNCTION)]
ControlPoint hull (InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    // the [patchconstantfunc declares the patch function - the tessellation guiding function]
    // hull shader comes after the vertex shader (so Varyings will be passed)
    return patch[id];
}

[UNITY_domain("tri")]
Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    // domain program comes after the tessellation function and generates triangles and vertices to the geometry program
    // after geometry program's vertex processing and interpolation (if exist), the data will be passed to the fragment program

    // This domain function takes the responsibility of calculating Varyings Struct for fragment shader.
    Attributes v;

    #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

    // MY_DOMAIN_PROGRAM_INTERPOLATE(positionCS)

    #ifdef TESSELLATION_AFFECT_NORMAL_OS
    MY_DOMAIN_PROGRAM_INTERPOLATE(normalOS)
    #endif

    #ifdef TESSELLATION_AFFECT_POSITION_OS
    MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS)
    #endif
    
    #ifdef TESSELLATION_AFFECT_POSITION_WS
    MY_DOMAIN_PROGRAM_INTERPOLATE(positionWS)
    #endif

    #ifdef TESSELLATION_AFFECT_POSITION_SS
    MY_DOMAIN_PROGRAM_INTERPOLATE(positionSS)
    #endif

    #ifdef TESSELLATION_AFFECT_UV
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
    #endif
    
    #ifdef TESSELLATION_AFFECT_NORMAL_WS
        MY_DOMAIN_PROGRAM_INTERPOLATE(normalWS)
    #endif

    #ifdef TESSELLATION_AFFECT_VIEW_DIRECTION_WS
    MY_DOMAIN_PROGRAM_INTERPOLATE(viewDirectionWS)
    #endif

    #ifdef TESSELLATION_AFFECT_TANGENT_OS
    MY_DOMAIN_PROGRAM_INTERPOLATE(tangentOS)
    #endif

    #ifdef TESSELLATION_AFFECT_COLOR
    MY_DOMAIN_PROGRAM_INTERPOLATE(color)
    #endif

    #ifdef TESSELLATION_AFFECT_UV_1
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
    #endif

    return VertexToFragment(v);
}

#endif