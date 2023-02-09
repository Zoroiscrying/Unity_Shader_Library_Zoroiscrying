#ifndef DEFORMABLE_SNOW_AND_SAND_SHADER_UTILITY_INCLUDED
#define DEFORMABLE_SNOW_AND_SAND_SHADER_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct SnowFootprintData
{
    float3 PositionWorldSpace;
    float DepressionCoefficient;
};

// 1<<16; 1<<6; 1<<0
// Use Step to clamp
// 32bits, 16bits for deformation height, 10bits for foot deformation, 6bits for timer.
uniform RWTexture2D<uint> SnowDepressionTexture;

// the center height of the depression space
float CurrentMinimumHeightWorldSpace;
float SnowTextureWorldCenterX;
float SnowTextureWorldCenterZ;
// texture resolution and world space size
uint SnowTextureResolution;
// Snow system coverage world space size
float SnowTextureSizeWorldSpace;

// uint16 range excluding the leftmost bit: 0, 32767
// FXDPT_SIZE conversion floating range: 0, 128 in meters, step size: 0.004m = 4 mm
#define FXDPT_SIZE (1 << 8)

// depression height takes up 16 bits (uint) range from 0 to 1<<16-1
#define DEPRESSION_MAX 0xffff
// foot height takes up 10 bits (uint), range from 0 to 1<<10 - 1 (right now we're using all 16 bits)
#define FOOT_HEIGHT_MAX 0xffff
// timer takes up 6 bits (uint), range from 0 to 1<<6 - 1
#define TIMER_MAX (1 << 6) - 1

// turn floating point to int32, because int32 have one leftmost sign bit, and a variant sign bit
// would ruin the atomic minimum operation, we need to not use that bit.
uint EmbedSnowDepressionDataToUInt32(float depression_height_depression_space, float foot_height_depression_space, float timer)
{
    // int32, 32 bits in all; 
    const uint depression_height_data = clamp(uint(depression_height_depression_space * FXDPT_SIZE), 0, DEPRESSION_MAX) << 16 & 0xffff0000;
    const uint foot_height_data = clamp(uint(foot_height_depression_space * FXDPT_SIZE), 0, FOOT_HEIGHT_MAX) << 0 & 0x0000ffff;
    const uint timer_data = clamp(uint(timer * FXDPT_SIZE), 0, TIMER_MAX) << 0;
    return foot_height_data | depression_height_data;
}

void ExtractDepressionDataFromInt32(uint data, out float depression_height_ws, out float foot_height_ws, out float timer)
{
    depression_height_ws = float(data >> 16) / (float)FXDPT_SIZE + CurrentMinimumHeightWorldSpace;
    // 00000000000000001111111111111111 | 00000000000000001111111111000000
    // float(data & (0x0000ffc0) >> 6) / (float)FXDPT_SIZE
    foot_height_ws = float(data & (0x0000ffff)) / (float)FXDPT_SIZE + CurrentMinimumHeightWorldSpace;
    // 00000000000000000000000000111111
    timer = float(data & (0x000003f)) / (float)FXDPT_SIZE;
}

// This keeps the coordinate in the [0, texture_size_world_space) range
float2 Modulus(float2 world_position_xz, float2 texture_size_world_space)
{
    return world_position_xz - (texture_size_world_space * floor(world_position_xz / texture_size_world_space));
}

#endif