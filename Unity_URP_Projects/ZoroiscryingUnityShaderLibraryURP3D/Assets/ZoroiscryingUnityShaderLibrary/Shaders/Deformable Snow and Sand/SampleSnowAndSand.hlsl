#ifndef SAMPLE_SNOW_AND_SAND_INCLUDED
#define SAMPLE_SNOW_AND_SAND_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"

#define FXDPT_SIZE (1 << 8)

// Snow and sand texture
// Be aware that in order to sample the texture from shader, the UAV needs to be Texture2D<uint>
uniform Texture2D<uint> SnowDepressionTexture; // We need to manually bilinear interpolate the embedded values in between

// the center height of the depression space
float CurrentMinimumHeightWorldSpace;
float SnowTextureWorldCenterX;
float SnowTextureWorldCenterZ;
// texture resolution and world space size
uint SnowTextureResolution;
float SnowTextureSizeWorldSpace;

float2 Modulus(float2 world_position_xz, float2 texture_size_world_space)
{
    return world_position_xz - (texture_size_world_space * floor(world_position_xz / texture_size_world_space));
}

void ExtractDepressionDataFromInt32(uint data, out float depression_height, out float foot_height, out float timer)
{
    depression_height = float(data >> 16) / (float)FXDPT_SIZE + CurrentMinimumHeightWorldSpace;
    // 00000000000000001111111111111111 | 00000000000000001111111111000000
    // float(data & (0x0000ffc0) >> 6) / (float)FXDPT_SIZE
    foot_height = float(data & (0x0000ffff)) / (float)FXDPT_SIZE + CurrentMinimumHeightWorldSpace;
    // 00000000000000000000000000111111
    timer = float(data & (0x000003f)) / (float)FXDPT_SIZE;
}

void SampleSnowAndSandTexture(float3 positionWS, out float depression, out float footHeight)
{
    // TODO:: Bilinear interpolation of the decompressed values
    // point sampling for now
    const float2 position_world_space_xz = positionWS.xz;
    const float2 world_position_modulus = Modulus(position_world_space_xz, SnowTextureSizeWorldSpace);
    const uint2 position_id = uint2(world_position_modulus / SnowTextureSizeWorldSpace * SnowTextureResolution);
    float timer;
    ExtractDepressionDataFromInt32(SnowDepressionTexture[position_id], depression, footHeight, timer);
    
    // early outs the depression amount if the snow position differs much from the foot height
    // this also indicates that snow height from the ground shouldn't be greater than 2.0f
    // if (abs(footHeight - positionWS.y) > 2.0f)
    // {
    //     depression = 0.0f;
    // }
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

void ProcessSnowAndSandDisplacement(inout float3 positionWS, float depression_height_ws, float footprint_height_ws)
{
    // valid foot position, displacement here
    // we only account situations when foot is below the snow, and it's not too deep below the snow
    const float delta = positionWS.y - footprint_height_ws;
    if (delta < 2.0f && delta > 0.25f)
    {
        // depression depth is the foot depth of this pixel
        const float depression_depth = max(0.0f, positionWS.y - footprint_height_ws); // make sure depression_depth is greater than 0
        const float depression_distance = max(sqrt(depression_depth), REAL_MIN);
        // deformation height is the pow2 deformation calculated based on distance to the foot center
        const float deformation_height = max(0.0f, depression_height_ws - footprint_height_ws);
        const float deformation_distance = sqrt(deformation_height);
        
        const float elevation_distance = max(0.0f, deformation_distance - depression_distance);
        const float max_elevation_distance = 0.5f;
        const float ratio = saturate(elevation_distance / max_elevation_distance);
        const float height_multiplier = max_elevation_distance * 0.5f;
        const float elevation = (SafePositivePow_float(0.5f - ratio, 2.0f)) * height_multiplier;

        // center = 0, elevation_start = 1
        const float center_to_elevation_start = saturate(deformation_distance / depression_distance);
        const float elevation_start_to_end = saturate(ratio);
        
        // positionWS.y = footprint_height_ws + lerp(deformation_height, elevation + depression_depth, center_to_elevation_start);
        positionWS.y = footprint_height_ws + lerp(deformation_height, depression_depth + elevation, center_to_elevation_start);
    }
}

#endif