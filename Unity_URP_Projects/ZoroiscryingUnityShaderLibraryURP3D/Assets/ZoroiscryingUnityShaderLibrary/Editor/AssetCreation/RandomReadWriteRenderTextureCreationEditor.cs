using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace ZoroiscryingUnityShaderLibrary.Editor.AssetCreation
{
    public class RandomReadWriteRenderTextureCreationEditor : EditorWindow
    {
        private bool _overrideExisting = false;
        private string _filePath;
        
        [MenuItem("Zoroiscrying/Random Read Write Render Texture Creation Tool")]
        public static void ShowWindow()
        {
            EditorWindow.GetWindow(typeof(RandomReadWriteRenderTextureCreationEditor));
        }
        
        private void OnGUI()
        {
            using (new EditorGUILayout.VerticalScope())
            {
                _overrideExisting = EditorGUILayout.Toggle("Override Existing", _overrideExisting);
                
                if (GUILayout.Button("Create Render Texture"))
                {
                    _filePath = EditorUtility.SaveFilePanelInProject("Choose File path", 
                        "New RT", "renderTexture", "File Path Chosen.");
                    if (_filePath.Length == 0) return;
                    
                    if (!_overrideExisting)
                    {
                        _filePath = AssetDatabase.GenerateUniqueAssetPath(_filePath);
                    }
                    
                    var volume = new RenderTexture(32, 16, 0,
                        RenderTextureFormat.ARGBHalf)
                    {
                        volumeDepth = 32,
                        dimension = TextureDimension.Tex3D,
                        enableRandomWrite = true
                    };
                    volume.Create();
                    AssetDatabase.CreateAsset(volume, _filePath);
                    AssetDatabase.Refresh();
                    EditorGUIUtility.PingObject(AssetDatabase.LoadAssetAtPath<Texture2D>(_filePath));
                }
            }
        }
    }
}
