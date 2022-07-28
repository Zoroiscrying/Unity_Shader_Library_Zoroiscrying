using System;
using System.Data.SqlTypes;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    /// <summary>
    /// 
    /// </summary>
    /// <typeparam name="TC">The type of the value component.</typeparam>
    /// <typeparam name="TR">The type of the root for retrieving the component.</typeparam>
    public abstract class AbstractBindableComponent<TC, TR> : MonoBehaviour, IBindableComponent<TC>, IMaterialPropertyBlockApplicable
    {
        [SerializeField] private bool preProcessComponentValue;
        // https://answers.unity.com/questions/179255/a-way-to-iterateenumerate-shader-properties.html
        // TODO:: This is a code example getting the possible shader properties, can be used to generate a enum panel
        // for user to select properties to bind to.
        public string MaterialPropName => propertyName;

        public void SetMaterialPropertyName(string name)
        {
            propertyName = name;
        }
        
        [SerializeField] protected string propertyName;

        public TC ComponentValue
        {
            get
            {
                return PreProcessComponentValue(RetrieveComponentValue(boundRoot), this.gameObject);
            }
        }

        [SerializeField]
        protected TR boundRoot = default;
        protected abstract TC RetrieveComponentValue(TR rootObject);

        public void BindRoot(TR rootObject)
        {
            boundRoot = rootObject;
        }

        public virtual TC PreProcessComponentValue(TC component, GameObject boundObject)
        {
            return component;
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