using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Shaders.ComputeShaderRelated
{
    public class ComputeUtils
    {
        //
        // Debug Compute Buffer
        // When you define a struct/class,
        // please use override ToString(), public override string ToString() => $"MpmParticle(position={position}, velocity={velocity})";
        //
        // debugging range is startIndex <= x < endIndex
        // example: 
        //    Util.DebugBuffer<uint2>(this.particlesBuffer, 1024, 1027); 
        //
        public static void DebugBuffer<T>(ComputeBuffer buffer, int startIndex, int endIndex) where T  : struct
        {
            int N = endIndex - startIndex;
            T[] array = new T[N];
            buffer.GetData(array, 0, startIndex, N);
            for (int i = 0; i < N; i++)
            {
                Debug.LogFormat("index={0}: {1}", startIndex + i, array[i]);
            }
        }
    }
}