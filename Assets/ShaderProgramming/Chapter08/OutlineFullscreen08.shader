Shader "ShaderProgramming/Chapter8/OutlineFullscreen08"
{
	Properties
	{
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_Threshold ("Edge Threshold", Range(0,0.2)) = 0.02
		_Sharpness ("Sharpness", Range(1,50)) = 10
		_Thickness ("Thickness (px)", Range(0.5,4)) = 1
	}

	SubShader
	{
		Tags { "RenderPipeline"="UniversalPipeline" }

		// フルスクリーン処理なので、カリング・深度書き込み・深度テストは使わない
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			Name "OutlineFullscreen"

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			// Blit 用の頂点シェーダーと _BlitTexture の宣言を取り込む
			#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
			// _CameraDepthTexture へのアクセス（SampleSceneDepth）を取り込む
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			half4 _OutlineColor;
			float _Threshold;
			float _Sharpness;
			float _Thickness;

			// 深度を「カメラからの実距離（線形深度）」に変換して返す
			float LinearDepthAt(float2 uv)
			{
				return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
			}

			half4 Frag(Varyings input) : SV_Target
			{
				float2 uv = input.texcoord;

				// 1 ピクセル分（太さ倍）のずらし量。_ScreenParams は画面の解像度
				float2 texel = _Thickness / _ScreenParams.xy;

				// 3x3 の近傍深度。index = (y+1)*3 + (x+1)
				float d[9];
				[unroll]
				for (int y = -1; y <= 1; y++)
				{
					[unroll]
					for (int x = -1; x <= 1; x++)
					{
						d[(y + 1) * 3 + (x + 1)] = LinearDepthAt(uv + float2(x, y) * texel);
					}
				}

				// Sobel フィルター（横方向・縦方向の勾配）
				float gx = (d[2] + 2.0 * d[5] + d[8]) - (d[0] + 2.0 * d[3] + d[6]);
				float gy = (d[6] + 2.0 * d[7] + d[8]) - (d[0] + 2.0 * d[1] + d[2]);

				// 中心深度で割ることで、遠くても近くても同じ比率で線が出るようにする
				float edge = length(float2(gx, gy)) / max(d[4], 0.001);

				// しきい値を超えた分を強調して 0〜1 のマスクにする
				float mask = saturate((edge - _Threshold) * _Sharpness);

				// 元の画像色（_BlitTexture は直前までの描画結果）
				half3 src = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv).rgb;

				// 輪郭色を、マスクと輪郭色の α で重ねる
				half3 result = lerp(src, _OutlineColor.rgb, mask * _OutlineColor.a);
				return half4(result, 1.0h);
				//return half4(mask.xxx, 1); 
			}
			ENDHLSL
		}
	}
}