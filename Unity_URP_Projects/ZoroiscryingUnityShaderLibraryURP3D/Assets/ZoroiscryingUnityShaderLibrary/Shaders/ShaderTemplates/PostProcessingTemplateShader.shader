Shader "PostProcess/PostProcessingTemplateShader"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
    }
    
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    ENDHLSL
    
    SubShader
    {
        Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            Name "Invert Color"
            
            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment frag

            TEXTURE2D_X(_InputTexture);
            
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
            float4 _MainTex_ST;
            CBUFFER_END

            half4 frag (Varyings i) : SV_Target
            {
                float2 uv = i.uv;
    #if UNITY_UV_STARTS_AT_TOP
                uv.y = 1 - uv.y;
    #endif
                
                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                float3 rgb = c.rgb;
                rgb = LinearToSRGB(rgb);

                rgb = 1-rgb;
                
                c.rgb = SRGBToLinear(rgb);
                return c;
            }
            ENDHLSL
        }
    }
}