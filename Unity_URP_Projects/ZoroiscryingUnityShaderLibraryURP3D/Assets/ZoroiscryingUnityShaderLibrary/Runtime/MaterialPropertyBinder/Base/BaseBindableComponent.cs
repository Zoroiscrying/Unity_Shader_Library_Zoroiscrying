using System;
using System.Data.SqlTypes;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    /// <summary>
    /// 
    /// </summary>
    /// <typeparam name="TC">The type of the value component.</typeparam>
    /// <typeparam name="TR">The type of the root for retrieving the component.</typeparam>
    public class BaseBindableComponent<TC, TR> : AbstractBindableComponent<TC, TR>
    {
        protected override TC RetrieveComponentValue(TR rootObject)
        {
            if (!RootObjectValid())
            {
                return default(TC);
            }

            return default(TC);
        }

        protected bool RootObjectValid()
        {
            if (boundRoot == null)
            {
                Debug.LogWarning(
                    $"The root object is not provided to retrieve component value.");
                return false;
            }

            return true;
        }
    }
}