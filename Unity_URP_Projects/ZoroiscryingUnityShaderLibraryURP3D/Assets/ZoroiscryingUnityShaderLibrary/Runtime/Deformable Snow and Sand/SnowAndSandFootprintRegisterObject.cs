using System;
using Unity.Mathematics;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Deformable_Snow_and_Sand
{
    /// <summary>
    /// Data aiding snow depression calculation
    /// - PositionWS: foot print position in world space (xy for calculating uv, z for calculating depression height)
    /// - DepressionCoefficient: coefficient for calculating depression height based on distance.
    /// </summary>
    [Serializable]
    public struct SnowFootprintData
    {
        public float3 positionWorldSpace;
        public float depressionCoefficient;
    }

    public class SnowAndSandFootprintRegisterObject : MonoBehaviour
    {
        #region Variables and Properties

        [SerializeField] private bool footPrintObjectActivated = true;
        
        private bool m_addedToFootprintManager = false;
        
        public bool FootPrintObjectActivated => footPrintObjectActivated && this.isActiveAndEnabled;
        
        [SerializeField] private float depressionCoefficient = 1.0f;
        
        private SnowFootprintData _snowFootprintData = new SnowFootprintData();
        public SnowFootprintData RetrieveFootPrintData 
        {
            get
            {
                UpdateSnowFootprintData();
                return _snowFootprintData;
            }
        }
        
        #endregion

        #region Unity Functions

        private void OnEnable()
        {
            AddToFootprintManager();
        }

        private void Update()
        {
            if (footPrintObjectActivated)
            {
                AddToFootprintManager();
            }
        }

        private void OnDisable()
        {
            SnowAndSandFootprintObjectManager.Remove(this);
            m_addedToFootprintManager = false;
        }

        #endregion

        private void UpdateSnowFootprintData()
        {
            _snowFootprintData.positionWorldSpace = this.transform.position;
            _snowFootprintData.depressionCoefficient = depressionCoefficient;
        }

        private void AddToFootprintManager()
        {
            if (!m_addedToFootprintManager)
            {
                m_addedToFootprintManager = SnowAndSandFootprintObjectManager.Add(this);
            }
        }
    }
}