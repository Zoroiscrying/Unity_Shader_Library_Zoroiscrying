using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    // From https://github.com/keijiro/Kino/blob/master/Packages/jp.keijiro.kino.post-processing/Runtime/Utility.cs
    // Only for learning purpose in URP
    [Serializable, VolumeComponentMenu("Custom-Post-Processing/Animate-Speed-Line")]
    public class AnimateSpeedLine : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter enableSpeedLine = new BoolParameter(false);
        
        public FloatParameter speedLineTilling = new FloatParameter(50f);
        public FloatParameter speedLineRadialScale = new FloatParameter(0.001f);
        public FloatParameter speedLinePower = new FloatParameter(1f);
        public FloatRangeParameter speedLineRange = new FloatRangeParameter(new Vector2(0.4f, 0.5f), 0f, 1f);
        public ClampedFloatParameter speedLineSmoothness = new ClampedFloatParameter(0.05f, 0.001f, 0.5f);
        public FloatParameter speedLineAnimation = new FloatParameter(0.05f);

        public ClampedFloatParameter maskScale = new ClampedFloatParameter(0.5f, 0.002f, 1f);
        public FloatParameter maskHardness = new FloatParameter(0.25f);
        public FloatParameter maskPower = new FloatParameter(4f);
        
        public ColorParameter animateLineColor = new ColorParameter(new Color(0, 0, 0, 0), false, true, true);
        
        public bool IsActive() => 
            enableSpeedLine.value;

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}