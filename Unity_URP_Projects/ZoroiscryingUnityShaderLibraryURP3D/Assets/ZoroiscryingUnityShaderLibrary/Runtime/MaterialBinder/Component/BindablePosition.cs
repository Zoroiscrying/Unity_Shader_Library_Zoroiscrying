using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BindablePosition : BaseBindableComponent<Vector3, GameObject>
    {
        protected override Vector3 RetrieveComponentValue(GameObject rootObject)
        {
            return RootObjectValid() ? rootObject.transform.position : default;
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetVector(propId, ComponentValue);
        }

        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetVector(propName, ComponentValue);
        }
    }
}