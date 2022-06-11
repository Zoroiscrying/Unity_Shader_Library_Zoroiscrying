using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using ZoroiscryingUnityShaderLibrary.Shaders.ComputeShaderRelated;

/// <summary>
/// Global Wind Calculation process:
/// 1. Inherit former wind velocities and directions to the current 3D Texture by
///     calculating the difference of former agent position and the current one.
/// 2. Update and inject existing wind contributor objects' wind directions and
///     intensities to the current 3D Texture.
/// 3. Propagate the current wind directions and intensities by updating the 3D Texture.
/// </summary>

[ExecuteInEditMode]
public class GlobalWind3D : MonoBehaviour
{
	// debug CPU read back
	[Header("Debugging")] 
	[SerializeField] private Mesh debugInstanceMesh;
	[SerializeField] private int subMeshIndex = 0;
	[SerializeField] private Material instanceMaterial;
	private int InstanceCount
	{
		get => _volumeResolution.x * _volumeResolution.y * _volumeResolution.z;
	}
	private int _cachedInstanceCount = -1;
	private int _cachedSubMeshIndex = -1;
	private ComputeBuffer _debugHandlePositionBuffer;
	private ComputeBuffer _debugArgsBuffer;
	private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
	//private NativeArray<Vector4> _windDirectionAndIntensitiesArray;
	//private AsyncGPUReadbackRequest _readBackRequest;
	
    // hidden properties
    public ComputeShader csWindInheritance;
    public ComputeShader csInjectWindDirectionAndIntensity;
    public ComputeShader csWindPropagation;
    
    // user-defined variables
    [SerializeField] private Transform windCenterTransform;
    [SerializeField] private bool debug = false;
    [Header("Propagation Variables")]
    [Range(0f, 0.99f)] [SerializeField]
    private float propagationIntensityMultiplier;
    [Min(0.01f)] [SerializeField]
    private float propagationIntensityThreshold;

    [Header("Global Wind")] 
    [SerializeField] private Vector4 ambientWind = Vector4.zero; // rgb direction and a intensity
    private Vector4 _ambientWindNormalized = Vector4.zero;
    [SerializeField] private float noiseWindIntensity = 1.0f;
    [SerializeField] private Vector3 noiseWindScrollDirection = Vector3.one;
    [SerializeField] private float noiseWindScrollSpeed = 1;
    [SerializeField] private bool textureNoise = false;
    [SerializeField] private Texture2D textureNoise2D;
    [SerializeField] private Vector3 noisePositionFrequency = Vector3.one;
    [SerializeField] private Vector3 noisePositionOffset = Vector3.zero;

    [Header("Wind Volume Density")] // 64 32 64 xyz
    [SerializeField] private Vector3 centerVolumePosition = Vector3.zero;
    [SerializeField] private float sizePerVoxel = 1.0f; // voxel size for wind texture sampling
    //[SerializeField] private float globalDensityMult = 1.0f; // position density for sampling
    private Vector3Int _windInheritanceNumThreads = new Vector3Int(8, 4, 8);
    private Vector3Int _windInjectionNumThreads = new Vector3Int(8, 4, 8);
    private Vector3Int _windPropagationNumThreads = new Vector3Int(8, 4, 8);
    private RenderTexture _windDirectionIntensityVolume;
    // private RenderTexture _windIntensityDirectionVolume2; // possibly for wind advocate
    private Vector3Int _volumeResolution = new Vector3Int(64, 32, 64);
    private Vector3Int _volumeResolutionMinusOne => _volumeResolution - new Vector3Int(1, 1, 1);

    // injection structs and params
    // struct params
    // params[] windInjectorParams;
    // ComputeBuffer _windInjectorParams;
    
    // Box/Capsule Wind Contributor, calculates collision with the 3D volume via boundaries
    // Calculates the product of the three axis of the box wind with the vector from center to current location,
    // compare the result with the extend (absolute less than extend, then intensity is 1.0, otherwise 0.0)
    public struct BoxWindParams
    {
	    public float3 center;
	    public float3 extends;
	    public float3x3 rotation;
    }
    private BoxWindParams[] _boxWindParams;
    private ComputeBuffer _boxWindParamsBuffer;
    
