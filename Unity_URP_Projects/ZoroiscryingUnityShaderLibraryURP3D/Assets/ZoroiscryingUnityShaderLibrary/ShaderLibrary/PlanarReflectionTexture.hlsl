#ifndef PLANAR_REFLECTION_TEXTURE_INCLUDED
#define PLANAR_REFLECTION_TEXTURE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D(_PlanarReflectionTexture);
SamplerState planar_Trilinear_Clamp_Sampler;


#endif 