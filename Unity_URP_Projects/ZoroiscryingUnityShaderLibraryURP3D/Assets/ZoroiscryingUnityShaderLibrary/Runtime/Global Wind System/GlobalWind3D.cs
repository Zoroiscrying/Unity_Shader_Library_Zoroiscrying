using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using JetBrains.Annotations;
using Unity.Collections;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using UnityEngine.UI;
using UnityEngine.VFX;
using ZoroiscryingUnityShaderLibrary.Runtime.DynamicVegetation;
using ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System;
using ZoroiscryingUnityShaderLibrary.Shaders.ComputeShaderRelated;

/// <summary>
/// Global Wind Calculation process:
/// 1. Inherit former wind velocities and directions to the current 3D Texture by
///     calculating the difference of former agent position and the current one.
/// 2. Update and inject existing wind contributor objects' wind directions and
///     intensities to the current 3D Texture.
/// 3. Blend the whole wind texture by using diffusion algorithm
/// 4. Propagate the current wind directions and intensities by updating the 3D Texture.
/// </summary>

// [ExecuteInEditMode]
public class GlobalWind3D : MonoBehaviour
{
	// debug CPU read back
	[Header("Debugging")] 
	[SerializeField] private Mesh debugInstanceMesh;
	[SerializeField] private int subMeshIndex = 0;
	[SerializeField] private Material instanceMaterial;
	private int InstanceCount
	{
		get => VolumeResolution.x * VolumeResolution.y * VolumeResolution.z;
	}
	private int _cachedInstanceCount = -1;
	private int _cachedSubMeshIndex = -1;
	private ComputeBuffer _debugHandlePositionBuffer;
	private ComputeBuffer _debugArgsBuffer;
	private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
	[FormerlySerializedAs("debug")] [SerializeField] private bool debug3DScene = false;
	private bool _initialized3DDebugScene = false;
	//[SerializeField] private bool debug2DUi;
	//[SerializeField] private Canvas debugCanvas;
	//[SerializeField] private GameObject imageObjectPrefab;
	//[SerializeField] private Material debug2DUiMaterial;
	private bool _initialized2DDebugUi = false;

	//private NativeArray<Vector4> _windDirectionAndIntensitiesArray;
	//private AsyncGPUReadbackRequest _readBackRequest;
	
    // hidden properties
    public ComputeShader csWindInheritance;
    public ComputeShader csInjectWindDirectionAndIntensity;
    public ComputeShader csWindDiffusion;
    [FormerlySerializedAs("csWindPropagation")] public ComputeShader csWindAdvection;
    public ComputeShader csIntToHalfExport;

    private LocalKeyword _windExportFunctionNoise;
    private LocalKeyword _windExportTextureNoise;
    
    // user-defined variables
    [Header("Volume Settings")]
    [SerializeField] private Transform windCenterTransform;
    //[Header("Wind Volume Density")] // 64 32 64 xyz
    [SerializeField] private Vector3 centerVolumePosition = Vector3.zero;
    private Vector3 _centerVolumePositionLastFrame = Vector3.zero;
    private Vector3 _deltaVolumePositionThisFrame = Vector3.zero;
    [SerializeField] private float sizePerVoxel = 1.0f;

    [Header("Wind Diffusion Variables")]
    [SerializeField] private bool diffusionEnabled = true;
    [SerializeField] private float diffusionIntensity = .5f;
    [SerializeField] private int windDiffusionIteration = 5;
    
    [Header("Wind Advection Variables")]
    [SerializeField] private bool advectionEnabled = true;
    [Range(0.01f, 0.99f), SerializeField] private float windAdvectionAttenuationStrength;
    [Min(0.000001f), SerializeField] private float windAdvectionIntensity = 1f;
    [Min(0.01f), SerializeField] private float propagationIntensityThreshold;

    [Header("Ambient Wind Variables")] 
    [SerializeField] private Vector4 ambientWind = Vector4.zero; // rgb direction and a intensity
    private Vector4 _ambientWindNormalized = Vector4.zero;
    [SerializeField] private float noiseWindIntensity = 1.0f;
    [SerializeField] private Vector3 noiseWindScrollDirection = Vector3.one;
    [SerializeField] private float noiseWindScrollSpeed = 1;
    [SerializeField] private bool textureNoise = false;
    [SerializeField] private Texture2D textureNoise2D;
    [SerializeField] private Vector3 noisePositionFrequency = Vector3.one;
    [SerializeField] private Vector3 noisePositionOffset = Vector3.zero;
	
    // voxel size for wind texture sampling
    //[SerializeField] private float globalDensityMult = 1.0f; // position density for sampling
    private readonly Vector3Int _windInheritanceNumThreads = new Vector3Int(8, 4, 8);
    private readonly Vector3Int _windInjectionNumThreads = new Vector3Int(8, 4, 8);
    private readonly Vector3Int _windDiffusionNumThreads = new Vector3Int(8, 4, 8);
    private readonly Vector3Int _windAdvectionNumThreads = new Vector3Int(8, 4, 8);
    private readonly Vector3Int _windExportNumThreads = new Vector3Int(8, 4, 8);
    // Render texture - 2 for ping pong processing
    private bool _betaIsTarget = false;
    private RenderTexture _windVolumeHalf16; // primary
    
    //private RenderTexture _windVolumeBeta; // secondary
    // int texture format for interlock add (3 axis, 2 for ping pong)
    private RenderTexture _windVolumeSInt32RAlpha;
    private RenderTexture _windVolumeSInt32GAlpha;
    private RenderTexture _windVolumeSInt32BAlpha;
    private RenderTexture _windVolumeSInt32RBeta;
    private RenderTexture _windVolumeSInt32GBeta;
    private RenderTexture _windVolumeSInt32BBeta;
    
    // private RenderTexture _windIntensityDirectionVolume2; // possibly for wind advocate
    private static readonly Vector3Int VolumeResolution = new Vector3Int(32, 16, 32);
    private Vector3 VolumeResolutionMinusOne => VolumeResolution - new Vector3Int(1, 1, 1);

    // currently, the unity don't support Global VFX Graph Parameters as well as custom hlsl support, so this part is 
    // quite tricky to make; 
    // Viable solutions maybe register VFX Graph with the global wind manager at runtime when VFX Graph is created.
    // Therefore, this part is not being developed anymore due to the bad support of VFX Graph customization.
    // Examples of custom nodes is available at Github though, which might be examined later (don't know when).
    // https://github.com/peeweek/net.peeweek.vfxgraph-extras
    [Header("VFX Graph Support")] [SerializeField]
    private VisualEffect vfxSubGraphSampleGlobalWind;
    
    // Profiling
    public static readonly ProfilingSampler WindInheritanceProfilingSampler = new ProfilingSampler($"{nameof(GlobalWind3D)}.{nameof(WindInjection)}");
    public static readonly ProfilingSampler WindInjectionProfilingSampler = new ProfilingSampler($"{nameof(GlobalWind3D)}.{nameof(WindInjection)}");
    public static readonly ProfilingSampler WindDiffusionProfilingSampler = new ProfilingSampler($"{nameof(GlobalWind3D)}.{nameof(WindDiffusion)}");
    public static readonly ProfilingSampler WindAdvectionProfilingSampler = new ProfilingSampler($"{nameof(GlobalWind3D)}.{nameof(WindAdvection)}");
    public static readonly ProfilingSampler WindExportProfilingSampler = new ProfilingSampler($"{nameof(GlobalWind3D)}.{nameof(WindExport)}");
    
