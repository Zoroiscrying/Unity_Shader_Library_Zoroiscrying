#ifndef NPR_SHADING_DATA_INCLUDED
#define NPR_SHADING_DATA_INCLUDED

struct NPRShadingData
{
    // Sharp Edging
    
    // Soft Edging
    
    // Banded Edging
    
    // Halftone Edging
    
    half DiffuseLightCutOff;
    half DiffuseBandNumber;
    half DiffuseEdgeSmoothness;
    
    half SpecularLightCutOff;
    half SpecularBandNumber;
    half SpecularEdgeSmoothness;
    
    half3 RimLightColor;
    half RimLightSize;

    half HalfToneValue;
};

struct NPRShadingOutlineData
{
    half OutlineThickness;
};

#endif