using System;
using System.Runtime.CompilerServices;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Runtime.DynamicVegetation
{
    /// <summary>
    /// Serves as an instance of Swayable Vegetation Object that communicates with the Vegetation Sway Global Manager system
    /// </summary>
    // [ExecuteInEditMode]
    public class SwayVegetationInstanceObject : MonoBehaviour
    {
        [SerializeField] private VegetationSwayGlobalManager.SwayObjectParameter swayObjectParameter = new VegetationSwayGlobalManager.SwayObjectParameter()
        {
            ObjectMass = 1.0f,
            SpringDampen = 1.0f,
            SpringStrength = 1.0f,
            WindStrength = 1.0f,
            WorldPosition = float3.zero
        };
        public VegetationSwayGlobalManager.SwayObjectParameter SwayObjectParameter => swayObjectParameter;
        private VegetationSwayGlobalManager SwayManager => VegetationSwayGlobalManager.Instance;

        private int _indexBeforeDisable = -1;
        private int _curSwayIndex = -1;
        private Renderer _renderer;
        private bool _isApplicationQuitting = false;
        private bool _updatePositionRealtime = false;

        private MaterialPropertyBlock MatPropertyBlock
        {
            get { return _matPropertyBlock ??= new MaterialPropertyBlock(); }
        }
        private MaterialPropertyBlock _matPropertyBlock;

        private void Awake()
        {
            this.swayObjectParameter.WorldPosition = this.transform.position;
        }

        private void Update()
        {
            if (_updatePositionRealtime)
            {
                this.swayObjectParameter.WorldPosition = this.transform.position;
            }
        }

        private void OnEnable()
        {
            Application.quitting += ApplicationOnQuitting;
            
            if (!_renderer)
            {
                _renderer = GetComponent<Renderer>();
            }
            // QueueUpForEnable();
        }

        private void ApplicationOnQuitting()
        {
            _isApplicationQuitting = true;
        }

        private void OnDisable()
        {
            if (!_isApplicationQuitting)
            {
                //QueueUpForDisable();   
            }
            
            Application.quitting -= ApplicationOnQuitting;
        }

        public void QueueUpForDisable()
        {
            if (_curSwayIndex >= 0)
            {
                _indexBeforeDisable = _curSwayIndex;
                VegetationSwayGlobalManager.Instance.DisableSwayInstance(_curSwayIndex);
                // Debug.Log("Queue up for disable, index: " + _curSwayIndex);
                this.enabled = false;
                UpdateSwayIndex(-1);
                UpdateSwayIndexMaterialProperty();
            }
        }

        public void QueueUpForEnable()
        {
            if (_curSwayIndex == -1)
            {
                this.enabled = true;
                VegetationSwayGlobalManager.Instance.RegisterNewSwayInstance(this);   
            }
        }

        public void RestoreStateBeforeDisable()
        {
            UpdateSwayIndex(_indexBeforeDisable);
            UpdateSwayIndexMaterialProperty();
        }
        
        public void UpdateSwayIndex(int index)
        {
            // Debug.Log("Update sway index to: " + index);
            _curSwayIndex = index;
        }
        
        public void UpdateSwayIndexMaterialProperty()
        {
            _renderer.GetPropertyBlock(MatPropertyBlock);
            _matPropertyBlock.SetInt("_SwayInstanceIndex", _curSwayIndex);
            _renderer.SetPropertyBlock(_matPropertyBlock);
            // Debug.Log("Set sway index: " + _curSwayIndex);
        }
    }
}