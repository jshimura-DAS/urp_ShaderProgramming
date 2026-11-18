using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EmptyRendererFeature : ScriptableRendererFeature
{
    class EmptyPass : ScriptableRenderPass
    {
        static readonly ProfilingSampler s_Sampler = new ProfilingSampler("EmptyPass08");

        public EmptyPass()
        {
            // 必要な入力（深度・法線など）をここで宣言する
            ConfigureInput(ScriptableRenderPassInput.None);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // CommandBuffer を借りて命令を記録し、最後に実行する
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, s_Sampler))
            {
                // ここに描画命令を書く
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    EmptyPass _pass;

    public override void Create()
    {
        _pass = new EmptyPass();
        _pass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_pass);
    }
}