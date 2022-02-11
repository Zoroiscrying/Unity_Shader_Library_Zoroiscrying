using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Utility
{
    public class ChildPositionOrganizer : ChildTransformOrganizer
    {
        [SerializeField] private Vector3 rootPosition;

        [SerializeField] private Vector3 childPosInterval;

        protected override void UpdateChildTransforms()
        {
            for (int i = 0; i < childTransforms.Count; i++)
            {
                childTransforms[i].position = rootPosition + i * childPosInterval;
            }
        }
    }
}