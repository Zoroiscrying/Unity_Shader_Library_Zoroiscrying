using UnityEngine;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    public class MaterialLibrary
    {
        public readonly Material InvertColorMat;
        public readonly Material UtilityMat;
        public readonly Material AnimateLineMat;
        public readonly Material ImageBasedOutline;

        public readonly Material DepthNormalsOutline;

        public readonly Material PostProcessLightVolume;

        public readonly Material GaussianBlur;

        public readonly Material GlobalWindDebug;

        public MaterialLibrary(AdditionalPostProcessData data)
        {
            InvertColorMat = Load(data.shaders.invertColorShader);
            UtilityMat = Load(data.shaders.utilityShader);
            AnimateLineMat = Load(data.shaders.animateLineShader);
            ImageBasedOutline = Load(data.shaders.imageBasedOutlineShader);
            DepthNormalsOutline = Load(data.shaders.depthNormalsOutlineShader);
            PostProcessLightVolume = Load(data.shaders.postProcessLightVolumeShader);
            GaussianBlur = Load(data.shaders.gaussianBlurDepthAwareness);
            GlobalWindDebug = Load(data.shaders.globalWindDebugShader);
        }

        private Material Load(Shader shader)
        {
            if (shader == null)
            {
                Debug.LogErrorFormat($"Missing shader. {GetType().DeclaringType.Name} render pass will not execute. Check for missing reference in the renderer resources.");
                return null;
            }

            return shader.isSupported ? CoreUtils.CreateEngineMaterial(shader) : null;
        }

        internal void CleanUp()
        {
            CoreUtils.Destroy(InvertColorMat);
        }
    }
}