using System;
using System.Runtime.Serialization;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BaseBindableValue<T> : MonoBehaviour, IMaterialPropertyBlockApplicable
    {
        public string MaterialPropName => propertyName;
        
        [SerializeField] protected string propertyName;

        protected virtual T Value => value;

        [SerializeField] private T value;
        
        public virtual void SetMaterialPropertyName(string name)
        {
            propertyName = name;
        }

        public virtual void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            throw new NotImplementedException();
        }

        public virtual void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            throw new NotImplementedException();
        }

        public event Action OnValidateEvent;
        
        private void OnValidate()
        {
            OnValidateEvent?.Invoke();
        }
    }
}