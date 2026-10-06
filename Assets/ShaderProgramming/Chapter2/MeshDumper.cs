using UnityEngine;

public class MeshDumper : MonoBehaviour
{
    // ノーマル表示設定
    public bool showVertexNormals = true;
    public float normalLength = 0.1f;
    public Color normalColor = Color.blue;
    public float normalLineWidth = 0.01f;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        Mesh mesh = null;
        var mf = GetComponent<MeshFilter>();
        if (mf != null) mesh = mf.sharedMesh;
        else
        {
            var smr = GetComponent<SkinnedMeshRenderer>();
            if (smr != null) mesh = smr.sharedMesh;
        }

        if (mesh == null)
        {
            Debug.LogWarning("MeshDumper: No mesh found on this GameObject.");
            return;
        }

        var verts = mesh.vertices;
        Debug.Log($"Mesh '{mesh.name}' vertex count: {verts.Length}");
        for (int i = 0; i < verts.Length; i++)
        {
            Vector3 worldPos = transform.TransformPoint(verts[i]);
            Debug.Log($"[{i}] Local: {verts[i]}  World: {worldPos}");
        }

        // 頂点ごとのノーマルをLineRendererで表示
        if (showVertexNormals)
        {
            var normals = mesh.normals;
            if (normals == null || normals.Length != verts.Length)
            {
                Debug.LogWarning("MeshDumper: Mesh does not contain valid normals to display.");
                return;
            }

            // ノーマル表示用の親オブジェクト
            var parent = new GameObject($"{name}_VertexNormals");
            parent.transform.SetParent(transform, false);

            // 共有マテリアルを1つ作成して使い回す
            var lineMat = new Material(Shader.Find("Sprites/Default"));

            for (int i = 0; i < verts.Length; i++)
            {
                Vector3 worldPos = transform.TransformPoint(verts[i]);
                Vector3 worldNormal = transform.TransformDirection(normals[i]).normalized;

                var go = new GameObject($"Normal_{i}");
                go.transform.SetParent(parent.transform, false);
                var lr = go.AddComponent<LineRenderer>();
                lr.useWorldSpace = true;
                lr.positionCount = 2;
                lr.SetPosition(0, worldPos);
                lr.SetPosition(1, worldPos + worldNormal * normalLength);
                lr.startWidth = lr.endWidth = normalLineWidth;
                lr.material = lineMat;
                lr.startColor = lr.endColor = normalColor;
                // 不要な余分な機能をオフ
                lr.loop = false;
            }
        }
    }


}
