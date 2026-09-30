Shader "ShaderProgramming/Chapter2/Phong"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
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
				half4 _SpecColor;
				half _Shininess;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
				half3 normalWS     : TEXCOORD1;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				Light mainLight = GetMainLight();
				half3 N = normalize(IN.normalWS);
				half3 L = normalize(-mainLight.direction);
				half3 V = normalize(_WorldSpaceCameraPos.xyz - IN.positionWS);
				half3 H = normalize(L + V);

				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));
				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				half3 specular = _SpecColor.rgb * pow(NdotH, _Shininess);

				return half4(diffuse + specular, 1.0h);
			}
			ENDHLSL
		}
	}
}
