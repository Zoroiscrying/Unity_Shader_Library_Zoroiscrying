using Unity.Mathematics;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System
{
    public abstract class BaseWindContributor : MonoBehaviour
    {
        [Header("Basic Parameters")] 
        public float intensityMult = 1.0f;
        public float sizeMult = 1.0f;
        
        public Vector3 WindCenter => this.transform.position;

        public Matrix4x4 WindTransformLocalToWorld => this.transform.localToWorldMatrix;

        public Matrix4x4 WindTransformWorldToLocal => this.transform.worldToLocalMatrix;

        /// <summary>
        /// Wind Contributor Shape
        /// 0 - None
        /// 1 - Box
        /// 2 - Sphere
        /// 3 - Cylinder
        /// </summary>
        public enum WindContributorShape {None, Box, Sphere, Cylinder}
        
        /// <summary>
        /// Wind Calculation Type
        /// 0 - Fixed
        /// 1 - Point
        /// 2 - AxisVortex
        /// </summary>
        public enum WindCalculationType {Fixed, Point, AxisVortex}

        [SerializeField] private WindContributorShape shape = WindContributorShape.None;
        [SerializeField] private WindCalculationType calculateType = WindCalculationType.Fixed;
        
        protected bool _initialized = false;

        public bool IsOn
        {
            get
            {
                if (!isActiveAndEnabled)
                {
                    return false;
                }
                
                Init();

                return WindEnabled();
            }
            
            private set {}
        }
        
        public WindContributorShape Shape 
        {
            get 
            { 
                Init();
                return shape; 
            }
            protected set {}
        }
        
        public WindCalculationType CalculationType {
            get 
            { 
                Init();
                return calculateType; 
            }
            protected set {}
        }

        protected abstract void Init();

        protected abstract bool WindEnabled();
    }
}