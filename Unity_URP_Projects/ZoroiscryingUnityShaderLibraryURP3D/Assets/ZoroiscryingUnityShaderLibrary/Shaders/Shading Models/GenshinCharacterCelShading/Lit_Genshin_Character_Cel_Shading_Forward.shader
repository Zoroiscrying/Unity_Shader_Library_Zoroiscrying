Shader "Custom/Shading Model/Lit_Genshin_Character_Cel_Shading_Forward"
{
    Properties
    {
        // Alpha channel - Emission Mask
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _Smoothness("Smoothness", Range(0.1, 32.0)) = 1.0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        // SRP batching compatibility for Clear Coat (Not used in Lit)
        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        // Editmode props
        _QueueOffset("Queue offset", Float) = 0.0
        
        // Cel Shading Lit Properties
        // Light/shadow layering
        [Toggle(_SMOOTH_STEP_LIGHT_EDGE)] _SmoothStepEdge ("Smooth Step Edge", Float) = 0
        [Toggle(_FACE_RENDERING)] _FaceRendering ("Face Rendering", Float) = 0
        _DiffuseEdgeSmoothness("DiffuseLightSmoothness", Range(0.0, 0.5)) = 0.05
        _SpecularEdgeSmoothness("SpecularLightSmoothness", Range(0.0, 0.5)) = 0.05
        _DiffuseLightCutOff("Diffuse Light Cutoff", Range(0.0, 1.0)) = 0.5
        _SpecularLightCutOff("Specular Light Cutoff", Range(0.0, 1.0)) = 0.5
        _DiffuseLightMultiplier("Diffuse Multiplier", Range(0.0, 1.0)) = 1.0
        _SpecularLightMultiplier("Specular Multiplier", Range(0.0, 1.0)) = 1.0
        _EmissionLightMultiplier("Emission Multiplier", Range(0.0, 1.0)) = 0.0
        
        // - Rim Light
        _RimLightThickness("Rim Light Thickness", Range(0.1, 32.0)) = 1.0
        [HDR]_RimLightColor("Rim Light Color", Color) = (1,1,1,1) 
        
        // - Light maps - R->Specular Strength / G->Shadow Channel / B->Specular Detail / A->Ramp Texture Line Aid
        _CharacterLightMap("Character Light Map", 2D) = "white" {}
        _CharacterRampTexture("Character Ramp Texture", 2D) = "White" {}
        
        // Outline
        _OutlinePixelWidth("Outline Pixel Width", Float) = 4
    }
    
    // Subshader with shader model 4.5
    // - UniversalForward
    // - ShadowCaster
    // - DepthOnly
    // - Outline

    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "UniversalMaterialType" = "Lit" 
            "IgnoreProjector" = "True" 
            "Queue" = "Geometry"
            "ShaderModel"="4.5"}
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
            Cull Back
        
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
        
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
        
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
        
            //---------------------------------------
            // Lit Cel Shading Keywords
            #pragma shader_feature_local _SMOOTH_STEP_LIGHT_EDGE
            #pragma shader_feature_local _FACE_RENDERING
            
        
            #include "GenshinCharacterCelShadingLitInput.hlsl"
            #include "GenshinCharacterCelShadingForwardPass.hlsl"
            ENDHLSL
        }
        
        // Outline pass for normal extrusion outlines
        Pass
        {
            Name "Outline"
            Tags{"LightMode" = "Outline" "RenderType" = "Opaque"}

            ZWrite Off
            Cull Front

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            
            #pragma vertex OutlinePass_ScreenSpace_Vertex
            #pragma fragment OutlinePassFragment
            
            #include "../CustomOutlinePass.hlsl"
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
            Cull Back

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

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "../../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "../../../ShaderLibrary/Template/CustomShadowCasterPass.hlsl"
            ENDHLSL
        }

        // Depth only pass used when drawing to the Depth Buffer, the pass can also be used for z-prepass etc.
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Back

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

            #include "../../../ShaderLibrary/Template/CustomLitInput.hlsl"
            #include "../../../ShaderLibrary/Template/CustomDepthOnlyPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "ZoroiscryingUnityShaderLibrary.Editor.CustomVersatileShaderGUI"
}
