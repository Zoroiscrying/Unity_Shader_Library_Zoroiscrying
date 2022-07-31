using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    // Only for learning purpose in URP
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Post-Process-Light-Volume")]
    public class PostProcessLightVolume : VolumeComponent, IPostProcessComponent
    {
        public MinFloatParameter exposure = new MinFloatParameter(0, 0f);
        public MinFloatParameter density = new MinFloatParameter(0, 0.1f);
        public MinFloatParameter decay = new MinFloatParameter(0, 0.01f);
        public MinFloatParameter weight = new MinFloatParameter(0, 0.1f);
        public ColorParameter lightColor = new ColorParameter(new Color(1, 1, 1, 1), true, true, true);
        public BoolParameter debugOcclusionPass = new BoolParameter(false);
        public BoolParameter debugLightCompositePass = new BoolParameter(false);
        
        public bool IsActive() => exposure.value > 0;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}