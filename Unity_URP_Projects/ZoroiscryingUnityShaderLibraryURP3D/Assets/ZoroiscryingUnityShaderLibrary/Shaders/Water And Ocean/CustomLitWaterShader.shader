Shader "Custom/Water/LitWaterShader"
{
    Properties
    {
        [KeywordEnum(CUBEMAP, PROBES, PLANAR)] _REFLECTION ("Reflection Type", int) = 0 
        
        [Header(Roughness)]
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _FresnelPower("Fresnel Power", Range(0, 32)) = 4
        
        [Header(Colors)]
        _GradientMap("Gradient map", 2D) = "white" {}
        _ShoreColor("Shore color", Color) = (1,1,1,1)
        _ShoreColorThreshold("Shore color threshold", Range(0, 1)) = 0
        [HDR]_Emission("Emission", Color) = (1,1,1,1)
        
        [Header(Tessellation)]
        _VectorLength("Vector length", Range(0.0001, 0.5)) = 0.1
        _TessellationMinDistance("Min tessellation distance", float) = 0
        _TessellationMaxDistance("Max tessellation distance", float) = 100
        _TessellationFactor("Tessellation Factor", Range(1.0, 128.0)) = 1.0
        
        [Header(Vertex Offset)]
        _NoiseTextureA("Noise texture A", 2D) = "white" {}
        _NoiseAProperties("Properties A (speedX, speedY, contrast, contribution)", Vector) = (0,0,1,1)
        _NoiseTextureB("Noise texture B", 2D) = "white" {}
        _NoiseBProperties("Properties B (speedX, speedY, contrast, contribution)", Vector) = (0,0,1,1)
        _OffsetAmount("Offset amount", Range(0.0, 10.0)) = 1.0
        _MinOffset("Min offset", Range(0.0, 1.0)) = 0.2
        
        [Header(Displacement)]
        _DisplacementGuide("Displacement guide", 2D) = "white" {}
        _DisplacementProperties("Displacement properties (speedX, speedY, contribution)", Vector) = (0,0,0,0)
        
        [Header(Shore and foam)]
        _ShoreIntersectionThreshold("Shore intersection threshold", float) = 0
        _FoamTexture("Foam texture", 2D) = "white" {} 
        _FoamProperties("Foam properties (speedX, speedY, threshold, threshold smoothness)", Vector) = (0,0,0,0)
        _FoamIntersectionProperties("Foam intersection properties (intersection threshold, foam threshold, threshold smoothness, cutoff)", Vector) = (0,0,0,0)
        
        [Header(Transparency)]
        _TransparencyIntersectionThresholdMin("Transparency intersection threshold min", float) = 0
        _TransparencyIntersectionThresholdMax("Transparency intersection threshold max", float) = 0
    }
    
    // Subshader with shader model 4.5
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

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // LightMode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha
            ZTest LEqual
            ZWrite On
            Cull BACK

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 5.0

            #pragma multi_compile_fog
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #define PATCH_FUNCTION "patchDistanceFunction_Variable_WS"
            #define TESSELLATION_AFFECT_POSITION_OS
            #define TESSELLATION_AFFECT_NORMAL_OS
            #define TESSELLATION_AFFECT_TANGENT_OS
            //#define TESSELLATION_AFFECT_POSITION_WS
            //#define TESSELLATION_AFFECT_POSITION_SS
            //#define TESSELLATION_AFFECT_NORMAL_WS
            //#define TESSELLATION_AFFECT_VIEW_DIRECTION_WS
            //#define TESSELLATION_AFFECT_COLOR
            #pragma shader_feature _REFLECTION_CUBEMAP _REFLECTION_PROBES _REFLECTION_PLANAR
            
            // -------------------------------------
            #pragma vertex LitWaterPassVertexForTessellation
            #pragma hull hull
            #pragma domain domain
            #pragma fragment LitWaterPassFragment
            
            #include "CustomLitWaterInput.hlsl"
            #include "CustomLitWaterPass.hlsl"
            #include "../../ShaderLibrary/Tessllation/CustomTessellation.hlsl"
            
            ENDHLSL
        }

        //// Shadow caster pass for lights, output variable - positionCS
        //// VERTEX PASS - output.positionCS = GetShadowPositionHClip(input);
        //// FRAGMENT PASS - Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
        //Pass
        //{
        //    Name "ShadowCaster"
        //    Tags{"LightMode" = "ShadowCaster"}
//
        //    ZWrite Off
        //    ZTest LEqual
        //    ColorMask 0
        //    Cull BACK
//
        //    HLSLPROGRAM
        //    #pragma exclude_renderers gles gles3 glcore
        //    #pragma target 4.5
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
        //    #pragma vertex ShadowPassVertex
        //    #pragma fragment ShadowPassFragment
//
        //    #include "../../ShaderLibrary/Template/CustomLitInput.hlsl"
        //    #include "../../ShaderLibrary/Template/CustomShadowCasterPass.hlsl"
        //    ENDHLSL
        //}

        // Depth only pass used when drawing to the Depth Buffer, the pass can also be used for z-prepass etc.
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Front

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

            ZWrite Off
            Cull BACK

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
    }

    FallBack "Diffuse"
}
