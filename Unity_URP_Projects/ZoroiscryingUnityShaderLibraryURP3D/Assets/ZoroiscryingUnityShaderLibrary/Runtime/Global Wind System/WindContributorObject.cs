using System;
using Unity.Mathematics;
using UnityEditor;
using static Unity.Mathematics.math;
using UnityEngine;
using UnityEngine.Serialization;
using quaternion = Unity.Mathematics.quaternion;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System
{
    // [ExecuteInEditMode]
    public class WindContributorObject : BaseWindContributor
    {
        #region Variables and Properties

        [SerializeField] private bool windActivated = true;
        //public bool WindActivated => windActivated;
        
        [Header("Box Wind Parameters")] 
        [SerializeField] private Vector3 boxWindLocalExtends = Vector3.one; // local XYZ extends
        
        public Vector3 BoxWindLocalExtends => boxWindLocalExtends;

        [Header("Sphere Wind Parameters")] 
        [SerializeField] private float sphereWindExtend = 1.0f; // radius
        
        public float SphereWindExtend => sphereWindExtend * this.transform.localScale.z;
        public float SphereWindExtendSquared => SphereWindExtend * SphereWindExtend;

        [Header("Cylinder Wind Parameters")] // Radius^2 and height
        [SerializeField] private Vector2 cylinderWindLocalExtends = Vector2.one;
        
        public Vector2 CylinderWindLocalExtends => cylinderWindLocalExtends;
        public Vector2 CylinderWindLocalExtendsRadiusSquared => 
            new Vector2(cylinderWindLocalExtends.x * cylinderWindLocalExtends.x, cylinderWindLocalExtends.y);

        [Header("Wind Shape Velocity Influence")] 
        [SerializeField] private float windShapeVelocityInfluence = 1.0f;

        public float WindShapeVelocityInfluence => windShapeVelocityInfluence;

        [Header("Fixed Wind Calculation")] // fixed wind can be local (direction follow rotation) or global
        [SerializeField] private bool fixedWindIsLocal = true;
        [SerializeField] private Vector3 fixedWindVelocityLocal = new Vector3(1, 0, 0);
        [SerializeField] private Vector3 fixedWindVelocityGlobal = new Vector3(1, 0, 0);

        public bool FixedWindIsLocal => fixedWindIsLocal;
        public Vector3 FixedWindVelocityWorldSpace => 
            fixedWindIsLocal ? this.transform.TransformVector(fixedWindVelocityLocal) : fixedWindVelocityGlobal;

        [Header("Point-based Wind Calculation")]
        [SerializeField] private Vector3 centerPointLocal = Vector3.zero;
        [FormerlySerializedAs("maxWindSpeed")] [SerializeField] 
        private float pointBasedMaxWindSpeed = 1f;
        [FormerlySerializedAs("distanceDecayInfluence")] [SerializeField] 
        private float pointBasedDistanceDecayInfluence = 1.0f; // logarithmic decay - e^(i * d)
        public Vector3 CenterPointWorldSPace => this.transform.TransformPoint(centerPointLocal);
        public float PointBasedMaxWindSpeed => pointBasedMaxWindSpeed;
        public float PointBasedDistanceDecayInfluence => pointBasedDistanceDecayInfluence;
        /// <summary>
        /// Center Point (XYZ) + MaxWindSpeed (W)
        /// </summary>
        public Vector4 PointBaseWindCalculationDataAlpha
        {
            get
            {
                var centerPointWs = CenterPointWorldSPace;
                return new Vector4(centerPointWs.x, centerPointWs.y, centerPointWs.z, PointBasedMaxWindSpeed);
            }
        }
        
        [Header("Axis-based Wind Calculation")] 
        [SerializeField] private Vector3 axisPointLocal = Vector3.zero;
        [SerializeField] private Vector3 axisDirectionLocal = Vector3.up;
        [SerializeField] private float axisDistanceDecayInfluence = 1.0f; // logarithmic decay
        [SerializeField] private float axisRotationVelocityMultiplier = 1.0f; // multiplied after cross product of two vectors

        /// <summary>
        /// Axis point world space (XYZ) + Axis Distance Decay Influence (W)
        /// </summary>
        public Vector4 AxisBaseWindCalculationDataAlpha
        {
            get
            {
                var axisPointWorldSpace = this.transform.TransformPoint(axisPointLocal);
                return new Vector4(axisPointWorldSpace.x, axisPointWorldSpace.y, axisPointWorldSpace.z, axisDistanceDecayInfluence);   
            }
        }
        /// <summary>
        /// Axis direction world space (XYZ) + Axis Rotation Velocity Multiplier (W)
        /// </summary>
        public Vector4 AxisBaseWindCalculationDataBeta
        {
            get
            {
                axisDirectionLocal = axisDirectionLocal.normalized;
                var axisDirectionWorldSpace = this.transform.TransformDirection(axisDirectionLocal);
                return new Vector4(axisDirectionWorldSpace.x, axisDirectionWorldSpace.y, axisDirectionWorldSpace.z, axisRotationVelocityMultiplier);       
            }
        }

        private bool m_addedToLightManager = false;

        #endregion

        #region Unity Functions

        private void OnEnable()
        {
            AddToWindContributorManager();
        }
        
        private void Update()
        {
            // wind contributor manager might not have been available during OnEnable, So keep trying
            AddToWindContributorManager();
        }

        private void OnDisable()
        {
            WindContributorManager.Remove(this);
            m_addedToLightManager = false;
        }

        #region Public Functions
        // Public Functions for modifying wind parameters at runtime (intensity, range, etc)
        

        #endregion

        #region Debug
        

        #endregion

        #endregion

        #region Private and Protected Functions

        protected override void Init()
        {
            if (_initialized)
            {
                return;
            }

            _initialized = true;
        }

        protected override bool WindEnabled()
        {
            return windActivated;
        }

        private void AddToWindContributorManager()
        {
            if (!m_addedToLightManager)
            {
                m_addedToLightManager = WindContributorManager.Add(this);
            }
        }

        #endregion
    }
}