using UnityEditor;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.GPUScreenSpaceParticles.Editor
{
    [CustomEditor(typeof(PrecipitationManager))] 
    public class PrecipitationManagerEditor : UnityEditor.Editor {

        public override void OnInspectorGUI() {
            base.OnInspectorGUI();
          
            if (GUILayout.Button("Rebuild Precipitation Mesh")) {
                (target as PrecipitationManager)?.RebuildPrecipitationMesh();
                // set dirty to make sure the editor updates
                EditorUtility.SetDirty(target);
            }
        }
    }
}