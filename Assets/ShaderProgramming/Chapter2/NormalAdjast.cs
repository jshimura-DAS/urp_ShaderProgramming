using UnityEngine;

public class NormalAdjast : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created

    void Start()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        if (meshFilter == null)
        {
            return;
        }

        Mesh mesh = meshFilter.mesh;
        Vector3[] vertices = mesh.vertices;
        Vector3[] normals = new Vector3[vertices.Length];

        for (int i = 0; i < vertices.Length; i++)
        {
            normals[i] = vertices[i].sqrMagnitude > 0.0f ? vertices[i].normalized : Vector3.up;
        }

        mesh.normals = normals;
    }

    // Update is called once per frame
    void Update()
    {

    }
}
