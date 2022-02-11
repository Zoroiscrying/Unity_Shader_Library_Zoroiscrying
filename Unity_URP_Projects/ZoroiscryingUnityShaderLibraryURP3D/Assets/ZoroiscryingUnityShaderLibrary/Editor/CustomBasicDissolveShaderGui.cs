using System;
using UnityEditor;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Editor
{
    public class CustomBasicDissolveShaderGui : BaseShaderGUI
    {
        protected enum DissolveMode
        {
            PositionBased,
            DistanceBased,
            UVBased,
        }

        public static readonly string[] DissolveModes = Enum.GetNames(typeof(DissolveMode));
        protected DissolveMode dissolveMode;
        
        protected struct BasicDissolveProperties
        {
            public MaterialProperty dissolveSpan;
            public MaterialProperty noiseScale;
            public MaterialProperty noiseValueScaleFactor;
            public MaterialProperty positionDissolveEdge;
            public MaterialProperty distanceDissolveEdge;
            public MaterialProperty dissolveColor;
            public MaterialProperty uvDissolveEdge;
            public MaterialProperty dissolveMode;

            public BasicDissolveProperties(MaterialProperty[] properties)
            {
                dissolveSpan = BaseShaderGUI.FindProperty("_DissolveSpan", properties);
                noiseScale = BaseShaderGUI.FindProperty("_NoiseScale", properties);
                noiseValueScaleFactor = BaseShaderGUI.FindProperty("_NoiseValueScaleFactor", properties);
                positionDissolveEdge = BaseShaderGUI.FindProperty("_PositionDissolveEdge", properties);
                distanceDissolveEdge = BaseShaderGUI.FindProperty("_DistanceDissolveEdge", properties);
                dissolveColor = BaseShaderGUI.FindProperty("_DissolveColor", properties);
                uvDissolveEdge = BaseShaderGUI.FindProperty("_UVDissolveEdge", properties);
                dissolveMode = BaseShaderGUI.FindProperty("_Dissolve", properties);
            }
        }

        protected BasicDissolveProperties basicDissolveProperties;

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            basicDissolveProperties = new BasicDissolveProperties(properties);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            base.DrawSurfaceOptions(material);
            //EditorGUI.BeginChangeCheck();
            //dissolveMode = (DissolveMode)EditorGUILayout.EnumPopup("Dissolve Mode", dissolveMode);
            //if (EditorGUI.EndChangeCheck())
            //{
            //    MaterialPropertyBlock matPropBlock = new MaterialPropertyBlock();
            //    switch (dissolveMode)
            //    {
            //        case DissolveMode.PositionBased:
            //            material.EnableKeyword("_DISSOLVE_POSITION_BASED");
            //            material.DisableKeyword("_DISSOLVE_DISTANCE_BASED");
            //            material.DisableKeyword("_DISSOLVE_UV_BASED");
            //            break;
            //        case DissolveMode.DistanceBased:
            //            material.EnableKeyword("_DISSOLVE_DISTANCE_BASED");
            //            material.DisableKeyword("_DISSOLVE_POSITION_BASED");
            //            material.DisableKeyword("_DISSOLVE_UV_BASED");
            //            break;
            //        case DissolveMode.UVBased:
            //            material.EnableKeyword("_DISSOLVE_UV_BASED");
            //            material.DisableKeyword("_DISSOLVE_DISTANCE_BASED");
            //            material.DisableKeyword("_DISSOLVE_POSITION_BASED");
            //            break;
            //        default:
            //            material.EnableKeyword("_DISSOLVE_POSITION_BASED");
            //            material.DisableKeyword("_DISSOLVE_DISTANCE_BASED");
            //            material.DisableKeyword("_DISSOLVE_UV_BASED");
            //            break;
            //    }   
            //}
            materialEditor.ShaderProperty(basicDissolveProperties.dissolveMode,
                EditorGUIUtility.TrTextContent("Dissolve Mode"));
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            DrawEmissionProperties(material, true);
            materialEditor.ShaderProperty(basicDissolveProperties.dissolveColor,
                EditorGUIUtility.TrTextContent("Dissolve Color"));
            materialEditor.ShaderProperty(basicDissolveProperties.dissolveSpan,
                EditorGUIUtility.TrTextContent("Dissolve span"));
            materialEditor.ShaderProperty(basicDissolveProperties.noiseScale,
                EditorGUIUtility.TrTextContent("Noise sampling scale"));
            materialEditor.ShaderProperty(basicDissolveProperties.noiseValueScaleFactor,
                EditorGUIUtility.TrTextContent("Noise value scale"));
            materialEditor.ShaderProperty(basicDissolveProperties.positionDissolveEdge,
                EditorGUIUtility.TrTextContent("Position dissolve edge"));
            materialEditor.ShaderProperty(basicDissolveProperties.distanceDissolveEdge,
                EditorGUIUtility.TrTextContent("Distance dissolve edge"));
            materialEditor.ShaderProperty(basicDissolveProperties.uvDissolveEdge,
                EditorGUIUtility.TrTextContent("UV dissolve edge"));
        }
    }
}