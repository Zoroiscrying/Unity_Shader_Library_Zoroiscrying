Shader "Custom/Object/Unlit_DoubleSided_Holofield"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)
        _Cutoff("AlphaCutout", Range(0.0, 1.0)) = 0.5

        // BlendMode
        _Surface("__surface", Float) = 0.0
        _Blend("__mode", Float) = 0.0
        _Cull("__cull", Float) = 2.0
        [ToggleUI] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _BlendOp("__blendop", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0

        // Editmode props
        _QueueOffset("Queue offset", Float) = 0.0
        
        // Emission
        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
        
        // Holofield properties
        // Texture emission
        [HDR]_AnimatedEmissionColor("Animated Emission Color", Color) = (1,1,1,1)
        _AnimatedEmissionMap("Emission Animated", 2D) = "Black" {}
        _AnimatedEmissionSpeed("Emission Animate Speed", Float) = 0.5
        
        // Texture displacement
        _DisplacementParallaxMap("Textured Parallax Map", 2D) = "Grey" {}
        _ParallaxStrength("Parallax Strength", Float) = 0.5
        
        // Shield hit effect
        [Tooltip(Distance, Intensity, Null, Thickness)]_ScanParameter("Scan Parameter", Vector) = (1,1,1,1)
        _ScanPosition("Scan position", Vector) = (0,0,0,0)
        
        // Depth awareness
        [HDR]_EdgeEmissionColor("Edge Emission Color", Color) = (1,1,1,1)
        [Tooltip(Depthstrength, Min, Max, Power)]_DepthParameter("Depth Parameter", Vector) = (1,0,4,1)
        
        // Refraction / Distortion
        [Tooltip(Refraction strength, Distortion strength)]_SceneColorParameter("SceneColor Parameter", Vector) = (1,1,1,1)
        
        // Rim light
        [Tooltip(Rim light intensity, Rim light power, null, null)]_RimLightParameters("Rim light parameter", Vector) = (1,1,1,1)
        
        // Back face rendering
        [Tooltip(Backface emission strength, Backface edge color strength, Null, Null)]_BackfaceRenderingParameters("BF Parameters", Vector) = (1,1,1,1)
       
    }

    SubShader
    {
        Tags {"RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "ShaderModel"="4.5"}
        LOD 100

        Blend [_SrcBlend][_DstBlend]
        ZWrite [_ZWrite]

        Pass
        {
            Cull Back
            Name "Unlit"

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile _ DEBUG_DISPLAY

            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment

            #include "../../../ShaderLibrary/Template/CustomUnlitInput.hlsl"
            #include "DoubleSidedHolofieldPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Cull Front
            ZTest LEqual
            ZWrite Off
            Tags{"RenderType" = "Opaque" "LightMode" = "BackFaceHolofield" "RenderPipeline" = "UniversalPipeline"}
            Name "Unlit"

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile _ DEBUG_DISPLAY

            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment

            #include "../../../ShaderLibrary/Template/CustomUnlitInput.hlsl"
            #include "DoubleSidedHolofieldPass_EdgeOnly.hlsl"
            ENDHLSL
        }

        Pass
        {
            Cull Front
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "../../../ShaderLibrary/Template/CustomUnlitInput.hlsl"
            #include "../../../ShaderLibrary/Template/CustomDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Cull Back
            Name "DepthNormalsOnly"
            Tags{"LightMode" = "DepthNormalsOnly"}

            ZWrite On

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT // forward-only variant

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitDepthNormalsPass.hlsl"
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
            #pragma fragment UniversalFragmentMetaUnlit
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitMetaPass.hlsl"
            ENDHLSL
        }
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "ZoroiscryingUnityShaderLibrary.Editor.UnlitVersatileShaderGUI"
}
