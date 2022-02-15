using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BindableVector : BaseBindableValue<Color>
    {
        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetVector(propName, Value);
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetVector(propId, Value);
        }
    }
}