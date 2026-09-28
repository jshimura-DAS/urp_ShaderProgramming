Shader "MyShaders/MyFirstShader"
{
    Properties
    {
        // 【修正箇所1】インスペクター上に表示するカラーパレットを追加
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 【修正箇所2】SRP Batcher対応の定数バッファに変数を追加
            // ★重要：Propertiesの「_BaseColor」と全く同じ綴り・型（16バイト）で宣言する
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END

            struct Attributes {
                float4 positionOS : POSITION;
            };

            struct Varyings {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            // 【修正箇所3】固定の白ではなく、受け取った _BaseColor を出力する
            half4 frag(Varyings IN) : SV_Target {
                return _BaseColor;
            }

            ENDHLSL
        }
    }
}