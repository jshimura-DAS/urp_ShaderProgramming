using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        public Shader shader;
        public Color outlineColor = Color.black;
        [Range(0f, 0.2f)] public float threshold = 0.02f;
        [Range(1f, 50f)] public float sharpness = 10f;
        [Range(0.5f, 4f)] public float thickness = 1f;
    }

    public Settings settings = new Settings();

    OutlinePass _pass;
    Material _material;

    public override void Create()
    {
        // 古いマテリアルを破棄してから作り直す（インスペクター変更時にも呼ばれる）
        CoreUtils.Destroy(_material);
        _material = settings.shader != null ? CoreUtils.CreateEngineMaterial(settings.shader) : null;

        _pass = new OutlinePass
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // シーンビューなど、ゲームカメラ以外には描画しない
        if (_material == null) return;
        if (renderingData.cameraData.cameraType != CameraType.Game) return;

        _pass.Setup(_material, settings);
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(_material);
        _pass?.Dispose();
    }
}