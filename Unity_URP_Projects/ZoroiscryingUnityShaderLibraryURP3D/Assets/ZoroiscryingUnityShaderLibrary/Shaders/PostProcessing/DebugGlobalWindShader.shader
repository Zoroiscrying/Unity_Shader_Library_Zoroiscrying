Shader "PostProcess/DebugGlobalWind"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Render Image", 2D) = "Grey" {}
    }
    
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Assets/ZoroiscryingUnityShaderLibrary/Shaders/GlobalWind3D/SampleGlobalWind3D.hlsl" // sample 3d wind texture
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

        TEXTURE2D(_MainTex);
        float4 _MainTex_TexelSize;
    
        float4 Fragment(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            uint2 positionSS = input.uv * _ScreenSize.xy; // pixel width and height of the current fragment
            uint sliceNumber = 16;
            uint2 centerXY = uint2(_ScreenSize.x / 2.0f, _ScreenSize.y * 0.8f);
            uint sliceWidth = 108;
            uint2 leftBottomBoundarySS = centerXY - half2(sliceNumber/2, 0.5f) * sliceWidth;
            uint2 rightTopBoundarySS = centerXY + half2(sliceNumber/2, 0.5f) * sliceWidth;
            
            uint2 greaterThanLeftBottomBoundary = step(leftBottomBoundarySS, positionSS); // step(a, x) == x>a -> 1, otherwise 0
            uint2 lessThanRightTopBoundary = step(positionSS, rightTopBoundarySS);
            uint2 inside = lessThanRightTopBoundary * greaterThanLeftBottomBoundary;
            uint inside2 = inside.x * inside.y;

            uint sliceDepth = (positionSS.x - leftBottomBoundarySS.x) / sliceWidth;
            half2 sliceUV = half2(
                frac((positionSS.x - leftBottomBoundarySS.x) / (half)sliceWidth),
                frac((positionSS.y - leftBottomBoundarySS.y) / (half)sliceWidth));
            half sliceBorder = step(0.99f, sliceUV.x);

            //half4 debugColor = half4(sliceUV, half(sliceDepth)/16.0h, 1);
            half4 debugColor = 0;
            float4 windParameters = RetrieveWindDirectionSpeedFragment(float3(sliceUV.x, frac(half(sliceDepth)/(half)sliceNumber), sliceUV.y));
            #if DEBUG_DIRECTION
            debugColor = half4((windParameters.xyz + 1)/2, 1);
            #elif DEBUG_SPEED
            float lerpMeter = clamp((windParameters.w - 0.1f) / (5.0f - 0.1f), 0.0 , 1.0);
            debugColor = lerp(half4(0, 1, 0, 1), half4(1, 0, 0, 1), lerpMeter);
            #endif

            debugColor = lerp(debugColor, half4(0, 0, 0, 1), sliceBorder);
            
            float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif
            
            float4 c = lerp(SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv), debugColor, inside2);
            return c;
        }
    
    ENDHLSL
    
    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Debug Global Wind"
            HLSLPROGRAM

            #pragma multi_compile DEBUG_DIRECTION DEBUG_SPEED
            #pragma vertex FullscreenVert
            #pragma fragment Fragment
            
            ENDHLSL
        }
    }
}