using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ZoroiscryingUnityShaderLibrary.Runtime.PostProcessing;

public class CustomPostProcessPassFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        RenderTextureDescriptor m_Descriptor;
        RenderTargetIdentifier m_ColorAttachment;
        private RenderTargetHandle PDepthAttachmentHandle { get; set; }
        RenderTargetHandle m_Destination;
        
        const string k_RenderPostProcessingTag = "Render AdditionalPostProcessing Effects";
        const string k_RenderFinalPostProcessingTag = "Render Final AdditionalPostProcessing Pass";

        // used for depth normals outline
        private ShaderTagId m_depthOnlyShaderTagId = new ShaderTagId("DepthOnly");
        
        private InvertColorPostProcess m_InvertColor;
        private UtilityPostProcess m_utility;
        private AnimateSpeedLine m_animateSpeedLine;
        private ImageBasedOutline m_imageBasedOutline;
        private DepthNormalsOutline m_depthNormalsOutline;
        private PostProcessLightVolume m_postProcessLightVolume;
        private DebugGlobalWindPostProcess m_debugWind;

        MaterialLibrary m_Materials;
        
        RenderTargetHandle m_TemporaryColorTexture01;
        RenderTargetHandle m_TemporaryColorTexture02;
        RenderTargetHandle m_TemporaryColorTexture03;
        
        public CustomRenderPass(AdditionalPostProcessData data)
        {
            m_Materials = new MaterialLibrary(data);
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture1");
            m_TemporaryColorTexture02.Init("_TemporaryColorTexture2");
            m_TemporaryColorTexture03.Init("_TemporaryColorTexture3");
        }
        
        public void Setup(in RenderTextureDescriptor baseDescriptor, RenderPassEvent @event)
        {
            m_Descriptor = baseDescriptor;
            m_Descriptor.useMipMap = false;
            m_Descriptor.autoGenerateMips = false;
            renderPassEvent = @event;
            //m_ColorAttachment = source;
            //m_DepthAttachment = ;
        }
        
        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_InvertColor = stack.GetComponent<InvertColorPostProcess>();
            m_utility = stack.GetComponent<UtilityPostProcess>();
            m_animateSpeedLine = stack.GetComponent<AnimateSpeedLine>();
            m_imageBasedOutline = stack.GetComponent<ImageBasedOutline>();
            m_depthNormalsOutline = stack.GetComponent<DepthNormalsOutline>();
            m_postProcessLightVolume = stack.GetComponent<PostProcessLightVolume>();
            m_debugWind = stack.GetComponent<DebugGlobalWindPostProcess>();
            
            var cmd = CommandBufferPool.Get(k_RenderPostProcessingTag);
            cmd.Clear();

            try
            {
                Render(cmd, ref renderingData);
                context.ExecuteCommandBuffer(cmd);
            }
            catch
            {
                Debug.LogError("Error");
            }
            
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        
        /// <summary>
        /// Used for actual rendering, insert various post process cmd logics here
        /// </summary>
        /// <param name="cmd"></param>
        /// <param name="renderingData"></param>
        private void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            ref ScriptableRenderer renderer = ref cameraData.renderer;
            bool isSceneViewCamera = cameraData.isSceneViewCamera;
            //m_DepthAttachment = renderer.cameraDepthTarget;

            if (m_InvertColor.IsActive())
            {
                SetupInvertColor(cmd, ref renderingData, m_Materials.InvertColorMat);
            }

            if (m_utility.IsActive())
            {
                SetupUtility(cmd, ref renderingData, m_Materials.UtilityMat);
            }

            if (m_animateSpeedLine.IsActive())
            {
                SetupAnimateSpeedLine(cmd, ref renderingData, m_Materials.AnimateLineMat);
            }

            if (m_imageBasedOutline.IsActive())
            {
                SetupImageBasedOutline(cmd, ref renderingData, m_Materials.ImageBasedOutline);
            }

            if (m_depthNormalsOutline.IsActive())
            {
                SetupDepthNormalsOutline(cmd, ref renderingData, m_Materials.DepthNormalsOutline);
            }

            if (m_postProcessLightVolume.IsActive())
            {
                SetupPostProcessLightVolumeOutline(
                    cmd, ref renderingData, m_Materials.PostProcessLightVolume, ref cameraData, m_Materials.GaussianBlur);
            }

            if (m_debugWind.IsActive())
            {
                SetupDebugGlobalWind(cmd, ref renderingData, m_Materials.GlobalWindDebug);
            }
        }

        private void SetupDebugGlobalWind(CommandBuffer cmd, ref RenderingData renderingData, Material debugWindMaterial)
        {
            cmd.BeginSample("Debug Global Wind");
            
            switch (m_debugWind.debugType.value)
            {
                case DebugGlobalWindType.DisplayDirection:
                    debugWindMaterial.EnableKeyword("DEBUG_DIRECTION");
                    debugWindMaterial.DisableKeyword("DEBUG_SPEED");
                    break;
                case DebugGlobalWindType.DisplaySpeed:
                    debugWindMaterial.EnableKeyword("DEBUG_SPEED");
                    debugWindMaterial.DisableKeyword("DEBUG_DIRECTION");
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }
            
            Blit(cmd, ref renderingData, debugWindMaterial, 0);
            cmd.EndSample("Debug Global Wind");
        }
        
        private void SetupInvertColor(CommandBuffer cmd, ref RenderingData renderingData, Material invertMaterial)
        {
            cmd.BeginSample("invertColor");
            Blit(cmd, ref renderingData, invertMaterial, 0);
            cmd.EndSample("invertColor");
        }

        private void SetupUtility(CommandBuffer cmd, ref RenderingData renderingData, Material material)
        {
            if (material == null)
            {
                return;
            }

            cmd.BeginSample("Utility");
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, m_Descriptor, FilterMode.Bilinear);

            material.SetColor(ShaderConstants.FadeColor, m_utility.fade.value);
            material.SetFloat(ShaderConstants.HueShift, m_utility.hueShift.value);
            material.SetFloat(ShaderConstants.Invert, m_utility.invert.value);
            material.SetFloat(ShaderConstants.Saturation, m_utility.saturation.value);
            //material.SetTexture(ShaderConstants.InputTexture, m_TemporaryColorTexture01.);
            // setup the camera opaque texture
            cmd.SetGlobalTexture(ShaderConstants.InputTexture, m_ColorAttachment);
            
            Blit(cmd, ref renderingData, material, 0);
            //cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier(), material, 0);
            //cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_Destination.Identifier());

            cmd.EndSample("Utility");
        }
        
        private void SetupAnimateSpeedLine(CommandBuffer cmd, ref RenderingData renderingData, Material material)
        {
            if (material == null)
            {
                return;
            }

            cmd.BeginSample("AnimateSpeedLine");
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, m_Descriptor, FilterMode.Bilinear);

            material.SetColor(ShaderConstants.SpeedLineColor, m_animateSpeedLine.animateLineColor.value);
            material.SetFloat(ShaderConstants.SpeedLineTilling, m_animateSpeedLine.speedLineTilling.value);
            material.SetFloat(ShaderConstants.SpeedLineRadialScale, m_animateSpeedLine.speedLineRadialScale.value);
            material.SetFloat(ShaderConstants.SpeedLinePower, m_animateSpeedLine.speedLinePower.value);
            
            material.SetFloat(ShaderConstants.SpeedLineStart, m_animateSpeedLine.speedLineRange.value.x);
            material.SetFloat(ShaderConstants.SpeedLineEnd, m_animateSpeedLine.speedLineRange.value.y);
            material.SetFloat(ShaderConstants.SpeedLineSmoothness, m_animateSpeedLine.speedLineSmoothness.value);
            
            material.SetFloat(ShaderConstants.SpeedLineAnimation, m_animateSpeedLine.speedLineAnimation.value);
            
            material.SetFloat(ShaderConstants.MaskScale, m_animateSpeedLine.maskScale.value);
            material.SetFloat(ShaderConstants.MaskHardness, m_animateSpeedLine.maskHardness.value);
            material.SetFloat(ShaderConstants.MaskPower, m_animateSpeedLine.maskPower.value);

            Blit(cmd, ref renderingData, material, 0);

            cmd.EndSample("AnimateSpeedLine");
        }
        
        private void SetupImageBasedOutline(CommandBuffer cmd, ref RenderingData renderingData, Material material)
        {
            if (material == null)
            {
                return;
            }

            cmd.BeginSample("Image Based Outline");
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, m_Descriptor, FilterMode.Bilinear);

            material.SetColor(ShaderConstants.EdgeColor, m_imageBasedOutline.edgeColor.value);
            material.SetFloat(ShaderConstants.EdgeOpacity, m_imageBasedOutline.edgeOpacity.value);
            
            Blit(cmd, ref renderingData, material, 0);

            cmd.EndSample("Image Based Outline");
        }

        private void SetupDepthNormalsOutline(CommandBuffer cmd, ref RenderingData renderingData, Material material)
        {
            if (material == null)
            {
                return;
            }

            cmd.BeginSample("Depth normals Outline");
            //cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, m_Descriptor, FilterMode.Bilinear);

            material.SetColor(ShaderConstants.OutlineColor, m_depthNormalsOutline.outlineColor.value);
            material.SetFloat(ShaderConstants.OutlineThickness, m_depthNormalsOutline.outlineThickness.value);
            material.SetFloat(ShaderConstants.DepthSensitivity, m_depthNormalsOutline.depthSensitivity.value);
            material.SetFloat(ShaderConstants.NormalsSensitivity, m_depthNormalsOutline.normalsSensitivity.value);
            material.SetFloat(ShaderConstants.ColorSensitivity, m_depthNormalsOutline.colorSensitivity.value);
            
            Blit(cmd, ref renderingData, material, 0);

            cmd.EndSample("Depth normals Outline");
        }

        private void SetupPostProcessLightVolumeOutline(CommandBuffer cmd, ref RenderingData renderingData, 
            Material material, ref CameraData cameraData, Material blurMaterial)
        {
            if (material == null)
            {
                return;
            }

            cmd.BeginSample("PostProcessLightVolume");
            
            var R16Descriptor =
                new RenderTextureDescriptor(m_Descriptor.width/2, m_Descriptor.height/2, RenderTextureFormat.R16);
            cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, R16Descriptor, FilterMode.Bilinear);
            cmd.GetTemporaryRT(m_TemporaryColorTexture02.id, R16Descriptor, FilterMode.Bilinear);
            cmd.GetTemporaryRT(m_TemporaryColorTexture03.id, m_Descriptor, FilterMode.Bilinear);

            material.SetColor(ShaderConstants.LightColor, m_postProcessLightVolume.lightColor.value);
            material.SetFloat(ShaderConstants.Density, m_postProcessLightVolume.density.value);
            material.SetFloat(ShaderConstants.Exposure, m_postProcessLightVolume.exposure.value);
            material.SetFloat(ShaderConstants.Weight, m_postProcessLightVolume.weight.value);
            material.SetFloat(ShaderConstants.Decay, m_postProcessLightVolume.decay.value);
            
            Vector3 sunDirectionWorldSpace = RenderSettings.sun.transform.forward;
            Vector3 cameraPositionWorldSpace = cameraData.camera.transform.position; 
            Vector3 sunPositionWorldSpace = cameraPositionWorldSpace + sunDirectionWorldSpace * cameraData.camera.farClipPlane;
            Vector3 sunPositionViewportSpace = cameraData.camera.WorldToViewportPoint(sunPositionWorldSpace);

            material.SetVector("_MainLightPositionSS", sunPositionViewportSpace);

            // Background Occluded texture generation
            cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier(), material, 1);
            cmd.SetGlobalTexture("_BackgroundOccluded", m_TemporaryColorTexture01.Identifier());
            if (m_postProcessLightVolume.debugOcclusionPass.value)
            {
                Blit(cmd, m_TemporaryColorTexture01.Identifier(), m_ColorAttachment);
                cmd.EndSample("PostProcessLightVolume");
                return;
            }
            // Occluded background Radial blur
            cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture02.Identifier(), material, 0);
            // Bilateral blur with depth awareness
            cmd.Blit(m_TemporaryColorTexture02.Identifier(), m_TemporaryColorTexture01.Identifier(), blurMaterial, 0);
            cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_TemporaryColorTexture02.Identifier(), blurMaterial, 1);
            cmd.SetGlobalTexture("_VolumetricLightTexture", m_TemporaryColorTexture02.Identifier());
            if (m_postProcessLightVolume.debugLightCompositePass.value)
            {
                Blit(cmd, m_TemporaryColorTexture02.Identifier(), m_ColorAttachment);
                cmd.EndSample("PostProcessLightVolume");
                return;
            }
            // Generate down sampled depth
            cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier(), material, 2);
            cmd.SetGlobalTexture("_LowResDepth", m_TemporaryColorTexture01.Identifier());

            Blit(cmd, m_ColorAttachment, m_TemporaryColorTexture03.Identifier(), material, 3);
            Blit(cmd, m_TemporaryColorTexture03.Identifier(), m_ColorAttachment);
            
            //cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture03.Identifier(), material, 3);
            //cmd.Blit(m_TemporaryColorTexture03.Identifier(), m_ColorAttachment);
            //Blit(cmd, ref renderingData, material, 0);

            cmd.EndSample("PostProcessLightVolume");
        }

        
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_ColorAttachment = renderingData.cameraData.renderer.cameraColorTarget;
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
    }

    // Precomputed shader ids to same some CPU cycles (mostly affects mobile)
    static class ShaderConstants
    {
        // Utility
        public static readonly int FadeColor = Shader.PropertyToID("_FadeColor");
        public static readonly int HueShift = Shader.PropertyToID("_HueShift");
        public static readonly int Invert = Shader.PropertyToID("_Invert");
        public static readonly int Saturation = Shader.PropertyToID("_Saturation");
        public static readonly int InputTexture = Shader.PropertyToID("_InputTexture");
        // Animate Speed Line
        public static readonly int SpeedLineColor = Shader.PropertyToID("_SpeedLineColor");
        public static readonly int SpeedLineTilling = Shader.PropertyToID("_SpeedLineTilling");
        public static readonly int SpeedLineRadialScale = Shader.PropertyToID("_SpeedLineRadialScale");
        public static readonly int SpeedLinePower = Shader.PropertyToID("_SpeedLinePower");
        public static readonly int SpeedLineStart = Shader.PropertyToID("_SpeedLineStart");
        public static readonly int SpeedLineEnd = Shader.PropertyToID("_SpeedLineEnd");
        public static readonly int SpeedLineSmoothness = Shader.PropertyToID("_SpeedLineSmoothness");
        public static readonly int SpeedLineAnimation = Shader.PropertyToID("_SpeedLineAnimation");
        public static readonly int MaskScale = Shader.PropertyToID("_MaskScale");
        public static readonly int MaskHardness = Shader.PropertyToID("_MaskHardness");
        public static readonly int MaskPower = Shader.PropertyToID("_MaskPower");
        // Image Based Outline
        public static readonly int EdgeOpacity = Shader.PropertyToID("_EdgeOpacity");
        public static readonly int EdgeColor = Shader.PropertyToID("_EdgeColor");
        // Depth Normals Outline
        public static readonly int OutlineColor = Shader.PropertyToID("_OutlineColor");
        public static readonly int OutlineThickness = Shader.PropertyToID("_OutlineThickness");
        public static readonly int NormalsSensitivity = Shader.PropertyToID("_NormalsSensitivity");
        public static readonly int DepthSensitivity = Shader.PropertyToID("_DepthSensitivity");
        public static readonly int ColorSensitivity = Shader.PropertyToID("_ColorSensitivity");
        // Post Processing Light Volume
        public static readonly int LightColor = Shader.PropertyToID("_LightColor");
        public static readonly int Density = Shader.PropertyToID("_Density");
        public static readonly int Exposure = Shader.PropertyToID("_Exposure");
        public static readonly int Weight = Shader.PropertyToID("_Weight");
        public static readonly int Decay = Shader.PropertyToID("_Decay");
    }

    CustomRenderPass m_ScriptablePass;
    public RenderPassEvent evt = RenderPassEvent.AfterRenderingTransparents;
    public AdditionalPostProcessData postProcessData;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(postProcessData);
        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = evt;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraColorTarget = renderer.cameraColorTarget;
        //var cameraDepth = renderer.cameraDepthTarget;
        if (postProcessData == null) return;
        m_ScriptablePass.Setup(renderingData.cameraData.cameraTargetDescriptor, m_ScriptablePass.renderPassEvent);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


