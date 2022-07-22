using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public enum TextureChannel
{
    None = 0,
    R = 1<<0,
    G = 1<<1,
    B = 1<<2,
    A = 1<<3,
    InverseR = 1<<4,
    InverseG = 1<<5,
    InverseB = 1<<6,
    InverseA = 1<<7,
    All = ~0,
}

public class TextureChannelCompositeEditor : EditorWindow
{
    private Texture2D _textureToModify;
    private Texture2D _textureToReadFrom;
    public TextureChannel ModifyTextureChannel;
    public TextureChannel ReadTextureChannel;
    private string _filePath;
    private bool _texturesValid = false;
    private bool _overrideExisting = false;
    private bool _customFilePath = false;
    
    [MenuItem("Zoroiscrying/Texture Channel Composite Editor")]
    public static void ShowWindow()
    {
        EditorWindow.GetWindow(typeof(TextureChannelCompositeEditor));
    }

    private void OnGUI()
    {
        using (new EditorGUILayout.VerticalScope())
        {
            _textureToModify =
                EditorGUILayout.ObjectField("Texture To Modify", _textureToModify, typeof(Texture2D), _textureToModify) as Texture2D;   
            _textureToReadFrom =
                EditorGUILayout.ObjectField("Texture To Read From", _textureToReadFrom, typeof(Texture2D), _textureToReadFrom) as Texture2D;
            ModifyTextureChannel = (TextureChannel)EditorGUILayout.EnumFlagsField(ModifyTextureChannel);
            ReadTextureChannel = (TextureChannel)EditorGUILayout.EnumFlagsField(ReadTextureChannel);
            _overrideExisting = EditorGUILayout.Toggle("Override Existing", _overrideExisting);
            _customFilePath = EditorGUILayout.Toggle("Choose Custom Save File Path", _customFilePath);

            CheckIfTexturesAreValid();

            if (_texturesValid)
            {
                if (GUILayout.Button("Run Texture Composite and Save"))
                {
                    // run texture composite
                    var tex = new Texture2D(_textureToModify.width, _textureToModify.height, TextureFormat.ARGB32, mipChain: true)
                        { wrapMode = _textureToModify.wrapMode, filterMode = _textureToModify.filterMode};
                    var pixels = tex.GetPixels();
                    var pixelsToModify = _textureToModify.GetPixels();
                    var pixelsToReadFrom = _textureToReadFrom.GetPixels();

                    bool modifyR = ((int)ModifyTextureChannel & 1 << 0) > 0;
                    bool modifyG = ((int)ModifyTextureChannel & 1 << 1) > 0;
                    bool modifyB = ((int)ModifyTextureChannel & 1 << 2) > 0;
                    bool modifyA = ((int)ModifyTextureChannel & 1 << 3) > 0;
                    bool modifyRInv = ((int)ModifyTextureChannel & 1 << 4) > 0;
                    bool modifyGInv = ((int)ModifyTextureChannel & 1 << 5) > 0;
                    bool modifyBInv = ((int)ModifyTextureChannel & 1 << 6) > 0;
                    bool modifyAInv = ((int)ModifyTextureChannel & 1 << 7) > 0;
                    
                    bool[] readChannels = new bool[8];
                    readChannels[0] = ((int)ReadTextureChannel & 1 << 0) > 0;
                    readChannels[1] = ((int)ReadTextureChannel & 1 << 1) > 0;
                    readChannels[2] = ((int)ReadTextureChannel & 1 << 2) > 0;
                    readChannels[3] = ((int)ReadTextureChannel & 1 << 3) > 0;
                    readChannels[4] = ((int)ReadTextureChannel & 1 << 4) > 0;
                    readChannels[5] = ((int)ReadTextureChannel & 1 << 5) > 0;
                    readChannels[6] = ((int)ReadTextureChannel & 1 << 6) > 0;
                    readChannels[7] = ((int)ReadTextureChannel & 1 << 7) > 0;

                    Color _tempCol = Color.black;
                    Color _tempReadCol = Color.black;
                    bool rUsed = false;
                    bool gUsed = false;
                    bool bUsed = false;
                    bool aUsed = false;
                    bool rInvUsed = false;
                    bool gInvUsed = false;
                    bool bInvUsed = false;
                    bool aInvUsed = false;
                    bool[] usedChannels = new bool[8] { false, false, false, false, false, false, false, false };

                    for (int i = 0; i < _textureToModify.width; i++)
                    {
                        for (int j = 0; j < _textureToModify.height; j++)
                        {
                            _tempCol = pixelsToModify[i + j * _textureToModify.width];
                            _tempReadCol = pixelsToReadFrom[i + j * _textureToModify.width];
                            rUsed = false;
                            gUsed = false;
                            bUsed = false;
                            aUsed = false;
                            rInvUsed = false;
                            gInvUsed = false;
                            bInvUsed = false;
                            aInvUsed = false;
                            for (int k = 0; k < CalculateFlagNum(ModifyTextureChannel); k++)
                            {
                                if (modifyR && !rUsed)
                                {
                                    _tempCol.r = GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    rUsed = true;
                                }
                                
                                if (modifyG && !gUsed)
                                {
                                    _tempCol.g = GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    gUsed = true;
                                }
                                
                                if (modifyB && !bUsed)
                                {
                                    _tempCol.b = GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    bUsed = true;
                                }
                                
                                if (modifyA && !aUsed)
                                {
                                    _tempCol.a = GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    aUsed = true;
                                }
                                
                                if (modifyRInv && !rInvUsed)
                                {
                                    _tempCol.r = 1.0f - GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    rInvUsed = true;
                                }
                                
                                if (modifyGInv && !gInvUsed)
                                {
                                    _tempCol.g = 1.0f - GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    gInvUsed = true;
                                }
                                
                                if (modifyBInv && !bInvUsed)
                                {
                                    _tempCol.b = 1.0f - GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    bInvUsed = true;
                                }
                                
                                if (modifyAInv && !aInvUsed)
                                {
                                    _tempCol.a = 1.0f - GetNextColorChannelValue(_tempReadCol, readChannels, ref usedChannels);
                                    aInvUsed = true;
                                }
                            }
                            pixels[i + j * _textureToModify.width] = _tempCol;
                        }
                    }
                    
                    tex.SetPixels(pixels);
                    tex.Apply();
                    var bytes = tex.EncodeToPNG();
                    _filePath = AssetDatabase.GetAssetPath(_textureToModify).Replace(".jpg", "_edited") + "_composited" + ".png";
                    if (_customFilePath)
                    {
                        _filePath = EditorUtility.SaveFilePanelInProject("Choose File path", "New Albedo_Edited", "png", "Location Settled", AssetDatabase.GetAssetPath(_textureToModify));
                    }
                    if(_filePath.Length != 0) {
                        if (!_overrideExisting)
                            _filePath = AssetDatabase.GenerateUniqueAssetPath(_filePath);
                        System.IO.File.WriteAllBytes(_filePath, bytes);
                        AssetDatabase.Refresh();
                        EditorGUIUtility.PingObject(AssetDatabase.LoadAssetAtPath<Texture2D>(_filePath));
                    }
                }   
            }
            
            GUILayout.Label("File Path: " + _filePath, EditorStyles.helpBox);
        }
    }

