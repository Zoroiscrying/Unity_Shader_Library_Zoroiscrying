Shader "PostProcess/DepthNormalOutline"
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
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    float _OutlineThickness;
    float _DepthSensitivity;
    float _NormalsSensitivity;
    float _ColorSensitivity;
    half4 _OutlineColor;

    TEXTURE2D(_CameraDepthNormalsTexture);
    SAMPLER(sampler_CameraDepthNormalsTexture);
    
    TEXTURE2D(_MainTex);
    float4 _MainTex_TexelSize;

    float3 DecodeNormal(float4 enc)
    {
        float kScale = 1.7777;
        float3 nn = enc.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
        float g = 2.0 / dot(nn.xyz,nn.xyz);
        float3 n;
        n.xy = g*nn.xy;
        n.z = g-1;
        return n;
    }

    half4 DepthNormalsOutline(float2 uv)
    {
        float halfScaleFloor = floor(_OutlineThickness * 0.5);
        float halfScaleCeil = ceil(_OutlineThickness * 0.5);

        float2 texel = _MainTex_TexelSize.xy;

        float2 uvSamples[4];
        float depthSamples[4];
        float3 normalSamples[4], colorSamples[4];

        // left down corner
        uvSamples[0] = uv - texel * halfScaleFloor;
        // right up corner
        uvSamples[1] = uv + texel * halfScaleCeil;
        // right down corner
        uvSamples[2] = uv + float2(texel.x * halfScaleCeil, -texel.y * halfScaleFloor);
        // left up corner
        uvSamples[3] = uv + float2(texel.x * - halfScaleFloor, texel.y * halfScaleCeil);

        UNITY_UNROLL
        for (uint i = 0; i < 4; i++)
        {
            depthSamples[i] = SampleSceneDepth(uvSamples[i]);
            normalSamples[i] = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i]));
            colorSamples[i] = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uvSamples[i]).rgb;
        }

        // Depth
        // diagonal difference 1 & 2
        float depthDiff0 = depthSamples[1] - depthSamples[0];
        float depthDiff1 = depthSamples[3] - depthSamples[2];
        float edgeDepth = abs(depthDiff0) + abs(depthDiff1);
        float depthThreshold = 1 / _DepthSensitivity * depthSamples[0];
        //edgeDepth > depthThreshold ? 1 : 0;
        edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

        // Normals
        float3 normalDiff0 = normalSamples[1] - normalSamples[0];
        float3 normalDiff1 = normalSamples[3] - normalSamples[2];
        float edgeNormal = abs(normalDiff0) + abs(normalDiff1);
        edgeNormal = edgeNormal > (1/_NormalsSensitivity) ? 1 : 0;

        // Color
        float3 colorDiff0 = colorSamples[1] - colorSamples[0];
        float3 colorDiff1 = colorSamples[3] - colorSamples[2];
        float edgeColor = abs(colorDiff0) + abs(colorDiff1);
        edgeColor = edgeColor > (1/_ColorSensitivity) ? 1 : 0;

        float edge = max(edgeDepth, max(edgeNormal, edgeColor));
        //edge = edgeNormal;

        half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, uv);
        return lerp(c, lerp(c, _OutlineColor, _OutlineColor.a), edge);
    }
     
    float4 Fragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;   
            }
#endif
        
        float4 c = DepthNormalsOutline(uv);
        
        float3 rgb = c.rgb;

        c.rgb = rgb;
        
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