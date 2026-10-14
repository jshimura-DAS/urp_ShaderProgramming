Shader "ShaderProgramming/Chapter2/Phong01"
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
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				half3 normalWS     : TEXCOORD0;
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
				Light mainLight = GetMainLight();
				half3 N = normalize(IN.normalWS);
				half3 L = normalize(mainLight.direction);
				half NdotL = saturate(dot(N, L));
				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return half4(diffuse , 1.0h);
			}
			ENDHLSL
		}
	}
}
