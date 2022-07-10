using UnityEditor;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Editor
{
    public class CustomBasicHologramShaderGui : BaseShaderGUI
    {
        protected struct BasicHologramProperties
        {
            public MaterialProperty bumpMapProp;
            public MaterialProperty bumpScaleProp;

            public MaterialProperty screenSpaceScanline;
            public MaterialProperty screenSpaceTransparency;
            
            public MaterialProperty scanlineThickness1;
            public MaterialProperty scanlineSpeed1;
            public MaterialProperty scanlineColor1;
            public MaterialProperty scanlineDirection1;
            public MaterialProperty scanlineSampleScale1;
            
            public MaterialProperty scanlineThickness2;
            public MaterialProperty scanlineSpeed2;
            public MaterialProperty scanlineColor2;
            public MaterialProperty scanlineDirection2;
            public MaterialProperty scanlineSampleScale2;
            
            public MaterialProperty rimLightThickness;
            public MaterialProperty rimLightColor;
            public MaterialProperty displacementStrength;
            public MaterialProperty displacementAmount;
            public MaterialProperty displacementSpeed;
            public MaterialProperty displacementDirection;

            public BasicHologramProperties(MaterialProperty[] properties)
            {
                bumpMapProp = BaseShaderGUI.FindProperty("_BumpMap", properties, false);
                bumpScaleProp = BaseShaderGUI.FindProperty("_BumpScale", properties, false);

                screenSpaceScanline = FindProperty("_ScreenSpaceScanline", properties);
                screenSpaceTransparency = FindProperty("_ScreenSpaceTransparent", properties);
                
                scanlineThickness1 = FindProperty("_ScanlineThickness1", properties);
                scanlineSpeed1 = FindProperty("_ScanlineSpeed1", properties);
                scanlineColor1 = FindProperty("_ScanlineColor1", properties);
                scanlineDirection1 = FindProperty("_ScanlineDirection1", properties);
                scanlineSampleScale1 = FindProperty("_ScanlineSampleScale1", properties);
                
                scanlineThickness2 = FindProperty("_ScanlineThickness2", properties);
                scanlineSpeed2 = FindProperty("_ScanlineSpeed2", properties);
                scanlineColor2 = FindProperty("_ScanlineColor2", properties);
                scanlineDirection2 = FindProperty("_ScanlineDirection2", properties);
                scanlineSampleScale2 = FindProperty("_ScanlineSampleScale2", properties);
                
                rimLightThickness = FindProperty("_RimLightThickness", properties);
                rimLightColor = FindProperty("_RimLightColor", properties);
                displacementStrength = FindProperty("_DisplacementStrength", properties);
                displacementAmount = FindProperty("_DisplacementAmount", properties);
                displacementSpeed = FindProperty("_DisplacementSpeed", properties);
                displacementDirection = FindProperty("_DisplacementDirection", properties);
            }
        }

        protected BasicHologramProperties basicHologramProperties;
        
        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            basicHologramProperties = new BasicHologramProperties(properties);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            base.DrawSurfaceOptions(material);
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            BaseShaderGUI.DrawNormalArea(materialEditor, basicHologramProperties.bumpMapProp,
                basicHologramProperties.bumpScaleProp);

            GUILayout.Label("Scanline Setting", EditorStyles.helpBox);
            materialEditor.ShaderProperty(basicHologramProperties.screenSpaceScanline,
                EditorGUIUtility.TrTextContent("Screen Space Scanline"));
            materialEditor.ShaderProperty(basicHologramProperties.screenSpaceTransparency,
                EditorGUIUtility.TrTextContent("Screen Space Transparency"));
            
            DrawEmissionProperties(material, true);
            GUILayout.Label("Scanline 1", EditorStyles.helpBox);
            materialEditor.ShaderProperty(basicHologramProperties.scanlineThickness1,
                EditorGUIUtility.TrTextContent("Scan line thickness"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineDirection1,
                EditorGUIUtility.TrTextContent("Scan line direction"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineSampleScale1,
                EditorGUIUtility.TrTextContent("Scan line sample scale"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineSpeed1,
                EditorGUIUtility.TrTextContent("Scan line speed"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineColor1,
                EditorGUIUtility.TrTextContent("Scan line color"));
            
            GUILayout.Label("Scanline 2", EditorStyles.helpBox);
            materialEditor.ShaderProperty(basicHologramProperties.scanlineThickness2,
                EditorGUIUtility.TrTextContent("Scan line thickness"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineDirection2,
                EditorGUIUtility.TrTextContent("Scan line direction"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineSampleScale2,
                EditorGUIUtility.TrTextContent("Scan line sample scale"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineSpeed2,
                EditorGUIUtility.TrTextContent("Scan line speed"));
            materialEditor.ShaderProperty(basicHologramProperties.scanlineColor2,
                EditorGUIUtility.TrTextContent("Scan line color"));
            
            GUILayout.Label("Rim Light", EditorStyles.helpBox);
            materialEditor.ShaderProperty(basicHologramProperties.rimLightThickness,
                EditorGUIUtility.TrTextContent("Rim light thickness"));
            materialEditor.ShaderProperty(basicHologramProperties.rimLightColor,
                EditorGUIUtility.TrTextContent("Rim light color"));
            GUILayout.Label("Vertex Displacement", EditorStyles.helpBox);
            materialEditor.ShaderProperty(basicHologramProperties.displacementStrength,
                EditorGUIUtility.TrTextContent("Displacement Strength"));
            materialEditor.ShaderProperty(basicHologramProperties.displacementAmount,
                EditorGUIUtility.TrTextContent("Displacement Amount"));
            materialEditor.ShaderProperty(basicHologramProperties.displacementSpeed,
                EditorGUIUtility.TrTextContent("Displacement Speed"));
            materialEditor.ShaderProperty(basicHologramProperties.displacementDirection,
                EditorGUIUtility.TrTextContent("Displacement Direction"));
        }
    }
}