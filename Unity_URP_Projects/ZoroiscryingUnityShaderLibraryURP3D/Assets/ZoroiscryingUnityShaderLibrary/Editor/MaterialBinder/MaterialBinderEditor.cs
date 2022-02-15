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

        void OnEnable()
        {
            GetSerializedProperty();
            GetTarget();
        }

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                serializedObject.Update();

                DrawUpdateButton();

                serializedObject.ApplyModifiedProperties();
            }
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
        }

        protected virtual void DrawBinderSlots()
        {
            
        }
    }
}