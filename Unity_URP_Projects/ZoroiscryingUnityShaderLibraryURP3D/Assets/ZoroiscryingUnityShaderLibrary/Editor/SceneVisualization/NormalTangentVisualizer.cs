using System.Linq;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Editor.SceneVisualization
{
    using UnityEditor;
    using UnityEngine;

    [CustomEditor(typeof(MeshFilter))]
    public class NormalTangentVisualizer : Editor {

        private const string EDITOR_PREF_KEY_NORMAL_LENGTH = "_normals_length";
        private const string EDITOR_PREF_KEY_ENABLED = "_normal_tangent_visualizer_enabled";
        private Mesh mesh;
        private MeshFilter mf;
        private Vector3[]  verts;
        private Vector3[]  normals;
        private Vector3[]  tangents;
        private float normalsLength = 1f;
        private bool enableVisualization = true;

        private void OnEnable() {
            mf   = target as MeshFilter;
            if (mf != null) {
                mesh = mf.sharedMesh;
            }
            enableVisualization = EditorPrefs.GetBool(EDITOR_PREF_KEY_ENABLED);
            normalsLength = EditorPrefs.GetFloat(EDITOR_PREF_KEY_NORMAL_LENGTH);
        }

        private void OnSceneGUI() {
            if (mesh == null) {
                return;
            }

            if (enableVisualization)
            {
                Handles.matrix = mf.transform.localToWorldMatrix;
                Handles.color = Color.yellow;
                Handles.zTest = CompareFunction.LessEqual;
                verts = mesh.vertices;
                normals = mesh.normals;
                tangents = new Vector3[mesh.tangents.Length];
                if (mesh.tangents.Length > 0)
                {
                    for (int i = 0; i < mesh.tangents.Length; i++)
                    {
                        var meshTangent = mesh.tangents[i];
                        tangents[i] = new Vector3(meshTangent.x, meshTangent.y, meshTangent.z) * meshTangent.w;
                    }   
                }
                int len = mesh.vertexCount;

                if (normals.Length > 0)
                {
                    for (int i = 0; i < len; i++) {
                        Handles.DrawLine(verts[i], verts[i] + normals[i] * normalsLength);
                    }   
                }

                Handles.color = Color.red;
            
                if (tangents.Length > 0)
                {
                    for (int i = 0; i < len; i++) {
                        Handles.DrawLine(verts[i], verts[i] + tangents[i] * normalsLength);
                    }   
                }   
            }
        }

        public override void OnInspectorGUI() {
            base.OnInspectorGUI();
            EditorGUI.BeginChangeCheck();
            normalsLength = EditorGUILayout.FloatField("Normals length", normalsLength);
            enableVisualization = EditorGUILayout.Toggle("Normal Tangent Visualization", enableVisualization);
            if (EditorGUI.EndChangeCheck()) {
                EditorPrefs.SetFloat(EDITOR_PREF_KEY_NORMAL_LENGTH, normalsLength);
                EditorPrefs.SetBool(EDITOR_PREF_KEY_ENABLED, enableVisualization);
            }
        }
    }
}