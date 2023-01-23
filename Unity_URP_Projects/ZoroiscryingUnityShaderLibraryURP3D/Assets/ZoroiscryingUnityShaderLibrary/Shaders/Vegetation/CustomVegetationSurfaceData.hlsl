#ifndef CUSTOM_VEGETATION_SURFACE_DATA
#define CUSTOM_VEGETATION_SURFACE_DATA

struct CustomVegetationSurfaceData
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 translucency;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
};

#endif