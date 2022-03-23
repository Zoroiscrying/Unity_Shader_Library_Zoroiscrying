using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing
{
    public class VolumetricLightFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class Settings
        {
            //future settings
            public Material material;
            public Material blurMaterial;
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
            
            public enum DownSample { off = 1, half = 2, third = 3, quarter = 4 };
            public DownSample downsampling;
            
            public float intensity = 1;
            public float scattering = 0;
            public int steps = 25;
            public float maxDistance=75;
            public float jitter = 250;

            public float blurAmount = 1;
            public int blurSamples = 5;
            
            public void Setup()
            {
                material = CoreUtils.CreateEngineMaterial(Shader.Find("PostProcess/VolumetricLight"));
                blurMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("PostProcess/GaussianBlur"));
            }
        }
        public Settings settings = new Settings();

        class Pass : ScriptableRenderPass
        {
            public Settings settings;
            private RenderTargetIdentifier source;
            private RenderTargetIdentifier colorBuffer;
            RenderTargetHandle tempTexture;
            RenderTargetHandle tempTexture2;
            RenderTargetHandle tempTexture3;

            private string profilerTag;

            public void Setup(RenderTargetIdentifier source)
            {
                this.source = source;
            }

            public Pass(string profilerTag)
            {
                this.profilerTag = profilerTag;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                tempTexture.Init("tempTexture1");
                tempTexture2.Init("tempTexture2");
                tempTexture3.Init("tempTexture3");
                
                var originalDescriptor = renderingData.cameraData.cameraTargetDescriptor;
                var downSampledDescriptor = originalDescriptor;
                //R8 has noticeable banding
                downSampledDescriptor.colorFormat = RenderTextureFormat.R16;
                //we dont need to resolve AA in every single Blit
                downSampledDescriptor.msaaSamples = 1;
                // enable bilinear filtering

                var divider = (int)settings.downsampling + 1;
                if (Camera.current != null){
                    downSampledDescriptor.width = (int)Camera.current.pixelRect.width / divider;
                    downSampledDescriptor.height = (int)Camera.current.pixelRect.height / divider;
                }
                else{
                    downSampledDescriptor.width /= divider;
                    downSampledDescriptor.height /= divider;
                }
                
                ConfigureInput(ScriptableRenderPassInput.Depth);

                cmd.GetTemporaryRT(tempTexture.id, downSampledDescriptor, FilterMode.Bilinear);
                ConfigureTarget(tempTexture.Identifier());
                
                cmd.GetTemporaryRT(tempTexture2.id, downSampledDescriptor, FilterMode.Bilinear);
                ConfigureTarget(tempTexture2.Identifier());
                
                cmd.GetTemporaryRT(tempTexture3.id, originalDescriptor, FilterMode.Bilinear);
                ConfigureTarget(tempTexture3.Identifier());

                colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;

                ConfigureClear(ClearFlag.All, Color.black);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                base.OnCameraCleanup(cmd);
                if (cmd == null) throw new ArgumentNullException("cmd");
        
                // Since we created a temporary render texture in OnCameraSetup, we need to release the memory here to avoid a leak.
                cmd.ReleaseTemporaryRT(tempTexture.id);
                cmd.ReleaseTemporaryRT(tempTexture2.id);
                cmd.ReleaseTemporaryRT(tempTexture3.id);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
                cmd.Clear();

                //it is very important that if something fails our code still calls 
                //CommandBufferPool.Release(cmd) or we will have a HUGE memory leak
                try
                {
                    //here we set out material properties
                    settings.material.SetFloat("_Scattering", settings.scattering);                
                    settings.material.SetFloat("_Steps", settings.steps);                
                    settings.material.SetFloat("_JitterVolumetric", settings.jitter);                
                    settings.material.SetFloat("_MaxDistance", settings.maxDistance);                
                    settings.material.SetFloat("_Intensity", settings.intensity);  
                    
                    settings.blurMaterial.SetInt("_GaussSamples", settings.blurSamples);
                    settings.blurMaterial.SetFloat("_GaussAmount", settings.blurAmount);

                    // never use a Blit from source to source, as it only works with MSAA
                    // enabled and the scene view doesnt have MSAA,
                    // so the scene view will be pure black
                    // Ray march
                    cmd.Blit(source, tempTexture.Identifier(), settings.material, 0);
                    // Bilateral blur X
                    cmd.Blit(tempTexture.Identifier(), tempTexture2.Identifier(), settings.blurMaterial, 0);
                    // Bilateral blur Y
                    cmd.Blit(tempTexture2.Identifier(), tempTexture.Identifier(), settings.blurMaterial, 1);
                    // Down Sample depth
                    cmd.Blit(source, tempTexture2.Identifier(), settings.material, 1);
                    cmd.SetGlobalTexture("_LowResDepth", tempTexture2.Identifier());
                    cmd.SetGlobalTexture("_volumetricTexture", tempTexture.Identifier());
                    // Up Sample and composite
                    Blit(cmd, colorBuffer, tempTexture3.Identifier(), settings.material, 2);
                    Blit(cmd, tempTexture3.Identifier(), colorBuffer);

                    context.ExecuteCommandBuffer(cmd);
                }
                catch
                {
                    Debug.LogError("Error");
                }

                cmd.Clear();
                CommandBufferPool.Release(cmd);
            }
        }
        Pass pass;
        RenderTargetHandle renderTextureHandle;

        public override void Create()
        {
            pass = new Pass("Volumetric Light");
            name = "Volumetric Light";
            settings.Setup();
            pass.settings = settings;
            pass.renderPassEvent = settings.renderPassEvent;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var cameraColorTargetIdent = renderer.cameraColorTarget;
            pass.Setup(cameraColorTargetIdent);
            renderer.EnqueuePass(pass);
        }
    }
}