using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.Mathematics;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Deformable_Snow_and_Sand
{
    /// <summary>
    /// Deformable Snow and Sand Manager:
    /// 1. Register the estimated deformed snow via a ARGB32 1024 Texture using Compute Shader Process
    /// 2. Deform the snow geometry in the vertex shading pass, compare the registered deformation and the snow vertex height
    ///     2.1. Use a compute shader and a UINT atomic minimum action to store min-deformed snow
    ///     2.2. CPU side pass in the foot positions to calculate the deformations (distance^2)
    ///     2.3. Add snow height to all pixels every fill shader pass
    /// 3. If Actual Snow Height is much different from the registered snow height, the deformation is bypassed.
    /// </summary>
    public class DeformableSnowAndSandManager : MonoBehaviour
    {
        #region Variables and Properties

        public ComputeShader csSnowDepressionRegisterShader;
        public ComputeShader csSnowFillShader;

        [SerializeField] private RenderTexture snowDepressionUIntR32Rt;
        private const int SNOW_TEX_RESOLUTION = 1024;
        [SerializeField] private float snowTextureWorldSize = 48.0f;
        
        private ComputeBuffer _footPrintDataBuffer;
        private ComputeBuffer _dummyComputeBuffer;

        [SerializeField] private Transform centerTransform;
        private const float SNOW_HEIGHT_RANGE = 16.0f;
        private float _currentLowestHeight = -8.0f;
        private float _deltaLowestHeight = 0.0f;
        private Vector3 _centerPosition = Vector3.zero;
        private Vector3 _centerPositionLastFrame = Vector3.zero;
        private Vector3 _deltaCenterPosition = Vector3.zero;

        [SerializeField] private float depressionCoefficient = 1.0f;
        [SerializeField] private float elevationCoefficient = 1.0f;

        private bool _shouldInitDepressionTex = false;

        private static readonly ProfilingSampler SnowEdgeEraseProfilingSampler =
            new ProfilingSampler($"{nameof(DeformableSnowAndSandManager)}.SnowEdgeErase");
        private static readonly ProfilingSampler SnowDepressionRegisterProfilingSampler =
            new ProfilingSampler($"{nameof(DeformableSnowAndSandManager)}.SnowDepressionRegisterPass");
        private static readonly ProfilingSampler SnowFillProfilingSampler =
            new ProfilingSampler($"{nameof(DeformableSnowAndSandManager)}.SnowFillPass");


        #endregion

        #region Unity Functions

        private void OnDrawGizmosSelected()
        {
            Gizmos.DrawWireCube(_centerPosition, new Vector3(snowTextureWorldSize, 0.01f, snowTextureWorldSize));
        }

        private void OnSceneSaved(UnityEngine.SceneManagement.Scene scene) 
        {
            OnDisable();
            OnEnable();
        }

        private void OnEnable()
        {
            EditorSceneManager.sceneSaved += OnSceneSaved;
            
            CheckIfNeedToInitResources();
            
            RenderPipelineManager.beginCameraRendering += HandleBeginCameraRendering;
            
            // init resources via compute shader
            _shouldInitDepressionTex = true;
        }

        private void OnDestroy()
        {
            RenderPipelineManager.beginCameraRendering -= HandleBeginCameraRendering;
            EditorSceneManager.sceneSaved -= OnSceneSaved;
            CleanUp();
        }

        private void OnDisable()
        {
            RenderPipelineManager.beginCameraRendering -= HandleBeginCameraRendering;
            EditorSceneManager.sceneSaved -= OnSceneSaved;
            CleanUp();
        }

        #endregion

        #region Public Functions

        

        #endregion

        #region Private Functions

        private void HandleBeginCameraRendering(ScriptableRenderContext context, Camera currentCamera)
        {
            // center position calculation
            _centerPositionLastFrame = _centerPosition;
            if (centerTransform)
            {
                _centerPosition = centerTransform.position;
            }
            _deltaCenterPosition = _centerPosition - _centerPositionLastFrame;

            var cmd = CommandBufferPool.Get();
            cmd.Clear();

            SetupSnowAndSandCalculationVariantUniforms(cmd);

            if (_shouldInitDepressionTex)
            {
                SnowTextureClear(cmd);
            }

            using (new ProfilingScope(cmd, SnowDepressionRegisterProfilingSampler))
            {
                SnowDepressionRegister(cmd);
            }
            
            using (new ProfilingScope(cmd, SnowFillProfilingSampler))
            {
                SnowFill(cmd);
            }
            
            using (new ProfilingScope(cmd, SnowEdgeEraseProfilingSampler))
            {
                SnowBoundaryErase(cmd);
            }
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();
        }

        private void CheckIfNeedToInitResources()
        {
            // RTs
            CheckIfNeedToInitUIntR32Texture(ref snowDepressionUIntR32Rt, 1024);
            
            // compute buffers
            var footPrintCount = 0;
            HashSet<SnowAndSandFootprintRegisterObject> snowFootPrints = SnowAndSandFootprintObjectManager.Get();
            footPrintCount = snowFootPrints.Count;
            CheckIfNeedToCreateComputeBuffer(ref _footPrintDataBuffer, footPrintCount, Marshal.SizeOf(typeof(SnowFootprintData)));

            // dummy buffer preventing null data injecting
            CheckIfNeedToCreateComputeBuffer(ref _dummyComputeBuffer, 1, 4);
        }
        
        private void CleanUp()
        {
            // destroy RTs
            DestroyImmediate(snowDepressionUIntR32Rt);

            // release compute buffers
            ReleaseComputeBuffer(ref _footPrintDataBuffer);
            ReleaseComputeBuffer(ref _dummyComputeBuffer);
            
            // reset RTs to null
            snowDepressionUIntR32Rt = null;
        }
        
        private void SetupSnowAndSandCalculationVariantUniforms(CommandBuffer cmd)
        {
            cmd.SetGlobalTexture("SnowDepressionTexture", snowDepressionUIntR32Rt);
        }

        #region Snow Tex Clear

        private void SnowTextureClear(CommandBuffer cmd)
        {
            const float threadGroupSize = 8.0f;
            var kernel = csSnowDepressionRegisterShader.FindKernel("ClearOutData");

            cmd.SetComputeIntParam(csSnowDepressionRegisterShader, "SnowTextureResolution", SNOW_TEX_RESOLUTION);
            //cmd.SetComputeTextureParam(csSnowDepressionRegisterShader, kernel, "SnowDepressionTexture",
            //    snowDepressionUIntR32Rt);
            
            // can also stop dispatching the shader if no foot print exist
            var threadSize = Mathf.CeilToInt(SNOW_TEX_RESOLUTION / threadGroupSize);
            Debug.Log("Cleared Snow Tex");
            cmd.DispatchCompute(csSnowDepressionRegisterShader, kernel, threadSize, threadSize, 1);
            _shouldInitDepressionTex = false;
        }

        #endregion

        #region Snow Boundary Erase

        private void SnowBoundaryErase(CommandBuffer cmd)
        {
            const float threadGroupSize = 8.0f;
            var kernel = csSnowDepressionRegisterShader.FindKernel("ErasePreviousFrameData");

            cmd.SetComputeIntParam(csSnowDepressionRegisterShader, "SnowTextureResolution", SNOW_TEX_RESOLUTION);
            // cmd.SetComputeTextureParam(csSnowDepressionRegisterShader, kernel, "SnowDepressionTexture",
            //     snowDepressionUIntR32Rt);
            
            // can also stop dispatching the shader if no foot print exist
            var threadSize = Mathf.CeilToInt(SNOW_TEX_RESOLUTION / threadGroupSize);
            // Debug.Log("Snow Boundary Erase.");
            cmd.DispatchCompute(csSnowDepressionRegisterShader, kernel, threadSize, threadSize, 1);
        }

        #endregion

        #region Snow Depression Register

        private void PrepareSnowDepressionRegister(CommandBuffer cmd, int kernel, out int snowFootPrintCount)
        {
            //
            // cmd.SetComputeTextureParam(csSnowDepressionRegisterShader, kernel, "SnowDepressionTexture",
            //     snowDepressionUIntR32Rt);
            cmd.SetGlobalInteger("SnowTextureResolution", SNOW_TEX_RESOLUTION);
            cmd.SetGlobalFloat( "SnowTextureSizeWorldSpace", snowTextureWorldSize);
            
            cmd.SetGlobalFloat( "CurrentMinimumHeightWorldSpace", _currentLowestHeight);
            cmd.SetGlobalFloat( "SnowTextureWorldCenterX", _centerPosition.x);
            cmd.SetGlobalFloat( "SnowTextureWorldCenterZ", _centerPosition.z);
            
            // get foot print data
            // todo:: some data are uniform so that can be changed to uniform.
            snowFootPrintCount = 0;
            var snowFootPrints = SnowAndSandFootprintObjectManager.GetData();
            snowFootPrintCount = snowFootPrints.Length;
            CheckIfNeedToCreateComputeBuffer(ref _footPrintDataBuffer, snowFootPrintCount, Marshal.SizeOf(typeof(SnowFootprintData)));
            // we need to update the buffer data every frame for footprints
            if (snowFootPrintCount > 0)
            {
                // Debug.Log("Footprint set: " + snowFootPrints[0].positionWorldSpace);
                cmd.SetBufferData(_footPrintDataBuffer, snowFootPrints);   
            }

            cmd.SetComputeIntParam(csSnowDepressionRegisterShader, "SnowFootprintAmount", snowFootPrintCount);
            cmd.SetComputeFloatParam(csSnowDepressionRegisterShader, "FootPrintAffectDistance", 1.0f);
            cmd.SetComputeBufferParam(csSnowDepressionRegisterShader, kernel, "SnowFootprintBuffer",
                snowFootPrintCount > 0 ? _footPrintDataBuffer : _dummyComputeBuffer);
            
            // if (snowFootPrintCount > 0)
            // {
            //     Debug.Log("Register Snow footprint");
            // }
        }
        
        private void SnowDepressionRegister(CommandBuffer cmd)
        {
            var kernel = csSnowDepressionRegisterShader.FindKernel("RegisterFootprint");
            
            PrepareSnowDepressionRegister(cmd, kernel, out var snowFootPrintCount);
            snowFootPrintCount = Mathf.Max(1, snowFootPrintCount);

            // can also stop dispatching the shader if no foot print exist
            cmd.DispatchCompute(csSnowDepressionRegisterShader, kernel, snowFootPrintCount, 1, 1);
        }

        #endregion

        #region Global Snow Fill

        private void PrepareSnowFill(CommandBuffer cmd)
        {
            
        }
        
        private void SnowFill(CommandBuffer cmd)
        {
            var kernel = csSnowFillShader.FindKernel("CSMain");
            const float threadGroupSize = 8.0f;
            var threadSize = Mathf.CeilToInt(SNOW_TEX_RESOLUTION / threadGroupSize);
            
            PrepareSnowFill(cmd);

            // Debug.Log("Snow Fill");
            cmd.DispatchCompute(csSnowFillShader, kernel, threadSize, threadSize, 1);
        }

        #endregion
        
        private void CheckIfNeedToInitUIntR32Texture(ref RenderTexture renderTexture, int resolution)
        {
            if (renderTexture)
            {
                return;
            }

            renderTexture = new RenderTexture(resolution, resolution, 0,
                GraphicsFormat.R32_UInt)
            {
                dimension = TextureDimension.Tex2D,
                enableRandomWrite = true
            };
            renderTexture.Create();
        }

        private void CheckIfNeedToCreateComputeBuffer(ref ComputeBuffer buffer, int count, int stride)
        {
            if (buffer != null && buffer.count == count)
                return;

            if(buffer != null)
            {
                buffer.Release();
                buffer = null;
            }

            if (count <= 0)
                return;

            buffer = new ComputeBuffer(count, stride);
        }
        
        private void ReleaseComputeBuffer(ref ComputeBuffer buffer)
        {
            buffer?.Release();
            buffer = null;
        }
        
        #endregion
    }
}
