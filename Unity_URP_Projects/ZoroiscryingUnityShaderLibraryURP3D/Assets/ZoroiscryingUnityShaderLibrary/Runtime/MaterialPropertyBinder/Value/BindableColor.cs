using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public class BindableColor : BaseBindableValue<Color>
    {
        protected override Color Value
        {
            get
            {
                if (useHDRColor)
                {
                    return hdrColor;
                }
                return base.Value;
            }
        }

        [SerializeField] private bool useHDRColor;
        
        [SerializeField, ColorUsage(false, true)]
        private Color hdrColor;
        
        public override void ApplyMatPropBlockChange(string propName, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetColor(propName, Value);
        }

        public override void ApplyMatPropBlockChange(int propId, MaterialPropertyBlock matPropBlock)
        {
            matPropBlock.SetColor(propId, Value);
        }
    }
}