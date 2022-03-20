using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    // From https://github.com/keijiro/Kino/blob/master/Packages/jp.keijiro.kino.post-processing/Runtime/Utility.cs
    // Only for learning purpose in URP
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Depth-Normals-Outline")]
    public class DepthNormalsOutline : VolumeComponent, IPostProcessComponent
    {
        public ClampedFloatParameter outlineThickness = new ClampedFloatParameter(0, 0, 32); 
        public ClampedFloatParameter depthSensitivity = new ClampedFloatParameter(1, 0.05f, 1); 
        public ClampedFloatParameter normalsSensitivity = new ClampedFloatParameter(1, 0.05f, 1); 
        public ClampedFloatParameter colorSensitivity = new ClampedFloatParameter(1, 0.05f, 1); 

        public ColorParameter outlineColor = new ColorParameter(new Color(1, 1, 1, 1), true, true, true);
        
        public bool IsActive() => outlineThickness.value > 0;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}