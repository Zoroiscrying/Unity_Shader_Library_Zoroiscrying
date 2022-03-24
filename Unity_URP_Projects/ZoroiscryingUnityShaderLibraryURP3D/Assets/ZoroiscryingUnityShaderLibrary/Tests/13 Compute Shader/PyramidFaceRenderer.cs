using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class PyramidFaceRenderer : MonoBehaviour
{
    [SerializeField] private Mesh sourceMesh = default;
    [SerializeField] private ComputeShader pyramidComputeShader = default;
    [SerializeField] private ComputeShader triCountToVertCountComputeShader = default;
    [SerializeField] private Material material = default;
    [SerializeField] private float pyramidHeight = 1;
    [SerializeField] private float animationFrequency = 1;

    // make sure the data layouts sequentially
    [System.Runtime.InteropServices.StructLayout(LayoutKind.Sequential)]
    private struct SourceVertex
    {
        public Vector3 position;
        public Vector2 uv;
    }

    private bool initialized;
    private ComputeBuffer sourceVertexBuffer;
    private ComputeBuffer sourceIndexBuffer;
    private ComputeBuffer outputTriangleBuffer;
    private ComputeBuffer argsBuffer;
    
    private int idPyramidKernel;
    private int idTriCountTrippleKernel;
        
    private int dispatchSize;

    private const int SOURCE_VERTEX_STRIDE = sizeof(float) * (3+2);
    private const int SOURCE_INDEX_STRIDE = sizeof(int);
    private const int OUTPUT_TRIANGLE_STRIDE = sizeof(float) * (3*(3+2) + 3);
    private const int ARGS_STRIDE = sizeof(int) * 4;

    private Bounds localBound;

    private void OnEnable()
    {
        if (initialized)
        {
           OnDisable();
        }
        initialized = true;
        
        Vector3[] positions = sourceMesh.vertices;
        Vector2[] uvs = sourceMesh.uv;
        int[] indices = sourceMesh.triangles;

        SourceVertex[] vertices = new SourceVertex[positions.Length];
        for (int i = 0; i < vertices.Length; i++)
        {
            vertices[i] = new SourceVertex()
            {
                position = positions[i],
                uv = uvs[i]
            };
        }
        int numTriangles = indices.Length / 3;
        
        // Create Args buffer and initialize
        argsBuffer = new ComputeBuffer(1, ARGS_STRIDE, ComputeBufferType.IndirectArguments);
        // 0 : vertex count per draw instance
        // 1 : instance count
        // 2 : start vertex location if using a graphics buffer
        // 3 : start instance location if using a graphics buffer
        argsBuffer.SetData(new int[]{0, 1, 0, 0});
        
        // Create compute buffers
        sourceVertexBuffer = new ComputeBuffer(vertices.Length, SOURCE_VERTEX_STRIDE, ComputeBufferType.Structured,
            ComputeBufferMode.Immutable);
        sourceVertexBuffer.SetData(vertices);
        sourceIndexBuffer = new ComputeBuffer(indices.Length, SOURCE_INDEX_STRIDE, ComputeBufferType.Structured,
            ComputeBufferMode.Immutable);
        sourceIndexBuffer.SetData(indices);
        outputTriangleBuffer = new ComputeBuffer(numTriangles * 3, OUTPUT_TRIANGLE_STRIDE, ComputeBufferType.Append);
        outputTriangleBuffer.SetCounterValue(0); // set the count to zero to append

        idPyramidKernel = pyramidComputeShader.FindKernel("CSPyramidFace");
        idTriCountTrippleKernel = triCountToVertCountComputeShader.FindKernel("CSMain");
        
        // Set the buffers to the compute shader
        pyramidComputeShader.SetBuffer(idPyramidKernel, "_SourceVertices", sourceVertexBuffer);
        pyramidComputeShader.SetBuffer(idPyramidKernel, "_SourceIndices", sourceIndexBuffer);
        pyramidComputeShader.SetBuffer(idPyramidKernel, "_OutputTriangles", outputTriangleBuffer);
        pyramidComputeShader.SetInt("_NumSourceTriangles", numTriangles);
        
        triCountToVertCountComputeShader.SetBuffer(idTriCountTrippleKernel, "_IndirectArgsBuffer", argsBuffer);
        
        material.SetBuffer("_OutputTriangles", outputTriangleBuffer);
        
        // Calculate the smallest dispatch size
        pyramidComputeShader.GetKernelThreadGroupSizes(idPyramidKernel, out uint threadGroupSize, out _, out _);
        dispatchSize = Mathf.CeilToInt((float)numTriangles / threadGroupSize);
        
        // Calculate the new computed bounds of the object
        localBound = sourceMesh.bounds;
        localBound.Expand(pyramidHeight);
    }

    private void OnDisable()
    {
        if (initialized)
        {
            sourceVertexBuffer.Release();
            sourceIndexBuffer.Release();
            outputTriangleBuffer.Release();
            argsBuffer.Release();
        }
        initialized = false;
    }

    public Bounds TransformBounds(Bounds boundsOS)
    {
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

    private void LateUpdate()
    {
        if (initialized)
        {
            outputTriangleBuffer.SetCounterValue(0);

            Bounds bounds = TransformBounds(localBound);
        
            pyramidComputeShader.SetMatrix("_Matrix_M", transform.localToWorldMatrix);
            pyramidComputeShader.SetFloat("_AnimationFrequency", animationFrequency);
            pyramidComputeShader.SetFloat("_PyramidHeight", pyramidHeight);

            pyramidComputeShader.Dispatch(idPyramidKernel, dispatchSize, 1, 1);
        
            // The dispatched output triangle buffer contains the number of the OutputTriangle
            // This number corresponds to 1/3 of the total vertex for the DrawProceduralIndirect method
            ComputeBuffer.CopyCount(outputTriangleBuffer, argsBuffer, 0);
        
            triCountToVertCountComputeShader.Dispatch(idTriCountTrippleKernel, 1, 1, 1);

            Graphics.DrawProceduralIndirect(material, bounds, MeshTopology.Triangles, argsBuffer, 0, null, null,
                ShadowCastingMode.On, true, gameObject.layer);   
        }
    }
}
