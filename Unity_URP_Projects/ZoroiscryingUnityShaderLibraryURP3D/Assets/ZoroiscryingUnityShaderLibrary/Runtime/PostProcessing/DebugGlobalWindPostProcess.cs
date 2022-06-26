using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    public enum DebugGlobalWindType
    {
        DisplayDirection,
        DisplaySpeed,
    }
    
    [Serializable]
    public sealed class GlobalWindDebugTypeParameter : VolumeParameter<DebugGlobalWindType> 
    { public GlobalWindDebugTypeParameter(DebugGlobalWindType value, bool overrideState = false) : base(value, overrideState) { } }
    
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/DebugGlobalWind")]
    public class DebugGlobalWindPostProcess : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter enabled = new BoolParameter(false);
        public GlobalWindDebugTypeParameter debugType =
            new GlobalWindDebugTypeParameter(DebugGlobalWindType.DisplayDirection);
        public MinIntParameter sliceNumber = new MinIntParameter(16, 1);
        public FloatParameter centerPosYScreenSpace = new FloatParameter(0.8f);
        public FloatParameter sliceIntervalPosXScreenSpace = new FloatParameter(0.005f);
        public MinIntParameter slicePixelSizeScreenSpace = new MinIntParameter(64, 1);

        public bool IsActive()
        {
            return (bool)enabled;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}