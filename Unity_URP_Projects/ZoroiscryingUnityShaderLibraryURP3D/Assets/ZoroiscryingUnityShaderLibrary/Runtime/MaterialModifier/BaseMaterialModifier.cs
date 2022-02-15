using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialModifier
{
    [ExecuteInEditMode]
    public class BaseMaterialModifier : MonoBehaviour
    {
        public Material material;
        public string propertyName;

        protected virtual void OnValidate()
        {
            ApplyMaterialChange();
        }

        protected virtual void OnEnable()
        {
            ApplyMaterialChange();
        }

        protected virtual void Update()
        {

        }

        public virtual void ApplyMaterialChange()
        {
            
        }
    }
}