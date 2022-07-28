using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
using Random = UnityEngine.Random;

public class ObjectMoverAndRandomOrganizer : MonoBehaviour
{
    public bool TranslatingLocal = true;
    public Vector3 TranslatingVelocity = Vector3.forward;
    public Vector3 RandomVelocity = Vector3.zero;

    public bool RotatingLocal = false;
    public Vector3 RotatingAxis = Vector3.forward;
    public float RotatingAngleDegreeSpeed = 360;

    public bool Reposition = true;
    public Vector3 RepositionRandomPositionOffsetScale = Vector3.one;
    public float RepositionTime = 10f;
    public float RepositionTimeRandomOffset = 0f;

    private float _repositionTime = 0f;
    private float _repositionTimer = 1f;
    private Vector3 _OrigPositionLocal = Vector3.zero;
    private quaternion _rotateQuaternionLocal = quaternion.identity;
    
    // Start is called before the first frame update
    void Start()
    {
        _OrigPositionLocal = this.transform.localPosition;
        _repositionTime = RepositionTime + Random.Range(-1f, 1f) * RepositionTimeRandomOffset;
        TranslatingVelocity += Random.Range(-1, 1) * RandomVelocity;
    }

    // Update is called once per frame
    void Update()
    {
        // timer
        if (Reposition)
        {
            _repositionTimer += Time.deltaTime;
            if (_repositionTimer > _repositionTime)
            {
                DoReposition();
            }
        }

        // update position
        if (TranslatingLocal)
        {
            this.transform.localPosition += TranslatingVelocity * Time.deltaTime;
        }
        
        // update direction
        if (RotatingLocal)
        {
            _rotateQuaternionLocal = quaternion.AxisAngle(RotatingAxis,  Mathf.Deg2Rad * RotatingAngleDegreeSpeed * Time.deltaTime);
            this.transform.rotation = this.transform.rotation * _rotateQuaternionLocal;
        }
    }

    private void DoReposition()
    {
        _repositionTime = RepositionTime + Random.Range(-1f, 1f) * RepositionTimeRandomOffset;
        _repositionTimer = 0f;
        var repositionOffset = Random.insideUnitSphere;
        repositionOffset.Scale(RepositionRandomPositionOffsetScale);
        this.transform.localPosition =
            _OrigPositionLocal + repositionOffset;
    }
}
