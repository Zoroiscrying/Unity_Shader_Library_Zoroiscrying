Shader "PostProcess/Utility"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Render Image", 2D) = "Grey" {}
    }
    
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        
        float4 _FadeColor;
        float _HueShift;
        float _Invert;
        float _Saturation;
        TEXTURE2D_X(_InputTexture);

        TEXTURE2D(_MainTex);
        float4 _MainTex_TexelSize;
    
        float4 Fragment(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //uint2 positionSS = input.uv * _ScreenSize.xy;
            //float4 c = LOAD_TEXTURE2D_X(_InputTexture, positionSS);

            float2 uv = input.uv;

#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif
            
            float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv);
            
            float3 rgb = c.rgb;

            // Saturation
            rgb = max(0, lerp(Luminance(rgb), rgb, _Saturation));

            // Linear -> sRGB
            rgb = LinearToSRGB(rgb);

            // Hue shift
            float3 hsv = RgbToHsv(rgb);
            hsv.x = frac(hsv.x + _HueShift);
            rgb = HsvToRgb(hsv);

            // Invert
            rgb = lerp(rgb, 1 - rgb, _Invert);

            // Fade
            rgb = lerp(rgb, _FadeColor.rgb, _FadeColor.a);

            // sRGB -> Linear
            c.rgb = SRGBToLinear(rgb);
            return c;
        }
    
    ENDHLSL
    
    SubShader
    {

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Utility"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment Fragment
            
            ENDHLSL
        }
    }
}