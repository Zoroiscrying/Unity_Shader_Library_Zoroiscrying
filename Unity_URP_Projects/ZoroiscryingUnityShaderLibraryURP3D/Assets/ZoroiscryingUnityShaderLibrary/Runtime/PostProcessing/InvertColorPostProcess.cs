using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Invert-Color")]
    public class InvertColorPostProcess : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter invert = new BoolParameter(false);

        public bool IsActive()
        {
            return (bool)invert;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}