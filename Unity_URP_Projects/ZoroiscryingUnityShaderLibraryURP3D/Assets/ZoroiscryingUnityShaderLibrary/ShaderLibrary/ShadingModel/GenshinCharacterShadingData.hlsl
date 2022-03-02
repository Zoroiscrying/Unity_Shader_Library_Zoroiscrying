#ifndef GENSHIN_CHARACTER_SHADING_DATA_INCLUDED
#define GENSHIN_CHARACTER_SHADING_DATA_INCLUDED

struct CelShadingData
{
    // from albedo texture map
    half3 Albedo;
    half3 Emission;
    half3 ShallowShadowColor;
    half3 DarkShadowColor;
    // not implemented 
    half  metallic;
    half  smoothness;
    half  clearCoatMask;
    half  clearCoatSmoothness;
    // from user input
    half DiffuseLightCutOff;
    half SpecularLightCutOff;
    half DiffuseLightMultiplier;
    half SpecularLightMultiplier;
    half EmissionLightMultiplier;
    // from user input
    half3 RimLightColor;
    half RimSize;
    // from light map
    half SpecularStrength;
    half ShadowWeight;
    half SpecularDetailMask;
    half RampTextureAxisAid_Y;
};

struct CelShadingOutlineData
{
    half OutlineThickness;
};

#endif