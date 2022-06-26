#ifndef PRECIPITATION_INCLUDED
#define PRECIPITATION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined (RAIN)
// creates a rotation matrix around the axis of 90 degrees
// (only needded for the second rain quad)
float4x4 rotationMatrix90(float3 axis) {    
    float ocxy = axis.x * axis.y;
    float oczx = axis.z * axis.x;
    float ocyz = axis.y * axis.z;
    return float4x4(
        axis.x * axis.x, ocxy - axis.z, oczx + axis.y, 0.0,
        ocxy + axis.z, axis.y * axis.y, ocyz - axis.x, 0.0,
        oczx - axis.y, ocyz + axis.x, axis.z * axis.z, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}
#endif

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

#define VERTEX_THRESHOLD_LEVELS 4

float _GridSize;
float _Amount;
float _FallSpeed;

float _MaxTravelDistance;

float2 _FlutterFrequency;
float2 _FlutterSpeed;
float2 _FlutterMagnitude;

float4 _Color;
float4 _ColorVariation;
float2 _SizeRange; 

float2 _CameraRange;

float4x4 _WindRotationMatrix;

struct MeshData
{
    float4 vertex : POSITION;
    float4 uv : TEXCOORD0;
    uint instanceID : SV_InstanceID;
};

// vertex shader, just pass along the mesh data to the geometry function
MeshData vert(MeshData meshData)
{
    return meshData; 
}

// structure that goes from the geometry shader to the fragment shader
struct g2f
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0; // uv.xy, opacity, color variation amount
    UNITY_VERTEX_OUTPUT_STEREO
};

void AddVertex (inout TriangleStream<g2f> stream, float3 vertex, float2 uv, float colorVariation, float opacity)
{      
    // initialize the struct with information that will go
    // form the vertex to the fragment shader
    g2f OUT;

    // unity specific
    ZERO_INITIALIZE(g2f, OUT);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
    OUT.pos = TransformObjectToHClip(vertex);

    // transfer the uv coordinates
    OUT.uv.xy = uv;    

    // we put `opacity` and `colorVariation` in the unused uv vector elements
    // this limits the amount of attributes we need going between the vertex
    // and fragment shaders, which is good for performance
    OUT.uv.z = opacity;
    OUT.uv.w = colorVariation;

    stream.Append(OUT);
}

void CreateQuad (inout TriangleStream<g2f> stream, float3 bottomMiddle, float3 topMiddle, float3 perpDir, float colorVariation, float opacity)
{    
    AddVertex (stream, bottomMiddle - perpDir, float2(0, 0), colorVariation, opacity);
    AddVertex (stream, bottomMiddle + perpDir, float2(1, 0), colorVariation, opacity);
    AddVertex (stream, topMiddle - perpDir, float2(0, 1), colorVariation, opacity);
    AddVertex (stream, topMiddle + perpDir, float2(1, 1), colorVariation, opacity);
    stream.RestartStrip();
}

