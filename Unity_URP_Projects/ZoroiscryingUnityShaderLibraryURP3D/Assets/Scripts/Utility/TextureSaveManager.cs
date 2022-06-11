using System;
using System.Collections;
using System.Collections.Generic;
using JetBrains.Annotations;
using UnityEditor;
using UnityEngine;
using Random = UnityEngine.Random;

public static class TextureSaveManager
{
    private static string _savePath = "";
    private static bool _initializedSavePath = false;

    public static bool CheckSavePathValidity()
    {
        if (_savePath == "")
        {
            // invalid save path
            _savePath = Application.dataPath;
            _initializedSavePath = true;
            Debug.Log("TextureSaveManager : Empty save path, changed to default Asset/ Folder");
            return false;
        }
        else if (!System.IO.Directory.Exists(_savePath))
        {
            try
            {
                System.IO.Directory.CreateDirectory(_savePath);
                _initializedSavePath = true;
                Debug.Log("Created new folder path: " + _savePath);
            }
            catch
            {
                _savePath = Application.dataPath;
                _initializedSavePath = true;
                Debug.LogError("Invalid save path, the system cannot create new folder, fallback to Asset/ Folder");
                //throw new Exception("Invalid save path, the system cannot create new folder, fallback to Asset/ Folder");
                return false;
            }
        }
        
        _initializedSavePath = true;
        return true;
    }

    public static void ChangeSavePath(string newSavePath)
    {
        _savePath = newSavePath;
        if (CheckSavePathValidity())
        {
            Debug.Log("Changed save path to: " + newSavePath);
        }
    }
    
    public static void SaveTexture2DAsPng(Texture2D tex, bool overrideIfExist = false, string fileName = "newTexture2D")
    {
        if (!_initializedSavePath)
        {
            CheckSavePathValidity();
        }

        byte[] bytes = tex.EncodeToPNG();
        if (CheckSavePathValidity())
        {
            string fullSavePath = _savePath + "/" + fileName + ".png";
#if UNITY_EDITOR
            if (!overrideIfExist)
            {
                fullSavePath = AssetDatabase.GenerateUniqueAssetPath(fullSavePath);
            }
#else
            if (!overrideIfExist)
            {
                fullSavePath = _savePath + "/" + fileName + Random.Range(0, 100000) + ".png";
            }
#endif
            System.IO.File.WriteAllBytes(fullSavePath, bytes);
            Debug.Log(bytes.Length / 1024 + "Kb was saved as: " + fullSavePath);
#if UNITY_EDITOR
            UnityEditor.AssetDatabase.Refresh();
#endif
        }
    }
    
    public static void SaveTexture2DAsJpg(Texture2D tex, bool overrideIfExist = false, string fileName = "newTexture2D")
    {
        if (!_initializedSavePath)
        {
            CheckSavePathValidity();
        }

        byte[] bytes = tex.EncodeToJPG();
        if (CheckSavePathValidity())
        {
            string fullSavePath = _savePath + "/" + fileName + ".jpg";
#if UNITY_EDITOR
            if (!overrideIfExist)
            {
                fullSavePath = AssetDatabase.GenerateUniqueAssetPath(fullSavePath);
            }
#else
            if (!overrideIfExist)
            {
                fullSavePath = _savePath + "/" + fileName + Random.Range(0, 100000) + ".jpg";
            }
#endif
            System.IO.File.WriteAllBytes(fullSavePath, bytes);
            Debug.Log(bytes.Length / 1024 + "Kb was saved as: " + fullSavePath);
#if UNITY_EDITOR
            UnityEditor.AssetDatabase.Refresh();
#endif
        }
    }
}
