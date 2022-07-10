Shader "Custom/Skybox/StylizedSkybox"
{
    Properties
    {
        [Header(Sky color)]
        [HDR]_ColorTop("Color top", Color) = (1,1,1,1)
        [HDR]_ColorMiddle("Color middle", Color) = (1,1,1,1)
        [HDR]_ColorBottom("Color bottom", Color) = (1,1,1,1)
 
        _MiddleSmoothness("Middle smoothness", Range(0.0,1.0)) = 1
        _MiddleOffset("Middle offset", float) = 0
        _TopSmoothness("Top smoothness", Range(0.0, 1.0)) = 1
        _TopOffset("Top offset", float) = 0
 
        [Header(Sun)]
        [KeywordEnum(A, B)] _SUN_TYPE("Sun Type",int) = 0
        _SunSize("Sun size", Range(0.0, 1.0)) = 0.1
        [HDR]_SunColor("Sun color", Color) = (1,1,1,1)
 
        [Header(Moon)]
        _MoonSize("Moon size", Range(0,1)) = 0
        [HDR]_MoonColor("Moon color", Color) = (1,1,1,1)
        _MoonPhase("Moon phase", Range(0,1)) = 0
         
        [Header(Stars)]
        [KeywordEnum(NOISE, TEXTURE)] _STAR_TYPE("Star Type",int) = 0
        _Stars("Stars", 2D) = "black" {}
        _StarsIntensity("Stars intensity", float) = 0
 
        [Header(Clouds)]
        [HDR]_CloudsColor("Clouds color", Color) = (1,1,1,1)
        _CloudsTexture("Clouds texture", 2D) = "black" {}
        _CloudsThreshold("Clouds threshold", Range(0.0, 1.0)) = 0
        _CloudsSmoothness("Clouds smoothness", Range(0.0, 1.0)) = 0.1
        _SunCloudIntensity("Sun behind clouds intensity", Range(0, 1)) = 0
        _PanningSpeedX("Panning speed X", float) = 0
        _PanningSpeedY("Panning speed Y", float) = 0
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Background" 
            "Queue"="Background"
            "RenderPipeline" = "UniversalPipeline" 
            //"UniversalMaterialType" = "Lit" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.5"
            "PreviewType"="Quad"
        }
        LOD 300

        Pass
        {
            Name "Unlit"

            Blend One Zero
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma shader_feature _SUN_TYPE_A _SUN_TYPE_B
            #pragma shader_feature _STAR_TYPE_NOISE _STAR_TYPE_TEXTURE
            
            #pragma vertex SkyboxPassVertex
            #pragma fragment SkyboxPassFragment

            #include "./StylizedSkyboxInput.hlsl"
            #include "./StylizedSkyboxPass.hlsl"
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

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //CustomEditor "ZoroiscryingUnityShaderLibrary.Editor.LitVersatileShaderGUI"
}
