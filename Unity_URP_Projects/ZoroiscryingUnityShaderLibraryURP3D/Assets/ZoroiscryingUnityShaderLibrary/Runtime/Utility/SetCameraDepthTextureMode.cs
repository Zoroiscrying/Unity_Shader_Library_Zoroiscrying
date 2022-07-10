using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Utility
{
    [ExecuteInEditMode, RequireComponent(typeof(Camera))]
    public class SetCameraDepthTextureMode : MonoBehaviour
    {
        private void Awake()
        {
            Camera cam = this.GetComponent<Camera>();
            if (cam == null)
            {
                return;
            }
            if(cam.depthTextureMode != DepthTextureMode.Depth)
                cam.depthTextureMode = DepthTextureMode.Depth;
        }
    }
}