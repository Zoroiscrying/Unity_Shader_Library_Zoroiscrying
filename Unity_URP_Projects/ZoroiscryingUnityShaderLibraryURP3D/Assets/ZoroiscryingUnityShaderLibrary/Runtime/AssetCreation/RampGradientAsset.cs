using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.AssetCreation
{
    [CreateAssetMenu(menuName = "Asset Creation/Ramp Gradient", fileName = "New Gradient Ramp Asset")]
    public class RampGradientAsset : ScriptableObject
    {
        public Gradient gradient = new Gradient();
        public int size = 16;
        public bool up = false;
        public bool overwriteExisting = true;
    }
}