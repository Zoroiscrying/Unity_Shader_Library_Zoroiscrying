using System;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.DynamicVegetation
{
    public class SwayInstanceActivator : MonoBehaviour
    {
        private void OnTriggerEnter(Collider other)
        {
            // Debug.Log(other.name);
            if (other.TryGetComponent(out SwayVegetationInstanceObject swayInstance))
            {
                swayInstance.QueueUpForEnable();
            }
        }

        private void OnTriggerExit(Collider other)
        {
            if (other.TryGetComponent(out SwayVegetationInstanceObject swayInstance))
            {
                swayInstance.QueueUpForDisable();
            }
        }
    }
}