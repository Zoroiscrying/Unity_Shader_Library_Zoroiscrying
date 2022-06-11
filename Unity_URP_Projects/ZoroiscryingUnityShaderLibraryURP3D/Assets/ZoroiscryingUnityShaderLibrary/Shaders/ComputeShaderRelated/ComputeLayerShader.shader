Shader "Custom/Compute/ComputeLayerShader"
{
    Properties
    {
        // Grass Properties
        _BottomColor("Bottom Color", Color) = (0, 0.5, 0, 1)
        _TopColor("Top Color", Color) = (0, 1, 0, 1)
        _DetailNoiseTexture("Grainy noise", 2D) = "white"{}
        _DetailNoiseScale("Grainy noise scale", Range(0, 1)) = 1 // The influence of texture A
        _SmoothNoiseTexture("Smoothe noise", 2D) = "white"{}
        _SmoothNoiseScale("Smooth noise scale", Range(0, 1)) = 1
        // Wind will affect the uv sampling the noise (not changing the actual geometry)
        _WindNoiseTexture("Wind noise texture", 2D) = "white"{}
        _WindTimeMult("Wind Frequency", float) = 1
        _WindAmplitude("Wind strength", float) = 1
        
    }
    
    // Subshader with shader model 5.0 For compute buffers
    // - UniversalForward
    // - ShadowCaster
    // - DepthOnly
    // - DepthNormals
    // - Meta
    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True" }

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // LightMode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 5.0

            // -------------------------------------
            // Material Keywords
            //#pragma shader_feature_local _NORMALMAP
            //#pragma shader_feature_local _PARALLAXMAP
            //#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            //#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            //#pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            //#pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            //#pragma shader_feature_local_fragment _EMISSION
            //#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            //#pragma shader_feature_local_fragment _OCCLUSIONMAP
            //#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            //#pragma shader_feature_local_fragment _SPECULAR_SETUP

            // -------------------------------------
            // Universal Pipeline keywords
            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            //#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            //#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            //#pragma multi_compile_fragment _ _SHADOWS_SOFT
            //#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            //#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            //#pragma multi_compile_fragment _ _LIGHT_LAYERS
            //#pragma multi_compile_fragment _ _LIGHT_COOKIES
            //#pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            //#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            //#pragma multi_compile _ SHADOWS_SHADOWMASK
            //#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            //#pragma multi_compile _ LIGHTMAP_ON
            //#pragma multi_compile _ DYNAMICLIGHTMAP_ON
            //#pragma multi_compile_fog
            //#pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            //#pragma multi_compile_instancing
            //#pragma instancing_options renderinglayer
            //#pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ComputeVertex
            #pragma fragment LitPassFragment2

            #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "ComputeLayerLitPass.hlsl"
            ENDHLSL
        }

        // Shadow caster pass for lights, output variable - positionCS
        // VERTEX PASS - output.positionCS = GetShadowPositionHClip(input);
        // FRAGMENT PASS - Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
        //Pass
        //{
        //    Name "ShadowCaster"
        //    //Tags{"LightMode" = "ShadowCaster"}
//
        //    ZWrite On
        //    ZTest LEqual
        //    ColorMask 0
        //    Cull[_Cull]
//
        //    HLSLPROGRAM
        //    #pragma exclude_renderers gles gles3 glcore
        //    #pragma target 5.0
//
        //    // -------------------------------------
        //    // Material Keywords
        //    #pragma shader_feature_local_fragment _ALPHATEST_ON
        //    #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
        //    //--------------------------------------
        //    // GPU Instancing
        //    #pragma multi_compile_instancing
        //    #pragma multi_compile _ DOTS_INSTANCING_ON
//
        //    // -------------------------------------
        //    // Universal Pipeline keywords
//
        //    // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
        //    #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
//
        //    #pragma vertex ShadowPassVertexCompute
        //    #pragma fragment ShadowPassFragment
//
        //    #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
        //    #include "ComputeLayerShadowCasterPass.hlsl"
        //    ENDHLSL
        //}

        // Depth only pass used when drawing to the Depth Buffer, the pass can also be used for z-prepass etc.
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "../../ShaderLibrary/Template/CustomDepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

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

            #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "../../ShaderLibrary/Template/CustomLitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECGLOSSMAP

            #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "../../ShaderLibrary/Template/CustomLitMetaPass.hlsl"

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
