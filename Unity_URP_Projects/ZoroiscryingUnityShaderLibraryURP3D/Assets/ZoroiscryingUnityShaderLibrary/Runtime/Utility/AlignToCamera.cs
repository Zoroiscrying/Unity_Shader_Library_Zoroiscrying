using System;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace ZoroiscryingUnityShaderLibrary.Runtime.Utility
{
    [ExecuteAlways]
    public class AlignToCamera : MonoBehaviour
    {
        [SerializeField] private Vector3 movableAxis = Vector3.one;
        private Camera _mainCam;
        private Quaternion _originalRotation;

        private void OnEnable()
        {
            if (Application.isPlaying)
            {
                _mainCam = Camera.main;
                _originalRotation = _mainCam.transform.rotation;   
            }
            else if (Application.isEditor)
            {
                _mainCam = Camera.current;
                if (_mainCam != null)
                {
                    _originalRotation = _mainCam.transform.rotation;    
                }
            }
        }

        private void Update()
        {
            if (_mainCam)
            {
                var forward = (_mainCam.transform.position - this.transform.position).normalized;
                forward.Scale(movableAxis);
                var quaternion = Quaternion.LookRotation(forward, _mainCam.transform.up);
                this.transform.rotation = quaternion;
            }

            if (!_mainCam)
            {
                OnEnable();
            }
        }
    }
}