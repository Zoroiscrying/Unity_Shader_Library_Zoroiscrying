#ifndef WAVE_CALCULATION_INCLUDED
#define WAVE_CALCULATION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// -------- SIN WAVE --------
float CalculateSinWave1D(float coord, float amplitude, float speed, float waveLength)
{
    float f = 0;
    float k = TWO_PI / waveLength;
    f = amplitude * sin(k * coord - speed * _Time.y);
    return f;
}

float CalculateSinWave2D(float2 coord, float2 directionXZNormalized, float amplitude, float speed, float waveLength)
{
    float f = 0;
    float k = TWO_PI / waveLength;
    f = amplitude * sin(k * dot(coord, directionXZNormalized) - speed * _Time.y);
    return f;
}

/**
 * \brief Get the results from a 2D(XZ) sin wave
 * \param coord The coordinate of the wave (x of the a * sin(x * f + o))
 * \param amplitude Amplitude 
 * \param speed Speed
 * \param waveLength Wavelength of the sin wave
 * \param directionXZNormalized The wave direction
 * \param normal Calculated Object Space Normal
 * \param tangent Calculated Object Space Tangent
 * \return 
 */
float CalculateSinWave2D_Normal_Tangent_Calculated(
    float2 coord, float2 directionXZNormalized, float amplitude, float speed, float waveLength, 
    inout float3 normal, inout float3 tangent)
{
    float f = 0;
    float k = TWO_PI / waveLength;
    float x = k * dot(coord, directionXZNormalized) - speed * _Time.y;
    f = amplitude * sin(x);
    // p.x = x
    // p.y = y + a * sin(k * (Dx * x + Dz * z) - speed * t)
    // p.z = z

    // tangent:
    // p.x' = 0
    // p.y' = 0 + Dz * k * a * cos(k * (Dx * x + Dz * z) - speed * t)
    // p.z' = 1
    tangent = normalize(float3(1, directionXZNormalized.x * k * amplitude * cos(x), 0));

    // bi tangent
    float3 biTangent = float3(0, directionXZNormalized.y * k * amplitude * cos(x), 1);
    
    normal = cross(biTangent, tangent);
    return f;
}

float Add_SinWave2D_BiTangent_Tangent_Calculated(
    float2 coord, float2 directionXZNormalized, float amplitude, float speed, float waveLength, 
    inout float3 biTangent, inout float3 tangent)
{
    float f = 0;
    float k = TWO_PI / waveLength;
    float x = k * dot(coord, directionXZNormalized) - speed * _Time.y;
    f = amplitude * sin(x);
    // p.x = x
    // p.y = y + a * sin(k * (Dx * x + Dz * z) - speed * t)
    // p.z = z

    // tangent:
    // p.x' = 0
    // p.y' = 0 + Dz * k * a * cos(k * (Dx * x + Dz * z) - speed * t)
    // p.z' = 1
    tangent += float3(1, directionXZNormalized.x * k * amplitude * cos(x), 0);

    // bi tangent
    biTangent += float3(0, directionXZNormalized.y * k * amplitude * cos(x), 1);
    
    return f;
}

// -------- Gerstner WAVE --------
float2 CalculateGerstnerWave1D(float coord, float steepness, float speed, float waveLength)
{
    float2 xy = 0;
    float k = TWO_PI / waveLength;
    float x = k * coord - speed * _Time.y;
    float a = steepness / k;
    xy.x = a * cos(x);
    xy.y = a * sin(x);
    return xy;
}

float3 CalculateGerstnerWave2D(float2 coord, float2 directionXZNormalized, float steepness, float speed, float waveLength)
{
    float3 xyz = 0;
    float k = TWO_PI / waveLength;
    float x = k * dot(coord, directionXZNormalized) - speed * _Time.y;
    float a = steepness / k;
    xyz.x = directionXZNormalized.x * a * cos(x);
    xyz.y = a * sin(x);
    xyz.z = directionXZNormalized.y * a * cos(x);
    return xyz;
}