    // injection structs and params
    // struct params
    // params[] windInjectorParams;
    // ComputeBuffer _windInjectorParams;

    #region Wind Shape Params

    // Box/Capsule Wind Contributor, calculates collision with the 3D volume via boundaries
    // Calculates the product of the three axis of the box wind with the vector from center to current location,
    // compare the result with the extend (absolute less than extend, then intensity is 1.0, otherwise 0.0)
    public struct BoxWindParams
    {
	    public uint calculationType;
	    public uint calculationBufferIndex;
	    public float3 extendsLocal;
	    public Matrix4x4 worldToLocalMatrix;

	    public override string ToString()
	    {
		    return "Type: " + ((BaseWindContributor.WindCalculationType)calculationType) + "Buffer Index: " +
		           calculationBufferIndex;
	    }
    }
    private BoxWindParams[] _boxWindParams;
    private ComputeBuffer _boxWindParamsBuffer;
    
    // Cylinder Wind Contributor, calculates collision with the 3D volume via boundaries
    // Calculates the product of the three axis of the cylinder wind with the vector from center to current location,
    // compare the result with the extend (absolute less than extend, then intensity is 1.0)
    public struct CylinderWindParams
    {
	    public uint calculationType;
	    public uint calculationBufferIndex;
	    public float2 extends; // up-down extend, radius extend (squared)
	    public Matrix4x4 worldToLocalMatrix;
    }
    private CylinderWindParams[] _cylinderWindParams;
    private ComputeBuffer _cylinderWindParamsBuffer;
    
    // Sphere wind contributor, calculates collision with the 3D volume via distance and radius
    // Distance <= radius --> Intensity is 1.0
    public struct SphereWindParams
    {
	    public uint calculationType;
	    public uint calculationBufferIndex;
	    public float3 centerWorldSpace;
	    public float extendSquared; // radius extend, Squared to reduce calculation
    }
    private SphereWindParams[] _sphereWindParams;
    private ComputeBuffer _sphereWindParamsBuffer;

    #endregion

    #region Wind Calculation Type Params

    // Fixed calculation, directly assign the velocity to the wind voxels
    public struct FixedCalculationParams
    {
	    public float3 fixedWindVelocityWorldSpace;

	    public override string ToString()
	    {
		    return "Fixed Velocity: " + fixedWindVelocityWorldSpace;
	    }
    }
    private FixedCalculationParams[] _fixedCalculationParams;
    private ComputeBuffer _fixedCalculationParamsBuffer;
    
    // Point based wind calculation, assign velocity based on direction and distance
    public struct PointBasedCalculationParams
    {
	    public Vector4 pointBasedWindCalculationDataAlpha;
	    public float distanceDecayInfluence;
    }
    private PointBasedCalculationParams[] _pointBasedCalculationParams;
    private ComputeBuffer _pointBasedCalculationParamsBuffer;
    
    // Axis based wind calculation, assign velocity based on cross direction and distance
    public struct AxisBasedCalculationParams
    {
	    public Vector4 axisBasedWindCalculationDataAlpha;
	    public Vector4 axisBasedWindCalculationDataBeta;
    }
    private AxisBasedCalculationParams[] _axisBasedCalculationParams;
    private ComputeBuffer _axisBasedCalculationParamsBuffer;

    private uint _fixedCalculationTypeIndex = 0;
    private uint _pointBasedCalculationTypeIndex = 0;
    private uint _axisBasedCalculationTypeIndex = 0;
    
    #endregion

    // dummy command buffer for null buffer inject
    private ComputeBuffer _dummyComputeBuffer;
    private void OnSceneSaved(UnityEngine.SceneManagement.Scene scene) 
    {
	    //Debug.Log("Scene Saved, Recreating resources.");
	    OnDisable();
	    OnEnable();
    }