    private float GetNextColorChannelValue(Color color, bool[] readChannels, ref bool[] usedChannels)
    {
        if (readChannels[0] && !usedChannels[0])
        {
            return color.r;
            usedChannels[0] = true;
        }
        if (readChannels[1] && !usedChannels[1])
        {
            return color.g;
            usedChannels[1] = true;
        }
        if (readChannels[2] && !usedChannels[2])
        {
            return color.b;
            usedChannels[2] = true;
        }
        if (readChannels[3] && !usedChannels[3])
        {
            return color.a;
            usedChannels[3] = true;
        }
        
        if (readChannels[4] && !usedChannels[4])
        {
            return 1.0f - color.r;
            usedChannels[4] = true;
        }
        if (readChannels[5] && !usedChannels[5])
        {
            return  1.0f - color.g;
            usedChannels[5] = true;
        }
        if (readChannels[6] && !usedChannels[6])
        {
            return  1.0f - color.b;
            usedChannels[6] = true;
        }
        if (readChannels[7] && !usedChannels[7])
        {
            return  1.0f - color.a;
            usedChannels[7] = true;
        }
        return color.r;
    }
    
    private void CheckIfTexturesAreValid()
    {
        if (_textureToModify == null || _textureToReadFrom == null)
        {
            // null textures
            EditorGUILayout.HelpBox("Please Assign Textures", MessageType.Warning);
            _texturesValid = false;
            return;
        }

        if (_textureToModify.width != _textureToReadFrom.width)
        {
            EditorGUILayout.HelpBox("Texture Width Not Same", MessageType.Error);
            _texturesValid = false;
            return;
        }

        if (_textureToModify.height != _textureToReadFrom.height)
        {
            EditorGUILayout.HelpBox("Texture Height Not Same", MessageType.Error);
            _texturesValid = false;
            return;
        }

        if (CalculateFlagNum(ReadTextureChannel) < 1 || CalculateFlagNum(ModifyTextureChannel) < 1)
        {
            EditorGUILayout.HelpBox("Please select Channels", MessageType.Warning);
            _texturesValid = false;
            return;
        }
        
        if (CalculateFlagNum(ReadTextureChannel) != CalculateFlagNum(ModifyTextureChannel))
        {
            EditorGUILayout.HelpBox("Channel Number Not Same", MessageType.Error);
            _texturesValid = false;
            return;
        }

        _texturesValid = true;
    }

    private int CalculateFlagNum(TextureChannel channelEnum)
    {
        int num = 0;
        
        if (((int)channelEnum & 1<<0) > 0) // R
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<1) > 0) // G
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<2) > 0) // B
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<3) > 0) // A
        {
            num++;
        }
        
        if (((int)channelEnum & 1<<4) > 0) // R
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<5) > 0) // G
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<6) > 0) // B
        {
            num++;
        }
                    
        if (((int)channelEnum & 1<<7) > 0) // A
        {
            num++;
        }

        return num;
    }
}
