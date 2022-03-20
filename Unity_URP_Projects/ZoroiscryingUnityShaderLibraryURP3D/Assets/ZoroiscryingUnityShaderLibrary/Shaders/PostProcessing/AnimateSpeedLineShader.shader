Shader "PostProcess/AnimateSpeedLine"
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
    #include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/FractalBrownianMotion.hlsl"

    half4 _SpeedLineColor;
    float _SpeedLineTilling;
    float _SpeedLineRadialScale;
    float _SpeedLinePower;
    float _SpeedLineStart;
    float _SpeedLineEnd;
    float _SpeedLineSmoothness;
    float _SpeedLineAnimation;

    float _MaskScale;
    float _MaskHardness;
    float _MaskPower;

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

        float2 centerUV = uv - 0.5;
        float2 radialUV = float2(
            length(centerUV) * _SpeedLineRadialScale * 2.0,
            FastAtan2(centerUV.y, centerUV.x) * (0.15915493866) * _SpeedLineTilling);
        // 0 to 1 noise value
        float noiseValue = simplex_noise12(radialUV + float2(_Time.y * _SpeedLineAnimation, 0.0));
        float speedLine = saturate( smoothstep(_SpeedLineStart - _SpeedLineSmoothness, _SpeedLineStart + _SpeedLineSmoothness, pow(noiseValue, _SpeedLinePower))
                        - smoothstep(_SpeedLineEnd - _SpeedLineSmoothness, _SpeedLineEnd + _SpeedLineSmoothness, pow(noiseValue, _SpeedLinePower)));
        
        float2 anotherUV = centerUV * 2;
        float maskValue = lerp(0, _MaskScale, _MaskHardness);
        maskValue = pow(saturate((length(anotherUV) - _MaskScale)/(maskValue - 0.001) - _MaskScale), _MaskPower);

        speedLine *= maskValue;
        
        float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv);
        
        float3 rgb = lerp(c.rgb, _SpeedLineColor, speedLine);

        c.rgb = rgb;
        
        return c;
    }
    
    ENDHLSL
    
    SubShader
    {

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Animate Speed Line"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment Fragment
            
            ENDHLSL
        }
    }
}