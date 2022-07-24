using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using ZoroiscryingUnityShaderLibrary.Runtime.AssetCreation;

namespace ZoroiscryingUnityShaderLibrary.Editor.AssetCreation
{
    [CustomEditor(typeof(RampGradientAsset))]
    public class RampGradientAssetEditor : UnityEditor.Editor
    {
        private bool _useCurrentSelectedFolderPath;
            
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();

            _useCurrentSelectedFolderPath = EditorGUILayout.ToggleLeft("Use Current Selected Folder Location",
                _useCurrentSelectedFolderPath);
            
            if (GUILayout.Button("Bake"))
                Bake();
        }
        void Bake()
        {
            var r = target as RampGradientAsset;
            if (r == null)
            {
                Debug.LogError("The ramp gradient asset target is null.");
                return;
            }

            var t = new Texture2D(r.size, r.size, TextureFormat.ARGB32, mipChain: true)
                { wrapMode = TextureWrapMode.Clamp };
            var p = t.GetPixels();
            for (var x = 0; x < r.size; x++)
            for (var y = 0; y < r.size; y++)
                p[r.up ? y + (r.size - x - 1) * r.size : x + y * r.size] = r.gradient.Evaluate(x * 1f / r.size);
            t.SetPixels(p);
            t.Apply();
            var bytes = t.EncodeToPNG();
            var path = "";
            try
            {
                if (_useCurrentSelectedFolderPath)
                {
                    var obj = Selection.activeObject;
                    if (obj == null) path = "Assets/";
                    else path = AssetDatabase.GetAssetPath(obj.GetInstanceID());
                    if (path.Length > 0)
                    {
                        if (Directory.Exists(path))
                        {
                            path += "new ramp gradient tex.png";
                        }
                        else
                        {
                            Debug.Log("File");
                            var lastIndexOfDot = path.LastIndexOf("/", StringComparison.Ordinal);
                            path = path.Remove(lastIndexOfDot, path.Length - lastIndexOfDot - 1);
                            path += "new ramp gradient tex.png";
                        }
                    }
                }
                else
                {
                    path = AssetDatabase.GetAssetPath(r).Replace(".asset", "") + ".png";
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning("Invalid Save File Path, fallback to Asset Folder.");
                path = "Assets/new ramp gradient tex.png";
            }
            
            if (!r.overwriteExisting)
                path = AssetDatabase.GenerateUniqueAssetPath(path);
            
            try
            {
                System.IO.File.WriteAllBytes(path, bytes);
            }
            catch (Exception e)
            {
                path = "Assets/new ramp gradient tex.png";
                System.IO.File.WriteAllBytes(path, bytes);
            }
            
            AssetDatabase.Refresh();
            
            // make tex readable
            var tImporter = AssetImporter.GetAtPath( path ) as TextureImporter;
            if ( tImporter != null )
            {
                tImporter.textureType = TextureImporterType.Default;
                tImporter.isReadable = true;
                AssetDatabase.ImportAsset( path );
                AssetDatabase.Refresh();
            }
            
            var createdTex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            createdTex.wrapMode = TextureWrapMode.Clamp;
            createdTex.Apply();
            EditorUtility.SetDirty(createdTex);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorGUIUtility.PingObject(createdTex);
        }
    }
}