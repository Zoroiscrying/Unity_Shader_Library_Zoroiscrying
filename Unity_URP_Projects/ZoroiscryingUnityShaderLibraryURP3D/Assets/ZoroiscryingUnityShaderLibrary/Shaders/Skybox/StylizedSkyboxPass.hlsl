#ifndef BASIC_STYLIZED_SKYBOX_PASS_INCLUDED
#define BASIC_STYLIZED_SKYBOX_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/CustomNoise.hlsl"

Varyings SkyboxPassVertex (Attributes input)
{
    Varyings output;
    ZERO_INITIALIZE(Varyings, output)
    
    output.positionVS = TransformObjectToHClip(input.positionOS);
    output.uv = input.uv;
    return output;
}

half4 SkyboxPassFragment (Varyings input) : SV_Target
{
    // https://medium.com/@jannik_boysen/procedural-skybox-shader-137f6b0cb77c
    // Spherical UV, the U circle around the XZ plane, the V circle around the XY / ZY plane, reach -1 & 1 at bot & top
    float2 uv = float2(atan2(input.uv.x, input.uv.z) / TWO_PI, asin(input.uv.y) / HALF_PI) + float2(_SkyBoxRotX, 0);

    // mid - 0.0 -> 0.5
    float middleThreshold = smoothstep(0.0, 0.5 - (1.0 - _MiddleSmoothness) / 2.0, input.uv.y - _MiddleOffset);
    // top - 0.5 -> 1.0
    float topThreshold = smoothstep(0.5, 1.0 - (1.0 - _TopSmoothness) / 2.0 , input.uv.y - _TopOffset);
    half4 col = lerp(_ColorBottom, _ColorMiddle, middleThreshold);
    col = lerp(col, _ColorTop, topThreshold);

    // --- Cloud ---
    float cloudsThreshold = input.uv.y - _CloudsThreshold;
    float cloudsTex = SAMPLE_TEXTURE2D(_CloudsTexture, sampler_CloudsTexture, uv * _CloudsTexture_ST.xy + _CloudsTexture_ST.zw + float2(_PanningSpeedX, _PanningSpeedY) * _Time.y);
    float clouds = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex); // clouds tex = opacity

    // --- Star ---
    #ifdef _STAR_TYPE_TEXTURE
    float star_tex = SAMPLE_TEXTURE2D(_Stars, sampler_Stars, (input.uv.xz / input.uv.y) * _Stars_ST.xy).x;
    float stars = step(0.5, star_tex) * _StarsIntensity * (saturate(-_MainLightPosition.y) + _StarIntensityBase) * (1.0 - clouds);
    #elif _STAR_TYPE_NOISE
    float2 plane_uv = (input.uv.xz / input.uv.y);
    float3 stars_noise = normalize((SAMPLE_TEXTURE2D(_Stars, sampler_Stars, uv * _Stars_ST.xy + float2(_SkyBoxRotX, 0)).xyz + spherical_noise33(input.uv.xyz * 100 * _Stars_ST.x/10 + float3(_SkyBoxRotX, 0, 0))/2 + 0.5) - 1);
    stars_noise = normalize(SAMPLE_TEXTURE2D(_Stars, sampler_Stars, uv * _Stars_ST.xy).xyz - ((spherical_noise33(input.uv.xyz * 100 * _Stars_ST.x/10 + float3(_SkyBoxRotX, 0, 0)))+1)/2);
    stars_noise = SAMPLE_TEXTURE2D(_Stars, sampler_Stars, uv * _Stars_ST.xy).xyz;
    stars_noise = spherical_noise33(input.uv.xyz * float3(200, 200, 200) + float3(_SkyBoxRotX, 0, 0));
    stars_noise = simplex_noise12(uv * float2(314, 100) * 1.5);
    float stars = saturate(step(0.75, saturate(dot(stars_noise, input.uv.xyz)))) * _StarsIntensity * (saturate(-_MainLightPosition.y) + _StarIntensityBase) * (1.0 - clouds);
    stars = saturate(step(0.75, stars_noise)) * _StarsIntensity * (saturate(-_MainLightPosition.y) + _StarIntensityBase) * (1.0 - clouds);;
    #endif
    stars *= pow(smoothstep(_StarAppearPos, 1.0 , uv.y), _StarPosPower); // only appear at the top part

    // --- Sun ---
    // SDF pointing at the sun's direction 
    float sunSDF = distance(input.uv.xyz, _MainLightPosition); // unit sphere distance (max is 2)
    #ifdef _SUN_TYPE_A
    float sun = max(clouds * _CloudsColor.a, smoothstep(0, sunSDF, _SunSize)); // the sun can affect cloud color
    #elif _SUN_TYPE_B
    float sun = max(clouds * _CloudsColor.a, 1 - smoothstep(0, _SunSize, sunSDF)); // this creates a more crispy look
    #else
    float sun = max(clouds * _CloudsColor.a, 1 - smoothstep(0, _SunSize, sunSDF));
    #endif

    // --- Moon --- 
    // SDF pointing at the negative sun's direction
    float moonSDF = distance(input.uv.xyz, -_MainLightPosition);
    float moonPhaseSDF = distance(input.uv.xyz - float3(0.0, 0.0, 0.1) * _MoonPhase, -_MainLightPosition);
    float moon = step(moonSDF, _MoonSize);
    moon -= step(moonPhaseSDF, _MoonSize);
    moon = saturate(moon * -_MainLightPosition.y - clouds * 0.5f); // the cloud will cover moon's light

    // --- Cloud Detail --- 
    // creates a smooth transition for the clouds
    float cloudSmooth = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness + 0.1, cloudsTex) -
                         smoothstep(cloudsThreshold + _CloudsSmoothness + 0.1, cloudsThreshold + _CloudsSmoothness + 0.4, cloudsTex);
    clouds = lerp(clouds, cloudSmooth, 0.5) * middleThreshold * _CloudsColor.a;

    // creates a outline around clouds (clouds threshold -> clouds threshold + clouds smoothness)
    float silverLining = (smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex)
                        - smoothstep(cloudsThreshold + 0.02, cloudsThreshold + _CloudsSmoothness + 0.02, cloudsTex));
    silverLining *=  smoothstep(_SunSize * 3.0, 0.0, sunSDF) * _CloudsColor.a;

    // --- COMPOSITING --- 
    col = lerp(col, _SunColor, sun);
    // this creates the color of the clouds ahead of the sun
    half4 cloudsCol = lerp(_CloudsColor, _CloudsColor * _SunColor, cloudSmooth * smoothstep(0.0, 0.3, sunSDF) * _SunCloudIntensity);
    col = lerp(col, cloudsCol, clouds);
    col += silverLining * _SunColor;
    col = lerp(col, _MoonColor, moon);
    col += stars;
    //stars_noise = length(stars_noise) - 1;
    //stars_noise = normalize(spherical_noise33(input.uv.xyz * 100 * _Stars_ST.x/10 + float3(_SkyBoxRotX, 0, 0)));
    //stars_noise = SAMPLE_TEXTURE2D(_Stars, sampler_Stars, uv * _Stars_ST.xy + float2(_SkyBoxRotX, 0)).xyz;
    //return half4(uv.x, uv.y, 0, 1);
    //return half4(stars_noise, 1);
    //return half4(input.uv.xyz, 1);
    return col;
}

#endif
