using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public interface IMaterialPropertyBlockApplicable
    {
        public String MaterialPropName { get; }
        public void SetMaterialPropertyName(string name);
        public void ApplyMatPropBlockChange(String propName, MaterialPropertyBlock matPropBlock);

        public void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock);

        public event Action OnValidateEvent;
    }
}