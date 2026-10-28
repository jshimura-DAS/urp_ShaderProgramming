using UnityEngine;

public class ColorChanger : MonoBehaviour
{
    private Material _targetMaterial;
    private int _baseColorId;

    void Start()
    {
        // 1. レンダラーからマテリアルのインスタンスを取得
        Renderer renderer = GetComponent<Renderer>();
        _targetMaterial = renderer.material;

        // 2. 文字列 "_BaseColor" を高速な整数IDに変換してキャッシュ（毎フレーム文字列検索しないため）
        _baseColorId = Shader.PropertyToID("_BaseColor");
    }

    void Update()
    {
        // 時間経過でRGBがグラデーション変化する色を計算
        float r = Mathf.Sin(Time.time * 2.0f) * 0.5f + 0.5f;
        float g = Mathf.Cos(Time.time * 2.0f) * 0.5f + 0.5f;
        float b = 1.0f;
        Color newColor = new Color(r, g, b, 1.0f);

        // 3. マテリアルに新しい色をセット → GPUの定数バッファへ反映！
        _targetMaterial.SetColor(_baseColorId, newColor);
    }
}
