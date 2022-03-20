using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    [ExecuteAlways]
    public class GlobalShaderPropertyConfigure : MonoBehaviour
    {
        public Light DirectionalLight;
        
        private void Update()
        {
            Shader.SetGlobalVector("_MainLightDirectionWS", transform.forward);
            //Shader.SetGlobalColor("_MainLightColor");
        }
    }
}