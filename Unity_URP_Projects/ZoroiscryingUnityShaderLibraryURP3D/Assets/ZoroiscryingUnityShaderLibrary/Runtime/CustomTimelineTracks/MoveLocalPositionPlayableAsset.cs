using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Playables;

namespace ZoroiscryingUnityShaderLibrary.Runtime.CustomTimelineTracks
{
    public class MoveLocalPositionPlayableAsset : PlayableAsset
    {
        //public ExposedReference<Transform> transform;
        public Vector3 relativeMovePosition = Vector3.zero;
        public double2 trackStartEnd = double2.zero;

        public override Playable CreatePlayable (PlayableGraph graph, GameObject owner)
        {
            var playable = ScriptPlayable<MoveLocalPositionPlayableBehavior>.Create(graph);

            var moveLocalPositionPlayableBehavior = playable.GetBehaviour();
            var newTransform = owner.transform;
            moveLocalPositionPlayableBehavior.InitializeParameters(newTransform, relativeMovePosition);
            moveLocalPositionPlayableBehavior.startEnd = trackStartEnd;
            moveLocalPositionPlayableBehavior.director = graph.GetResolver() as PlayableDirector;

            return playable;
        }
    }
}