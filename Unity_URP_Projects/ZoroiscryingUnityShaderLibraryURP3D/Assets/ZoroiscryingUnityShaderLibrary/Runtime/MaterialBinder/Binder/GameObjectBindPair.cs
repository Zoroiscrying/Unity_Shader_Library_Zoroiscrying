using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    [Serializable]
    public class GameObjectBindPair : BaseBindPair
    {
        public GameObjectBindOption bindOption;
        public GameObject gameObj;
    }
}