    // Cylinder Wind Contributor, calculates collision with the 3D volume via boundaries
    // Calculates the product of the three axis of the cylinder wind with the vector from center to current location,
    // compare the result with the extend (absolute less than extend, then intensity is 1.0)
    public struct CylinderWindParams
    {
	    public float3 center;
	    public float2 extends; // up-down extend, radius extend
	    public float3x3 rotation;
	    //tbd
    }
    private CylinderWindParams[] _cylinderWindParams;
    private ComputeBuffer _cylinderWindParamsBuffer;

    // TODO:: Sphere Wind? Other types of wind?
    
    // dummy command buffer for null buffer inject
    private ComputeBuffer _dummyCommandBuffer;

    private void OnEnable()
    {
	    ValidateInput();
	    InitResources();
	    SetupWindConstantUniforms();
	    SetUpWindVariantUniforms();
	    
	    // Debug with text info
	    //_windDirectionAndIntensitiesArray =
		    //new NativeArray<Vector4>(_volumeResolution.x * _volumeResolution.y * _volumeResolution.z, Allocator.Temp);
	    //_readBackRequest = AsyncGPUReadback.Request(_windDirectionIntensityVolume);
	    //Debug.Log("Read Back Request initialized.");
	    
	    // Dealing with debug drawing mesh instanced
	    Debug.Log("Setup Debugs");
	    if (debugInstanceMesh == null || instanceMaterial == null)
	    {
		    return;
	    }
	    _debugArgsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
	    // Update buffers 
	    UpdateDebugBuffers();
    }

    private void OnDestroy()
    {
        CleanUp();
    }

    private void OnDisable()
    {
        CleanUp();
    }

    private void Update()
    {
	    if (windCenterTransform)
	    {
		    centerVolumePosition = windCenterTransform.position;
		    Shader.SetGlobalVector("_WindVolumeCenterPosition", centerVolumePosition);
	    }
	    
	    if (debug)
	    {
		    DebugDisplay();
	    }
	    
	    //WindInheritance();
	    WindInjection();
	    //WindPropagation();
    }
    
    private void ValidateInput()
    {
	    //
    }
    
    private void CleanUp()
    {
	    Debug.Log("Clean Up");
	    DestroyImmediate(_windDirectionIntensityVolume);
	    ReleaseComputeBuffer(ref _dummyCommandBuffer);
	    
	    // DestroyImmediate(RenderTextures);
        // ReleaseComputeBuffer(ref ComputeBuffers);
        // RenderTextures = null;
        _windDirectionIntensityVolume = null;

        if (debug)
        {
	        if (_debugHandlePositionBuffer != null)
	        {
		        _debugHandlePositionBuffer.Release();
	        }

	        _debugHandlePositionBuffer = null;

	        if (_debugArgsBuffer != null)
	        {
		        _debugArgsBuffer.Release();
	        }

	        _debugArgsBuffer = null;
        }
    }

    /// <summary>
    /// Inject box wind contributor parameters into the created command buffers
    /// </summary>
    /// <param name="kernel">Compute shader kernel</param>
    private void SetUpBoxWindCommandBuffers(int kernel)
    {
	    int count = _boxWindParamsBuffer == null ? 0 : _boxWindParamsBuffer.count;
	    csInjectWindDirectionAndIntensity.SetFloat("_boxWindCount", count);
	    if (count == 0)
	    {
		    // cannot set the buffer
		    csInjectWindDirectionAndIntensity.SetBuffer(kernel, "_boxWindContributors", _dummyCommandBuffer);
		    return;
	    }

	    if (_boxWindParams == null || _boxWindParams.Length != count)
	    {
		    _boxWindParams = new BoxWindParams[count];
	    }
	    
	    // iterate through existing wind contributors "class WindContributor"
	    
	    /*
	    if (m_PointLightParams == null || m_PointLightParams.Length != count)
		    m_PointLightParams = new PointLightParams[count];

	    HashSet<FogLight> fogLights = LightManagerFogLights.Get();

	    int j = 0;
	    for (var x = fogLights.GetEnumerator(); x.MoveNext();)
	    {
		    var fl = x.Current;
		    if (fl == null || fl.type != FogLight.Type.Point || !fl.isOn)
			    continue;

		    Light light = fl.light;
		    m_PointLightParams[j].pos = light.transform.position;
		    float range = light.range * fl.m_RangeMult;
		    m_PointLightParams[j].range = 1.0f / (range * range);
		    m_PointLightParams[j].color = new Vector3(light.color.r, light.color.g, light.color.b) * light.intensity * fl.m_IntensityMult;
		    j++;
	    }

	    // TODO: try a constant buffer with setfloats instead for perf
	    m_PointLightParamsCB.SetData(m_PointLightParams);
	    m_InjectLightingAndDensity.SetBuffer(kernel, "_PointLights", m_PointLightParamsCB);
        */
    }

