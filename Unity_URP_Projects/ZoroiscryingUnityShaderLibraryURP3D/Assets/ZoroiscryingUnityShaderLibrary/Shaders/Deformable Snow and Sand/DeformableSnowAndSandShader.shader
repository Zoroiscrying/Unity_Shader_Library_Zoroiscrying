Shader "Custom/DeformableSnowAndSand/DefaultSnowAndSand"
{
    // 
    Properties
    {
        [MainTexture] _BaseMap("Albedo (RGB) and Opacity (Alpha)", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0
        
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}
        
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax("Scale", Range(0.005, 0.08)) = 0.005
        _ParallaxMap("Height Map", 2D) = "black" {}
        
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}
        _DetailAlbedoMapScale("Scale", Range(0.0, 2.0)) = 1.0
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "linearGrey" {}
        _DetailNormalMapScale("Scale", Range(0.0, 2.0)) = 1.0
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}
        
        // SRP batching compatibility for Clear Coat (Not used in Lit)
        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        
        // Blending state
        _Surface("__surface", Float) = 0.0
        _Blend("__blend", Float) = 0.0
        _Cull("__cull", Float) = 2.0
        [ToggleUI] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0

        [ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        // Editmode props
        _QueueOffset("Queue offset", Float) = 0.0
        
        [Header(Tessellation)]
		_TessellationMinDistance("Min tessellation distance", float) = 0
        _TessellationMaxDistance("Max tessellation distance", float) = 100
        _TessellationFactor("Tessellation Factor", Range(1.0, 128.0)) = 1.0
        
        // Snow And Sand Custom Parameters
        // - not that I can think of right now...
        
    }
    
    HLSLINCLUDE
    
    #include "DeformableSnowAndSandInput.hlsl"
    
    #define PATCH_FUNCTION "patchDistanceFunction_Variable_WS"
	#define TESSELLATION_AFFECT_POSITION_OS
    #define TESSELLATION_AFFECT_NORMAL_OS
    #define TESSELLATION_AFFECT_TANGENT_OS
    #define TESSELLATION_AFFECT_UV
	// #define TESSELLATION_AFFECT_UV_1

    ENDHLSL
    
    // Subshader with shader model 4.6
    // - UniversalForward
    // - ShadowCaster
    // - DepthOnly
    // - DepthNormals
    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "UniversalMaterialType" = "Opaque" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.6"}
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // LightMode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend One Zero
            ZWrite On
            Cull BACK

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.6

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            // #pragma vertex LitPassVertex
            #pragma vertex SnowAndSandPassVertexForTessellation
            #pragma hull hull
            #pragma domain domain
            #pragma fragment LitPassFragment
            
            #include "DeformableSnowAndSandPass.hlsl"
            #include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"
            ENDHLSL
        }

        // Shadow caster pass for lights, output variable - positionCS
        // VERTEX PASS - output.positionCS = GetShadowPositionHClip(input);
        // FRAGMENT PASS - Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
         Pass
         {
             Name "ShadowCaster"
             Tags{"LightMode" = "ShadowCaster"}
 
             ZWrite On
             ZTest LEqual
             ColorMask 0
             Cull BACK
 
             HLSLPROGRAM
             #pragma exclude_renderers gles gles3 glcore
             #pragma target 4.5
 
             // -------------------------------------
             // Material Keywords
             #pragma shader_feature_local_fragment _ALPHATEST_ON
             #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

             //--------------------------------------
             // GPU Instancing
             #pragma multi_compile_instancing
             #pragma multi_compile _ DOTS_INSTANCING_ON
 
             // -------------------------------------
             // Universal Pipeline keywords
 
             // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
             #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
 
             // #pragma vertex ShadowPassVertex
             #pragma vertex SnowAndSandPassVertexForTessellation
             #pragma hull hull
             #pragma domain domain
             #pragma fragment ShadowPassFragment
             
             #include "DeformableSnowAndSandShadowCasterPass.hlsl"
             #include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"
             ENDHLSL
         }

        // Depth only pass used when drawing to the Depth Buffer, the pass can also be used for z-prepass etc.
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull BACK

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            
            #pragma vertex SnowAndSandPassVertexForTessellation
            #pragma hull hull
            #pragma domain domain
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            #include "DeformableSnowAndSandShadowCasterPass.hlsl"
            #include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}
        
            ZWrite On
            Cull BACK
        
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
        
            #pragma vertex SnowAndSandPassVertexForTessellation
            #pragma hull hull
            #pragma domain domain
            #pragma fragment DepthOnlyFragment
        
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
        
            #include "DeformableSnowAndSandShadowCasterPass.hlsl"
            #include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "ZoroiscryingUnityShaderLibrary.Editor.LitVersatileShaderGUI"
}
