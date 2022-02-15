using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialModifier
{
    public class GradientTextureMaterialModifier : BaseMaterialModifier
    {
        public Gradient lutGradient;
        public Vector2Int lutTextureSize;
        public Texture2D lutTexture;
        public bool realtimeGeneration;

        protected override void Update()
        {
            if (realtimeGeneration)
            {
                ApplyMaterialChange();
            }
        }

        public override void ApplyMaterialChange()
        {
            lutTexture = new Texture2D(lutTextureSize.x, lutTextureSize.y) {wrapMode = TextureWrapMode.Clamp};

            for (var x = 0; x < lutTextureSize.x ; x++)
            {
                var color = lutGradient.Evaluate(x / (float) lutTextureSize.x);
                for (var y = 0; y < lutTextureSize.y; y++)
                {
                    lutTexture.SetPixel(x,y,color);
                }
            }
            
            lutTexture.Apply();
            material.SetTexture(propertyName, lutTexture);
        }
    }
}