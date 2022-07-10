using UnityEditor.SceneManagement;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialModifier
{
    [ExecuteInEditMode]
    public class BaseMaterialModifier : MonoBehaviour
    {
        public Material material;
        public string propertyName;
        
        private void OnSceneSaved(UnityEngine.SceneManagement.Scene scene) 
        {
            //Debug.Log("Scene Saved, Recreating resources.");
            OnDisable();
            OnEnable();
        }

        protected virtual void OnDisable()
        {
            EditorSceneManager.sceneSaved -= OnSceneSaved;
        }

        protected virtual void OnValidate()
        {
            ApplyMaterialChange();
        }

        protected virtual void OnEnable()
        {
            EditorSceneManager.sceneSaved += OnSceneSaved;
            ApplyMaterialChange();
        }

        protected virtual void Update()
        {

        }

        protected virtual void ApplyMaterialChange()
        {
            
        }
    }
}