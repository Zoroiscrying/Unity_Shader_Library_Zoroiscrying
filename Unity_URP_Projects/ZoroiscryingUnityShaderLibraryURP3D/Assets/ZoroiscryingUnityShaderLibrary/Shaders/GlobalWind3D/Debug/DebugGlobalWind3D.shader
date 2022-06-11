Shader "Custom/Debug/Debug_Global_Wind_3D"
{
    Properties
    {
        _ColorMinVel("Color Of Min Velocity", Color) = (0, 1, 0, 1)
        _ColorMaxVel("Color Of Max Velocity", Color) = (1, 0, 0, 1)
        _MinVelClamp("Minimum Velocity to debug", Float) = 0
        _MaxVelClamp("Maximum Velocity to debug", Float) = 3
    }
    
    // Subshader with shader model 4.5
    // - UniversalForward

    SubShader
    {
        Tags{"RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "UniversalMaterialType" = "Unlit" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.5"}
        LOD 300

        Pass
        {
            // LightMode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardUnlitDebug"
            Tags{"LightMode" = "UniversalForward"}

            // Blend[_SrcBlend][_DstBlend]
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

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

            #pragma vertex DebugWindPassVertex
            #pragma fragment DebugWindPassFragment
            //#include "../../../ShaderLibrary/Template/CustomUnlitInput.hlsl"
            // Handle inputs in the pass file
            #include "DebugGlobalWind3DPass.hlsl"
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
