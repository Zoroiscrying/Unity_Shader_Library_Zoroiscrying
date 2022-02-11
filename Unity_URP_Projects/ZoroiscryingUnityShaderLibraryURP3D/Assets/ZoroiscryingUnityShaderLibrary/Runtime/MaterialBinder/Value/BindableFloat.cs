using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BindableFloat : BaseBindableValue<float>
    {
        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetFloat(propName, Value);
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetFloat(propId, Value);
        }
    }
}