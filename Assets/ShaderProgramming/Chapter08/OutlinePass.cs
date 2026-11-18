using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlinePass : ScriptableRenderPass
{
    static readonly ProfilingSampler s_Sampler = new ProfilingSampler("Outline08");

    Material _material;
    OutlineRendererFeature.Settings _settings;
    RTHandle _tempTarget;

    public OutlinePass()
    {
        // 深度テクスチャを使うことを URP に伝える
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public void Setup(Material material, OutlineRendererFeature.Settings settings)
    {
        _material = material;
        _settings = settings;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, s_Sampler))
        {
            // 設定値をマテリアルへ反映する
            _material.SetColor("_OutlineColor", _settings.outlineColor);
            _material.SetFloat("_Threshold", _settings.threshold);
            _material.SetFloat("_Sharpness", _settings.sharpness);
            _material.SetFloat("_Thickness", _settings.thickness);

            // カメラと同じサイズの一時 RT を用意する（深度は不要）
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            RenderingUtils.ReAllocateHandleIfNeeded(ref _tempTarget, desc, name: "_OutlineTemp");

            // カメラのカラーターゲットを読み、輪郭を重ねた結果を一時 RT へ書く
            RTHandle source = renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blitter.BlitCameraTexture(cmd, source, _tempTarget, _material, 0);

            // 結果をカメラのカラーターゲットへ戻す
            Blitter.BlitCameraTexture(cmd, _tempTarget, source);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
        _tempTarget?.Release();
    }
}