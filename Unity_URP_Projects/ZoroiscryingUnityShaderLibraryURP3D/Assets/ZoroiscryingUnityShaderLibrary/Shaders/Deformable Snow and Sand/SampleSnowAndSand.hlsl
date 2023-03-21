#ifndef SAMPLE_SNOW_AND_SAND_INCLUDED
#define SAMPLE_SNOW_AND_SAND_INCLUDED


#include "Compute Shaders/DeformableSnowAndSandShaderUtility.hlsl"
#include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/FractalBrownianMotion.hlsl"

uniform Texture2D<uint> SnowDepressionTexture;

void SampleSnowAndSandTexture_float(float3 positionWS, out float depression_ws, out float footHeight_ws)
{
    #if SHADERGRAPH_PREVIEW
    depression_ws = 0.0f;
    footHeight_ws = 0.0f;
    #else

    // TODO:: Bilinear interpolation of the decompressed values, point sampling for now
    const float2 position_world_space_xz = positionWS.xz;

    if (NotInsideTheCurrentSnowTextureCoverage(positionWS.xz))
    {
        depression_ws = 0.0f;
        footHeight_ws = CurrentMinimumHeightWorldSpace + 16.0f;
        return;
    }
    
    const float2 world_position_modulus = Modulus(position_world_space_xz, SnowTextureSizeWorldSpace);
    const uint2 position_id = uint2(world_position_modulus / SnowTextureSizeWorldSpace * SnowTextureResolution);
    float timer;
    ExtractDepressionDataFromUInt32(SnowDepressionTexture[position_id], depression_ws, footHeight_ws, timer);
    
    // early outs the depression amount if the snow position differs much from the foot height
    // this also indicates that snow height from the ground shouldn't be greater than 2.0f
    // if (abs(footHeight - positionWS.y) > 2.0f)
    // {
    //     depression = 0.0f;
    // }
    
    #endif
}

void SampleSnowAndSandTexture_Raw(float3 positionWS, out uint RawData)
{
    // TODO:: Bilinear interpolation of the decompressed values
    // point sampling for now
    const float2 position_world_space_xz = positionWS.xz;
    const float2 world_position_modulus = Modulus(position_world_space_xz, SnowTextureSizeWorldSpace);
    const uint2 position_id = uint2(world_position_modulus / SnowTextureSizeWorldSpace * SnowTextureResolution);
    RawData = SnowDepressionTexture[position_id];
}

void RecalculateVertexNormal_DerivativeBased_PixelShaderOnly(float3 positionOS, inout float3 normalOS)
{
    const float3 ddxPos = ddx(positionOS);
    const float3 ddyPos = ddy(positionOS)*_ProjectionParams.x;
    normalOS = normalize(cross(ddxPos, ddyPos));
}

void RecalculateVertexNormal_CrossBased_TwoDirection(float3 positionOS, float3 positionOS_Tangent_Direction, float3 positionOS_BiTangent_Direction, inout float3 normalOS)
{
    float3 tangent = SafeNormalize(positionOS_Tangent_Direction - positionOS);
    float3 biTangent = SafeNormalize(positionOS_BiTangent_Direction - positionOS);
    normalOS = normalize(cross(tangent, biTangent));
}

void RecalculateVertexNormal_CrossBased_FourDirection(float3 positionOS,
    float3 positionOS_Tangent_Direction, float3 positionOS_BiTangent_Direction,
    float3 positionOS_Neg_Tangent_Direction, float3 positionOS_Net_BiTangent_Direction,
    inout float3 normalOS)
{
    float3 tangent = SafeNormalize(positionOS_Tangent_Direction - positionOS_Neg_Tangent_Direction);
    float3 biTangent = SafeNormalize(positionOS_BiTangent_Direction - positionOS_Net_BiTangent_Direction);
    normalOS = normalize(cross(tangent, biTangent));
}

void GetSnowAndSandWorldPositionY_float(float3 positionWS, float depression_height_ws, float footprint_height_ws, out float world_height, out float is_valid)
{
    #if SHADERGRAPH_PREVIEW
    world_height = 0.0f;
    is_valid = 0.0f;
    #else
    // valid foot position, displacement here
    // we only account situations when foot is below the snow, and it's not too deep below the snow
    const float delta = positionWS.y - footprint_height_ws;
    world_height = 0.0f;
    is_valid = 0.0f;
    
    if ((delta) < 2.0f && delta > 0.0f)
    {
        // world space noise value
        const float noise = (fbm_snoise_4step_12(positionWS.xz * 0.75f) - 0.5f) * 2.0f * 0.4f;
        
        // depression depth is the foot depth of this pixel
        const float depression_depth = positionWS.y - footprint_height_ws; // make sure depression_depth is greater than 0
        const float depression_depth_sign = saturate(sign(depression_depth));
        const float depression_distance = max(sqrt(max(0.0f, depression_depth)), REAL_MIN);
        // deformation height is the pow2 deformation calculated based on distance to the foot center
        float deformation_height = max(0.0f, depression_height_ws - footprint_height_ws);
        const float deformation_distance = sqrt(deformation_height);
        deformation_height = max(0.0f, deformation_height + noise * 0.2f);
        
        const float elevation_distance = max(0.0f, deformation_distance - depression_distance);
        const float max_elevation_distance = depression_distance * 0.5f;
        const float ratio = saturate(elevation_distance / max_elevation_distance);
        const float height_multiplier = max_elevation_distance * 0.3f + noise * max_elevation_distance * 0.8f;
        const float elevation = max((1.0f - SafePositivePow_float(2.0f * ratio - 1.0f, 2.0f)) * height_multiplier, 0.0f);

        // center = 0, elevation_start = 1
        const float center_to_elevation_start = saturate(deformation_distance / depression_distance);
        const float elevation_start_to_end = saturate(ratio);
        
        world_height = footprint_height_ws + lerp(deformation_height, elevation + depression_depth, center_to_elevation_start);
        is_valid = 1.0f;
        // positionWS.y += lerp(-deformation_height, elevation, center_to_elevation_start);
        // positionWS.y = lerp(depression_height_ws, positionWS.y + elevation, center_to_elevation_start);
    }
    #endif
}

void ProcessSnowAndSandDisplacement(inout float3 positionWS, float depression_height_ws, float footprint_height_ws)
{
    float world_height;
    float is_valid;
    GetSnowAndSandWorldPositionY_float(positionWS, depression_height_ws, footprint_height_ws, world_height, is_valid );

    if (is_valid)
    {
        positionWS.y = world_height;
    }
}

#endif