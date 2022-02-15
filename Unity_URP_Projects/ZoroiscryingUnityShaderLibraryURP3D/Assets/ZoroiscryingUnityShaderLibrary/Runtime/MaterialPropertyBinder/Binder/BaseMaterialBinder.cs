using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    [ExecuteAlways]
    public class BaseMaterialBinder : MonoBehaviour
    {
        protected Renderer ComponentRenderer
        {
            get
            {
                if (_componentRenderer == null)
                {
                    _componentRenderer = this.GetComponent<Renderer>();
                    if (_componentRenderer == null)
                    {
                        Debug.LogError("This object has no renderer, automatically added.");
                        _componentRenderer = this.gameObject.AddComponent<Renderer>();
                    }
                }

                return _componentRenderer;
            }
        }
        
        private Renderer _componentRenderer;

        protected MaterialPropertyBlock MatPropBlock
        {
            get
            {
                if (_matPropertyBlock == null)
                {
                    _matPropertyBlock = new MaterialPropertyBlock();
                }

                return _matPropertyBlock;
            }
        }
        
        private MaterialPropertyBlock _matPropertyBlock;

        private List<IMaterialPropertyBlockApplicable>
            _bindableComponents = new List<IMaterialPropertyBlockApplicable>();

        private void OnEnable()
        {
            _matPropertyBlock = new MaterialPropertyBlock();
            Initialize();
        }

        public void OnValidate()
        {
            // bind the properties to the material block and update
            _bindableComponents = this.GetComponents<IMaterialPropertyBlockApplicable>().ToList();
            ApplyMaterialBlockChange();
            //Debug.Log("Trying to change material property.");
        }

        private void Initialize()
        {
            _bindableComponents = this.GetComponents<IMaterialPropertyBlockApplicable>().ToList();
            foreach (var bindableComponent in _bindableComponents)
            {
                bindableComponent.OnValidateEvent += OnValidate;
            }
        }

        private void Dispose()
        {
            foreach (var bindableComponent in _bindableComponents)
            {
                bindableComponent.OnValidateEvent -= OnValidate;
            }
            _bindableComponents = null;
        }

        private void Update()
        {
            ApplyMaterialBlockChange();
        }

        public void RemoveBinderProperty(IMaterialPropertyBlockApplicable binderPropertyToRemove)
        {
            if (_bindableComponents.Contains(binderPropertyToRemove))
            {
                _bindableComponents.Remove(binderPropertyToRemove);
            }
        }

        public void AddNewBinderProperty(IMaterialPropertyBlockApplicable newBinderProperty)
        {
            _bindableComponents.Add(newBinderProperty);
        }

        public void ApplyMaterialBlockChange()
        {
            //ComponentRenderer.GetPropertyBlock(_matPropertyBlock);
            foreach (var bindableComponent in _bindableComponents)
            {
                //Debug.Log(bindableComponent.MaterialPropName);
                bindableComponent?.ApplyMatPropBlockChange(bindableComponent.MaterialPropName, MatPropBlock);
            }
            ComponentRenderer.SetPropertyBlock(MatPropBlock);
        }
    }
}