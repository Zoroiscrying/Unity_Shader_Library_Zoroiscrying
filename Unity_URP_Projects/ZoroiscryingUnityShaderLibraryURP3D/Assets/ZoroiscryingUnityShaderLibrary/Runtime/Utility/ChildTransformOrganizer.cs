using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class ChildTransformOrganizer : MonoBehaviour
{
    [SerializeField] private bool affectOnlyTheChildrenOneLevelDown = true;
    protected List<Transform> childTransforms = new List<Transform>();

    private void OnEnable()
    {
        EditorApplication.hierarchyChanged += RefillChildTransforms;
        RefillChildTransforms();
    }

    private void OnValidate()
    {
        RefillChildTransforms();
    }

    private void OnDisable()
    {
        EditorApplication.hierarchyChanged -= RefillChildTransforms;
    }

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void RefillChildTransforms()
    {
        childTransforms = transform.GetComponentsInChildren<Transform>().ToList();
        childTransforms.Remove(transform);
        if (affectOnlyTheChildrenOneLevelDown)
        {
            for (int i = 0; i < childTransforms.Count; i++)
            {
                if (childTransforms[i].parent != this.transform)
                {
                    childTransforms.RemoveAt(i);
                }
            }
        }
        UpdateChildTransforms();
    }

    protected virtual void UpdateChildTransforms()
    {
        //
    }
}
