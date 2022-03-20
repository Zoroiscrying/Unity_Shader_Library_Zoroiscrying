Shader "PostProcess/ImageBasedOutline"
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

    TEXTURE2D(_MainTex);
    float4 _MainTex_TexelSize;

    half _EdgeOpacity;
    half4 _EdgeColor;

    struct OutlineVaryings
    {
        float4 positionCS : SV_POSITION;
        half2 uv[9]         : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    OutlineVaryings Vertex(Attributes input)
    {
        OutlineVaryings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        half2 uv = input.uv;
        
        output.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
        output.uv[1] = uv + _MainTex_TexelSize.xy * half2( 0, -1);
        output.uv[2] = uv + _MainTex_TexelSize.xy * half2( 1, -1);
        output.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1,  0);
        output.uv[4] = uv + _MainTex_TexelSize.xy * half2( 0,  0);
        output.uv[5] = uv + _MainTex_TexelSize.xy * half2( 1,  0);
        output.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1,  1);
        output.uv[7] = uv + _MainTex_TexelSize.xy * half2( 0,  1);
        output.uv[8] = uv + _MainTex_TexelSize.xy * half2( 1,  1);

        return output;
    }

    // Sobel operator, if edgeX + edgeY > 0, then it is count as edge (can change the threshold)
    half Sobel(OutlineVaryings input)
    {
        const half weightX[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
        const half weightY[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};
        half luminance;
        half edgeX = 0;
        half edgeY = 0;

        uint i = 0;
        
        UNITY_UNROLL
        for (i = 0; i < 9; i++)
        {
#if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            {
                input.uv[i].y = 1 - input.uv[i].y;   
            }
#endif
            luminance = Luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, input.uv[i]));
            edgeX += luminance * weightX[i];
            edgeY += luminance * weightY[i];
        }
        half edge = 1 - abs(edgeX) - abs(edgeY);
        return edge;
    }
    
    float4 Fragment(OutlineVaryings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        half edge = Sobel(input);
        float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, input.uv[4]);
        
        half4 edgeColor = lerp(_EdgeColor, c, edge);
        edgeColor = lerp(c, edgeColor, _EdgeOpacity);
        
        float3 rgb = edgeColor.rgb;
        c.rgb = rgb;
        
        return c;
    }
    
    ENDHLSL
    
    SubShader
    {

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Image Based Outline"
            HLSLPROGRAM

            #pragma vertex Vertex
            #pragma fragment Fragment
            
            ENDHLSL
        }
    }
}