    private void SetUpForWindInheritance(int kernel)
    {
	    ValidateInput();
	    InitResources();
	    
	    // setup wind inheritance parameters in the Compute Shader
	    // render texture & parameters
	    SetUpWindVariantUniforms();
    }

    private void WindInheritance()
    {
	    int kernel = csWindInheritance.FindKernel("CSMain");
	    
	    SetUpForWindInheritance(kernel);
	    
	    // Solve Inheritance
	    csWindInheritance.Dispatch(kernel, 
		    _volumeResolution.x / _windInheritanceNumThreads.x,
		    _volumeResolution.y / _windInheritanceNumThreads.y, 
		    _volumeResolution.z / _windInheritanceNumThreads.z);
    }

    private void SetUpForWindInjection(int kernel)
    {
	    ValidateInput();
	    InitResources();
	    
	    // setup wind injection parameters in the compute shader
	    // render texture & parameters
	    SetUpWindVariantUniforms();
	    
	    Shader.SetGlobalVector("_WindNoisePosFrequency", noisePositionFrequency);
	    Shader.SetGlobalVector("_WindNoisePosOffset", noisePositionOffset);
	    Shader.SetGlobalVector("_AmbientWind", _ambientWindNormalized);
	    Shader.SetGlobalFloat("_NoiseWindIntensity", noiseWindIntensity);
	    Vector3 normalizedNoiseWindDirection = noiseWindScrollDirection.normalized;
		    Shader.SetGlobalVector("_WindNoiseScrollDirAndSpeed",
		    new Vector4(normalizedNoiseWindDirection.x, normalizedNoiseWindDirection.y, normalizedNoiseWindDirection.z,
			    noiseWindScrollSpeed));
	    
	    if (textureNoise)
	    {
		    csInjectWindDirectionAndIntensity.SetTexture(kernel, "_Noise", textureNoise2D);
		    csInjectWindDirectionAndIntensity.EnableKeyword("TEXTURE_NOISE");
		    csInjectWindDirectionAndIntensity.DisableKeyword("FUNCTION_NOISE");
	    }
	    else
	    {
		    csInjectWindDirectionAndIntensity.EnableKeyword("FUNCTION_NOISE");
		    csInjectWindDirectionAndIntensity.DisableKeyword("TEXTURE_NOISE");
	    }
    }

    private void WindInjection()
    {
	    int kernel = csInjectWindDirectionAndIntensity.FindKernel("CSMain");
	    
	    SetUpForWindInjection(kernel);
	    
	    csInjectWindDirectionAndIntensity.Dispatch(kernel, 
		    _volumeResolution.x / _windInjectionNumThreads.x, 
		    _volumeResolution.y / _windInjectionNumThreads.y, 
		    _volumeResolution.z / _windInjectionNumThreads.z);
	    //Debug.Log("Dispatched.");
    }
    
    private void SetUpForWindPropagation(int kernel)
    {
	    ValidateInput();
	    InitResources();
	    
	    // setup wind propagation parameters in the compute shader
	    // render texture & parameters
	    SetUpWindVariantUniforms();
    }

    private void WindPropagation()
    {
	    int kernel = csWindPropagation.FindKernel("CSMain");
	    
	    SetUpForWindPropagation(kernel);
	    
	    csWindPropagation.Dispatch(kernel, 
		    _volumeResolution.x / _windPropagationNumThreads.x, 
		    _volumeResolution.y / _windPropagationNumThreads.y, 
		    _volumeResolution.z / _windPropagationNumThreads.z);
    }
    
