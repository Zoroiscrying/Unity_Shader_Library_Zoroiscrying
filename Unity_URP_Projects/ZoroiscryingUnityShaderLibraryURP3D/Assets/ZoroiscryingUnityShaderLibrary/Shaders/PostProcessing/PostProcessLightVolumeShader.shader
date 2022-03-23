Shader "PostProcess/PostProcessLightVolume"
{
    // Based on the implementation from 
    // https://developer.nvidia.com/gpugems/gpugems3/part-ii-light-and-shadows/chapter-13-volumetric-light-scattering-post-process
    Properties
    {
        [NoScaleOffset] _MainTex ("Render Image", 2D) = "Grey" {}
    }
    
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/FractalBrownianMotion.hlsl"
    
    float4 _LightColor;
    float _Density;
    float _Exposure;
    float _Weight;
    float _Decay;
    
    float4 _MainLightDirectionWS;
    float4 _MainLightPositionSS;

    TEXTURE2D(_MainTex);
    float4 _MainTex_TexelSize;

    TEXTURE2D(_BackgroundOccluded);

    #define NUM_SAMPLES 32

    float FragmentRaymarch(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float2 uv = input.uv;
        float2 lightPositionSS = _MainLightPositionSS.xy;
        float2 randomOffset = random12(uv) * 0.01;
        uv += randomOffset;

#if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0)
        {
            uv.y = 1 - uv.y;
        }
#endif

        //lightPositionSS.y = 1 - lightPositionSS.y;
        // Calculate vector from pixel to light source in screen space.
        half2 deltaUV = lightPositionSS - uv;
        half2 deltaUVDirection = normalize(deltaUV);
        half deltaUVLength = length(deltaUV) + 1;
        deltaUV = clamp(deltaUV, half2(0,0), half2(1,1));
        deltaUV *= 1.0f / NUM_SAMPLES * _Density / deltaUVLength;

        // Set up illumination decay factor.
        half illuminationDecay = 1.0f;

        float lightShaft = 0;

        // Evaluate summation from Equation 3 NUM_SAMPLES iterations.
        UNITY_UNROLL
        for (int i = 0; i < NUM_SAMPLES; i++)
        {
            // Step sample location along ray.
            uv += deltaUV;
            // Retrieve sample at new location.
            float sample = SAMPLE_TEXTURE2D(_BackgroundOccluded, sampler_LinearClamp, uv).r;
            // Apply sample attenuation scale/decay factors.
            sample *= illuminationDecay * _Weight;
            // Accumulate combined color.
            lightShaft += sample;
            // Update exponential decay factor.
            illuminationDecay *= _Decay;
        }
        
        //return depth;
        // Output final color with a further scale control factor.
        return lightShaft;
    }

    float FragmentDepthOcclusion(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0)
        {
            uv.y = 1 - uv.y;   
        }
#endif

        float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv);
        float luminance = Luminance(c);
        
        #if UNITY_REVERSED_Z
            real depth = SampleSceneDepth(uv);
        #else
            // Adjust z to match NDC for OpenGL
            real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif

        float occlusionFilter = step(0.99999999f, 1 - depth);
        
        //return depth;
        // Output final color with a further scale control factor.
        return occlusionFilter * luminance;
    }

    float FragmentDepth(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif

        #if UNITY_REVERSED_Z
            float depth = SampleSceneDepth(uv);
        #else
            // Adjust z to match NDC for OpenGL
            float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif
        
        return depth;
    }
    
    TEXTURE2D(_VolumetricLightTexture);
    SAMPLER(sampler_VolumetricLightTexture);
    TEXTURE2D(_LowResDepth);
    SAMPLER(sampler_LowResDepth);
    
    real3 FragmentComposite(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif

        real col = 0;

        int offset = 0;
        real d0;
        #if UNITY_REVERSED_Z
            d0 = SampleSceneDepth(uv);
        #else
            // Adjust z to match NDC for OpenGL
            d0 = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif

        /* calculating the distances between the depths of the pixels
        * in the low-res neighborhood and the full res depth value
        * (texture offset must be compile time constant and so we
        * can't use a loop)
        */
        //depth in the adjacent lower res pixels
        real d1 = _LowResDepth.Sample(sampler_LowResDepth, uv, int2(0, 1)).x;
        real d2 = _LowResDepth.Sample(sampler_LowResDepth, uv, int2(0, -1)).x;
        real d3 =_LowResDepth.Sample(sampler_LowResDepth, uv, int2(1, 0)).x;
        real d4 = _LowResDepth.Sample(sampler_LowResDepth, uv, int2(-1, 0)).x;

        //difference between the two values
        d1 = abs(d0 - d1);
        d2 = abs(d0 - d2);
        d3 = abs(d0 - d3);
        d4 = abs(d0 - d4);

        // choosing the closer one in depth, less depth difference between high res center depth and low res border depth
        // => 
        real dmin = min(min(d1, d2), min(d3, d4));

        if (dmin == d1)
            offset= 0;
        else if (dmin == d2)
            offset= 1;
        else if (dmin == d3)
            offset= 2;
        else  if (dmin == d4)
            offset= 3;
        else offset = 4;

        // sampling the chosen fragment
        switch(offset){
            case 0:
                col = _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv, int2(0, 1)).x;
                break;
            case 1:
                col = _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv, int2(0, -1)).x;
                break;
            case 2:
                col = _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv, int2(1, 0)).x;
                break;
            case 3:
                col = _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv, int2(-1, 0)).x;
                break;
            case 4:
                col = _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv, int2(0, 0)).x;
                break;
            default:
                col =  _VolumetricLightTexture.Sample(sampler_VolumetricLightTexture, uv);
                break;
        }
        //col =  _volumetricTexture.Sample(sampler_volumetricTexture, uv);
        
        //color our rays and multiply by the intensity
        real screenSpaceLightDot = saturate(1 - dot(UNITY_MATRIX_IT_MV[2].xyz, _MainLightDirectionWS));
        real3 finalShaft =(saturate(col)*_Exposure * screenSpaceLightDot)* normalize (_LightColor);
        real3 screen = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv).rgb;
        
        //regular sum (linear dodge/additive)
        //return finalShaft;
        return screen + finalShaft;
    }
    
    ENDHLSL
    
    SubShader
    {

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Post Process Light Volume"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment FragmentRaymarch
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Post Process Depth Occlusion"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment FragmentDepthOcclusion
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Post Process Down Sample Depth"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment FragmentDepth
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Post Process Light Volume Composite"
            HLSLPROGRAM

            #pragma vertex FullscreenVert
            #pragma fragment FragmentComposite
            
            ENDHLSL
        }
    }
}