    private void OnEnable()
    {
	    EditorSceneManager.sceneSaved += OnSceneSaved;
	    
	    ValidateInput();
	    CheckIfNeedToInitResources();
	    SetupWindConstantUniforms();
	    
	    // vfx graph support
	    if (vfxSubGraphSampleGlobalWind)
	    {
		    vfxSubGraphSampleGlobalWind.SetTexture("GlobalWindTex3D", _windVolumeHalf16);   
	    }

	    // command buffer for wind diffusion
	    RenderPipelineManager.beginCameraRendering += HandleBeginCameraRendering;

	    // Debug with text info
	    //_windDirectionAndIntensitiesArray =
		    //new NativeArray<Vector4>(_volumeResolution.x * _volumeResolution.y * _volumeResolution.z, Allocator.Temp);
	    //_readBackRequest = AsyncGPUReadback.Request(_windDirectionIntensityVolume);
	    //Debug.Log("Read Back Request initialized.");

	    // Update 3d debug buffers 
	    _debugArgsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
	    UpdateDebugBuffers3DScene();
	    
	    // Update for 2D UI
	    UpdateDebugBuffers2DUi();
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

    private void HandleBeginCameraRendering(ScriptableRenderContext context, Camera currentCamera)
    {
	    // Center volume position variables calculation
	    _centerVolumePositionLastFrame = centerVolumePosition;
	    if (windCenterTransform)
	    {
		    centerVolumePosition = windCenterTransform.position;
	    }
	    _deltaVolumePositionThisFrame = centerVolumePosition - _centerVolumePositionLastFrame;
	    
	    // similar to update, process the texture, use cmd.Command to set shader keywords, textures, etc.
	    // Inheritance -> Injection -> Diffusion -> Advection -> Export
	    var cmd = CommandBufferPool.Get();
	    cmd.Clear();
	    // cmd.SetExecutionFlags(CommandBufferExecutionFlags.AsyncCompute);
	    
	    // Wind Uniforms (variant) used across different operations
	    SetUpWindVariantUniforms(cmd);
	    
	    // Wind Inheritance Transformation (Copy the whole texture and apply the center movement)
	    using (new UnityEngine.Rendering.ProfilingScope(cmd, WindInheritanceProfilingSampler))
	    {
		    // WindInheritance(cmd);
	    }
	    
	    // Injection
	    using (new UnityEngine.Rendering.ProfilingScope(cmd, WindInjectionProfilingSampler))
	    {
		    WindInjection(cmd);   
	    }

	    // Diffusion
	    using (new UnityEngine.Rendering.ProfilingScope(cmd, WindDiffusionProfilingSampler))
	    {
		    if (diffusionEnabled)
		    {
			    WindDiffusion(cmd);
		    }
	    }

	    // Advection
	    using (new UnityEngine.Rendering.ProfilingScope(cmd, WindAdvectionProfilingSampler))
	    {
		    if (advectionEnabled)
		    {
			    WindAdvection(cmd);
		    }
	    }

	    // Export and provide the texture to global shaders
	    using (new UnityEngine.Rendering.ProfilingScope(cmd, WindExportProfilingSampler))
	    {
		    WindExport(cmd);
	    }

	    cmd.SetGlobalTexture("_GlobalWindVolume3D",  _windVolumeHalf16);
	    // Async will make the 3D Texture hard to sync with other sampling methods (e.g., sample in VFX Graph)
	    context.ExecuteCommandBuffer(cmd);
	    //context.ExecuteCommandBuffer(cmd);
	    cmd.Release();
	}

    private void Update()
    {
	    // Debug display
	    if (debug3DScene)
	    {
		    Debug3DSceneDisplay();
	    }

	    if (Input.GetKeyDown(KeyCode.Space))
	    {
		    VegetationSwayGlobalManager.DebugComputeBuffer<FixedCalculationParams>(_fixedCalculationParamsBuffer.count, _fixedCalculationParamsBuffer);
		    VegetationSwayGlobalManager.DebugComputeBuffer<BoxWindParams>(_boxWindParamsBuffer.count, _boxWindParamsBuffer);
	    }
    }

    private void ValidateInput()
    {
	    //
    }
    
    private void CleanUp()
    {
	    // Index clean up
	    _fixedCalculationTypeIndex = 0;
	    _pointBasedCalculationTypeIndex = 0;
	    _axisBasedCalculationTypeIndex = 0;

	    // Destroy Render Textures
	    DestroyImmediate(_windVolumeHalf16);
	    DestroyImmediate(_windVolumeSInt32RAlpha);
	    DestroyImmediate(_windVolumeSInt32GAlpha);
	    DestroyImmediate(_windVolumeSInt32BAlpha);
	    DestroyImmediate(_windVolumeSInt32RBeta);
	    DestroyImmediate(_windVolumeSInt32GBeta);
	    DestroyImmediate(_windVolumeSInt32BBeta);
	    
	    // Release Compute Buffers
	    ReleaseComputeBuffer(ref _dummyComputeBuffer);
	    ReleaseComputeBuffer(ref _boxWindParamsBuffer);
	    ReleaseComputeBuffer(ref _sphereWindParamsBuffer);
	    ReleaseComputeBuffer(ref _cylinderWindParamsBuffer);
	    ReleaseComputeBuffer(ref _fixedCalculationParamsBuffer);
	    ReleaseComputeBuffer(ref _pointBasedCalculationParamsBuffer);
	    ReleaseComputeBuffer(ref _axisBasedCalculationParamsBuffer);
	    
	    // Reset render textures to null
	    _windVolumeHalf16 = null;
	    _windVolumeSInt32RAlpha = null;
	    _windVolumeSInt32GAlpha = null;
	    _windVolumeSInt32BAlpha = null;
	    _windVolumeSInt32RBeta = null;
	    _windVolumeSInt32GBeta = null;
	    _windVolumeSInt32BBeta = null;
	    
		// Debug clean up
		_initialized2DDebugUi = _initialized3DDebugScene = false;
		ReleaseComputeBuffer(ref _debugHandlePositionBuffer);
		ReleaseComputeBuffer(ref _debugArgsBuffer);
    }
    
    #region Wind Inheritance
    
    private void SetUpForWindInheritance(int kernel, CommandBuffer cmd)
    {
	    ValidateInput();
	    CheckIfNeedToInitResources();

	    // setup wind inheritance parameters in the compute shader
	    // render texture & parameters
	    if (_betaIsTarget)
	    {
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DXFrom",
			    _windVolumeSInt32RAlpha);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DYFrom",
			    _windVolumeSInt32GAlpha);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DZFrom",
			    _windVolumeSInt32BAlpha);
		    
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DXTo",
			    _windVolumeSInt32RBeta);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DYTo",
			    _windVolumeSInt32GBeta);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DZTo",
			    _windVolumeSInt32BBeta);
		    _betaIsTarget = !_betaIsTarget;
	    }
	    else
	    {
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DXFrom",
			    _windVolumeSInt32RBeta);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DYFrom",
			    _windVolumeSInt32GBeta);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DZFrom",
			    _windVolumeSInt32BBeta);
		    
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DXTo",
			    _windVolumeSInt32RAlpha);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DYTo",
			    _windVolumeSInt32GAlpha);
		    cmd.SetComputeTextureParam(csWindInheritance, kernel, "_GlobalWindVolume3DZTo",
			    _windVolumeSInt32BAlpha);
		    _betaIsTarget = !_betaIsTarget;
	    }
	    // _DeltaWindCenterPosition and _WindVolumeSizeXYZ
	    cmd.SetComputeVectorParam(csWindInheritance, "_DeltaWindCenterPosition", _deltaVolumePositionThisFrame);
	    if (_deltaVolumePositionThisFrame.sqrMagnitude > 0.1f)
	    {
		    Debug.Log(_deltaVolumePositionThisFrame);   
	    }
	    Vector3 windVolumeSizeXYZ = VolumeResolution;
	    windVolumeSizeXYZ *= sizePerVoxel;
	    cmd.SetComputeVectorParam(csWindInheritance, "_WindVolumeSizeXYZ", windVolumeSizeXYZ);
    }

    private void WindInheritance(CommandBuffer cmd)
    {
	    int kernel = csWindInheritance.FindKernel("CSMain");
        
	    SetUpForWindInheritance(kernel, cmd);
        
	    cmd.DispatchCompute(csInjectWindDirectionAndIntensity, kernel, 
		    VolumeResolution.x / _windInheritanceNumThreads.x,
		    VolumeResolution.y / _windInheritanceNumThreads.y,
		    VolumeResolution.z / _windInheritanceNumThreads.z);
    }

    #endregion
    
    #region Wind Injection

    private uint RegisterNewWindCalculationType(WindContributorObject windContributorObject)
    {
	    //Debug.Log("Registering for " + windContributorObject.Shape + " with Calculation Type of " + windContributorObject.CalculationType);
	    uint bufferIndexIdentifier = 0;
	    int count = WindContributorManager.GetWindCalculationTypeCount(windContributorObject.CalculationType);

	    switch (windContributorObject.CalculationType)
	    {
		    case BaseWindContributor.WindCalculationType.Fixed:
			    if (_fixedCalculationParams == null || _fixedCalculationParams.Length != count)
			    {
				    // reset the fixed calculation type index
				    _fixedCalculationTypeIndex = 0;
				    _fixedCalculationParams = new FixedCalculationParams[count];
			    }
			    // Add data into the calculation buffer
			    // Debug.Log("Adding new fixed calculation velocity of: " + windContributorObject.FixedWindVelocityWorldSpace);
			    _fixedCalculationParams[_fixedCalculationTypeIndex].fixedWindVelocityWorldSpace =
				    windContributorObject.FixedWindVelocityWorldSpace;
			    // 
			    // Debug.Log(windContributorObject.FixedWindVelocityWorldSpace);
			    bufferIndexIdentifier = _fixedCalculationTypeIndex;
			    _fixedCalculationTypeIndex++;
			    break;
		    case BaseWindContributor.WindCalculationType.Point:
			    if (_pointBasedCalculationParams == null || _pointBasedCalculationParams.Length != count)
			    {
				    // reset the fixed calculation type index
				    _pointBasedCalculationTypeIndex = 0;
				    _pointBasedCalculationParams = new PointBasedCalculationParams[count];
			    }
			    // Add data into the calculation buffer
			    _pointBasedCalculationParams[_pointBasedCalculationTypeIndex].pointBasedWindCalculationDataAlpha =
				    windContributorObject.PointBaseWindCalculationDataAlpha;
			    _pointBasedCalculationParams[_pointBasedCalculationTypeIndex].distanceDecayInfluence =
				    windContributorObject.PointBasedDistanceDecayInfluence;
			    bufferIndexIdentifier = _pointBasedCalculationTypeIndex;
			    _pointBasedCalculationTypeIndex++;
			    break;
		    case BaseWindContributor.WindCalculationType.AxisVortex:
			    if (_axisBasedCalculationParams == null || _axisBasedCalculationParams.Length != count)
			    {
				    // reset the fixed calculation type index
				    _axisBasedCalculationTypeIndex = 0;
				    _axisBasedCalculationParams = new AxisBasedCalculationParams[count];
			    }
			    // Add data into the calculation buffer
			    _axisBasedCalculationParams[_axisBasedCalculationTypeIndex].axisBasedWindCalculationDataAlpha =
				    windContributorObject.AxisBaseWindCalculationDataAlpha;
			    _axisBasedCalculationParams[_axisBasedCalculationTypeIndex].axisBasedWindCalculationDataBeta =
				    windContributorObject.AxisBaseWindCalculationDataBeta;
			    bufferIndexIdentifier = _axisBasedCalculationTypeIndex;
			    _axisBasedCalculationTypeIndex++;
			    break;
		    default:
			    throw new ArgumentOutOfRangeException(nameof(windContributorObject.CalculationType), windContributorObject.CalculationType, "The stored calculation type is not valid!");
	    }
	    
	    return bufferIndexIdentifier;
    }

    // Check each buffer type and see if need new compute buffer creation, Upload data to the compute shader for further calculation
    private void UploadCalculationTypeBuffers(int kernel, CommandBuffer cmd)
    {
	    // -- FIXED CALCULATION --
	    int fixedCalculationCount = WindContributorManager.GetWindCalculationTypeCount(BaseWindContributor.WindCalculationType.Fixed);
	    // need to recreate the compute buffer
	    if (_fixedCalculationParamsBuffer == null || (fixedCalculationCount != _fixedCalculationParamsBuffer.count && fixedCalculationCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _fixedCalculationParamsBuffer, fixedCalculationCount, Marshal.SizeOf(typeof(FixedCalculationParams)));
	    }

	    if (_fixedCalculationParams is { Length: > 0 } && fixedCalculationCount > 0)
	    {
		    //Debug.Log("Setting fixed calculation types, Count : " + _fixedCalculationParams.Length);
		    cmd.SetBufferData(_fixedCalculationParamsBuffer, _fixedCalculationParams);
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_fixedCalculationParams", _fixedCalculationParamsBuffer);   
	    }
	    else
	    {
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_fixedCalculationParams", _dummyComputeBuffer);   
	    }

	    // -- POINT BASED CALCULATION --
	    int pointBasedCalculationCount = WindContributorManager.GetWindCalculationTypeCount(BaseWindContributor.WindCalculationType.Point);
	    // need to recreate the compute buffer
	    if (_pointBasedCalculationParamsBuffer == null || (pointBasedCalculationCount != _pointBasedCalculationParamsBuffer.count && pointBasedCalculationCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _pointBasedCalculationParamsBuffer, pointBasedCalculationCount, Marshal.SizeOf(typeof(PointBasedCalculationParams)));
	    }

	    if (_pointBasedCalculationParams is {Length : > 0} && pointBasedCalculationCount > 0)
	    {
		    cmd.SetBufferData(_pointBasedCalculationParamsBuffer, _pointBasedCalculationParams);
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_pointBasedCalculationParams", _pointBasedCalculationParamsBuffer);
	    }
	    else
	    {
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_pointBasedCalculationParams", _dummyComputeBuffer);
	    }

	    // -- AXIS BASED CALCULATION --
	    int axisBasedCalculationCount = WindContributorManager.GetWindCalculationTypeCount(BaseWindContributor.WindCalculationType.AxisVortex);
	    // need to recreate the compute buffer
	    if (_axisBasedCalculationParamsBuffer == null || (axisBasedCalculationCount != _axisBasedCalculationParamsBuffer.count && axisBasedCalculationCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _axisBasedCalculationParamsBuffer, axisBasedCalculationCount, Marshal.SizeOf(typeof(AxisBasedCalculationParams)));
	    }

	    if (_axisBasedCalculationParams is {Length : > 0} && axisBasedCalculationCount > 0)
	    {
		    cmd.SetBufferData(_axisBasedCalculationParamsBuffer, _axisBasedCalculationParams);
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_axisBasedCalculationParams", _axisBasedCalculationParamsBuffer);
	    }
	    else
	    {
		    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_axisBasedCalculationParams", _dummyComputeBuffer);
	    }
    }
    
    /// <summary>
    /// Inject box wind contributor parameters into the created command buffers
    /// </summary>
    /// <param name="kernel">Compute shader kernel</param>
    /// <param name="cmd">Command Buffer of this rendering process.</param>>
    private void SetUpBoxWindComputeBuffers(int kernel, CommandBuffer cmd)
    {
	    int currentBoxWindCount =
		    WindContributorManager.GetWindShapeCount(BaseWindContributor.WindContributorShape.Box);
	    int count = _boxWindParamsBuffer == null ? 0 : _boxWindParamsBuffer.count;
	    if (currentBoxWindCount == 0)
	    {
		    // replace with dummy buffer
		    csInjectWindDirectionAndIntensity.SetBuffer(kernel, "_boxWindContributors", _dummyComputeBuffer);
		    return;
	    }

	    // If New box wind added/removed || Params array not created
	    if (_boxWindParams == null || _boxWindParams.Length != currentBoxWindCount)
	    {
		    _boxWindParams = new BoxWindParams[currentBoxWindCount];
	    }
	    
	    // Debug.Log(currentBoxWindCount);

	    // Iterate through existing wind contributors and calculate counts, create buffers.
	    int existingBoxContributorCount = 0;
	    HashSet<WindContributorObject> windContributors = WindContributorManager.Get();
	    for (var x = windContributors.GetEnumerator(); x.MoveNext();)
	    {
		    var windContributorObj = x.Current;
		    if (windContributorObj == null || 
		        windContributorObj.Shape != BaseWindContributor.WindContributorShape.Box || 
		        !windContributorObj.IsOn)
			    continue;
		    
		    _boxWindParams[existingBoxContributorCount].extendsLocal = windContributorObj.BoxWindLocalExtends;
		    _boxWindParams[existingBoxContributorCount].worldToLocalMatrix = windContributorObj.WindTransformWorldToLocal;
		    _boxWindParams[existingBoxContributorCount].calculationType = (uint)windContributorObj.CalculationType;
		    _boxWindParams[existingBoxContributorCount].calculationBufferIndex = RegisterNewWindCalculationType(windContributorObj);
		    existingBoxContributorCount++;
	    }
	    
		// need to recreate the compute buffer
	    if (_boxWindParamsBuffer == null || (existingBoxContributorCount != _boxWindParamsBuffer.count && existingBoxContributorCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _boxWindParamsBuffer, existingBoxContributorCount, Marshal.SizeOf(typeof(BoxWindParams)));
	    }
	    
	    csInjectWindDirectionAndIntensity.SetInt("_boxWindCount", existingBoxContributorCount);
	    cmd.SetBufferData(_boxWindParamsBuffer, _boxWindParams);
	    //_boxWindParamsBuffer.SetData(_boxWindParams);
	    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_boxWindContributors", _boxWindParamsBuffer);
    }

    private void SetUpSphereWindComputeBuffers(int kernel, CommandBuffer cmd)
    {
	    int currentSphereWindCount =
		    WindContributorManager.GetWindShapeCount(BaseWindContributor.WindContributorShape.Sphere);
	    if (currentSphereWindCount == 0)
	    {
		    // replace with dummy buffer
		    csInjectWindDirectionAndIntensity.SetBuffer(kernel, "_sphereWindContributors", _dummyComputeBuffer);
		    return;
	    }

	    // If New sphere wind added/removed || Params array not created
	    if (_sphereWindParams == null || _sphereWindParams.Length != currentSphereWindCount)
	    {
		    _sphereWindParams = new SphereWindParams[currentSphereWindCount];
	    }

	    // Iterate through existing wind contributors and calculate counts, create buffers.
	    int existingSphereContributorCount = 0;
	    HashSet<WindContributorObject> windContributors = WindContributorManager.Get();
	    for (var x = windContributors.GetEnumerator(); x.MoveNext();)
	    {
		    var windContributorObj = x.Current;
		    if (windContributorObj == null || 
		        windContributorObj.Shape != BaseWindContributor.WindContributorShape.Sphere || 
		        !windContributorObj.IsOn)
			    continue;
		    
		    _sphereWindParams[existingSphereContributorCount].extendSquared = windContributorObj.SphereWindExtendSquared;
		    _sphereWindParams[existingSphereContributorCount].centerWorldSpace = windContributorObj.WindCenter;
		    _sphereWindParams[existingSphereContributorCount].calculationType = (uint)windContributorObj.CalculationType;
		    _sphereWindParams[existingSphereContributorCount].calculationBufferIndex = RegisterNewWindCalculationType(windContributorObj);
		    existingSphereContributorCount++;
	    }
	    
		// need to recreate the compute buffer
	    if (_sphereWindParamsBuffer == null || (existingSphereContributorCount != _sphereWindParamsBuffer.count && existingSphereContributorCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _sphereWindParamsBuffer, existingSphereContributorCount, Marshal.SizeOf(typeof(SphereWindParams)));
	    }
	    
	    csInjectWindDirectionAndIntensity.SetInt("_sphereWindCount", existingSphereContributorCount);
	    cmd.SetBufferData(_sphereWindParamsBuffer, _sphereWindParams);
	    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_sphereWindContributors", _sphereWindParamsBuffer);
    }
    
    private void SetUpCylinderWindComputeBuffers(int kernel, CommandBuffer cmd)
    {
	    int currentCylinderWindCount =
		    WindContributorManager.GetWindShapeCount(BaseWindContributor.WindContributorShape.Cylinder);
	    if (currentCylinderWindCount == 0)
	    {
		    // replace with dummy buffer
		    csInjectWindDirectionAndIntensity.SetBuffer(kernel, "_cylinderWindContributors", _dummyComputeBuffer);
		    return;
	    }

	    // If New sphere wind added/removed || Params array not created
	    if (_cylinderWindParams == null || _cylinderWindParams.Length != currentCylinderWindCount)
	    {
		    _cylinderWindParams = new CylinderWindParams[currentCylinderWindCount];
	    }

	    // Iterate through existing wind contributors and calculate counts, create buffers.
	    int existingCylinderContributorCount = 0;
	    HashSet<WindContributorObject> windContributors = WindContributorManager.Get();
	    for (var x = windContributors.GetEnumerator(); x.MoveNext();)
	    {
		    var windContributorObj = x.Current;
		    if (windContributorObj == null || 
		        windContributorObj.Shape != BaseWindContributor.WindContributorShape.Cylinder || 
		        !windContributorObj.IsOn)
			    continue;
		    
		    _cylinderWindParams[existingCylinderContributorCount].extends = windContributorObj.CylinderWindLocalExtendsRadiusSquared;
		    _cylinderWindParams[existingCylinderContributorCount].worldToLocalMatrix = windContributorObj.WindTransformWorldToLocal;
		    _cylinderWindParams[existingCylinderContributorCount].calculationType = (uint)windContributorObj.CalculationType;
		    _cylinderWindParams[existingCylinderContributorCount].calculationBufferIndex = RegisterNewWindCalculationType(windContributorObj);
		    existingCylinderContributorCount++;
	    }
	    
		// need to recreate the compute buffer
	    if (_cylinderWindParamsBuffer == null || (existingCylinderContributorCount != _cylinderWindParamsBuffer.count && existingCylinderContributorCount > 0))
	    {
		    CheckIfNeedToCreateComputeBuffer(ref _cylinderWindParamsBuffer, existingCylinderContributorCount, Marshal.SizeOf(typeof(CylinderWindParams)));
	    }
	    
	    csInjectWindDirectionAndIntensity.SetInt("_cylinderWindCount", existingCylinderContributorCount);
	    cmd.SetBufferData(_cylinderWindParamsBuffer, _cylinderWindParams);
	    cmd.SetComputeBufferParam(csInjectWindDirectionAndIntensity, kernel, "_cylinderWindContributors", _cylinderWindParamsBuffer);
    }

    private void SetUpForWindInjection(int kernel, CommandBuffer cmd)
    {
        ValidateInput();
        CheckIfNeedToInitResources();
        
        SetUpBoxWindComputeBuffers(kernel, cmd);
        SetUpSphereWindComputeBuffers(kernel, cmd);
        SetUpCylinderWindComputeBuffers(kernel, cmd);
        
        UploadCalculationTypeBuffers(kernel, cmd);
        
        // setup wind injection parameters in the compute shader
        // render texture & parameters
        if (_betaIsTarget)
        {
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DX",
    		    _windVolumeSInt32RAlpha);
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DY",
    		    _windVolumeSInt32GAlpha);
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DZ",
    		    _windVolumeSInt32BAlpha);
    	    //_betaIsTarget = !_betaIsTarget;
    	    // TODO:: BE CAREFUL OF THE CODE ABOVE
        }
        else
        {
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DX",
    		    _windVolumeSInt32RBeta);
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DY",
    		    _windVolumeSInt32GBeta);
    	    cmd.SetComputeTextureParam(csInjectWindDirectionAndIntensity, kernel, "_GlobalWindVolume3DZ",
    		    _windVolumeSInt32BBeta);
    	    //_betaIsTarget = !_betaIsTarget;
    	    // TODO:: BE CAREFUL OF THE CODE ABOVE
        }
        
        _fixedCalculationTypeIndex = 0;
        _pointBasedCalculationTypeIndex = 0;
        _axisBasedCalculationTypeIndex = 0;
    }

    private void WindInjection(CommandBuffer cmd)
    {
        int kernel = csInjectWindDirectionAndIntensity.FindKernel("CSMain");
        
        SetUpForWindInjection(kernel, cmd);
        
        cmd.DispatchCompute(csInjectWindDirectionAndIntensity, kernel, 
    	    VolumeResolution.x / _windInjectionNumThreads.x,
    	    VolumeResolution.y / _windInjectionNumThreads.y,
    	    VolumeResolution.z / _windInjectionNumThreads.z);
    }

    #endregion

    #region Wind Diffusion

	private void SetUpForWindDiffusion(CommandBuffer cmd)
    {
	    cmd.SetComputeFloatParam(csWindDiffusion, "_DiffusionStrength", diffusionIntensity);
	    //cmd.SetComputeFloatParam(csWindDiffusion, "_DeltaTime", Time.deltaTime);
	    cmd.SetComputeIntParams(csWindDiffusion, "_WindVolumeTextureSize", new int[]{32, 16, 32});
    }

    private void WindDiffusion(CommandBuffer cmd)
    {
	    int kernelX = csWindDiffusion.FindKernel("DiffusionX");
	    int kernelY = csWindDiffusion.FindKernel("DiffusionY");
	    int kernelZ = csWindDiffusion.FindKernel("DiffusionZ");
	    
	    SetUpForWindDiffusion(cmd);
	    
	    // dispatch multiple times
	    for (int i = 0; i < windDiffusionIteration; i++)
	    {
		    if (_betaIsTarget) // target is beta (prev prev is beta)
		    {
			    cmd.SetGlobalTexture("_WindTexturePrevX", _windVolumeSInt32RAlpha);
			    cmd.SetGlobalTexture("_WindTexturePrevY", _windVolumeSInt32GAlpha);
			    cmd.SetGlobalTexture("_WindTexturePrevZ", _windVolumeSInt32BAlpha);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevX", _windVolumeSInt32RBeta);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevY", _windVolumeSInt32GBeta);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevZ", _windVolumeSInt32BBeta);
			    //cmd.SetComputeTextureParam(csWindDiffusion, kernel, "_WindTexturePrev", _windVolumeAlpha);
			    //cmd.SetComputeTextureParam(csWindDiffusion, kernel, "_WindTexturePrevPrev", _windVolumeBeta);
			    _betaIsTarget = !_betaIsTarget;
		    }
		    else // target is alpha (prev prev is alpha)
		    {
			    cmd.SetGlobalTexture("_WindTexturePrevX", _windVolumeSInt32RBeta);
			    cmd.SetGlobalTexture("_WindTexturePrevY", _windVolumeSInt32GBeta);
			    cmd.SetGlobalTexture("_WindTexturePrevZ", _windVolumeSInt32BBeta);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevX", _windVolumeSInt32RAlpha);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevY", _windVolumeSInt32GAlpha);
			    cmd.SetGlobalTexture("_WindTexturePrevPrevZ", _windVolumeSInt32BAlpha);
			    //cmd.SetComputeTextureParam(csWindDiffusion, kernel, "_WindTexturePrev", _windVolumeBeta);
			    //cmd.SetComputeTextureParam(csWindDiffusion, kernel, "_WindTexturePrevPrev", _windVolumeAlpha);
			    _betaIsTarget = !_betaIsTarget;
		    }
		    
		    // Dispatch X
		    cmd.DispatchCompute(csWindDiffusion, kernelX, 
			    VolumeResolution.x / _windDiffusionNumThreads.x,
			    VolumeResolution.y / _windDiffusionNumThreads.y, 
			    VolumeResolution.z / _windDiffusionNumThreads.z);
		    
		    // Dispatch Y
		    cmd.DispatchCompute(csWindDiffusion, kernelY, 
			    VolumeResolution.x / _windDiffusionNumThreads.x,
			    VolumeResolution.y / _windDiffusionNumThreads.y, 
			    VolumeResolution.z / _windDiffusionNumThreads.z);
		    
		    // Dispatch Z
		    cmd.DispatchCompute(csWindDiffusion, kernelZ, 
			    VolumeResolution.x / _windDiffusionNumThreads.x,
			    VolumeResolution.y / _windDiffusionNumThreads.y, 
			    VolumeResolution.z / _windDiffusionNumThreads.z);
	    }
    }

    #endregion
    
    #region Wind Advection

        private void SetUpForWindAdvection(CommandBuffer cmd)
        {
    	    ValidateInput();
    	    
    	    // cmd.SetComputeFloatParam(csWindAdvection, "_DeltaTime", Time.deltaTime);
            cmd.SetComputeVectorParam(csWindInheritance, "_DeltaWindCenterPosition", _deltaVolumePositionThisFrame);
            cmd.SetComputeIntParams(csWindAdvection, "_WindVolumeTextureSize", new int[]{32, 16, 32});
            cmd.SetComputeFloatParam(csWindAdvection, "_WindVoxelSize", sizePerVoxel);
    	    cmd.SetComputeFloatParam(csWindAdvection, "_WindAttenuationStrength", windAdvectionAttenuationStrength);
            cmd.SetComputeFloatParam(csWindAdvection, "_WindAdvectionIntensity", windAdvectionIntensity);
    	    
    	    // Setup textures
    	    if (_betaIsTarget) // target is beta (prev prev is beta)
    	    {
	            cmd.SetGlobalTexture("_WindTexturePrevX", _windVolumeSInt32RAlpha);
    		    cmd.SetGlobalTexture("_WindTexturePrevY", _windVolumeSInt32GAlpha);
    		    cmd.SetGlobalTexture("_WindTexturePrevZ", _windVolumeSInt32BAlpha);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevX", _windVolumeSInt32RBeta);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevY", _windVolumeSInt32GBeta);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevZ", _windVolumeSInt32BBeta);
    		    _betaIsTarget = !_betaIsTarget;
    	    }
    	    else // target is alpha (prev prev is alpha)
    	    {
    		    cmd.SetGlobalTexture("_WindTexturePrevX", _windVolumeSInt32RBeta);
    		    cmd.SetGlobalTexture("_WindTexturePrevY", _windVolumeSInt32GBeta);
    		    cmd.SetGlobalTexture("_WindTexturePrevZ", _windVolumeSInt32BBeta);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevX", _windVolumeSInt32RAlpha);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevY", _windVolumeSInt32GAlpha);
    		    cmd.SetGlobalTexture("_WindTexturePrevPrevZ", _windVolumeSInt32BAlpha);
    		    _betaIsTarget = !_betaIsTarget;
    	    }
        }
    
        private void WindAdvection(CommandBuffer cmd) // forward and backward advection
        {
	        int kernelForwardXYZ = csWindAdvection.FindKernel("ForwardAdvectionXYZ");
	        int kernelBackwardXYZ = csWindAdvection.FindKernel("BackwardAdvectionXYZ");
	        
    	    int kernelForwardX = csWindAdvection.FindKernel("ForwardAdvectionX");
    	    int kernelForwardY = csWindAdvection.FindKernel("ForwardAdvectionY");
    	    int kernelForwardZ = csWindAdvection.FindKernel("ForwardAdvectionZ");
    	    int kernelBackwardX = csWindAdvection.FindKernel("BackwardAdvectionX");
    	    int kernelBackwardY = csWindAdvection.FindKernel("BackwardAdvectionY");
    	    int kernelBackwardZ = csWindAdvection.FindKernel("BackwardAdvectionZ");
    	    int kernelCleanPrevPrev = csWindAdvection.FindKernel("AdvectionCleanUp");
    	    
    	    SetUpForWindAdvection(cmd);
    
    	    // Clean up before adding new values
    	    cmd.DispatchCompute(csWindAdvection, kernelCleanPrevPrev, 
    		    VolumeResolution.x / _windAdvectionNumThreads.x, 
    		    VolumeResolution.y / _windAdvectionNumThreads.y, 
    		    VolumeResolution.z / _windAdvectionNumThreads.z);
    	    
    	    // Forward Advection
            cmd.DispatchCompute(csWindAdvection, kernelForwardXYZ, 
	            VolumeResolution.x / _windAdvectionNumThreads.x, 
	            VolumeResolution.y / _windAdvectionNumThreads.y, 
	            VolumeResolution.z / _windAdvectionNumThreads.z);
            
    	    //cmd.DispatchCompute(csWindAdvection, kernelForwardX, 
    		//    VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//    VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//    VolumeResolution.z / _windAdvectionNumThreads.z);
    	    //cmd.DispatchCompute(csWindAdvection, kernelForwardY, 
    		//    VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//    VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//    VolumeResolution.z / _windAdvectionNumThreads.z);
    	    //cmd.DispatchCompute(csWindAdvection, kernelForwardZ, 
    		//    VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//    VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//    VolumeResolution.z / _windAdvectionNumThreads.z);
    
    	    // Backward Advection
            cmd.DispatchCompute(csWindAdvection, kernelBackwardXYZ, 
	            VolumeResolution.x / _windAdvectionNumThreads.x, 
	            VolumeResolution.y / _windAdvectionNumThreads.y, 
	            VolumeResolution.z / _windAdvectionNumThreads.z);
            
            // cmd.DispatchCompute(csWindAdvection, kernelBackwardX, 
    		//     VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//     VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//     VolumeResolution.z / _windAdvectionNumThreads.z);
    	    // cmd.DispatchCompute(csWindAdvection, kernelBackwardY, 
    		//     VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//     VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//     VolumeResolution.z / _windAdvectionNumThreads.z);
    	    // cmd.DispatchCompute(csWindAdvection, kernelBackwardZ, 
    		//     VolumeResolution.x / _windAdvectionNumThreads.x, 
    		//     VolumeResolution.y / _windAdvectionNumThreads.y, 
    		//     VolumeResolution.z / _windAdvectionNumThreads.z);
        }

    #endregion
    
    #region Wind Export

        private void SetUpForWindExport(int kernel, CommandBuffer cmd)
        {
    	    ValidateInput();
    
    	    //cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSource", _windVolumeInt32);
    	    cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureTarget", _windVolumeHalf16);
    	    
    	    if (_betaIsTarget) // next target is beta, we should use alpha now
    	    {
    			cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceX", _windVolumeSInt32RAlpha);
    			cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceY", _windVolumeSInt32GAlpha);
    			cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceZ", _windVolumeSInt32BAlpha);
    	    }
    	    else // use beta
    	    {
    		    cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceX", _windVolumeSInt32RBeta);
    		    cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceY", _windVolumeSInt32GBeta);
    		    cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_WindTextureSourceZ", _windVolumeSInt32BBeta);
    	    }
    	    
    	    // Global wind calculation moved here
    	    cmd.SetGlobalVector("_WindNoisePosFrequency", noisePositionFrequency);
    	    cmd.SetGlobalVector("_AmbientWind", _ambientWindNormalized);
    	    cmd.SetGlobalFloat("_NoiseWindIntensity", noiseWindIntensity);
    	    Vector3 normalizedNoiseWindDirection = noiseWindScrollDirection.normalized;
    	    cmd.SetGlobalVector("_WindNoiseScrollDirAndSpeed",
    		    new Vector4(normalizedNoiseWindDirection.x, normalizedNoiseWindDirection.y, normalizedNoiseWindDirection.z,
    			    noiseWindScrollSpeed));
    	    
    	    if (textureNoise)
    	    {
    		    cmd.EnableKeyword(csIntToHalfExport, _windExportTextureNoise);
    		    cmd.DisableKeyword(csIntToHalfExport, _windExportFunctionNoise);
    		    cmd.SetComputeTextureParam(csIntToHalfExport, kernel, "_Noise", textureNoise2D);
    		    //csInjectWindDirectionAndIntensity.SetTexture(kernel, "_Noise", textureNoise2D);
    	    }
    	    else
    	    {
    		    cmd.EnableKeyword(csIntToHalfExport, _windExportFunctionNoise);
    		    cmd.DisableKeyword(csIntToHalfExport, _windExportTextureNoise);
    	    }
        }
    
        private void WindExport(CommandBuffer cmd) // transform the int32 texture to ARGBHalf format
        {
    	    int kernel = csIntToHalfExport.FindKernel("CSMain");
    	    
    	    SetUpForWindExport(kernel, cmd);
    
    		cmd.DispatchCompute(csIntToHalfExport, kernel, 
    			VolumeResolution.x / _windExportNumThreads.x, 
    			VolumeResolution.y / _windExportNumThreads.y, 
    			VolumeResolution.z / _windExportNumThreads.z);
        }

    #endregion

    #region Debug

        private void UpdateDebugBuffers2DUi()
        {
    	    if (_initialized2DDebugUi)
    	    {
    		    return;
    	    }
    	    
    	    //InitDebugRenderTextureSliceXZ(ref _windVolumeSliceArray);
    	    
    	    _initialized2DDebugUi = true;
        }
    
        private void Debug2DUiTextureSlices(RenderTexture source, RenderTexture dest)
        {
    	    if (!_initialized2DDebugUi)
    	    {
    		    UpdateDebugBuffers2DUi();
    		    return;
    	    }
    	    
    	    // use post processing to debug and display the render texture array
    	    // Graphics.Blit(source, dest, debug2DUiMaterial);
        }
    
        private void UpdateDebugBuffers3DScene()
        {
    	    if (_initialized3DDebugScene)
    	    {
    		    return;
    	    }
    	    
    	    if (debugInstanceMesh == null || instanceMaterial == null)
    	    {
    		    return;
    	    }
    
    	    // Ensure sub mesh index in range
    	    if (debugInstanceMesh != null)
    	    {
    		    subMeshIndex = Mathf.Clamp(subMeshIndex, 0, debugInstanceMesh.subMeshCount - 1);
            }
    
    	    // Setup buffer of Offset Positions that don't change during game
    	    _debugHandlePositionBuffer?.Release();
    	    _debugHandlePositionBuffer = new ComputeBuffer(InstanceCount, 16);
    	    Vector4[] positions = new Vector4[InstanceCount];
    	    // https://stackoverflow.com/questions/7367770/how-to-flatten-or-index-3d-array-in-1d-array
    	    for (int x = 0; x < VolumeResolution.x; x++)
    	    {
    		    for (int y = 0; y < VolumeResolution.y; y++)
    		    {
    			    for (int z = 0; z < VolumeResolution.z; z++)
    			    {
    				    // id as (i, j, k), calculate flattened id and its corresponding position
                        // positions[(x * VolumeResolution.y + y) * VolumeResolution.z + z] =
	                    //     sizePerVoxel * (new Vector3(x, y, z) - VolumeResolutionMinusOne / 2.0f);
                        positions[x + VolumeResolution.x * (y + VolumeResolution.y * z)] =
    					    sizePerVoxel * (new Vector3(x, y, z) - VolumeResolutionMinusOne / 2.0f);
    				    //Debug.Log("New position offset: " +
    				    //          positions[i + _volumeResolution.x * (j + _volumeResolution.y * k)]);
    			    }
    		    }
    	    }
    	    _debugHandlePositionBuffer.SetData(positions);
    	    instanceMaterial.SetBuffer("_PositionOffset", _debugHandlePositionBuffer);
    
    	    // Indirect Args
    	    if (debugInstanceMesh != null)
    	    {
    		    args[0] = (uint)debugInstanceMesh.GetIndexCount(subMeshIndex); // index count per instance
    		    args[1] = (uint)InstanceCount; // instance count
    		    args[2] = (uint)debugInstanceMesh.GetIndexStart(subMeshIndex); // start index location
    		    args[3] = (uint)debugInstanceMesh.GetBaseVertex(subMeshIndex); // base vertex location
    		    // start instance location
    		    //Debug.Log("Initializing Debug Args Buffer: " + args[0] + "," + args[1] + "," + args[2] + "," + args[3]);
    	    }
    	    else
    	    {
    		    args[0] = args[1] = args[2] = args[3] = 0;
    	    }
    	    _debugArgsBuffer.SetData(args);
    
    	    _cachedInstanceCount = InstanceCount;
    	    _cachedSubMeshIndex = subMeshIndex;
    	    _initialized3DDebugScene = true;
        }
    
        private void Debug3DSceneDisplay()
        {
    	    // Read wind volume texture and use Gizmos & Handles.ArrowHandleCap() to draw
    	    /*
    	    if(_readBackRequest.done && !_readBackRequest.hasError)
    	    {
    		    //Readback And show result on texture
    		    _windDirectionAndIntensitiesArray = _readBackRequest.GetData<Vector4>();
    		    //Request AsyncReadback again
    		    _readBackRequest = AsyncGPUReadback.Request(_windDirectionIntensityVolume);
    		    if (Input.GetMouseButton(0))
    		    {
    			    Debug.Log(_windDirectionAndIntensitiesArray[2]);   
    		    }
    	    }
    	    */
    	    // Use DrawMeshInstancedIndirect to display wind vectors https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstancedIndirect.html
    	    //Graphics.DrawMeshInstancedIndirect();
    
    	    if (!_initialized3DDebugScene)
    	    {
    		    UpdateDebugBuffers3DScene();
                return;
    	    }
    	    
    	    if (debugInstanceMesh == null || instanceMaterial == null)
    	    {
    		    return;
    	    }
    	    
    	    // Position that change - global vector already set
    	    // instanceMaterial.SetVector("_WindCenterPosition", centerVolumePosition);
    	    
    	    if (_cachedInstanceCount != InstanceCount || _cachedSubMeshIndex != subMeshIndex)
    	    {
    		    UpdateDebugBuffers3DScene();
    	    }
    
    	    Graphics.DrawMeshInstancedIndirect(debugInstanceMesh, subMeshIndex, instanceMaterial,
    		    new Bounds(centerVolumePosition,
    			    new Vector3(VolumeResolution.x, VolumeResolution.y, VolumeResolution.z) * (sizePerVoxel + 0.1f)),
    		    _debugArgsBuffer);
        }

    #endregion
    
    private void SetupWindConstantUniforms()
    {
	    Shader.SetGlobalFloat("_WindVolumeVoxelSize", sizePerVoxel);
    }

    private void SetUpWindVariantUniforms(CommandBuffer cmd)
    {
	    var ambientWindNormalized = new Vector3(ambientWind.x, ambientWind.y, ambientWind.z).normalized;
	    _ambientWindNormalized = new Vector4(ambientWindNormalized.x, ambientWindNormalized.y,
		    ambientWindNormalized.z, ambientWind.w);
	    cmd.SetGlobalVector("_WindVolumeCenterPosition", centerVolumePosition);

	    // UVW - FloatToIntFloor((currentPos - centerPos) / windAffectRange) + WindVolumeSize/2;
	    // Global Texture - Wind Volume
	    // Global Vector - Wind Center Position
	    // Global Vector - Wind Affect Range
	    // Global Vector - Wind Volume Texture Size
    }

    /// <summary>
    /// Create 3D Texture and Command Buffers for future use.
    /// </summary>
    private void CheckIfNeedToInitResources ()
    {
	    _windExportFunctionNoise = new LocalKeyword(csIntToHalfExport, "FUNCTION_NOISE");
	    _windExportTextureNoise = new LocalKeyword(csIntToHalfExport, "TEXTURE_NOISE");
	    
	    // Volume
	    CheckIfNeedToInitHalfVolume(ref _windVolumeHalf16);
	    //CheckIfNeedToInitHalfVolume(ref _windVolumeBeta);
	    
	    // Int volumes
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32RAlpha);
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32GAlpha);
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32BAlpha);
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32RBeta);
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32GBeta);
	    CheckIfNeedToInitInt32Volume(ref _windVolumeSInt32BBeta);
	    
	    // Compute buffers
	    int fixedCalculationCount = 0, pointBasedCalculationCount = 0, axisBasedCalculationCount = 0;
	    int boxContributorCount = 0, sphereContributorCount = 0, cylinderContributorCount = 0;
	    
	    // Iterate through existing wind contributors and calculate counts, create buffers.
	    HashSet<WindContributorObject> fogLights = WindContributorManager.Get();
	    for (var x = fogLights.GetEnumerator(); x.MoveNext();)
	    {
	        var windContributorObj = x.Current;
	        if (windContributorObj == null)
	    	    continue;

	        bool isOn = windContributorObj.IsOn;

	        if (isOn)
	        {
		        switch(windContributorObj.Shape)
		        {
			        case BaseWindContributor.WindContributorShape.Box : boxContributorCount++; break;
			        case BaseWindContributor.WindContributorShape.Sphere : sphereContributorCount++; break;
			        case BaseWindContributor.WindContributorShape.Cylinder : cylinderContributorCount++; break;
		        }

		        switch (windContributorObj.CalculationType)
		        {
			        case BaseWindContributor.WindCalculationType.Fixed : fixedCalculationCount++; break;
			        case BaseWindContributor.WindCalculationType.Point : pointBasedCalculationCount++; break;
			        case BaseWindContributor.WindCalculationType.AxisVortex : axisBasedCalculationCount++; break;
		        }   
	        }
	    }

	    CheckIfNeedToCreateComputeBuffer(ref _boxWindParamsBuffer, boxContributorCount, Marshal.SizeOf(typeof(BoxWindParams)));
	    CheckIfNeedToCreateComputeBuffer(ref _cylinderWindParamsBuffer, cylinderContributorCount, Marshal.SizeOf(typeof(CylinderWindParams)));
	    CheckIfNeedToCreateComputeBuffer(ref _sphereWindParamsBuffer, sphereContributorCount, Marshal.SizeOf(typeof(SphereWindParams)));
	    
	    CheckIfNeedToCreateComputeBuffer(ref _fixedCalculationParamsBuffer, fixedCalculationCount, Marshal.SizeOf(typeof(FixedCalculationParams)));
	    CheckIfNeedToCreateComputeBuffer(ref _pointBasedCalculationParamsBuffer, pointBasedCalculationCount, Marshal.SizeOf(typeof(PointBasedCalculationParams)));
	    CheckIfNeedToCreateComputeBuffer(ref _axisBasedCalculationParamsBuffer, axisBasedCalculationCount, Marshal.SizeOf(typeof(AxisBasedCalculationParams)));
	    // dummy buffer preventing null data injecting
	    CheckIfNeedToCreateComputeBuffer(ref _dummyComputeBuffer, 1, 4);
    }

    private void CheckIfNeedToInitHalfVolume(ref RenderTexture volume)
    {
	    if (volume)
	    {
		    return;
	    }

	    volume = new RenderTexture(VolumeResolution.x, VolumeResolution.y, 0,
		    RenderTextureFormat.ARGBHalf)
	    {
		    volumeDepth = VolumeResolution.z,
		    dimension = TextureDimension.Tex3D,
		    enableRandomWrite = true
	    };
	    volume.Create();
    }
    
    private void ForceInitHalfVolume([NotNull] ref RenderTexture volume)
    {
	    volume = new RenderTexture(VolumeResolution.x, VolumeResolution.y, 0,
		    RenderTextureFormat.ARGBHalf)
	    {
		    volumeDepth = VolumeResolution.z,
		    dimension = TextureDimension.Tex3D,
		    enableRandomWrite = true
	    };
	    volume.Create();
    }

    private void CheckIfNeedToInitInt32Volume(ref RenderTexture volume)
    {
	    if (volume)
	    {
		    return;
	    }

	    volume = new RenderTexture(VolumeResolution.x, VolumeResolution.y, 0,
		    RenderTextureFormat.RInt);
	    volume.volumeDepth = VolumeResolution.z;
	    volume.dimension = TextureDimension.Tex3D;
	    volume.enableRandomWrite = true;
	    volume.Create();
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
}
