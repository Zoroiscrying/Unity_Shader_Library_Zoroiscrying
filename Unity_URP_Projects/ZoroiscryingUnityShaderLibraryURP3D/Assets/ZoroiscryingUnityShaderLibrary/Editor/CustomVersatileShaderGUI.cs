using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Editor
{
    public class CustomVersatileShaderGUI : BaseShaderGUI
    {
        protected List<MaterialPropertyNamePair> materialPropertyNamePairs = new List<MaterialPropertyNamePair>();
        protected List<MatPropEditorItem> editorPropertyNames = new List<MatPropEditorItem>();
        protected bool expanded = true;
        readonly MaterialHeaderScopeList m_customMatScopeList = new MaterialHeaderScopeList(uint.MaxValue);

        [Flags]
        protected enum CustomExpandable
        {
            Custom = 1 << 4,
        }
        
        public override void OnGUI(MaterialEditor materialEditorIn, MaterialProperty[] properties)
        {
            var mat = materialEditorIn != null ? materialEditorIn.target as Material : null;
            
            RetrieveGlobalShaderPropertyNames(mat);   
            
            m_customMatScopeList.DrawHeaders(materialEditorIn, mat);
            base.OnGUI(materialEditorIn, properties);
            
            SaveGlobalShaderPropertyNames(mat);
        }

        public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
        {
            base.OnOpenGUI(material, materialEditor);
            var filter = (CustomExpandable)materialFilter;
            if (filter.HasFlag(CustomExpandable.Custom))
                m_customMatScopeList.RegisterHeaderScope(
                    EditorGUIUtility.TrTextContent("Custom Inputs", "Auto generated inputs from the property fields."), 
                    (uint)CustomExpandable.Custom, 
                    DrawMaterialPropertyNamePairs);
        }

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            InitializeMaterialPropertyNamePairs(properties);
        }
        
        public override void DrawSurfaceOptions(Material material)
        {
            base.DrawSurfaceOptions(material);
        }
        
        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            
            //BaseShaderGUI.DrawNormalArea(materialEditor, basicHologramProperties.bumpMapProp,
            //    basicHologramProperties.bumpScaleProp);

            DrawEmissionProperties(material, true);
        }

        protected void DrawEditorPropertyNames()
        {
            EditorGUI.BeginChangeCheck();

            //DrawType newDrawType = DrawType.General;
            //int newItemIndex = 0;
            //string newPropName = "Default";
            
            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                using (new EditorGUILayout.HorizontalScope(EditorStyles.helpBox))
                {
                    GUILayout.Label("Material Properties to Show:");
                    if (GUILayout.Button("+", GUILayout.MaxWidth(40)))
                    {
                        editorPropertyNames.Add(new MatPropEditorItem()
                        {
                            drawType = DrawType.General,
                            propertyName = "Default Property Name"
                        });
                    }
                    if (GUILayout.Button("-", GUILayout.MaxWidth(40)))
                    {
                        editorPropertyNames.RemoveAt(editorPropertyNames.Count - 1);
                    }

                    if (expanded)
                    {
                        if (GUILayout.Button("Collapse", GUILayout.MaxWidth(60)))
                        {
                            expanded = false;
                        }   
                    }
                    else
                    {
                        if (GUILayout.Button("Expand", GUILayout.MaxWidth(60)))
                        {
                            expanded = true;
                        }   
                    }
                }

                if (expanded)
                {
                    EditorGUI.indentLevel += 1;
                    for (int i = 0; i < editorPropertyNames.Count; i++)
                    {
                        var propertyName = editorPropertyNames[i];
                        using (new EditorGUILayout.HorizontalScope())
                        {
                            GUILayout.Label("--Item: " + i.ToString(), EditorStyles.boldLabel ,GUILayout.MaxWidth(60)); 
                            editorPropertyNames[i].drawType = ((DrawType)EditorGUILayout.EnumPopup("Draw Type", propertyName.drawType));  
                        }
                        editorPropertyNames[i].propertyName = (EditorGUILayout.TextField("Property Name", propertyName.propertyName));
                    }
                    EditorGUI.indentLevel -= 1;   
                }
            }

            if (EditorGUI.EndChangeCheck())
            {
                
            }
        }

        protected void DrawMaterialPropertyNamePairs(Material material)
        {
            DrawEditorPropertyNames();
            foreach (var materialPropertyNamePair in materialPropertyNamePairs)
            {
                DrawMaterialPropertyNamePair(materialPropertyNamePair, material);
            }
        }

        protected void DrawMaterialPropertyNamePair(MaterialPropertyNamePair propertyNamePair, Material mat)
        {
            switch (propertyNamePair.drawType)
            {
                case DrawType.General:
                    materialEditor.ShaderProperty(propertyNamePair.materialProperty,
                        EditorGUIUtility.TrTextContent(propertyNamePair.propertyName));
                    break;
                case DrawType.NormalMap:
                    materialEditor.ShaderProperty(propertyNamePair.materialProperty,
                        EditorGUIUtility.TrTextContent(propertyNamePair.propertyName));
                    break;
                case DrawType.ThumbnailTexture:
                    materialEditor.TexturePropertySingleLine(
                        EditorGUIUtility.TrTextContent(propertyNamePair.propertyName),
                        propertyNamePair.materialProperty);
                    break;
                case DrawType.EditorHeader:
                    GUILayout.Label(propertyNamePair.propertyName, EditorStyles.helpBox);
                    break;
                case DrawType.CheckKeywordEnabledOrNot:
                    bool Keywordenabled = mat.IsKeywordEnabled(propertyNamePair.propertyName);
                    string text = Keywordenabled ? "ENABLED!" : "NOT ENABLED";
                    GUILayout.Label("  Keyword: " + propertyNamePair.propertyName + " ---- " + text, EditorStyles.helpBox);
                    break;
                default:
                    break;
            }
        }

        protected void InitializeMaterialPropertyNamePairs(MaterialProperty[] properties)
        {
            materialPropertyNamePairs.Clear();
            foreach (var propertyName in editorPropertyNames)
            {
                var materialProperty = FindProperty(propertyName.propertyName, properties, false);
                if (propertyName.drawType == DrawType.CheckKeywordEnabledOrNot ||
                    propertyName.drawType == DrawType.EditorHeader||
                    materialProperty != null)
                {
                    materialPropertyNamePairs.Add(new MaterialPropertyNamePair(materialProperty, propertyName.propertyName,
                        propertyName.drawType));   
                }
            }
        }

        protected string GetKey(Material mat)
        {
            return mat.shader.ToString();
        }

        protected void RetrieveGlobalShaderPropertyNames(Material mat)
        {
            var key = GetKey(mat);
            if (PlayerPrefs.HasKey(key))
            {
                expanded = PlayerPrefs.GetInt(key + "expanded") == 1;
                editorPropertyNames.Clear();   
                var keyItemNumber = key + "itemNum";
                int itemNumber = PlayerPrefs.GetInt(keyItemNumber);
                for (int i = 0; i < itemNumber; i++)
                {
                    string propertyName = PlayerPrefs.GetString(key + "propName" + i);
                    DrawType drawType = (DrawType)PlayerPrefs.GetInt(key + "drawType" + i);
                    editorPropertyNames.Add(new MatPropEditorItem()
                    {
                        propertyName = propertyName,
                        drawType = drawType
                    });
                }
            }
        }

        protected void SaveGlobalShaderPropertyNames(Material mat)
        {
            int itemNumber = editorPropertyNames.Count;
            
            var key = GetKey(mat);
            var keyItemNumber = key + "itemNum";
            PlayerPrefs.SetInt(keyItemNumber, itemNumber);
            for (int i = 0; i < editorPropertyNames.Count; i++)
            {
                //Debug.Log(editorPropertyNames[i].propertyName);
                PlayerPrefs.SetString(key + "propName" + i, editorPropertyNames[i].propertyName);
                PlayerPrefs.SetInt(key + "drawType" + i, (int)editorPropertyNames[i].drawType);
            }
            PlayerPrefs.SetInt(key, 1);
            PlayerPrefs.SetInt(key + "expanded", expanded ? 1 : 0);
        }
    }
}