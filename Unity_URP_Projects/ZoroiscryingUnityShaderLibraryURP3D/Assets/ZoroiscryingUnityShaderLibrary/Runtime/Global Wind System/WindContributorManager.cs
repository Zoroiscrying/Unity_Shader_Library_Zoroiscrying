using System;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System
{
    public class WindContributorManager : MonoBehaviour
    {
        private static bool _shuttingDown = false;
        
        private static WindContributorManager s_Instance;
        private HashSet<WindContributorObject> m_Container = new HashSet<WindContributorObject>();
        private Dictionary<BaseWindContributor.WindContributorShape, int> m_shapeCounterDictionary =
            new Dictionary<BaseWindContributor.WindContributorShape, int>();

        //public Dictionary<BaseWindContributor.WindContributorShape, int> ShapeCounterDict => m_shapeCounterDictionary;
        
        private Dictionary<BaseWindContributor.WindCalculationType, int> m_calculationTypeDictionary =
            new Dictionary<BaseWindContributor.WindCalculationType, int>();

        //public Dictionary<BaseWindContributor.WindCalculationType, int> CalculationTypeDict =>
        //    m_calculationTypeDictionary;

        public static WindContributorManager Instance
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

                s_Instance = (WindContributorManager)FindObjectOfType(typeof(WindContributorManager));

                if (s_Instance == null)
                {
                    s_Instance = new GameObject("Wind Contributor Manager").AddComponent<WindContributorManager>();
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

        public static HashSet<WindContributorObject> Get()
        {
            WindContributorManager instance = Instance;
            return instance == null ? new HashSet<WindContributorObject>() : instance.m_Container;
        }

        public static int GetWindShapeCount(BaseWindContributor.WindContributorShape shape)
        {
            if (Instance == null)
            {
                return 0;
            }
            return !Instance.m_shapeCounterDictionary.ContainsKey(shape) ? 0 : Instance.m_shapeCounterDictionary[shape];
        }
        
        public static int GetWindCalculationTypeCount(BaseWindContributor.WindCalculationType calculationType)
        {
            if (Instance == null)
            {
                return 0;
            }
            return !Instance.m_calculationTypeDictionary.ContainsKey(calculationType) ? 0 : Instance.m_calculationTypeDictionary[calculationType];
        }

        public static bool Add(WindContributorObject obj)
        {
            WindContributorManager instance = Instance;
            if (instance == null)
            {
                return false;
            }

            instance.m_Container.Add(obj);

            if (obj.Shape != BaseWindContributor.WindContributorShape.None)
            {
                if (instance.m_shapeCounterDictionary.ContainsKey(obj.Shape))
                {
                    instance.m_shapeCounterDictionary[obj.Shape]++;
                }
                else
                {
                    instance.m_shapeCounterDictionary.Add(obj.Shape, 1);
                }   
            }

            if (instance.m_calculationTypeDictionary.ContainsKey(obj.CalculationType))
            {
                instance.m_calculationTypeDictionary[obj.CalculationType]++;
            }
            else
            {
                instance.m_calculationTypeDictionary.Add(obj.CalculationType, 1);
            }

            return true;
        }

        public static void Remove(WindContributorObject obj)
        {
            WindContributorManager instance = Instance;
            if (instance == null)
            {
                return;
            }
            
            if (obj.Shape != BaseWindContributor.WindContributorShape.None)
            {
                if (instance.m_shapeCounterDictionary.ContainsKey(obj.Shape))
                {
                    instance.m_shapeCounterDictionary[obj.Shape]--;
                }
            }

            if (instance.m_calculationTypeDictionary.ContainsKey(obj.CalculationType))
            {
                instance.m_calculationTypeDictionary[obj.CalculationType]--;
            }

            instance.m_Container.Remove(obj);
        }

    }
}