    private void UpdateDebugBuffers()
    {
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
	    for (int i = 0; i < _volumeResolution.x; i++)
	    {
		    for (int j = 0; j < _volumeResolution.y; j++)
		    {
			    for (int k = 0; k < _volumeResolution.z; k++)
			    {
				    // id as (i, j, k), calculate flattened id and its corresponding position
				    positions[i + _volumeResolution.x * (j + _volumeResolution.y * k)] =
					    sizePerVoxel * (new Vector3(i, j, k) - _volumeResolutionMinusOne / 2);
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
    }

    private void DebugDisplay()
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

	    if (debugInstanceMesh == null || instanceMaterial == null)
	    {
		    return;
	    }
	    
	    // Position that change - global vector already set
	    // instanceMaterial.SetVector("_WindCenterPosition", centerVolumePosition);
	    
	    if (_cachedInstanceCount != InstanceCount || _cachedSubMeshIndex != subMeshIndex)
	    {
		    UpdateDebugBuffers();
	    }

	    Graphics.DrawMeshInstancedIndirect(debugInstanceMesh, subMeshIndex, instanceMaterial,
		    new Bounds(centerVolumePosition,
			    new Vector3(_volumeResolution.x, _volumeResolution.y, _volumeResolution.z) * (sizePerVoxel + 0.1f)),
		    _debugArgsBuffer);
	    //Debug.Log("Drawing Debug Meshes.");
    }

    private void SetupWindConstantUniforms()
    {
	    Shader.SetGlobalTexture("_WindDirectionIntensityVolume", _windDirectionIntensityVolume);   
	    Shader.SetGlobalFloat("_WindVolumeVoxelSize", sizePerVoxel);
    }

    private void SetUpWindVariantUniforms()
    {
	    float ambientWindIntensity = new Vector3(ambientWind.x, ambientWind.y, ambientWind.z).magnitude;
	    _ambientWindNormalized = new Vector4(ambientWind.x / ambientWindIntensity, ambientWind.y / ambientWindIntensity,
		    ambientWind.z / ambientWindIntensity, ambientWind.w);
	    Shader.SetGlobalVector("_WindVolumeCenterPosition", centerVolumePosition);

	    // UVW - FloatToIntFloor((currentPos - centerPos) / windAffectRange) + WindVolumeSize/2;
	    // Global Texture - Wind Volume
	    // Global Vector - Wind Center Position
	    // Global Vector - Wind Affect Range
	    // Global Vector - Wind Volume Texture Size
    }

    /// <summary>
    /// Create 3D Texture and Command Buffers for future use.
    /// </summary>
    private void InitResources ()
    {
	    // Volume
	    InitVolume(ref _windDirectionIntensityVolume);
	    
	    // Compute buffers
	    int boxContributorCount = 0, capsuleContributorCount = 0, rigidBodyContributorCount = 0;
	    
	    // Iterate through existing wind contributors and calculate counts, create buffers.
	    //HashSet<FogLight> fogLights = LightManagerFogLights.Get();
	    //for (var x = fogLights.GetEnumerator(); x.MoveNext();)
	    //{
	    //    var fl = x.Current;
	    //    if (fl == null)
	    //	    continue;

	    //    bool isOn = fl.isOn;

	    //    switch(fl.type)
	    //    {
	    //	    case FogLight.Type.Point: 	if (isOn) pointLightCount++; break;
	    //	    case FogLight.Type.Tube: 	if (isOn) tubeLightCount++; break;
	    //	    case FogLight.Type.Area: 	if (isOn) areaLightCount++; break;
	    //    }
	    //}
	    
	    //CreateBuffer(ref m_PointLightParamsCB, pointLightCount, Marshal.SizeOf(typeof(PointLightParams)));
	    //CreateBuffer(ref m_TubeLightParamsCB, tubeLightCount, Marshal.SizeOf(typeof(TubeLightParams)));
	    //CreateBuffer(ref m_TubeLightShadowPlaneParamsCB, tubeLightCount, Marshal.SizeOf(typeof(TubeLightShadowPlaneParams)));
	    //CreateBuffer(ref m_AreaLightParamsCB, areaLightCount, Marshal.SizeOf(typeof(AreaLightParams)));
	    //HashSet<FogEllipsoid> fogEllipsoids = LightManagerFogEllipsoids.Get();
	    //CreateBuffer(ref m_FogEllipsoidParamsCB, fogEllipsoids == null ? 0 : fogEllipsoids.Count, Marshal.SizeOf(typeof(FogEllipsoidParams)));
	    CreateComputeBuffer(ref _dummyCommandBuffer, 1, 4);
    }

    private void InitVolume(ref RenderTexture volume)
    {
	    if (volume)
	    {
		    return;
	    }

	    volume = new RenderTexture(_volumeResolution.x, _volumeResolution.y, 0,
		    RenderTextureFormat.ARGBFloat);
	    volume.volumeDepth = _volumeResolution.z;
	    volume.dimension = TextureDimension.Tex3D;
	    volume.enableRandomWrite = true;
	    volume.Create();
    }

    private void CreateComputeBuffer(ref ComputeBuffer buffer, int count, int stride)
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
