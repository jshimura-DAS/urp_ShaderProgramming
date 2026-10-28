using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
public sealed class UvCoordinateVisualizer : MonoBehaviour
{
    [SerializeField] private bool showVertexLabels = true;
    [SerializeField] private bool showTriangleEdges = true;
    [SerializeField] private int maximumVertexCount = 128;
    [SerializeField] private float markerRadius = 0.015f;

    private Mesh _mesh;

    private void OnValidate()
    {
        maximumVertexCount = Mathf.Max(1, maximumVertexCount);
        markerRadius = Mathf.Max(0.001f, markerRadius);
        CacheMesh();
    }

    private void OnDrawGizmos()
    {
        if (!CacheMesh() || _mesh.uv == null || _mesh.uv.Length == 0)
        {
            return;
        }

        Vector3[] vertices = _mesh.vertices;
        Vector2[] uv = _mesh.uv;
        int vertexCount = Mathf.Min(Mathf.Min(vertices.Length, uv.Length), maximumVertexCount);

        for (int i = 0; i < vertexCount; i++)
        {
            Vector3 positionWS = transform.TransformPoint(vertices[i]);
            Color uvColor = new Color(uv[i].x, uv[i].y, 0.0f, 1.0f);
            Gizmos.color = uvColor;
            Gizmos.DrawSphere(positionWS, markerRadius);

#if UNITY_EDITOR
            if (showVertexLabels)
            {
                Handles.Label(positionWS, $"{i}: ({uv[i].x:F2}, {uv[i].y:F2})");
            }
#endif
        }

        if (!showTriangleEdges)
        {
            return;
        }

        Gizmos.color = Color.white;
        int[] triangles = _mesh.triangles;
        for (int i = 0; i + 2 < triangles.Length; i += 3)
        {
            int a = triangles[i];
            int b = triangles[i + 1];
            int c = triangles[i + 2];
            if (a >= vertexCount || b >= vertexCount || c >= vertexCount)
            {
                continue;
            }

            Vector3 positionA = transform.TransformPoint(vertices[a]);
            Vector3 positionB = transform.TransformPoint(vertices[b]);
            Vector3 positionC = transform.TransformPoint(vertices[c]);
            Gizmos.DrawLine(positionA, positionB);
            Gizmos.DrawLine(positionB, positionC);
            Gizmos.DrawLine(positionC, positionA);
        }
    }

    private bool CacheMesh()
    {
        if (_mesh != null)
        {
            return true;
        }

        MeshFilter meshFilter = GetComponent<MeshFilter>();
        if (meshFilter != null)
        {
            _mesh = meshFilter.sharedMesh;
        }

        if (_mesh == null)
        {
            SkinnedMeshRenderer skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
            if (skinnedMeshRenderer != null)
            {
                _mesh = skinnedMeshRenderer.sharedMesh;
            }
        }

        return _mesh != null;
    }
}
