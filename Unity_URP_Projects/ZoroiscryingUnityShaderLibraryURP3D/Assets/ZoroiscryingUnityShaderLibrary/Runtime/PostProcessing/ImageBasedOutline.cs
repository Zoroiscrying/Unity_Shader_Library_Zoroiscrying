using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    // From https://github.com/keijiro/Kino/blob/master/Packages/jp.keijiro.kino.post-processing/Runtime/Utility.cs
    // Only for learning purpose in URP
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Image-Based-Outline")]
    public class ImageBasedOutline : VolumeComponent, IPostProcessComponent
    {
        public ClampedFloatParameter edgeOpacity = new ClampedFloatParameter(0, 0, 1); 
        public ColorParameter edgeColor = new ColorParameter(new Color(1, 1, 1, 1), true, true, true);
        
        public bool IsActive() => edgeOpacity.value > 0;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}