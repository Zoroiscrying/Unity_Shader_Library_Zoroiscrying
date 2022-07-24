Shader "Skybox/SkyShader"
{
    Properties
    {
        [Header(Sky color)]
        [HDR]_ColorTop("Color top", Color) = (1,1,1,1)
        [HDR]_ColorMiddle("Color middle", Color) = (1,1,1,1)
        [HDR]_ColorBottom("Color bottom", Color) = (1,1,1,1)

        _MiddleSmoothness("Middle smoothness", Range(0.0,1.0)) = 1
        _MiddleOffset("Middle offset", float) = 0
        _TopSmoothness("Top smoothness", Range(0.0, 1.0)) = 1
        _TopOffset("Top offset", float) = 0

        [Header(Sun)]
        _SunSize("Sun size", Range(0.0, 1.0)) = 0.1
        [HDR]_SunColor("Sun color", Color) = (1,1,1,1)

        [Header(Moon)]
        _MoonSize("Moon size", Range(0,1)) = 0
        [HDR]_MoonColor("Moon color", Color) = (1,1,1,1)
        _MoonPhase("Moon phase", Range(0,1)) = 0
        
        [Header(Stars)]
        _Stars("Stars", 2D) = "black" {}
        _StarsIntensity("Stars intensity", float) = 0

        [Header(Clouds)]
        [HDR]_CloudsColor("Clouds color", Color) = (1,1,1,1)
        _CloudsTexture("Clouds texture", 2D) = "black" {}
        _CloudsThreshold("Clouds threshold", Range(0.0, 1.0)) = 0
        _CloudsSmoothness("Clouds smoothness", Range(0.0, 1.0)) = 0.1
        _SunCloudIntensity("Sun behind clouds intensity", Range(0, 1)) = 0
        _PanningSpeedX("Panning speed X", float) = 0
        _PanningSpeedY("Panning speed Y", float) = 0

    }
    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" "PreviewType"="Quad"}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            fixed4 _ColorBottom;
            fixed4 _ColorMiddle;
            fixed4 _ColorTop;

            float _MiddleSmoothness;
            float _MiddleOffset;
            float _TopSmoothness;
            float _TopOffset;

            fixed4 _SunColor;
            float _SunSize;

            float _MoonSize;
            fixed4 _MoonColor;
            float _MoonPhase;

            sampler2D _Stars;
            float4 _Stars_ST;
            float _StarsIntensity;

            sampler2D _CloudsTexture;
            float4 _CloudsTexture_ST;
            fixed4 _CloudsColor;
            float _CloudsSmoothness;
            float _CloudsThreshold;
            float _SunCloudIntensity;
            float _PanningSpeedX;
            float _PanningSpeedY;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = float2(atan2(i.uv.x,i.uv.z) / UNITY_TWO_PI, asin(i.uv.y) / UNITY_HALF_PI);
                float middleThreshold = smoothstep(0.0, 0.5 - (1.0 - _MiddleSmoothness) / 2.0, i.uv.y - _MiddleOffset);
                float topThreshold = smoothstep(0.5, 1.0 - (1.0 - _TopSmoothness) / 2.0 , i.uv.y - _TopOffset);
                fixed4 col = lerp(_ColorBottom, _ColorMiddle, middleThreshold);
                col = lerp(col, _ColorTop, topThreshold);

                float cloudsThreshold = i.uv.y - _CloudsThreshold;
                float cloudsTex = tex2D(_CloudsTexture, uv * _CloudsTexture_ST.xy + _CloudsTexture_ST.zw + float2(_PanningSpeedX, _PanningSpeedY) * _Time.y);
                float clouds = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex);

                float stars = tex2D(_Stars, (i.uv.xz / i.uv.y) * _Stars_ST.xy) * _StarsIntensity * saturate(-_WorldSpaceLightPos0.y) * (1.0 - clouds);
                stars *= smoothstep(0.5, 1.0 , i.uv.y);

                float sunSDF = distance(i.uv.xyz, _WorldSpaceLightPos0);
                float sun = max(clouds * _CloudsColor.a, smoothstep(0, _SunSize, sunSDF));

                float moonSDF = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                float moonPhaseSDF = distance(i.uv.xyz - float3(0.0, 0.0, 0.1) * _MoonPhase, -_WorldSpaceLightPos0);
                float moon = step(moonSDF, _MoonSize);
                moon -= step(moonPhaseSDF, _MoonSize);
                moon = saturate(moon * -_WorldSpaceLightPos0.y - clouds);
                
                float cloudShading = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness + 0.1, cloudsTex) -
                                     smoothstep(cloudsThreshold + _CloudsSmoothness + 0.1, cloudsThreshold + _CloudsSmoothness + 0.4, cloudsTex);
                clouds = lerp(clouds, cloudShading, 0.5) * middleThreshold * _CloudsColor.a;

                float silverLining = (smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex)
                                    - smoothstep(cloudsThreshold + 0.02, cloudsThreshold + _CloudsSmoothness + 0.02, cloudsTex));
                silverLining *=  smoothstep(_SunSize * 3.0, 0.0, sunSDF) * _CloudsColor.a;


                col = lerp(_SunColor, col, sun);
                return col;
                fixed4 cloudsCol = lerp(_CloudsColor, _CloudsColor + _SunColor, cloudShading * smoothstep(0.3, 0.0, sunSDF) * _SunCloudIntensity);
                col = lerp(col, cloudsCol, clouds);
                col += silverLining * _SunColor;
                col = lerp(col, _MoonColor, moon);
                col += stars;
                
                return col;
            }
            ENDCG
        }
    }
}
