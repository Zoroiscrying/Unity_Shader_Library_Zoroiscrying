using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    // From https://github.com/keijiro/Kino/blob/master/Packages/jp.keijiro.kino.post-processing/Runtime/Utility.cs
    // Only for learning purpose in URP
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Utility")]
    public class UtilityPostProcess : VolumeComponent, IPostProcessComponent
    {
        public ClampedFloatParameter saturation = new ClampedFloatParameter(1, 0, 2);
        public ClampedFloatParameter hueShift = new ClampedFloatParameter(0, -1, 1);
        public ClampedFloatParameter invert = new ClampedFloatParameter(0, 0, 1);
        public ColorParameter fade = new ColorParameter(new Color(0, 0, 0, 0), false, true, true);
        
        public bool IsActive() => (saturation.value != 1 || hueShift.value != 0 || invert.value > 0 || fade.value.a > 0);

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}