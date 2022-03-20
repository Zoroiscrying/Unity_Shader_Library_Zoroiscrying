Shader "PostProcess/GaussianBlur"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Render Image", 2D) = "Grey" {}
    }
    
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    
    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    float4 _MainTex_TexelSize;

    int _GaussSamples;
    real _GaussAmount;
    //bilateral blur from 
    static const real gauss_filter_weights[] = { 0.14446445, 0.13543542, 0.11153505, 0.08055309, 0.05087564, 0.02798160, 0.01332457, 0.00545096} ;         
    #define BLUR_DEPTH_FALLOFF 100.0

    real FragmentX(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif

        real col =0;
        real accumResult =0;
        real accumWeights=0;
        //depth at the current pixel
        real depthCenter;

        #if UNITY_REVERSED_Z
            depthCenter = SampleSceneDepth(uv);  
        #else
            // Adjust z to match NDC for OpenGL
            depthCenter = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif

        for (int i = -_GaussSamples; i <= _GaussSamples; i++)
        {
            float2 gaussianUV = uv + float2(i * _GaussAmount * 0.0001, 0);
            // sample the color at that location
            float kernelSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, gaussianUV).r;
            // depth at the sampled pixel
            float depthKernel;
            #if UNITY_REVERSED_Z
                depthKernel = SampleSceneDepth(gaussianUV);
            #else
                // Adjust z to match NDC for OpenGL
                depthKernel = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(gaussianUV));
            #endif
            // weight calculation depending on distance and depth difference
            float depthDiff = abs(depthKernel - depthCenter);
            float r2 = depthDiff * BLUR_DEPTH_FALLOFF;
            // greater depth difference -> less weight, so that edges won't get blurred that much
            // g is 1 only when depth difference is nearly 0, or the sample won't get count
            float g = exp(-r2*r2);
            real weight = g * gauss_filter_weights[abs(i)];
            //sum for every iteration of the color and weight of this sample 
            accumResult += weight * kernelSample;
            accumWeights += weight;
        }
        col= accumResult/accumWeights;
        return col;
    }

    real FragmentY(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif

        real col =0;
        real accumResult =0;
        real accumWeights=0;
        //depth at the current pixel
        real depthCenter;

        #if UNITY_REVERSED_Z
            depthCenter = SampleSceneDepth(uv);  
        #else
            // Adjust z to match NDC for OpenGL
            depthCenter = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif

        for (int i = -_GaussSamples; i <= _GaussSamples; i++)
        {
            float2 gaussianUV = uv + float2(0, i * _GaussAmount * 0.0001);
            // sample the color at that location
            float kernelSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, gaussianUV).r;
            // depth at the sampled pixel
            float depthKernel;
            #if UNITY_REVERSED_Z
                depthKernel = SampleSceneDepth(gaussianUV);
            #else
                // Adjust z to match NDC for OpenGL
                depthKernel = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(gaussianUV));
            #endif
            // weight calculation depending on distance and depth difference
            float depthDiff = abs(depthKernel - depthCenter);
            float r2 = depthDiff * BLUR_DEPTH_FALLOFF;
            float g = exp(-r2*r2); // greater distance / depth difference -> less weight
            real weight = g * gauss_filter_weights[abs(i)];
            //sum for every iteration of the color and weight of this sample 
            accumResult += weight * kernelSample;
            accumWeights += weight;
        }
        col= accumResult/accumWeights;
        return col;
    }
    
    ENDHLSL
    
    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Gaussian Blur X"
            HLSLPROGRAM
            
            #pragma vertex FullscreenVert
            #pragma fragment FragmentX
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Gaussian Blur Y"
            HLSLPROGRAM
            
            #pragma vertex FullscreenVert
            #pragma fragment FragmentY
            
            ENDHLSL
        }
    }
}