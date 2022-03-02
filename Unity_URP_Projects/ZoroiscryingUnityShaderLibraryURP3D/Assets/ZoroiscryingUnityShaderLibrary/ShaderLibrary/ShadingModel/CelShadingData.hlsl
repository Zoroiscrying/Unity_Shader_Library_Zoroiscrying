#ifndef CEL_SHADING_DATA_INCLUDED
#define CEL_SHADING_DATA_INCLUDED

struct CelShadingData
{
    half DiffuseLightCutOff;
    half DiffuseBandNumber;
    half SpecularLightCutOff;
    half SpecularBandNumber;
    half3 RimLightColor;
    half RimLightSize;
};

struct CelShadingCharacterData
{
    half DiffuseLightCutOff;
    half DiffuseBandNumber;
    half SpecularLightCutOff;
    half SpecularBandNumber;
    half3 RimLightColor;
    half RimSize;
};

struct CelShadingOutlineData
{
    half OutlineThickness;
};

#endif