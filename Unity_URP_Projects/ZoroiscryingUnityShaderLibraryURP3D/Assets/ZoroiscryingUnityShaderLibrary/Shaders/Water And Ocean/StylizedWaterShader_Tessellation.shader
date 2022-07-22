Shader "Custom/Water/StylizedWaterShader_Tessellation"
{
	// This shader aims to produce versatile control over the look of the water surface, 
	// supporting stylized as well as half-realistic water look
	// - Displacement: Gerstner Wave, Sin Wave, Displacement Map, Interaction Water Wave, Tessellation support
	// - Normal: Normal Mapping, Height Based Normal Calculation, Interaction Water Wave Normal
	// - Color: Direct Lighting, Specular, SSS, Reflection (Cubemap / Planar / Environment) + Refraction (Based On Opaque Map), Edge Detection + Height based Foam
	// - Control: Ramp Gradient, Normal + Strength, Texture Scrolling, Color Component Strength
	// - More: Depth-based water caustics / Top Down Camera Depth Capture
	Properties
	{
		[KeywordEnum(CUBEMAP, PROBES, PLANAR)] _REFLECTION ("Reflection Type", int) = 0 
		_ReflectionIntensity("Reflection Intensity", float) = 1.0
		
		[Header(Roughness)]
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _FresnelPower("Fresnel Power", Range(0, 32)) = 4
		
		[Header(Tessellation)]
		_TessellationMinDistance("Min tessellation distance", float) = 0
        _TessellationMaxDistance("Max tessellation distance", float) = 100
        _TessellationFactor("Tessellation Factor", Range(1.0, 128.0)) = 1.0
		
		[Header(Displacement)]
		[KeywordEnum(SINWAVE, GERSTNER, TEXTURE)] _DISPLACEMENT ("Reflection Type", int) = 0 
		[Toggle(REAL_TIME_DISPLACEMENT)] _RealTimeDisplacement ("Real Time Displacement", int) = 0
		
		_WaveProperties("Wave Direction (XY), Wavelength, Wave Speed", Vector) = (1, 0, 10, 1)
		[Toggle(WAVE_ALPHA)] _WaveAlphaOn ("Calculate Wave Alpha", int) = 0
		_WaveProperties_A("Wave Alpha", Vector) = (1, 1, 10, 0.75)
		[Toggle(WAVE_BETA)] _WaveBetaOn ("Calculate Wave Beta", int) = 0
		_WaveProperties_B("Wave Beta", Vector) = (1, 2, 20, 0.5)
		[Toggle(WAVE_C)] _WaveCOn ("Calculate Wave C", int) = 0
		_WaveProperties_C("Wave C", Vector) = (2, 1, 30, 0.5)
		
		[Header(Sin Wave)] // f = a * sin(2pi * x / w + speed * t);
		_Amplitude ("Amplitude Prime Alpha Beta C", Vector) = (0.5, 0.5, 0.25, 0.25)
		
		[Header(Gerstner Wave)] // x (cos) and y(sin) both affected
		_Steepness ("Steepness Prime Alpha Beta C", Vector) = (0.5, 0.5, 0.25, 0.25)
		
		[Header(Foam Control)]
		_FoamTexture("Foam Texture", 2D) = "white"{}
		_FoamDistance("Foam Distance", Float) = 1.0
		
		[Header(Refraction)]
		_RefractionStrength("Refraction Strength", Range(-2, 2)) = 0.5
		
		[Header(Absorption)]
		_AbsorptionIntensity("Absorption Intensity", Range(0, 1)) = 1.0
		_AbsorptionDistance("Absorption Distance", Float) = 20.0
		_AbsorptionFogDistance("Absorption Fog Distance", Float) = 40.0
		_AbsorptionRamp("Absorption Ramp", 2D) = "white"{}
		
		[Header(Scattering)]
		_ScatteringIntensityControl("Scattering Control: Height, Normal, Sun, Bubble", Vector) = (1.0, 1.0, 1.0, 1.0)
		_ScatteringDistance("Scattering Distance", Float) = 20.0
		_ScatteringFogDistance("Scattering Fog Distance", Float) = 40.0
		_ScatteringRamp("Scattering Ramp", 2D) = "white"{}
		
		[Header(Lighting Control)]
		_NormalAlphaStrength("Normal Alpha Strength", float) = 0.5
		_NormalMapAlpha("Normal Map Alpha", 2D) = "bump"{}
		_NormalBetaStrength("Normal Beta Strength", float) = 0.5
		_NormalMapBeta("Normal Map Beta", 2D) = "bump"{}
		
	}
	SubShader
	{
		Tags
        {
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline" 
            "UniversalMaterialType" = "Lit" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.6"
        }
		
		LOD 300

		Pass
		{
			Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
			Blend One Zero // Use Opaque Map to get the underwater color, enabling refraction calculation
            ZTest LEqual
            ZWrite On
            Cull BACK
			
			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
            #pragma target 5.0
			
			// Keywords, defines and Compiles
			#pragma multi_compile_fog // make fog work
			#pragma multi_compile _ LIGHTMAP_ON // light map
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED // direct lighting and light map combine
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS // main light shadow
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE // main light shadow cascade
            #pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF // vertex light, other lights
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS // additional light shadows
            #pragma multi_compile _ _SHADOWS_SOFT // custom compile - soft shadow calculation
			// In Subtractive Lighting Mode, all Mixed Lights in your Scene provide baked direct and indirect lighting.
			// Unity bakes shadows cast by static GameObjects into the lightmaps
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			
			#pragma shader_feature _REFLECTION_CUBEMAP _REFLECTION_PROBES _REFLECTION_PLANAR
			#pragma shader_feature _DISPLACEMENT_SINWAVE _DISPLACEMENT_GERSTNER _DISPLACEMENT_TEXTURE
			#pragma shader_feature __ WAVE_ALPHA
			#pragma shader_feature __ WAVE_BETA
			#pragma shader_feature __ WAVE_C

			#define PATCH_FUNCTION "patchDistanceFunction_Variable_WS"
			#define TESSELLATION_AFFECT_POSITION_OS
            #define TESSELLATION_AFFECT_NORMAL_OS
            #define TESSELLATION_AFFECT_TANGENT_OS
			#define TESSELLATION_AFFECT_UV_1

			// Register Functions
			#pragma vertex StylizedWaterPassVertexForTessellation
			#pragma hull hull
            #pragma domain domain
			#pragma fragment StylizedWaterPassFragment

			#include "StylizedWaterInput.hlsl"
			#include "StylizedWaterPass.hlsl"
			#include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"

			ENDHLSL
		}
	}
	
	FallBack "Diffuse"
}