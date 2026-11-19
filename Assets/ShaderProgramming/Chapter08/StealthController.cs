using UnityEngine;

public class StealthController : MonoBehaviour
{
    [Tooltip("監視する敵（未設定なら常に隠れた状態）")]
    public Transform enemy;

    [Tooltip("この距離より近いと、ステルスを解除して見える")]
    public float detectRadius = 3f;

    [Tooltip("隠れているときの可視度（0 で本体が完全に消え、縁だけになる）")]
    [Range(0f, 1f)] public float hiddenVisibility = 0.05f;

    [Tooltip("可視度が変化する速さ")]
    public float fadeSpeed = 4f;

    static readonly int VisibilityId = Shader.PropertyToID("_Visibility");

    Renderer[] _renderers;
    MaterialPropertyBlock _block;
    float _current = 1f;

    void Awake()
    {
        _renderers = GetComponentsInChildren<Renderer>();
        _block = new MaterialPropertyBlock();
    }

    void Update()
    {
        bool detected = enemy != null &&
                        Vector3.Distance(transform.position, enemy.position) < detectRadius;

        float target = detected ? 1f : hiddenVisibility;
        _current = Mathf.MoveTowards(_current, target, fadeSpeed * Time.deltaTime);

        // マテリアルを複製せず、レンダラーごとに値だけを渡す
        foreach (Renderer r in _renderers)
        {
            r.GetPropertyBlock(_block);
            _block.SetFloat(VisibilityId, _current);
            r.SetPropertyBlock(_block);
        }
    }
}
