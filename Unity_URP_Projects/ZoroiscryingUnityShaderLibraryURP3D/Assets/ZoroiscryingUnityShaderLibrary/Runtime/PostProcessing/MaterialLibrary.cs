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
        
        

        public MaterialLibrary(AdditionalPostProcessData data)
        {
            InvertColorMat = Load(data.shaders.invertColorShader);
            UtilityMat = Load(data.shaders.utilityShader);
            AnimateLineMat = Load(data.shaders.animateLineShader);
            ImageBasedOutline = Load(data.shaders.imageBasedOutlineShader);
            DepthNormalsOutline = Load(data.shaders.depthNormalsOutlineShader);
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