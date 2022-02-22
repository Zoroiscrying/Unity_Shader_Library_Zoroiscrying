using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

namespace ZoroiscryingUnityShaderLibrary.Runtime.CustomTimelineTracks
{
    [TrackClipType(typeof(MoveLocalPositionPlayableAsset))]
    [TrackBindingType(typeof(Transform))]
    public class MoveLocalPositionTrackAsset : TrackAsset
    {
        public override Playable CreateTrackMixer(PlayableGraph graph, GameObject go, int inputCount)
        {
            foreach (var clip in GetClips())
            {
                var myAsset = clip.asset as MoveLocalPositionPlayableAsset;
                if (myAsset)
                {
                    //clip.duration
                    myAsset.trackStartEnd = new double2(clip.start, clip.end);
                }
            }
            
            return base.CreateTrackMixer(graph, go, inputCount);
        }
    }
}