/*
    this geom function actually builds the quad from each vertex in the
    mesh. so this function runs once for each "rain drop" or "snowflake"
*/
#if defined(RAIN)
[maxvertexcount(8)] // rain draws 2 quads
#else
[maxvertexcount(4)] // snow draws one quad that's billboarded towards the camera
#endif
void geom(point MeshData IN[1], inout TriangleStream<g2f> stream) {    

    MeshData meshData = IN[0];

    UNITY_SETUP_INSTANCE_ID(meshData);

    // the position of the snowflake / raindrop
    float3 pos = meshData.vertex.xyz;
    // make sure the position is spread out across the entire grid, the original vertex position
    // is normalized to a plane in the -.5 to .5 range
    pos.xz *= _GridSize;

    // samples 2 separate noise values so we get some variation
    float2 noise = float2(
        frac(SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, float2(meshData.uv.xy), 0).r + (pos.x + pos.z)), 
        frac(SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, float2(meshData.uv.yx * 2), 0).r + (pos.x * pos.z))
    );
    
    float vertexAmountThreshold = meshData.uv.z;
    // add some noise to the threshold
    vertexAmountThreshold *= noise.y;
    if (vertexAmountThreshold > _Amount)
        return;

    float3x3 windRotation = (float3x3)_WindRotationMatrix;
    // cache the offset we get from rotating the particle with the wind
    // 储存这个值是为了把旋转的 offset 重新赋予变化后的位置，使得粒子模拟起始位置处于平面上，而不是倾斜后的平面
    float3 rotatedVertexOffset = mul(windRotation, pos) - pos;
    
    // falling down movement, add 10000 to the time variable so it starts out prebaked, modify the speed by noise as well
    pos.y -= (_Time.y + 10000) * (_FallSpeed + (_FallSpeed * noise.y));

    // Add random noise while travelling based on time, some randomness, and "distance travelled"
    float2 inside = pos.y * noise.yx * _FlutterFrequency + ((_FlutterSpeed + (_FlutterSpeed * noise)) * _Time.y);
    float2 flutter = float2(sin(inside.x), cos(inside.y)) * _FlutterMagnitude;
    pos.xz += flutter;
    
    // make sure the particles loops around back to the top once it reaches the max travel distance
    pos.y = fmod(pos.y, -_MaxTravelDistance) + noise.x;

    pos = mul(windRotation, pos);
    // this rotates the entire mesh quad, so we counteract that tilt
    pos -= rotatedVertexOffset;
    
    // make sure the position originates from the top of the local grid
    pos.y += _GridSize * .5;

    float3 positionWS = TransformObjectToWorld(pos);
    float3 vectorFromCam = positionWS - GetCameraPositionWS();
    float distanceToCam = length(vectorFromCam);
    vectorFromCam /= distanceToCam; // normalization
    float3 camForwardVector = normalize(mul((float3x3)unity_CameraToWorld, float3(0,0,1)));
    // if the point position is outside of camera frustum (wrong calculation here)
    if (dot(camForwardVector, vectorFromCam) < 0.5f)
    {
        return;
    }

    float opacity = 1.0;
    
    // fade out as the amount reaches the limit for this vertex threshold
    float vertexAmountThresholdFade = min((_Amount - vertexAmountThreshold) * VERTEX_THRESHOLD_LEVELS, 1);
    opacity *= vertexAmountThresholdFade;
    
    // produces a value between 0 and 1 corresponding to where the distance to camera is within
    // the Camera Distance range (1 when at or below minimum, 0 when at or above maximum)
    // this way the particle fades out as it get's too far, and doesnt just pop out of existence
    float camDistanceInterpolation = 1.0 - min(max(distanceToCam - _CameraRange.x, 0) / (_CameraRange.y - _CameraRange.x), 1);
    opacity *= camDistanceInterpolation;
    
    if (opacity <= 0)
        return;

    // calculate the color variation based on the position, time, and some randomness
    // and multiply it by the amount the user specified (in the color variation alpha channel)
    // (from speed tree)
    float colorVariation = (sin(noise.x * (pos.x + pos.y * noise.y + pos.z + _Time.y * 2)) * .5 + .5) * _ColorVariation.a;

    // choose a size multiplier randomly
    float2 quadSize = lerp(_SizeRange.x, _SizeRange.y, noise.x);

    #if defined (RAIN)
    // rain is skinny along the x axis
    quadSize.x *= .01;
    // rain is stretched in the direction of the wind
    float3 quadUpDirection = mul(windRotation, float3(0,1,0));
    float3 topMiddle = pos + quadUpDirection * quadSize.y;
    float3 rightDirection = float3(.5 * quadSize.x, 0, 0);
    #else
    // snow is billboarded, that means the quad always faces the camera
    float3 quadUpDirection = UNITY_MATRIX_IT_MV[1].xyz; // inverse transpose of model view matrix, row 2, xyz == world space camera y axis direction
    float3 topMiddle = pos + quadUpDirection * quadSize.y;
    float3 rightDirection = UNITY_MATRIX_IT_MV[0].xyz * .5 * quadSize.x; // inverse transpose of model view matrix, row 1, xyz == world space camera x axis direction
    #endif
    
    CreateQuad (stream, pos, topMiddle, rightDirection, colorVariation, opacity);
    #if defined (RAIN)
    // rain draws 2 quads perpendicular to eachotehr
    rightDirection = mul((float3x3)rotationMatrix90(quadUpDirection), rightDirection);
    CreateQuad (stream, pos, topMiddle, rightDirection, colorVariation, opacity);
    #endif
}

float4 frag(g2f IN) : SV_Target {
    float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv.xy) * _Color;

    // add hue variation (taken from speed tree)
    float colorVariationAmount = IN.uv.w;
    float3 shiftedColor = lerp(color.rgb, _ColorVariation.rgb, colorVariationAmount);
    float maxBase = max(color.r, max(color.g, color.b));
    float newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
    // preserve vibrance
    color.rgb = saturate(shiftedColor * ((maxBase/newMaxBase) * 0.5 + 0.5));
    
    color.a *= IN.uv.z; // uv.z == opacity
    return color;
}


#endif