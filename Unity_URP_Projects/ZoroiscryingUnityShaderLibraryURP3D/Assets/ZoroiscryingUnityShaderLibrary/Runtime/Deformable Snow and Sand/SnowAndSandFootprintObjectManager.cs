using System;
using System.Collections.Generic;
using UnityEngine;
using ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Deformable_Snow_and_Sand
{
    public class SnowAndSandFootprintObjectManager : MonoBehaviour
    {
        private static bool _shuttingDown = false;
        
        private static SnowAndSandFootprintObjectManager s_Instance;
        private HashSet<SnowAndSandFootprintRegisterObject> m_Container = new HashSet<SnowAndSandFootprintRegisterObject>();
        private SnowFootprintData[] m_snowFootprintData = Array.Empty<SnowFootprintData>();

        public static SnowAndSandFootprintObjectManager Instance
        {
            get
            {
                if (_shuttingDown)
                {
                    Debug.LogWarning(
                        "Trying to access the Wind Contributor Manager while shutting down, returning null.");
                    return null;
                }

                if (s_Instance != null)
                {
                    return s_Instance;
                }

                s_Instance = (SnowAndSandFootprintObjectManager)FindObjectOfType(typeof(SnowAndSandFootprintObjectManager));

                if (s_Instance == null)
                {
                    s_Instance = new GameObject("Wind Contributor Manager").AddComponent<SnowAndSandFootprintObjectManager>();
                }

                if (s_Instance == null)
                {
                    Debug.LogWarning("Failed to create or find Wind Contributor Manager, Please check the code.");
                }

                return s_Instance;
            }
        }
        
        private void OnEnable()
        {
            _shuttingDown = false;
        }

        private void OnApplicationQuit()
        {
            _shuttingDown = true;
        }

        private void OnDestroy()
        {
            _shuttingDown = true;
        }
        
        public static HashSet<SnowAndSandFootprintRegisterObject> Get()
        {
            SnowAndSandFootprintObjectManager instance = Instance;
            return instance == null ? new HashSet<SnowAndSandFootprintRegisterObject>() : instance.m_Container;
        }

        public static SnowFootprintData[] GetData()
        {
            SnowAndSandFootprintObjectManager instance = Instance;
            if (instance == null)
            {
                return null;
            }
            
            // update all data and then pass the data out
            var index = 0;
            foreach (var footPrint in instance.m_Container)
            {
                instance.m_snowFootprintData[index++] = footPrint.RetrieveFootPrintData;
            }

            return instance.m_snowFootprintData;
        }

        public static int GetFootprintCount()
        {
            if (Instance == null)
            {
                return 0;
            }
            return Get().Count;
        }
        
        public static bool Add(SnowAndSandFootprintRegisterObject obj)
        {
            SnowAndSandFootprintObjectManager instance = Instance;
            
            if (instance == null)
            {
                return false;
            }

            if (obj.FootPrintObjectActivated)
            {
                if (!instance.m_Container.Contains(obj))
                {
                    instance.m_Container.Add(obj);   
                    // re-create the data array
                    instance.m_snowFootprintData = new SnowFootprintData[instance.m_Container.Count];
                }
            }

            return true;
        }

        public static void Remove(SnowAndSandFootprintRegisterObject obj)
        {
            SnowAndSandFootprintObjectManager instance = Instance;
            
            if (instance == null)
            {
                return;
            }

            if (instance.m_Container.Contains(obj))
            {
                instance.m_Container.Remove(obj);   
                // re-create the data array
                instance.m_snowFootprintData = new SnowFootprintData[instance.m_Container.Count];
            }
        }
    }
}