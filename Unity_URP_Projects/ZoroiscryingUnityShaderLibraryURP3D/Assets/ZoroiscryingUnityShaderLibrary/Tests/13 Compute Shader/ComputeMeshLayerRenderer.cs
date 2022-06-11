// MIT License

// Copyright (c) 2020 NedMakesGames

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode] // This allows the grass renderer to be visible in edit mode
public class ComputeMeshLayerRenderer : MonoBehaviour {
    // A class to hold grass settings
    [System.Serializable]
    public class LayerSettings {
        [Tooltip("The total height of the grass layer stack")]
        public float layerHeight = 0.5f;
        [Tooltip("The maximum number of layers")]
        public int maxLayers = 16;
        [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n " +
            "This is the distance from the camera LOD will start to take effect")]
        public float lodMinCameraDistance = 1;
        [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n " +
            "This is the distance from the camera the grass will have the fewest possible layers")]
        public float lodMaxCameraDistance = 1;
        [Tooltip("Level-of-detail settings. As the camera moves away, the shader will decrease the number of layers.\n " +
            "This is a power applied to the distance lerp to control layer falloff")]
        public float lodFactor = 2;
        [Tooltip("Use world position XZ as the UV. Useful for tiling")]
        public bool useWorldPositionAsUV;
        [Tooltip("Multiplier on world position when using it as a UV")]
        public float worldPositionUVScale;
    }

    [Tooltip("A mesh to extrude the grass from")]
    [SerializeField] private Mesh sourceMesh = default;
    [Tooltip("The grass geometry creating compute shader")]
    [SerializeField] private ComputeShader layerComputeShader = default;
    [Tooltip("The triangle count adjustment compute shader")]
    [SerializeField] private ComputeShader triToVertComputeShader = default;
    [Tooltip("The material to render the grass mesh")]
    [SerializeField] private Material material = default;

    [SerializeField] private LayerSettings layerSettings = default;

    // The structure to send to the compute shader
    // This layout kind assures that the data is laid out sequentially
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct SourceVertex {
        public Vector3 position;
        public Vector3 normal;
        public Vector2 uv;
    }

    // A state variable to help keep track of whether compute buffers have been set up
    private bool initialized;
    // A compute buffer to hold vertex data of the source mesh
    private ComputeBuffer sourceVertBuffer;
    // A compute buffer to hold index data of the source mesh
    private ComputeBuffer sourceTriBuffer;
    // A compute buffer to hold vertex data of the generated mesh
    private ComputeBuffer drawBuffer;
    // A compute buffer to hold indirect draw arguments
    private ComputeBuffer argsBuffer;
    // We have to instantiate the shaders so each points to their unique compute buffers
    // An instantiated copy of the grass compute shader 
    private ComputeShader instantiatedLayerComputeShader;
    // An instantiated copy of the triangle to vertex compute shader 
    private ComputeShader instantiatedTriToVertComputeShader;
    // An instantiated copy of the material
    private Material instantiatedMaterial;
    // The id of the kernel in the grass compute shader
    private int idLayerKernel;
    // The id of the kernel in the tri to vert count compute shader
    private int idTriToVertKernel;
    // The x dispatch size for the grass compute shader
    private int dispatchSize;
    // The local bounds of the generated mesh
    private Bounds localBounds;

    // The size of one entry into the various compute buffers
    private const int SOURCE_VERT_STRIDE = sizeof(float) * (3 + 3 + 2); // postion + normal + UV
    private const int SOURCE_TRI_STRIDE = sizeof(int);
    private const int DRAW_STRIDE = sizeof(float) * (2 + (3 + 3 + 2) * 3); // height + 3 * (position + normal + UV)
    private const int ARGS_STRIDE = sizeof(int) * 4;

    private void OnEnable() {
        // If initialized, call on disable to clean things up
        if(initialized) {
            OnDisable();
        }
        initialized = true;

        // Instantiate the shaders so they can point to their own buffers
        instantiatedLayerComputeShader = Instantiate(layerComputeShader);
        instantiatedTriToVertComputeShader = Instantiate(triToVertComputeShader);
        instantiatedMaterial = Instantiate(material);

        // Grab data from the source mesh
        Vector3[] positions = sourceMesh.vertices;
        Vector3[] normals = sourceMesh.normals;
        Vector2[] uvs = sourceMesh.uv;
        int[] tris = sourceMesh.triangles;

        // Create the data to upload to the source vert buffer
        SourceVertex[] vertices = new SourceVertex[positions.Length];
        for(int i = 0; i < vertices.Length; i++) {
            vertices[i] = new SourceVertex() {
                position = positions[i],
                normal = normals[i],
                uv = uvs[i],
            };
        }
        int numTriangles = tris.Length / 3; // The number of triangles in the source mesh is the index array / 3

        // Create compute buffers
        // The stride is the size, in bytes, each object in the buffer takes up
        sourceVertBuffer = new ComputeBuffer(vertices.Length, SOURCE_VERT_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceVertBuffer.SetData(vertices);
        sourceTriBuffer = new ComputeBuffer(tris.Length, SOURCE_TRI_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceTriBuffer.SetData(tris);
        drawBuffer = new ComputeBuffer(numTriangles * layerSettings.maxLayers, DRAW_STRIDE, ComputeBufferType.Append);
        drawBuffer.SetCounterValue(0); // Set the count to zero
        argsBuffer = new ComputeBuffer(1, ARGS_STRIDE, ComputeBufferType.IndirectArguments);
        // The data in the args buffer correspond to:
        // 0: vertex count per draw instance. We will only use one instance
        // 1: instance count. One
        // 2: start vertex location if using a Graphics Buffer
        // 3: and start instance location if using a Graphics Buffer
        argsBuffer.SetData(new int[] { 0, 1, 0, 0 });

        // Cache the kernel IDs we will be dispatching
        idLayerKernel = instantiatedLayerComputeShader.FindKernel("CSMain");
        idTriToVertKernel = instantiatedTriToVertComputeShader.FindKernel("CSMain");

        // Set data on the shaders
        instantiatedLayerComputeShader.SetBuffer(idLayerKernel, "_SourceVertices", sourceVertBuffer);
        instantiatedLayerComputeShader.SetBuffer(idLayerKernel, "_SourceTriangles", sourceTriBuffer);
        instantiatedLayerComputeShader.SetBuffer(idLayerKernel, "_DrawTriangles", drawBuffer);
        instantiatedLayerComputeShader.SetInt("_NumSourceTriangles", numTriangles);
        instantiatedLayerComputeShader.SetInt("_MaxLayers", layerSettings.maxLayers);
        instantiatedLayerComputeShader.SetFloat("_TotalHeight", layerSettings.layerHeight);
        instantiatedLayerComputeShader.SetFloat("_CameraDistanceMin", layerSettings.lodMinCameraDistance);
        instantiatedLayerComputeShader.SetFloat("_CameraDistanceMax", layerSettings.lodMaxCameraDistance);
        instantiatedLayerComputeShader.SetFloat("_CameraDistanceFactor", Mathf.Max(0, layerSettings.lodFactor));
        instantiatedLayerComputeShader.SetFloat("_WorldPositionToUVScale", layerSettings.worldPositionUVScale);
        if(layerSettings.useWorldPositionAsUV) {
            instantiatedLayerComputeShader.EnableKeyword("USE_WORLD_POSITION_AS_UV");
        }

        instantiatedTriToVertComputeShader.SetBuffer(idTriToVertKernel, "_IndirectArgsBuffer", argsBuffer);

        instantiatedMaterial.SetBuffer("_OutputTriangles", drawBuffer);

        // Calculate the number of threads to use. Get the thread size from the kernel
        // Then, divide the number of triangles by that size
        instantiatedLayerComputeShader.GetKernelThreadGroupSizes(idLayerKernel, out uint threadGroupSize, out _, out _);
        dispatchSize = Mathf.CeilToInt((float)numTriangles / threadGroupSize);

        // Get the bounds of the source mesh and then expand by the grass height
        localBounds = sourceMesh.bounds;
        localBounds.Expand(layerSettings.layerHeight);
    }

    private void OnDisable() {
        // Dispose of buffers and copied shaders here
        if(initialized) {
            // If the application is not in play mode, we have to call DestroyImmediate
            if(Application.isPlaying) {
                Destroy(instantiatedLayerComputeShader);
                Destroy(instantiatedTriToVertComputeShader);
                Destroy(instantiatedMaterial);
            } else {
                DestroyImmediate(instantiatedLayerComputeShader);
                DestroyImmediate(instantiatedTriToVertComputeShader);
                DestroyImmediate(instantiatedMaterial);
            }
            // Release each buffer
            sourceVertBuffer.Release();
            sourceTriBuffer.Release();
            drawBuffer.Release();
            argsBuffer.Release();
        }
        initialized = false;
    }

    // This applies the game object's transform to the local bounds
    // Code by benblo from https://answers.unity.com/questions/361275/cant-convert-bounds-from-world-coordinates-to-loca.html
    public Bounds TransformBounds(Bounds boundsOS) {
        var center = transform.TransformPoint(boundsOS.center);

        // transform the local extents' axes
        var extents = boundsOS.extents;
        var axisX = transform.TransformVector(extents.x, 0, 0);
        var axisY = transform.TransformVector(0, extents.y, 0);
        var axisZ = transform.TransformVector(0, 0, extents.z);

        // sum their absolute value to get the world extents
        extents.x = Mathf.Abs(axisX.x) + Mathf.Abs(axisY.x) + Mathf.Abs(axisZ.x);
        extents.y = Mathf.Abs(axisX.y) + Mathf.Abs(axisY.y) + Mathf.Abs(axisZ.y);
        extents.z = Mathf.Abs(axisX.z) + Mathf.Abs(axisY.z) + Mathf.Abs(axisZ.z);

        return new Bounds { center = center, extents = extents };
    }

    // LateUpdate is called after all Update calls
    private void LateUpdate() {
        // If in edit mode, we need to update the shaders each Update to make sure settings changes are applied
        // Don't worry, in edit mode, Update isn't called each frame
        if(Application.isPlaying == false) {
            OnDisable();
            OnEnable();
        }

        if (initialized)
        {
            // Clear the draw buffer of last frame's data
            drawBuffer.SetCounterValue(0);

            // Transform the bounds to world space
            Bounds bounds = TransformBounds(localBounds);

            // Update the shader with frame specific data
            instantiatedLayerComputeShader.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);
            instantiatedLayerComputeShader.SetVector("_CameraPosition", Camera.main.transform.position);

            // Dispatch the grass shader. It will run on the GPU
            instantiatedLayerComputeShader.Dispatch(idLayerKernel, dispatchSize, 1, 1);

            // Copy the count (stack size) of the draw buffer to the args buffer, at byte position zero
            // This sets the vertex count for our draw procediral indirect call
            ComputeBuffer.CopyCount(drawBuffer, argsBuffer, 0);

            // This the compute shader outputs triangles, but the graphics shader needs the number of vertices,
            // we need to multiply the vertex count by three. We'll do this on the GPU with a compute shader 
            // so we don't have to transfer data back to the CPU
            instantiatedTriToVertComputeShader.Dispatch(idTriToVertKernel, 1, 1, 1);

            // DrawProceduralIndirect queues a draw call up for our generated mesh
            // It will receive a shadow casting pass, like normal
            Graphics.DrawProceduralIndirect(instantiatedMaterial, bounds, MeshTopology.Triangles, argsBuffer, 0,
                null, null, ShadowCastingMode.Off, true, gameObject.layer);   
        }
    }
}