float3 CalculateGerstnerWave2D_Normal_Tangent_Calculated(
    float2 coord, float2 directionXZNormalized, float steepness, float speed, float waveLength,
    inout float3 normal, inout float3 tangent)
{
    float3 xyz = 0;
    float k = TWO_PI / waveLength;
    // https://www.soest.hawaii.edu/oceanography/courses_html/OCN201/instructors/Carter/SP2016/waves2_2016_handout.pdf
    // speed can be replaced by sqrt(9.8 / k) - physically based wave speed (another factor is the water depth)
    // * longer waves travels faster
    float x = k * dot(coord, directionXZNormalized) - speed * _Time.y;
    float a = steepness / k;
    xyz.x = directionXZNormalized.x * a * cos(x);
    xyz.y = a * sin(x);
    xyz.z = directionXZNormalized.y * a * cos(x);
    // p.x = x + Dx * a * cos(k * (x * Dx + z * Dz) - speed * t)
    // p.y = a * sin(k * (x * Dx + z * Dz) - speed * t)
    // p.z = y + Dz * a * cos(k * (x * Dx + z * Dz) - speed * t)
    // tangent calculation - partial derivative for x
    // p.x' = 1 - Dx^2 * (a * k == steepness) sin(k * (x * Dx + z * Dz) - speed * t)
    // p.y' = Dx * (a * k == steepness) * cos(k * (x * Dx + z * Dz) - speed * t)
    // p.z' = 0 - DzDx * (a * k == steepness) * cos(k * (x * Dx + z * Dz) - speed * t)
    tangent = float3(
        1 - directionXZNormalized.x * directionXZNormalized.x * steepness * sin(x),
        directionXZNormalized.x * steepness * cos(x),
        -directionXZNormalized.x * directionXZNormalized.y * steepness * cos(x));
 
    // bi-tangent calculation - partial derivative for z
    // p.x' = 0 - DxDz * steepness * sin(f)
    // p.y' = Dz * steepness * cos(f)
    // p.z' = 1 - Dz^2 * steepness * sin(f)
    float3 biTangent = float3(
        -directionXZNormalized.x * directionXZNormalized.y * (steepness * sin(x)),
        directionXZNormalized.y * (steepness * cos(x)),
        1 - directionXZNormalized.y * directionXZNormalized.y * (steepness * sin(x)));

    normal = normalize(cross(biTangent, tangent));
    
    return xyz;
}

float3 Add_GerstnerWave2D_BiTangent_Tangent_Calculated(
    float2 coord, float2 directionXZNormalized, float steepness, float speed, float waveLength,
    inout float3 biTangent, inout float3 tangent, inout float maxHeight)
{
    float3 xyz = 0;
    float k = TWO_PI / waveLength;
    // https://www.soest.hawaii.edu/oceanography/courses_html/OCN201/instructors/Carter/SP2016/waves2_2016_handout.pdf
    // speed can be replaced by sqrt(9.8 / k) - physically based wave speed (another factor is the water depth)
    // * longer waves travels faster
    float x = k * dot(coord, directionXZNormalized) - speed * _Time.y;
    float a = steepness / k;
    maxHeight += a;
    xyz.x = directionXZNormalized.x * a * cos(x);
    xyz.y = a * sin(x);
    xyz.z = directionXZNormalized.y * a * cos(x);
    // p.x = x + Dx * a * cos(k * (x * Dx + z * Dz) - speed * t)
    // p.y = a * sin(k * (x * Dx + z * Dz) - speed * t)
    // p.z = y + Dz * a * cos(k * (x * Dx + z * Dz) - speed * t)
    // tangent calculation - partial derivative for x
    // p.x' = 1 - Dx^2 * (a * k == steepness) sin(k * (x * Dx + z * Dz) - speed * t)
    // p.y' = Dx * (a * k == steepness) * cos(k * (x * Dx + z * Dz) - speed * t)
    // p.z' = 0 - DzDx * (a * k == steepness) * cos(k * (x * Dx + z * Dz) - speed * t)
    tangent += float3(
        1 - directionXZNormalized.x * directionXZNormalized.x * steepness * sin(x),
        directionXZNormalized.x * steepness * cos(x),
        -directionXZNormalized.x * directionXZNormalized.y * steepness * cos(x));
 
    // bi-tangent calculation - partial derivative for z
    // p.x' = 0 - DxDz * steepness * sin(f)
    // p.y' = Dz * steepness * cos(f)
    // p.z' = 1 - Dz^2 * steepness * sin(f)
    biTangent += float3(
        -directionXZNormalized.x * directionXZNormalized.y * (steepness * sin(x)),
        directionXZNormalized.y * (steepness * cos(x)),
        1 - directionXZNormalized.y * directionXZNormalized.y * (steepness * sin(x)));
    
    return xyz;
}

// Future Features: Wind waves approaching shore
// Wave period remains constant, wavelength decreases.
// 


#endif