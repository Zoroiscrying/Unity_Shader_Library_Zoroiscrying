using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public enum PropertyRetargetingOptions
    {
        X,
        Y,
        Z,
        XYZ,
    }
    
    public class BindablePosition : BaseBindableComponent<Vector3, GameObject>
    {
        [SerializeField] private PropertyRetargetingOptions retargetOption;
        [SerializeField] private bool transformToLocal = false;
    
        protected override Vector3 RetrieveComponentValue(GameObject rootObject)
        {
            return RootObjectValid() ? rootObject.transform.position : default;
        }

        public override Vector3 PreProcessComponentValue(Vector3 component, GameObject boundObject)
        {
            if (!transformToLocal)
            {
                return base.PreProcessComponentValue(component, boundObject);
            }
            else
            {
                return boundObject.transform.InverseTransformPoint(component);
            }
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            switch (retargetOption)
            {
                case PropertyRetargetingOptions.X:
                    matPropBlock.SetFloat(propId, ComponentValue.x);
                    break;
                case PropertyRetargetingOptions.Y:
                    matPropBlock.SetFloat(propId, ComponentValue.y);
                    break;
                case PropertyRetargetingOptions.Z:
                    matPropBlock.SetFloat(propId, ComponentValue.z);
                    break;
                case PropertyRetargetingOptions.XYZ:
                    matPropBlock.SetVector(propId, ComponentValue);
                    break;
                default:
                    matPropBlock.SetVector(propId, ComponentValue);
                    break;
            }
        }

        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            switch (retargetOption)
            {
                case PropertyRetargetingOptions.X:
                    matPropBlock.SetFloat(propName, ComponentValue.x);
                    break;
                case PropertyRetargetingOptions.Y:
                    matPropBlock.SetFloat(propName, ComponentValue.y);
                    break;
                case PropertyRetargetingOptions.Z:
                    matPropBlock.SetFloat(propName, ComponentValue.z);
                    break;
                case PropertyRetargetingOptions.XYZ:
                    matPropBlock.SetVector(propName, ComponentValue);
                    break;
                default:
                    matPropBlock.SetVector(propName, ComponentValue);
                    break;
            }
        }
    }
}