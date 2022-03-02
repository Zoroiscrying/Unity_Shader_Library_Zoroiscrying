Shader "Custom/Shading Model/Unlit_Matcap_Shader"
{
    Properties
    {
        // MatCap properties
        [Toggle(_PERSPECTIVE_STILL)] _PerspectiveStill ("_PerspectiveStill", Float) = 0
        _MatCapTexture("Mat Cap Texture", 2D) = "grey" {}
        // Outline
        _OutlinePixelWidth("Outline Pixel Width", Float) = 4
    }
    
    // Subshader with shader model 4.5
    // - UniversalForward
    // - ShadowCaster
    // - DepthOnly

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
            Name "ForwardUnlit"
            Tags{"LightMode" = "UniversalForward"}
        
            Blend One Zero
            ZWrite On
            Cull Back
        
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
        
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
        
            #pragma vertex MatCapPassVertex
            #pragma fragment MatCapPassFragment
        
            //---------------------------------------
            // Lit Cel Shading Keywords
            #pragma shader_feature_local _PERSPECTIVE_STILL

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/ShadingModel/SharedShading.hlsl"
            
            TEXTURE2D(_MatCapTexture); SAMPLER(sampler_MatCapTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float fogCoord : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            Varyings MatCapPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                output.positionCS = vertexInput.positionCS;
                
                float3 normalVS = TransformWorldToViewDir(TransformObjectToWorldNormal(input.normalOS));
    
                #if _PERSPECTIVE_STILL
                    output.uv = CalculateMatCapUV_PerspectiveStill(normalVS, input.positionOS);
                #else
                    output.uv = CalculateMatCapUV(normalVS, input.positionOS);
                #endif
                #if defined(_FOG_FRAGMENT)
                output.fogCoord = vertexInput.positionVS.z;
                #else
                output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                #if defined(DEBUG_DISPLAY)
                // normalWS and tangentWS already normalize.
                // this is required to avoid skewing the direction during interpolation
                // also required for per-vertex lighting and SH evaluation
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                // already normalized from normal transform to WS.
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = viewDirWS;
                #endif

                return output;
            }

            half4 MatCapPassFragment(Varyings input) : SV_Target
            {
                return half4(SAMPLE_TEXTURE2D(_MatCapTexture, sampler_MatCapTexture, input.uv).xyz, 1.0);
            }
            
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
