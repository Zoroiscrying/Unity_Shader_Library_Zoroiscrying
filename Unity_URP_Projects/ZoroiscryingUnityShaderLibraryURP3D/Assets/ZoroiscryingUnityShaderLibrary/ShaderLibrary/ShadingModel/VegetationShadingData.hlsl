#ifndef VEGETATION_SHADING_DATA_INCLUDED
#define VEGETATION_SHADING_DATA_INCLUDED

struct Vegetation_DisplacementData
{
    // - leaf params
    half _ParameterMovementDensity;
    half _ParameterMovementScale;
    half _ParameterMovementBend;
    half _ParameterMovementStretch;
    half _ParameterMovementStiffness;
    // - sway params
    half _SwayMovementSpring;
    half _SwayMovementDamping;
    // - tree params
    half _TreeMovementBend;
    half _TreeMovementScale;
    half _TreeLeafLag;
    // - world wind params (require magnitude, so it's velocity)
    half3 _WindVelocityVector;
};

struct VegetationSurfaceShadingData
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
    half  translucency;
};


#endif