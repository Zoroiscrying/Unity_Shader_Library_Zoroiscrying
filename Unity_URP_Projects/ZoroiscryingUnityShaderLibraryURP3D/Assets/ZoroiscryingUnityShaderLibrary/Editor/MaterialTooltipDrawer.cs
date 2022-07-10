﻿// --------------------------------------------------------------------------------------------------------------------
// <copyright file="TooltipDrawer.cs" company="Supyrb">
//   Copyright (c) 2018 Supyrb. All rights reserved.
// </copyright>
// <author>
//   Johannes Deml
//   send@johannesdeml.com
// </author>
// --------------------------------------------------------------------------------------------------------------------

using System;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Editor
{
    public class MaterialTooltipDrawer : MaterialPropertyDrawer
    {
        private GUIContent guiContent;
 
        private MethodInfo internalMethod;
        private Type[] methodArgumentTypes;
        private object[] methodArguments;
 
        public MaterialTooltipDrawer(string tooltip)
        {
            this.guiContent = new GUIContent(string.Empty, tooltip);
 
            methodArgumentTypes = new[] {typeof(Rect), typeof(MaterialProperty), typeof(GUIContent)};
            methodArguments = new object[3];
         
            internalMethod = typeof(MaterialEditor)
                .GetMethod("DefaultShaderPropertyInternal", BindingFlags.Instance | BindingFlags.NonPublic,
                    null,
                    methodArgumentTypes,
                    null);
        }
 
        public override void OnGUI(Rect position, MaterialProperty prop, String label, MaterialEditor editor)
        {
            guiContent.text = label;
             
            if (internalMethod != null)
            {
                methodArguments[0] = position;
                methodArguments[1] = prop;
                methodArguments[2] = guiContent;
             
                internalMethod.Invoke(editor, methodArguments);
            }
        }
    }
}