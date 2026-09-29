Shader "ShaderProgramming/Chapter2/Flat"
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
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				Light mainLight = GetMainLight();

				half3 dpdx = ddx(IN.positionWS);
				half3 dpdy = ddy(IN.positionWS);
				half3 faceN = normalize(cross(dpdy, dpdx));

				half3 L = normalize(-mainLight.direction);
				half NdotL = saturate(dot(faceN, L));

				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return half4(diffuse, 1.0h);
			}
			ENDHLSL
		}
	}
}
