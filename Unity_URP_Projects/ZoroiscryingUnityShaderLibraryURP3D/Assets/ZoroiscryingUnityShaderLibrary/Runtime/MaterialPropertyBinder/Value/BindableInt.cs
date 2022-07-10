using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BindableInt : BaseBindableValue<int>
    {
        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetInt(propName, Value);
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetInt(propId, Value);
        }
    }
}