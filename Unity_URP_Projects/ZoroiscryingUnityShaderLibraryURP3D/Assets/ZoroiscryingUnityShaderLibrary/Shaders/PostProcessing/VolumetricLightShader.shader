Shader "PostProcess/VolumetricLight"
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
    #include "Assets/ZoroiscryingUnityShaderLibrary/ShaderLibrary/Mapping/Math.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    
    
    TEXTURE2D(_MainTex);
    float4 _MainTex_TexelSize;

    float3 _MainLightDirectionWS;

    //We will set up these uniforms from the ScriptableRendererFeature in the future
    real _Scattering;
    real _Steps;
    real _MaxDistance;
    real _JitterVolumetric;
    real _Intensity;

    //This function will tell us if a certain point in world space coordinates is in light or shadow of the main light
    real ShadowAtten(real3 worldPosition)
    {
        return MainLightRealtimeShadow(TransformWorldToShadowCoord(worldPosition));
    }

    //Unity already has a function that can reconstruct world space position from depth
    real3 GetWorldPos(real2 uv){
        #if UNITY_REVERSED_Z
            real depth = SampleSceneDepth(uv);
        #else
            // Adjust z to match NDC for OpenGL
            real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
        #endif
        return ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
    }

    // Mie scattering approximated with Henyey-Greenstein phase function.
    real ComputeScattering(real lightDotView)
    {
        // product num - 6
        // divide num - 1
        // add minus num - 3 
        real result = 1.0f - _Scattering * _Scattering;
        result /= (4.0f * PI * pow(1.0f + _Scattering * _Scattering - (2.0f * _Scattering) * lightDotView, 1.5f));
        return max(0, result);
    }
    
    //this implementation is loosely based on http://www.alexandre-pestana.com/volumetric-lights/ 
    //and https://fr.slideshare.net/BenjaminGlatzel/volumetric-lighting-for-many-lights-in-lords-of-the-fallen
    real Fragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif

        real3 positionWS = GetWorldPos(uv);

        // ray marching process
        float3 startPositionWS = _WorldSpaceCameraPos;
        float3 rayVector = positionWS - startPositionWS;
        float3 rayDirection = SafeNormalize(rayVector);
        float rayLength = length(rayVector);

        // clamp the ray march to the max distance
        if (rayLength > _MaxDistance)
        {
            rayLength = _MaxDistance;
            positionWS = startPositionWS + rayDirection * rayLength;
        }

        // limit the amount of steps for close objects (may break parallelism)
        // steps= remap(0,_MaxDistance,MIN_STEPS,_Steps,rayLength);  
        //or
        // steps= remap(0,_MaxDistance,0,_Steps,rayLength);   
        // steps = max(steps,MIN_STEPS);

        float stepLength = rayLength / _Steps;
        float3 step = rayDirection * stepLength;

        // randomized ray starting position to reduce artifacts
        float rayStartOffset = random12(uv) * stepLength * _JitterVolumetric * 0.01;
        float3 currentPosition = startPositionWS + rayStartOffset * rayDirection;
        float accumFog = 0;
        
        for (int j = 0; j < _Steps; j++)
        {
            float shadowAttneuation = ShadowAtten(currentPosition);

            // if it is in light
            if (shadowAttneuation > 0)
            {
                float kernelColor = ComputeScattering(dot(rayDirection, _MainLightDirectionWS));
                accumFog += kernelColor;
            }
            currentPosition += step;
        }

        accumFog /= _Steps;
        
        return accumFog;
    }

    real FragmentDepth(Varyings input) : SV_Target
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
            real depth = SampleSceneDepth(uv);
        #else
            // Adjust z to match NDC for OpenGL
            real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
        #endif
        
        return depth;
    }
    
    TEXTURE2D(_volumetricTexture);
    SAMPLER(sampler_volumetricTexture);
    TEXTURE2D(_LowResDepth);
    SAMPLER(sampler_LowResDepth);
    real4 _SunMoonColor;
    //real _Intensity;

    // //based on https://eleni.mutantstargoat.com/hikiko/on-depth-aware-upsampling/ 
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
                col = _volumetricTexture.Sample(sampler_volumetricTexture, uv, int2(0, 1)).x;
                break;
            case 1:
                col = _volumetricTexture.Sample(sampler_volumetricTexture, uv, int2(0, -1)).x;
                break;
            case 2:
                col = _volumetricTexture.Sample(sampler_volumetricTexture, uv, int2(1, 0)).x;
                break;
            case 3:
                col = _volumetricTexture.Sample(sampler_volumetricTexture, uv, int2(-1, 0)).x;
                break;
            case 4:
                col = _volumetricTexture.Sample(sampler_volumetricTexture, uv, int2(0, 0)).x;
                break;
            default:
                col =  _volumetricTexture.Sample(sampler_volumetricTexture, uv);
                break;
        }
        //col =  _volumetricTexture.Sample(sampler_volumetricTexture, uv);
        
        //color our rays and multiply by the intensity
        _SunMoonColor = half4(1,1,1,1);
        real3 finalShaft =(saturate(col)*_Intensity)* normalize (_SunMoonColor);
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
            Name "Volumetric Light"
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma multi_compile _  _MAIN_LIGHT_SHADOWS_CASCADE
            
            #pragma vertex FullscreenVert
            #pragma fragment Fragment
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Sample Depth"
            HLSLPROGRAM
            
            #pragma vertex FullscreenVert
            #pragma fragment FragmentDepth
            
            ENDHLSL
        }
        
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Compositing"
            HLSLPROGRAM
            
            #pragma vertex FullscreenVert
            #pragma fragment FragmentComposite
            
            ENDHLSL
        }
    }
}