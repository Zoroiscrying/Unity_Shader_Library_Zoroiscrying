using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Mathematics;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Rendering;
using ZoroiscryingUnityShaderLibrary.Runtime.RuntimeUtility;
using Debug = UnityEngine.Debug;

namespace ZoroiscryingUnityShaderLibrary.Runtime.DynamicVegetation
{
    /// <summary>
    /// Vegetation Sway Global Manager, storing instances of in-game vegetation that feature sway-like movements
    /// (Such as Ferns, Non-trivial Vegetation (i.e., not grass), )
    /// </summary>
    // [ExecuteInEditMode]
    public class VegetationSwayGlobalManager : RuntimeMonoSingleton<VegetationSwayGlobalManager>
    {
        [SerializeField] private ComputeShader statefulSwayComputeShader;
        [Tooltip("This count determines how many instances can be added per frame.")]
        [Min(1)]
        [SerializeField] private int addInstanceBufferAllocateCount = 4;

        private const int COMPUTE_THREAD_NUM = 8;
        private int _computeGroupSizeX = 0;
        
        // although the list is a unique list, cannot use set because we would need index to query the specific data in GPU
        private List<SwayVegetationInstanceObject> _swayVegetationInstances = new List<SwayVegetationInstanceObject>();
        
        // double-sized buffer expansion
        private int _curSwayInstanceBufferSize = -1;
        private int _curDataListTailIndex = -1;
        
        private List<int> _swayInstancesToDisable = new List<int>();
        private List<SwayVegetationInstanceObject> _swayInstancesToEnable = new List<SwayVegetationInstanceObject>();

        private int _kernelProcessSway;
        private int _kernelCopyBuffers;
        private int _kernelAddInstance;

        private ComputeBuffer _swayVectorsBuffer;
        private ComputeBuffer _swayVelocitiesBuffer;
        private ComputeBuffer _swayObjectParameterBuffer;
        
        private ComputeBuffer _swayVectorsBufferBeta;
        private ComputeBuffer _swayVelocitiesBufferBeta;
        private ComputeBuffer _swayObjectParameterBufferBeta;

        private ComputeBuffer _instancesToDisableBuffer;
        private ComputeBuffer _instancesToAddBuffer;

        private bool _alphaIsValid = true;
        private bool _initialized = false;
        private bool _updatedInitialInstanceList = false;

        private bool _statefulSwayParamsNeedToUpdate = true;
        private bool _globalSwayVectorBufferNeedToUpdate = true;
        
        [Serializable]
        public struct SwayObjectParameter
        {
            [Min(0.0f)]
            public float WindStrength;
            [Min(0.0f)]
            public float ObjectMass;
            [Min(0.0f)]
            public float SpringStrength;
            [Range(0, 1)]
            public float SpringDampen;
            public float3 WorldPosition;

            public override string ToString()
            {
                return $"({WindStrength}," +
                       $"{ObjectMass}," +
                       $"{SpringStrength}," +
                       $"{SpringDampen}," +
                       $"P:({WorldPosition.x}, {WorldPosition.y}, {WorldPosition.z}))";
            }
        }

        private const int OBJECT_PARAMETER_STRIDE = sizeof(float) * 7;
        
        public void RegisterNewSwayInstance(SwayVegetationInstanceObject instance)
        {
            if (instance != null)
            {
                // Formerly disabled, but not removed from the list
                if (_swayVegetationInstances.Contains(instance))
                {
                    instance.RestoreStateBeforeDisable();
                }
                // Prevent double add
                else if(!_swayInstancesToEnable.Contains(instance))
                {
                    _swayInstancesToEnable.Add(instance);
                }
            }
        }

        public void DisableSwayInstance(int index)
        {
            if (index < 0)
            {
                return;
            }
            
            if (!_swayInstancesToDisable.Contains(index) && index < _swayVegetationInstances.Count)
            {
                _swayInstancesToDisable.Add(index);
            }
        }

