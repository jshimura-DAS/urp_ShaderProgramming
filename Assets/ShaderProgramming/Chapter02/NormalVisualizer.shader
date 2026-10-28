Shader "ShaderProgramming/Chapter2/NormalVisualizer"
{
	Properties
	{
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				half3  normalWS    : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				// 法線を [-1, 1] から [0, 1] へ変換
				half3 n = normalize(IN.normalWS);
				half3 visualNormal = n * 0.5h + 0.5h;

				return half4(visualNormal, 1.0h);
			}
			ENDHLSL
		}
	}
}
