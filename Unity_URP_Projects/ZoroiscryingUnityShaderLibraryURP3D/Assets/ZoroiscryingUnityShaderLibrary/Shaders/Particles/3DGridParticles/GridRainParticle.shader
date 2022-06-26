Shader "Hidden/Environment/GridRainParticle"
{
    Properties
    { }
    SubShader
    {
        Tags 
        {           
            "RenderPipeline" = "UniversalPipeline"   
            "Queue" = "Transparent" 
            "RenderType" = "Transparent" 
            "IgnoreProjector" = "True"  
        }
        LOD 100
        CULL FRONT
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            Name "Grid Particle Rain"
            Tags{"LightMode" = "UniversalForward"}
            
            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma target 4.0
            #define RAIN

            #include "Precipitation.hlsl"
            
            ENDHLSL
        }
    }
}