        public static void DebugComputeBuffer<T>(int bufferSize, ComputeBuffer computeBuffer)
        {
            T[] data = new T[bufferSize];
            computeBuffer.GetData(data);
            var tempLog = data.Aggregate("List:{", (current, item) => current + item.ToString());
            Debug.Log(tempLog + "}.");
        }
        
        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Space))
            {
                DebugComputeBuffer<SwayObjectParameter>(_curSwayInstanceBufferSize,
                    _alphaIsValid ? _swayObjectParameterBuffer : _swayObjectParameterBufferBeta);
            }
        }

        private void OnEnable()
        {
            Assert.IsNotNull(statefulSwayComputeShader);
            
            // Retrieve Scene Vegetation Sway Instance Objects ()
            ValidateInput();
            
            RetrieveSceneSwayInstanceInfo();
            
            InitResources();
            
            SetupSwayConstantUniforms();
            
            EditorSceneManager.sceneSaved += OnSceneSaved;

            // command buffer approach, rendering via URP
            RenderPipelineManager.beginCameraRendering += HandleBeginCameraRendering;
            _initialized = true;
            
            Debug.Log("Global Sway Started.");
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

        private void ValidateInput()
        {
            
        }
        
        private void RetrieveSceneSwayInstanceInfo()
        {
            _swayVegetationInstances = FindObjectsOfType<SwayVegetationInstanceObject>().Where((o => o.enabled))
                .ToList();
            // if count == 17, and compute thread num is 8, the group size should be 3.
            _computeGroupSizeX = Mathf.Max(1, Mathf.CeilToInt(_curSwayInstanceBufferSize / (float)COMPUTE_THREAD_NUM));
            // Debug.Log(_computeGroupSizeX);
        }

        /// <summary>
        /// Initialize command buffers based on 
        /// </summary>
        private void InitResources()
        {
            _kernelProcessSway = statefulSwayComputeShader.FindKernel("ProcessSway");
            _kernelCopyBuffers = statefulSwayComputeShader.FindKernel("CopyBuffers");
            _kernelAddInstance = statefulSwayComputeShader.FindKernel("AddInstance");
            
            _curSwayInstanceBufferSize = _swayVegetationInstances.Count * 2;
            _curDataListTailIndex = _swayVegetationInstances.Count;

            _instancesToDisableBuffer = new ComputeBuffer(1, sizeof(int));
            _instancesToAddBuffer = new ComputeBuffer(addInstanceBufferAllocateCount, OBJECT_PARAMETER_STRIDE);

            int swayInstanceAmountClamped = Mathf.Max(_curSwayInstanceBufferSize, 1);
            
            _swayVectorsBuffer = new ComputeBuffer(swayInstanceAmountClamped, sizeof(float)*3, ComputeBufferType.Structured);
            _swayVelocitiesBuffer = new ComputeBuffer(swayInstanceAmountClamped, sizeof(float)*3, ComputeBufferType.Structured);
            _swayObjectParameterBuffer = new ComputeBuffer(swayInstanceAmountClamped, OBJECT_PARAMETER_STRIDE, ComputeBufferType.Structured);

            // Fill in the info from CPU to GPU
            var tempVector7List = new SwayObjectParameter[swayInstanceAmountClamped];
            for (int i = 0; i < _curDataListTailIndex; i++)
            {
                var instanceParameter = _swayVegetationInstances[i].SwayObjectParameter;
                tempVector7List[i] =  new SwayObjectParameter{
                    WindStrength = instanceParameter.WindStrength,
                    ObjectMass = instanceParameter.ObjectMass,
                    SpringStrength = instanceParameter.SpringStrength,
                    SpringDampen = instanceParameter.SpringDampen,
                    WorldPosition = instanceParameter.WorldPosition
                    };
            }
            
            // - initialize sway vectors as 0 vectors
            var tempVector3List = new float3[swayInstanceAmountClamped];
            for (int i = 0; i < tempVector3List.Length; i++)
            {
                tempVector3List[i] = 0;
            }

            _swayVectorsBuffer.SetData(tempVector3List);
            // - initialize velocity vectors as 0 vectors
            _swayVelocitiesBuffer.SetData(tempVector3List);
            // - the sway parameters are retrieved from the sway instance objects
            _swayObjectParameterBuffer.SetData(tempVector7List);
        }
        
        private void SetupSwayConstantUniforms()
        {
            //
        }

        private void OnSceneSaved(UnityEngine.SceneManagement.Scene scene) 
        {
            //Debug.Log("Scene Saved, Recreating resources.");
            OnDisable();
            OnEnable();
        }

        private void HandleBeginCameraRendering(ScriptableRenderContext context, Camera currentCamera)
        {
            if (!_initialized)
            {
                return;
            }

            if (!_updatedInitialInstanceList)
            {
                _updatedInitialInstanceList = true;
                for (int i = 0; i < _swayVegetationInstances.Count; i++)
                {
                    _swayVegetationInstances[i].UpdateSwayIndex(i);
                    _swayVegetationInstances[i].UpdateSwayIndexMaterialProperty();
                }
            }

            // setup uniforms -> process sway (spring physics dynamics) -> push the result to the global shader buffer
            // the IDs (index for retrieving the vectors) are stored via material property block in each sway instance.
            var cmd = CommandBufferPool.Get();
            cmd.Clear();
            cmd.SetExecutionFlags(CommandBufferExecutionFlags.None);

            // disabling existing sway instances and
            // enabling new sway instances, if new instances would lead to increased list size, expand the buffers first
            if (_swayInstancesToEnable.Count > 0)
            {
                var disableCount = _swayInstancesToDisable.Count;
                var enableCount = _swayInstancesToEnable.Count;
                
                // if temp enable size = 4, temp disable size = 1, curSwayBufferSize = 6, curDataListTail = 3, 
                // the data can be then filled in 3, 4, and 5 (full).
                int spaceNeeded = enableCount - disableCount - (_curSwayInstanceBufferSize - _curDataListTailIndex);
                if (spaceNeeded > 0)
                {
                    // more space is needed
                    EnlargeBuffers(spaceNeeded, cmd);
                }
                
                EnablingNewSwayInstances(_swayInstancesToEnable, _swayInstancesToDisable, cmd);
                // _swayInstancesToEnable.Clear(); The removal of instances to add is placed inside the function above
                // To achieve max instance add count per frame (avoiding create compute buffer at runtime)
            }
            
            // setup uniforms (buffers), if already set, we don't need to reset it, because they're all constant buffers
            if (_statefulSwayParamsNeedToUpdate)
            {
            }

            PrepareForSwayCompute(cmd);
            // execute(dispatch) compute shader, this is necessary every frame
            ProcessSway(cmd);
            
            // setup structured buffer to global shader
            cmd.SetGlobalBuffer("InstancesSwayVectorBuffer",
                _alphaIsValid ? _swayVectorsBuffer : _swayVectorsBufferBeta);
            cmd.SetGlobalInt("SwayInstanceTailIndex", _curDataListTailIndex);

            if (_globalSwayVectorBufferNeedToUpdate)
            {
                // don't update the buffer unless issued new update
                // _globalSwayVectorBufferNeedToUpdate = false;
            }
            //cmd.SetGlobalConstantBuffer(_swayVectorsBuffer, "InstancesSwayVectorBuffer", 0,
            //    _swayVectorsBuffer.stride * _swayVectorsBuffer.count);

            context.ExecuteCommandBuffer(cmd);
            
            cmd.Release();
            
            // after updating the GPU buffer, update the index in the material to correctly fetch the sway vector
            // foreach (var instance in _swayInstancesToEnable)
            // {
            //     instance.UpdateSwayIndexMaterialProperty();
            // }
            // _swayInstancesToEnable.Clear();
        }

        /// <summary>
        /// Enlarge all buffers related to sway computation. Double the buffer size, and copy all the buffer data.
        /// </summary>
        /// <param name="newSpaceNeeded"></param>
        /// <param name="cmd"></param>
        private void EnlargeBuffers(int newSpaceNeeded, CommandBuffer cmd)
        {
            // double the size (may not be enough) of buffers, recalculate the dispatch size
            _curSwayInstanceBufferSize *=
                Mathf.Max(2, Mathf.CeilToInt((float)newSpaceNeeded / _curSwayInstanceBufferSize));
            
            Debug.Log("Buffer space not enough, enlarged to size of: " + _curSwayInstanceBufferSize);
            
            _computeGroupSizeX = Mathf.Max(1, Mathf.CeilToInt(_curDataListTailIndex / (float)COMPUTE_THREAD_NUM));

            if (_alphaIsValid)
            {
                _swayVectorsBufferBeta = new ComputeBuffer(_curSwayInstanceBufferSize, sizeof(float)*3, ComputeBufferType.Structured);
                _swayVelocitiesBufferBeta = new ComputeBuffer(_curSwayInstanceBufferSize, sizeof(float)*3, ComputeBufferType.Structured);
                _swayObjectParameterBufferBeta = new ComputeBuffer(_curSwayInstanceBufferSize, OBJECT_PARAMETER_STRIDE, ComputeBufferType.Structured);

                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVectors", _swayVectorsBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVelocities", _swayVelocitiesBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayObjectParameters",
                    _swayObjectParameterBuffer);
                
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVectorsEnlarged", _swayVectorsBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVelocitiesEnlarged", _swayVelocitiesBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayObjectParametersEnlarged",
                    _swayObjectParameterBufferBeta);
            }
            else
            {
                _swayVectorsBuffer = new ComputeBuffer(_curSwayInstanceBufferSize, sizeof(float)*3, ComputeBufferType.Structured);
                _swayVelocitiesBuffer = new ComputeBuffer(_curSwayInstanceBufferSize, sizeof(float)*3, ComputeBufferType.Structured);
                _swayObjectParameterBuffer = new ComputeBuffer(_curSwayInstanceBufferSize, OBJECT_PARAMETER_STRIDE, ComputeBufferType.Structured);
                
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVectors", _swayVectorsBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVelocities", _swayVelocitiesBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayObjectParameters",
                    _swayObjectParameterBufferBeta);
                
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVectorsEnlarged", _swayVectorsBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayVelocitiesEnlarged", _swayVelocitiesBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelCopyBuffers, "SwayObjectParametersEnlarged",
                    _swayObjectParameterBuffer);
            }
            
            cmd.SetComputeIntParam(statefulSwayComputeShader, "CurrentDataTailIndex", _curDataListTailIndex);
            cmd.DispatchCompute(statefulSwayComputeShader, _kernelCopyBuffers, _computeGroupSizeX, 1, 1);
            
            // only change target when buffer is double sized.
            _globalSwayVectorBufferNeedToUpdate = true;
            _statefulSwayParamsNeedToUpdate = true;
            
            _alphaIsValid = !_alphaIsValid;
            // DebugComputeBuffer<SwayObjectParameter>(_curSwayInstanceBufferSize,
            //     _alphaIsValid ? _swayObjectParameterBuffer : _swayObjectParameterBufferBeta);
        }

        /// <summary>
        /// Disable the data in both GPU (do not copy) and CPU (index minus or intact)
        /// </summary>
        /// <param name="instancesToDisable"></param>
        /// <param name="cmd"></param>
        private void DisableExistingSwayInstances(List<int> instancesToDisable, CommandBuffer cmd)
        {
            foreach (var instanceIndex in instancesToDisable)
            {
                _swayVegetationInstances[instanceIndex].enabled = false;
            }
            // inject the "indices to bypass the copy process of the existing buffer" buffer to the compute shader
            // this is done in the 'EnablingNewSwayInstances' Function
        }

        private void UpdateIndexOfExistingInstance(int indexToDisable)
        {
            
        }

        /// <summary>
        /// Enable the data in both GPU (append) and CPU (index of the end of the list)
        /// </summary>
        /// <param name="instancesToEnable"></param>
        /// <param name="instancesDisabled"></param>
        /// <param name="cmd"></param>
        private void EnablingNewSwayInstances(List<SwayVegetationInstanceObject> instancesToEnable, List<int> instancesDisabled, CommandBuffer cmd)
        {
            // - update in CPU
            // for every new instance, add them into the vegetation instance list, and have their indices updated accordingly
            // because we need to update the buffers first, the calling for their index update is delayed.
            
            // set the tail index before injecting in CPU
            cmd.SetComputeIntParam(statefulSwayComputeShader, "CurrentSwayListTailIndex", _curDataListTailIndex);

            var removeIndexEnd = -1;
            var instancesToAddCountThisFrame = Mathf.Min(instancesToEnable.Count, addInstanceBufferAllocateCount);
                
            for (int i = 0; i < instancesToAddCountThisFrame; i++)
            {
                var instance = instancesToEnable[i];
                // garbage data available
                if (instancesDisabled != null && i < instancesDisabled.Count)
                {
                    var disabledIndex = instancesDisabled[i];
                    instance.UpdateSwayIndex(disabledIndex);
                    _swayVegetationInstances[disabledIndex] = instance;
                    removeIndexEnd = i;
                }
                else
                {
                    instance.UpdateSwayIndex(_curDataListTailIndex++);   
                    _swayVegetationInstances.Add(instance);
                }
                instance.UpdateSwayIndexMaterialProperty();
            }

            List<int> instancesDisabledTemp = new List<int>();

            if (instancesDisabled is { Count: > 0 })
            {
                instancesDisabledTemp = instancesDisabled.GetRange(0, removeIndexEnd + 1);
                instancesDisabled.RemoveRange(0, removeIndexEnd + 1);   
            }

            // - update in GPU
            // inject the "data to append to the existing buffer" buffer to the compute shader
            var disableCount = removeIndexEnd + 1;
            
            // Debug.Log("Disabled Instances: " + disableCount);

            if (instancesDisabled != null && disableCount > 0)
            {
                _instancesToDisableBuffer = new ComputeBuffer(disableCount, sizeof(int));
                cmd.SetBufferData(_instancesToDisableBuffer, instancesDisabledTemp);
            }
            
            // todo:: this is possibly inefficient
            
            var tempVector7List = new SwayObjectParameter[addInstanceBufferAllocateCount];
            for (int i = 0; i < instancesToAddCountThisFrame; i++)
            {
                var instanceParameter = instancesToEnable[i].SwayObjectParameter;
                tempVector7List[i] =  new SwayObjectParameter{
                    WindStrength = instanceParameter.WindStrength,
                    ObjectMass = instanceParameter.ObjectMass,
                    SpringStrength = instanceParameter.SpringStrength,
                    SpringDampen = instanceParameter.SpringDampen,
                    WorldPosition = instanceParameter.WorldPosition
                };
            }

            Debug.Log("Added Instances: " + instancesToAddCountThisFrame);
            instancesToEnable.RemoveRange(0, instancesToAddCountThisFrame);
            
            cmd.SetBufferData(_instancesToAddBuffer, tempVector7List);
            cmd.SetComputeIntParam(statefulSwayComputeShader, "DisabledInstanceCount", disableCount);
            cmd.SetComputeIntParam(statefulSwayComputeShader, "AddInstanceCount", instancesToAddCountThisFrame);
            
            cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelAddInstance, "SwayObjectParameters",
                _alphaIsValid ? _swayObjectParameterBuffer : _swayObjectParameterBufferBeta);
            cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelAddInstance, "SwayVectors", 
                _alphaIsValid ? _swayVectorsBuffer : _swayVectorsBufferBeta);
            cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelAddInstance, "SwayVelocities", 
                _alphaIsValid ? _swayVelocitiesBuffer : _swayVelocitiesBufferBeta);
            cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelAddInstance, "InstanceIndexDisabledList", _instancesToDisableBuffer);
            cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelAddInstance, "SwayObjectParametersToAdd", _instancesToAddBuffer);

            var computeGroupSizeX = Mathf.Max(1, Mathf.CeilToInt(instancesToAddCountThisFrame / (float)COMPUTE_THREAD_NUM));
            cmd.DispatchCompute(statefulSwayComputeShader, _kernelAddInstance, computeGroupSizeX, 1, 1);
        }

        /// <summary>
        /// Setting up the variables for the compute shader
        /// </summary>
        private void PrepareForSwayCompute(CommandBuffer cmd)
        {
            if (_alphaIsValid)
            {
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayVectors", _swayVectorsBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayVelocities", _swayVelocitiesBuffer);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayObjectParameters",
                    _swayObjectParameterBuffer);   
            }
            else
            {
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayVectors", _swayVectorsBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayVelocities", _swayVelocitiesBufferBeta);
                cmd.SetComputeBufferParam(statefulSwayComputeShader, _kernelProcessSway, "SwayObjectParameters",
                    _swayObjectParameterBufferBeta);   
            }
            cmd.SetComputeIntParam(statefulSwayComputeShader, "SwayInstancesCount", _curDataListTailIndex);
            cmd.SetComputeFloatParam(statefulSwayComputeShader, "deltaTime", Time.deltaTime);
            // _statefulSwayParamsNeedToUpdate = false;
        }

        private void ProcessSway(CommandBuffer cmd)
        {
            statefulSwayComputeShader.Dispatch(_kernelProcessSway, _computeGroupSizeX, 1, 1);
        }
        
        private void CleanUp()
        {
            // release command buffers
            _swayVectorsBuffer?.Release();
            _swayVelocitiesBuffer?.Release();
            _swayObjectParameterBuffer?.Release();
        
            _swayVectorsBufferBeta?.Release();
            _swayVelocitiesBufferBeta?.Release();
            _swayObjectParameterBufferBeta?.Release();
        
            _instancesToAddBuffer?.Release();
            _instancesToDisableBuffer?.Release();   
            
        }
    }
}