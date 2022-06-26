using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GridHandler3D : MonoBehaviour
{
    [Tooltip("How large (in meters) one grid block side is")]
    [SerializeField] private float gridSize = 10f;

    public float GridSize => gridSize;
    
    [Tooltip("The player's transform to track")]
    [SerializeField] private Transform playerTransform;
    public Vector3 TransformCenterPosition => playerTransform.position;
    
    // a callback to subscribe to when the player grid changes
    public event Action<Vector3Int> OnPlayerGridChange;
    
    private Vector3Int _lastPlayerGrid = new Vector3Int(-99999,-99999,-99999);
    
    void Update () 
    {
        if (playerTransform == null) {
            Debug.LogWarning("Grid Handler Has No Player Transform!");
            return;
        }
      
        // calculate the grid coordinate where the player currently is
        Vector3 playerPos = playerTransform.position;
        Vector3Int playerGrid = new Vector3Int(
            Mathf.FloorToInt(playerPos.x / gridSize),
            Mathf.FloorToInt(playerPos.y / gridSize),
            Mathf.FloorToInt(playerPos.z / gridSize)
        );
      
        // check if the player changed grid coordinates since the last check
        if (playerGrid != _lastPlayerGrid) {
          
            // if it has, then broadcast the new grid coordinates
            // to whoever subscribed to the callback
            if (OnPlayerGridChange != null)
                OnPlayerGridChange(playerGrid);
            
            _lastPlayerGrid = playerGrid;
        }
    }
    
    /// <summary>
    /// calculate the center position of a certain grid coordinate
    /// </summary>
    /// <param name="grid"></param>
    /// <returns>The world space position of the grid center according to the current grid int id</returns>
    public Vector3 GetGridCenter(Vector3Int grid) {
        float halfGrid = gridSize * .5f;
        return new Vector3(
            grid.x * gridSize + halfGrid,
            grid.y * gridSize + halfGrid,
            grid.z * gridSize + halfGrid
        );
    }
    
    // draw gizmo cubes around teh grids where the player is
    // so we can see it in the scene view
    void OnDrawGizmos () {
        // loop in a 3 x 3 x 3 grid
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                for (int z = -1; z <= 1; z++) {
                  
                    bool isCenter = x == 0 && y == 0 && z == 0;
                    Vector3 gridCenter = GetGridCenter(_lastPlayerGrid + new Vector3Int(x, y, z));
                    
                    // make the center one green and slightly smaller so it stands out visually
                    Gizmos.color = isCenter ? Color.green : Color.red;
                    Gizmos.DrawWireCube(gridCenter, Vector3.one * (gridSize * (isCenter ? .95f : 1.0f)));
                }
            }
        }
    }
}
