using System;
using UnityEditor;

namespace ZoroiscryingUnityShaderLibrary.Editor
{
    public enum DrawType
    {
        General,
        NormalMap,
        ThumbnailTexture,
        EditorHeader,
        CheckKeywordEnabledOrNot,
    }
    
    public struct MaterialPropertyNamePair
    {
        public MaterialProperty materialProperty;
        public string propertyName;
        public DrawType drawType;

        public MaterialPropertyNamePair(MaterialProperty matProp, string propName, DrawType dType)
        {
            drawType = dType;
            materialProperty = matProp;
            propertyName = propName;
        }
    }

    [Serializable]
    public class MatPropEditorItem
    {
        public string propertyName;
        public DrawType drawType;

        public void NewPropName(string newPropName)
        {
            propertyName = newPropName;
        }

        public void NewDrawType(DrawType newDrawType)
        {
            drawType = newDrawType;
        }
    }
}