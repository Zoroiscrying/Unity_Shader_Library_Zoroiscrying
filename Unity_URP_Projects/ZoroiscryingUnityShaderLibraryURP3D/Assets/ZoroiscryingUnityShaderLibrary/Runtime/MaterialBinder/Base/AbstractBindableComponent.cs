using System;
using System.Data.SqlTypes;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public abstract class AbstractBindableComponent<TC, TR> : MonoBehaviour, IBindableComponent<TC>, IMaterialPropertyBlockApplicable
    {
        public string MaterialPropName => propertyName;

        public void SetMaterialPropertyName(string name)
        {
            propertyName = name;
        }
        
        [SerializeField] protected string propertyName;

        public TC ComponentValue { get => RetrieveComponentValue(boundRoot); }

        [SerializeField]
        protected TR boundRoot = default;
        protected abstract TC RetrieveComponentValue(TR rootObject);

        public void BindRoot(TR rootObject)
        {
            boundRoot = rootObject;
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

        //TODO:: Deal with the component change.
        private void OnValidate()
        {
            OnValidateEvent?.Invoke();
        }
    }
}