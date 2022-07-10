#ifndef TESSELLATION_UTILITY_INCLUDED
#define TESSELLATION_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// ---- Structs
struct TessellationFactors 
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

// ---- utility functions
// Get the distance from the vertex to the camera, remap to 0.01-1.0, and then multiplied with tess factor
float UnityCalcDistanceTessFactor (float4 positionOS, float minDist, float maxDist, float tess)
{
    float3 wpos = TransformObjectToWorld(positionOS.xyz);
    float dist = distance (wpos, _WorldSpaceCameraPos);
    // clamp 0.01 - 1 before
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
    return f;
}

// Get the distance from the vertex to the camera, remap to 0.01-1.0, and then multiplied with tess factor
float UnityCalcDistanceTessFactor_WS (float3 positionWS, float minDist, float maxDist, float tess)
{
    float3 wpos = positionWS.xyz;
    float dist = distance (wpos, _WorldSpaceCameraPos);
    // clamp 0.01 - 1 before
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
    return f;
}

// Calculates tessellation factors based on triangle vertex factors
TessellationFactors UnityCalcTriEdgeTessFactors (float3 triVertexFactors)
{
    TessellationFactors f;
    f.edge[0] = 0.5 * (triVertexFactors.y + triVertexFactors.z);
    f.edge[1] = 0.5 * (triVertexFactors.x + triVertexFactors.z);
    f.edge[2] = 0.5 * (triVertexFactors.x + triVertexFactors.y);
    f.inside  = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
    return f;
}

// 
float UnityCalcEdgeTessFactor (float3 wpos0, float3 wpos1, float edgeLen)
{
    // camera distance to edge center
    float dist = distance (0.5 * (wpos0 + wpos1), _WorldSpaceCameraPos);
    // length of the edge
    float len = distance(wpos0, wpos1);
    // edgeLen is approximate desired size in pixels
    float f = max(len * _ScreenParams.y / (edgeLen * dist), 1.0);
    return f;
}

// Plane -> (xyz(normal vector), w(length to world point 000))
float UnityDistanceFromPlane (float3 pos, float4 plane)
{
    float d = dot (float4(pos, 1.0f), plane);
    return d;
}

// Returns true if triangle with given 3 world positions is outside of camera's view frustum.
// cullEps is distance outside of frustum that is still considered to be inside (i.e. max displacement)
bool UnityWorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps)
{
    float4 planeTest;

    // left
    planeTest.x = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f );
    // right
    planeTest.y = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f );
    // top
    planeTest.z = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f );
    // bottom
    planeTest.w = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f );

    // has to pass all 4 plane tests to be visible
    return !all (planeTest);
}



// ---- functions that compute tessellation factors



// Distance based tessellation:
// Tessellation level is "tess" before "minDist" from camera, and linearly decreases to '0.01 * tess'
// up to "maxDist" from camera.
TessellationFactors UnityDistanceBasedTess (float4 v0, float4 v1, float4 v2, float minDist, float maxDist, float tess)
{
    float3 f;
    f.x = UnityCalcDistanceTessFactor (v0,minDist,maxDist,tess);
    f.y = UnityCalcDistanceTessFactor (v1,minDist,maxDist,tess);
    f.z = UnityCalcDistanceTessFactor (v2,minDist,maxDist,tess);

    return UnityCalcTriEdgeTessFactors (f);
}

TessellationFactors UnityDistanceBasedTess_WS (float3 v0, float3 v1, float3 v2, float minDist, float maxDist, float tess)
{
    float3 f;
    f.x = UnityCalcDistanceTessFactor_WS (v0,minDist,maxDist,tess);
    f.y = UnityCalcDistanceTessFactor_WS (v1,minDist,maxDist,tess);
    f.z = UnityCalcDistanceTessFactor_WS (v2,minDist,maxDist,tess);

    return UnityCalcTriEdgeTessFactors (f);
}

// Desired edge length based tessellation:
// Approximate resulting edge length in pixels is "edgeLength".
// Does not take viewing FOV into account, just flat out divides factor by distance.
TessellationFactors UnityEdgeLengthBasedTess (float4 v0, float4 v1, float4 v2, float edgeLength)
{
    TessellationFactors f;
    float3 pos0 = TransformObjectToWorld(v0.xyz).xyz;
    float3 pos1 = TransformObjectToWorld(v1.xyz).xyz;
    float3 pos2 = TransformObjectToWorld(v2.xyz).xyz;
    float4 tess;
    f.edge[0] = UnityCalcEdgeTessFactor (pos1, pos2, edgeLength);
    f.edge[1] = UnityCalcEdgeTessFactor (pos2, pos0, edgeLength);
    f.edge[2] = UnityCalcEdgeTessFactor (pos0, pos1, edgeLength);
    f.inside  = (tess.x + tess.y + tess.z) / 3.0f;
    return f;
}


// Same as UnityEdgeLengthBasedTess, but also does patch frustum culling:
// patches outside of camera's view are culled before GPU tessellation. Saves some wasted work.
TessellationFactors UnityEdgeLengthBasedTessCull (float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement)
{
    TessellationFactors f;
    float3 pos0 = TransformObjectToWorld(v0.xyz).xyz;
    float3 pos1 = TransformObjectToWorld(v1.xyz).xyz;
    float3 pos2 = TransformObjectToWorld(v2.xyz).xyz;

    if (UnityWorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement))
    {
        f = (TessellationFactors)0;
    }
    else
    {
        f.edge[0] = UnityCalcEdgeTessFactor (pos1, pos2, edgeLength);
        f.edge[1] = UnityCalcEdgeTessFactor (pos2, pos0, edgeLength);
        f.edge[2] = UnityCalcEdgeTessFactor (pos0, pos1, edgeLength);
        f.inside  = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0f;
    }
    return f;
}

TessellationFactors UnityScreenSpaceTess_WS(real3 p0, real3 p1, real3 p2, real4x4 viewProjectionMatrix, real4 screenSize, real triangleSize)
{
    // Get screen space adaptive scale factor
    real2 edgeScreenPosition0 = ComputeNormalizedDeviceCoordinates(p0, viewProjectionMatrix) * screenSize.xy;
    real2 edgeScreenPosition1 = ComputeNormalizedDeviceCoordinates(p1, viewProjectionMatrix) * screenSize.xy;
    real2 edgeScreenPosition2 = ComputeNormalizedDeviceCoordinates(p2, viewProjectionMatrix) * screenSize.xy;

    real EdgeScale = 1.0 / triangleSize; // Edge size in reality, but name is simpler
    real3 tessFactor;
    tessFactor.x = saturate(distance(edgeScreenPosition1, edgeScreenPosition2) * EdgeScale);
    tessFactor.y = saturate(distance(edgeScreenPosition0, edgeScreenPosition2) * EdgeScale);
    tessFactor.z = saturate(distance(edgeScreenPosition0, edgeScreenPosition1) * EdgeScale);

    return UnityCalcTriEdgeTessFactors(tessFactor);
}

#endif