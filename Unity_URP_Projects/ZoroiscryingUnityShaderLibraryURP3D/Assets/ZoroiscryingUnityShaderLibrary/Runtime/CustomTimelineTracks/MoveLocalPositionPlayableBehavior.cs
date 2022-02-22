using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Playables;

namespace ZoroiscryingUnityShaderLibrary.Runtime.CustomTimelineTracks
{
    public class MoveLocalPositionPlayableBehavior : PlayableBehaviour
    {
        //public Transform transform = null;
        //public Vector3 localMovePosition = Vector3.zero;
        private Vector3 originalWorldPos = Vector3.zero;
        private Vector3 endWorldPos = Vector3.zero;
        public Transform targetTransform = null;
        public double2 startEnd = double2.zero;
        public PlayableDirector director = null;
        //public 

        public void InitializeParameters(Transform transform, Vector3 rltvMovePos)
        {
            targetTransform = transform;
            originalWorldPos = transform.position;
            endWorldPos = transform.TransformPoint(Vector3.zero + rltvMovePos);
        }

        public override void ProcessFrame(Playable playable, FrameData info, object playerData)
        {
            if (targetTransform != null)
            {
                if (director)
                {
                    double tUnclamped = (director.time - startEnd.x) / (startEnd.y - startEnd.x);
                    float t = Mathf.Clamp01((float)tUnclamped);
                    targetTransform.localPosition = Vector3.Lerp(originalWorldPos, endWorldPos, t);
                }
            }
        }
    }
}