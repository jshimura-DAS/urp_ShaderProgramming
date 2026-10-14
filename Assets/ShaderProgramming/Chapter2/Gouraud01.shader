Shader "ShaderProgramming/Chapter2/Gouraud01"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
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
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;			// 法線情報を追加
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				// 頂点ごとに計算した拡散反射色をフラグメントへ補間して渡す。
				half3 diffuse      : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(positionWS);

				// 頂点ごとに拡散反射を計算する。
				half3 N = normalize(TransformObjectToWorldNormal(IN.normalOS));
				Light mainLight = GetMainLight();
				half3 L = normalize(-mainLight.direction);
				half NdotL = saturate(dot(N, L));
				OUT.diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				return half4(IN.diffuse, 1.0h);
			}
			ENDHLSL
		}
	}
}