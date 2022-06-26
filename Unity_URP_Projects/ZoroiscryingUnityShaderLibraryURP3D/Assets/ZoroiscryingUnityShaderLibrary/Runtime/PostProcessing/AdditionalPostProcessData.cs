using System;
using System.Collections;
using System.Collections.Generic;
using TMPro.EditorUtilities;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{

    [Serializable]
    public class AdditionalPostProcessData : ScriptableObject
    {
        [Serializable]
        public sealed class Shaders
        {
            public Shader invertColorShader;
            public Shader utilityShader;
            public Shader animateLineShader;
            public Shader imageBasedOutlineShader;

            public Shader depthNormalsOutlineShader;

            public Shader postProcessLightVolumeShader;

            public Shader gaussianBlurDepthAwareness;

            public Shader globalWindDebugShader;

            public void Init()
            {
                invertColorShader = Shader.Find("PostProcess/PostProcessingTemplateShader");
                utilityShader = Shader.Find("PostProcess/Utility");
                animateLineShader = Shader.Find("PostProcess/AnimateSpeedLine");
                imageBasedOutlineShader = Shader.Find("PostProcess/ImageBasedOutline");
                depthNormalsOutlineShader = Shader.Find("PostProcess/DepthNormalOutline");
                postProcessLightVolumeShader = Shader.Find("PostProcess/PostProcessLightVolume");
                gaussianBlurDepthAwareness = Shader.Find("PostProcess/GaussianBlur");
                globalWindDebugShader = Shader.Find("PostProcess/DebugGlobalWind");
            }
        }

        private void OnEnable()
        {
            shaders = new Shaders();
            shaders.Init();
        }

        public Shaders shaders;

#if UNITY_EDITOR
    [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]

    [MenuItem("Assets/Create/Rendering/Universal Render Pipeline/Additional Post-process Data",
        priority = CoreUtils.Priorities.editMenuPriority + 1)]
    static void CreateAdditionalPostProcessData()
    {
        var instance = CreateInstance<AdditionalPostProcessData>();
        AssetDatabase.CreateAsset(instance, $"Assets/Settings/{nameof(AdditionalPostProcessData)}.asset");
        Selection.activeObject = instance;
    }
#endif
    }

}