using System;
using UnityEditor;
using UnityEngine;
using ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder;

namespace ZoroiscryingUnityShaderLibrary.Editor.MaterialBinder
{
    [CustomEditor(typeof(BaseMaterialBinder))]
    public class MaterialBinderEditor : UnityEditor.Editor
    {
        private BaseMaterialBinder _materialBinder;
        private DrawType _drawType;
        
        void OnEnable()
        {
            GetSerializedProperty();
            GetTarget();
        }

        public override void OnInspectorGUI()
        {
            _drawType = (DrawType)PlayerPrefs.GetInt("test");
            
            base.OnInspectorGUI();
            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                serializedObject.Update();

                DrawUpdateButton();

                serializedObject.ApplyModifiedProperties();
            }
            
            PlayerPrefs.SetInt("test", (int)_drawType);
        }
        
        protected virtual void GetSerializedProperty()
        {
            //
        }
        
        protected virtual void GetTarget()
        {
            _materialBinder = (BaseMaterialBinder)target;
        }

        protected virtual void DrawUpdateButton()
        {
            if (GUILayout.Button("Update Bound Components"))
            {
                _materialBinder.OnValidate();
            }
            _drawType = (DrawType)EditorGUILayout.EnumPopup("Draw Type", _drawType);   
        }
    }
}