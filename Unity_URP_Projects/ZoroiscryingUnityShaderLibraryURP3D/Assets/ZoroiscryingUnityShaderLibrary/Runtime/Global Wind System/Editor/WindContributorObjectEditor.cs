using System;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Global_Wind_System.Editor
{
    [CustomEditor(typeof(WindContributorObject))]
    public class WindContributorObjectEditor : UnityEditor.Editor
    {
        private WindContributorObject _windObject;
        private bool _cached = false;
        private bool _selected = false;

        private Color _boxWindColor = Color.white;
        private Color _sphereWindColor = Color.white;
        private Color _cylinderWindColor = Color.white;
        
        private Color _fixedCalculationColor = new Color(1.0f, 0.5f, 0f, 0.5f);
        private Color _pointBasedCalculationColor = new Color(1, 1, 0, 0.5f);
        private Color _axisBasedCalculationColor = new Color(0f, 0.5f, 1, 0.5f);

        private Vector3[] _pointDirections =
        {
            Vector3.up, Vector3.down, Vector3.left, Vector3.right, Vector3.forward, Vector3.back, 
            new Vector3(1, 1, 1), new Vector3(1 ,1 , -1), new Vector3(1, -1, 1), new Vector3(1, -1, -1),
            new Vector3(-1, 1 ,1), new Vector3(-1, 1, -1), new Vector3(-1, -1, 1), new Vector3(-1, -1, -1)
        };
        
        private Vector3[] _axisSurroundingPointsLocal =
        {
            Vector3.right, Vector3.left, Vector3.forward, Vector3.back, 
            new Vector3(1, 0, 1), new Vector3(1, 0, -1), new Vector3(-1, 0 ,1), new Vector3(-1, 0 ,-1)
        };

        // Control IDs
        private int _boxHandleID;
        private int _sphereHandleID;
        private int _cylinderHandleID;
        private int _fixedCalculationHandleID;
        private int _pointBasedCalculationHandleID;
        private int _axisBasedCalculationHandleID;
        
        // Inspector GUI
        // Basic Parameters
        private SerializedProperty _intensityMult;
        private SerializedProperty _sizeMult;
        private SerializedProperty _shape;
        private SerializedProperty _calculateType;
        // Box Wind
        private SerializedProperty _boxWindLocalExtends;
        // Sphere Wind
        private SerializedProperty _sphereWindExtend;
        // Cylinder Wind
        private SerializedProperty _cylinderWindLocalExtends;
        // Fixed Wind
        private SerializedProperty _fixedWindIsLocal;
        private SerializedProperty _fixedWindVelocityLocal;
        private SerializedProperty _fixedWindVelocityGlobal;
        // Point Based Wind
        private SerializedProperty _centerPointLocal;
        private SerializedProperty _pointBasedMaxWindSpeed;
        private SerializedProperty _pointBasedDistanceDecayInfluence;
        // Axis Based Wind
        private SerializedProperty _axisPointLocal;
        private SerializedProperty _axisDirectionLocal;
        private SerializedProperty _axisDistanceDecayInfluence;
        private SerializedProperty _axisRotationVelocityMultiplier;

        public override void OnInspectorGUI()
        {
            Initialize();
            
            //base.OnInspectorGUI();
            serializedObject.Update();
            
            // Basic Parameters
            EditorGUILayout.PropertyField(_shape, new GUIContent("Wind Shape"));
            EditorGUILayout.PropertyField(_calculateType, new GUIContent("Velocity Type"));
            EditorGUILayout.PropertyField(_intensityMult, new GUIContent("Intensity Multiplier"));
            EditorGUILayout.PropertyField(_sizeMult, new GUIContent("Size Multiplier"));

            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                switch (_windObject.Shape)
                {
                    case BaseWindContributor.WindContributorShape.None:
                        EditorGUILayout.HelpBox("Please Choose A Wind Shape.", MessageType.Error);
                        break;
                    case BaseWindContributor.WindContributorShape.Box:
                        EditorGUILayout.PropertyField(_boxWindLocalExtends, new GUIContent("Box Wind Local Extends"));
                        break;
                    case BaseWindContributor.WindContributorShape.Sphere:
                        EditorGUILayout.PropertyField(_sphereWindExtend, new GUIContent("Sphere Wind Radius"));
                        break;
                    case BaseWindContributor.WindContributorShape.Cylinder:
                        EditorGUILayout.TextField("ExtendX - Radius, ExtendY - Height");
                        EditorGUILayout.PropertyField(_cylinderWindLocalExtends, new GUIContent("Cylinder Wind Local Extends", "ExtendX - Radius, ExtendY - Height"));
                        break;
                    default:
                        EditorGUILayout.HelpBox("Please Choose A Wind Shape.", MessageType.Error);
                        break;
                }   
            }

            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                switch (_windObject.CalculationType)
                {
                    case BaseWindContributor.WindCalculationType.Fixed:
                        EditorGUILayout.PropertyField(_fixedWindIsLocal, new GUIContent("Fixed Velocity Is Local"));
                        if (_windObject.FixedWindIsLocal)
                        {
                            EditorGUILayout.PropertyField(_fixedWindVelocityLocal, new GUIContent("Local Velocity"));
                        }
                        else
                        {
                            EditorGUILayout.PropertyField(_fixedWindVelocityGlobal, new GUIContent("World Space Velocity"));
                        }
                        break;
                    case BaseWindContributor.WindCalculationType.Point:
                        EditorGUILayout.PropertyField(_centerPointLocal, 
                            new GUIContent("Position Local", "Position In Local Space"));
                        EditorGUILayout.PropertyField(_pointBasedMaxWindSpeed, 
                            new GUIContent("Max Speed", "Wind Speed Closest to the center point, Can be negative to change wind direction."));
                        EditorGUILayout.PropertyField(_pointBasedDistanceDecayInfluence, 
                            new GUIContent("Distance Decay", "The Calculation is e^(-distance * decay), greater decay would cause wind speed to shrink faster."));
                        break;
                    case BaseWindContributor.WindCalculationType.AxisVortex:
                        EditorGUILayout.PropertyField(_axisPointLocal, 
                            new GUIContent("Axis Position Local", "Axis Center Position In Local Space"));
                        EditorGUILayout.PropertyField(_axisDirectionLocal, 
                            new GUIContent("Axis Direction Local", "Axis Direction In Local Space"));
                        EditorGUILayout.PropertyField(_axisDistanceDecayInfluence, 
                            new GUIContent("Distance Decay", "The calculation is e^(-distance * decay), greater decay would cause wind speed to shrink faster."));
                        EditorGUILayout.PropertyField(_axisRotationVelocityMultiplier, 
                            new GUIContent("Velocity Multiplier", "The velocity multiplier, can be negative to change wind directions."));
                        break;
                    default:
                        EditorGUILayout.HelpBox("Please Choose A Wind Calculation Type.", MessageType.Error);
                        break;
                }
            }

            serializedObject.ApplyModifiedProperties();
        }

        private void OnSceneGUI()
        {
            Initialize();

            _selected = false || Selection.Contains(_windObject.gameObject);

            if (Event.current.type == EventType.Repaint)
            {
                switch (_windObject.Shape)
                {
                    case BaseWindContributor.WindContributorShape.Box:
                        DebugGizmosBoxWind();
                        break;
                    case BaseWindContributor.WindContributorShape.Sphere:
                        DebugGizmosSphereWind();
                        break;
                    case BaseWindContributor.WindContributorShape.Cylinder:
                        DebugGizmosCylinderWind();
                        break;
                }
            }
        }

        #region Scene GUI

        private void Initialize()
        {
            if (_cached) return;
            
            _windObject = (WindContributorObject)target;

            _boxHandleID = GUIUtility.GetControlID(FocusType.Passive);
            _sphereHandleID = GUIUtility.GetControlID(FocusType.Passive);
            _cylinderHandleID = GUIUtility.GetControlID(FocusType.Passive);
            _fixedCalculationHandleID = GUIUtility.GetControlID(FocusType.Passive);
            _pointBasedCalculationHandleID = GUIUtility.GetControlID(FocusType.Passive);
            _axisBasedCalculationHandleID = GUIUtility.GetControlID(FocusType.Passive);

            // up down, left right, forward backward
            _pointDirections[6].Normalize();
            _pointDirections[7].Normalize();
            _pointDirections[8].Normalize();
            _pointDirections[9].Normalize();
            _pointDirections[10].Normalize();
            _pointDirections[11].Normalize();
            _pointDirections[12].Normalize();
            _pointDirections[13].Normalize();
                
            // 
            _axisSurroundingPointsLocal[4].Normalize();
            _axisSurroundingPointsLocal[5].Normalize();
            _axisSurroundingPointsLocal[6].Normalize();
            _axisSurroundingPointsLocal[7].Normalize();
                
            // Inspector GUI
            _intensityMult = serializedObject.FindProperty("intensityMult");
            _sizeMult = serializedObject.FindProperty("sizeMult");
            _shape = serializedObject.FindProperty("shape");
            _calculateType = serializedObject.FindProperty("calculateType");
                
            _boxWindLocalExtends = serializedObject.FindProperty("boxWindLocalExtends");
                
            _sphereWindExtend = serializedObject.FindProperty("sphereWindExtend");
                
            _cylinderWindLocalExtends = serializedObject.FindProperty("cylinderWindLocalExtends");
                
            _fixedWindIsLocal = serializedObject.FindProperty("fixedWindIsLocal");
            _fixedWindVelocityLocal = serializedObject.FindProperty("fixedWindVelocityLocal");
            _fixedWindVelocityGlobal = serializedObject.FindProperty("fixedWindVelocityGlobal");
                
            _centerPointLocal = serializedObject.FindProperty("centerPointLocal");
            _pointBasedMaxWindSpeed = serializedObject.FindProperty("pointBasedMaxWindSpeed");
            _pointBasedDistanceDecayInfluence = serializedObject.FindProperty("pointBasedDistanceDecayInfluence");
                
            _axisPointLocal = serializedObject.FindProperty("axisPointLocal");
            _axisDirectionLocal = serializedObject.FindProperty("axisDirectionLocal");
            _axisDistanceDecayInfluence = serializedObject.FindProperty("axisDistanceDecayInfluence");
            _axisRotationVelocityMultiplier = serializedObject.FindProperty("axisRotationVelocityMultiplier");
                
            _cached = true;
        }

        /// <summary>
        /// Draw box extends in world space
        /// Enabling dragging-editing of box extends
        /// </summary>
        private void DebugGizmosBoxWind()
        {
            Handles.color = _boxWindColor;
            Handles.matrix = _windObject.WindTransformLocalToWorld;
            Handles.DrawWireCube(Vector3.zero,  _windObject.BoxWindLocalExtends);
            
            Handles.matrix = Matrix4x4.identity;
            
            switch (_windObject.CalculationType)
            {
                case BaseWindContributor.WindCalculationType.Fixed:
                    DebugGizmosFixedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.Point:
                    DebugGizmosPointBasedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.AxisVortex:
                    DebugGizmosAxisBasedCalculation();
                    break;
            }
        }

        /// <summary>
        /// Draw Sphere wireframe in world space
        /// Enabling dragging-editing of sphere radius
        /// </summary>
        private void DebugGizmosSphereWind()
        {
            Handles.color = new Color(_sphereWindColor.r, _sphereWindColor.g, _sphereWindColor.b, _sphereWindColor.a * 0.5f);
            Handles.DrawWireDisc(_windObject.WindCenter, Vector3.up, _windObject.SphereWindExtend);
            Handles.DrawWireDisc(_windObject.WindCenter, Vector3.right, _windObject.SphereWindExtend);
            Handles.DrawWireDisc(_windObject.WindCenter, Vector3.forward, _windObject.SphereWindExtend);
            Handles.color = _sphereWindColor;
            Handles.DrawWireDisc(_windObject.WindCenter, Camera.current.transform.forward,
                _windObject.SphereWindExtend);
            
            switch (_windObject.CalculationType)
            {
                case BaseWindContributor.WindCalculationType.Fixed:
                    DebugGizmosFixedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.Point:
                    DebugGizmosPointBasedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.AxisVortex:
                    DebugGizmosAxisBasedCalculation();
                    break;
            }
        }
        
        /// <summary>
        /// Draw Cylinder wireframe in world space
        /// Enabling dragging-editing of cylinder extends
        /// </summary>
        private void DebugGizmosCylinderWind()
        {
            Handles.matrix = _windObject.WindTransformLocalToWorld;
            Handles.DrawWireDisc( +_windObject.CylinderWindLocalExtends.y/2 * Vector3.up, Vector3.up, _windObject.CylinderWindLocalExtends.x);
            Handles.DrawWireDisc(-_windObject.CylinderWindLocalExtends.y/2 * Vector3.up, Vector3.up, _windObject.CylinderWindLocalExtends.x);
            
            Handles.DrawLine(new Vector3(_windObject.CylinderWindLocalExtends.x, _windObject.CylinderWindLocalExtends.y/2, 0), 
                new Vector3(_windObject.CylinderWindLocalExtends.x, -_windObject.CylinderWindLocalExtends.y/2, 0));
            
            Handles.DrawLine(new Vector3(-_windObject.CylinderWindLocalExtends.x, _windObject.CylinderWindLocalExtends.y/2, 0), 
                new Vector3(-_windObject.CylinderWindLocalExtends.x, -_windObject.CylinderWindLocalExtends.y/2, 0));
            
            Handles.DrawLine(new Vector3(0, _windObject.CylinderWindLocalExtends.y/2, _windObject.CylinderWindLocalExtends.x), 
                new Vector3(0, -_windObject.CylinderWindLocalExtends.y/2, _windObject.CylinderWindLocalExtends.x));
            
            Handles.DrawLine(new Vector3(0, _windObject.CylinderWindLocalExtends.y/2, -_windObject.CylinderWindLocalExtends.x),
                new Vector3(0, -_windObject.CylinderWindLocalExtends.y/2, -_windObject.CylinderWindLocalExtends.x));
            
            Handles.matrix = Matrix4x4.identity;
            
            switch (_windObject.CalculationType)
            {
                case BaseWindContributor.WindCalculationType.Fixed:
                    DebugGizmosFixedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.Point:
                    DebugGizmosPointBasedCalculation();
                    break;
                case BaseWindContributor.WindCalculationType.AxisVortex:
                    DebugGizmosAxisBasedCalculation();
                    break;
            }
        }

        /// <summary>
        /// Draw Several Indicators for velocity influences
        /// </summary>
        private void DebugGizmosFixedCalculation()
        {
            // FixedWindVelocityWorldSpace
            Vector3 centerPointWorldSpace = _windObject.WindCenter;
            var normalizedFixedWindDirection = _windObject.FixedWindVelocityWorldSpace.normalized;
            var fixedWindSpeed = _windObject.FixedWindVelocityWorldSpace.magnitude;
            var right = _windObject.transform.right;
            var upVec = Vector3.Cross(right, normalizedFixedWindDirection);
            var remapVal = math.remap(0f, 5f, 1.0f, 4.0f, fixedWindSpeed);

            var rotation = Quaternion.LookRotation(normalizedFixedWindDirection, upVec);
            
            Handles.color = _fixedCalculationColor;

            Handles.ArrowHandleCap(_fixedCalculationHandleID, 
                centerPointWorldSpace + right * 1.0f, 
                rotation, 
                remapVal * 0.15f, 
                EventType.Repaint);
            
            Handles.ArrowHandleCap(_fixedCalculationHandleID, 
                centerPointWorldSpace, 
                rotation, 
                remapVal * 0.15f, 
                EventType.Repaint);
            
            Handles.ArrowHandleCap(_fixedCalculationHandleID, 
                centerPointWorldSpace - right * 1.0f, 
                rotation, 
                remapVal * 0.15f, 
                EventType.Repaint);
        }
        
        /// <summary>
        /// Draw point position as well as indicators for velocity influences
        /// Enabling user editing in scene editor
        /// </summary>
        private void DebugGizmosPointBasedCalculation()
        {
            Vector3 centerPointWorldSpace = _windObject.WindCenter;
            var pointWindSpeed = _windObject.PointBaseWindCalculationDataAlpha.w;
            var remapVal = math.remap(0f, 5f, 1.0f, 4.0f, pointWindSpeed);
            //var rotation = Quaternion.LookRotation(normalizedFixedWindDirection, upVec);
            
            Handles.color = _pointBasedCalculationColor;

            // draw one center sphere, and (6 + 4 + 4) 14 surrounding arrows
            Handles.SphereHandleCap(_pointBasedCalculationHandleID,
                centerPointWorldSpace,
                Quaternion.identity, 
                remapVal * 0.05f,
                EventType.Repaint);
            
            // remapVal * 0.15f for wire sphere

            for (int i = 0; i < 14; i++)
            {
                var direction = _pointDirections[i];
                var rotation = Quaternion.LookRotation(direction);
                Handles.ArrowHandleCap(_pointBasedCalculationHandleID, 
                    centerPointWorldSpace + direction * remapVal * 0.15f, 
                    rotation, 
                    remapVal * 0.15f, 
                    EventType.Repaint);
            }
        }
        
        /// <summary>
        /// Draw Axis point and direction, as well as indicators for velocity influences
        /// Enabling user editing in scene editor
        /// </summary>
        private void DebugGizmosAxisBasedCalculation()
        {
            Vector3 centerPointWorldSpace = _windObject.WindCenter;
            var normalizedAxisPointDecayMultiplier = _windObject.AxisBaseWindCalculationDataAlpha;
            var normalizedAxisDirectionRotationVelocityMultiplier = _windObject.AxisBaseWindCalculationDataBeta;
            var axisDirection = new Vector3(
                normalizedAxisDirectionRotationVelocityMultiplier.x,
                normalizedAxisDirectionRotationVelocityMultiplier.y,
                normalizedAxisDirectionRotationVelocityMultiplier.z);
            var axisWindSpeed = Mathf.Abs(normalizedAxisDirectionRotationVelocityMultiplier.w);
            var remapVal = math.remap(0f, 5f, 1.0f, 4.0f, axisWindSpeed);
            var velocityMultiplierIsPositive = Mathf.Sign(normalizedAxisDirectionRotationVelocityMultiplier.w);
            //var rotation = Quaternion.LookRotation(normalizedFixedWindDirection, upVec);
            
            Handles.color = _axisBasedCalculationColor;
            
            // center axis line
            Handles.DrawLine(
                centerPointWorldSpace - axisDirection * 1.0f, 
                centerPointWorldSpace + axisDirection * 1.0f, 
                4.0f);

            for (int i = 0; i < 8; i++)
            {
                var worldSurroundingPointPos = _windObject.transform.TransformPoint(_axisSurroundingPointsLocal[i]);
                var centerTowardPoint = (worldSurroundingPointPos - centerPointWorldSpace).normalized;
                var direction = Vector3.Cross(centerTowardPoint, axisDirection) * velocityMultiplierIsPositive;
                var rotation = Quaternion.LookRotation(direction);
                Handles.ArrowHandleCap(_axisBasedCalculationHandleID, 
                    worldSurroundingPointPos, 
                    rotation, 
                    remapVal * 0.1f, 
                    EventType.Repaint);
            }
        }

        #endregion

        #region Inspector GUI

        

        #endregion
        
    }
}