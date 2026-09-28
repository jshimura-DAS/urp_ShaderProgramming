Shader "ShaderProgramming/Chapter2/LightingBasics"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
		[Enum(NormalDebug,0,Flat,1,Gouraud,2,Phong,3)] _Mode ("Mode", Float) = 3
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
				half _Mode;
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
				half3  normalWS    : TEXCOORD1;
				half3  gouraudLit  : TEXCOORD2;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

				// Gouraud用: 頂点でライティング
				Light mainLight = GetMainLight();
				half3 N = normalize(OUT.normalWS);
				half3 L = normalize(-mainLight.direction);
				half3 V = normalize(_WorldSpaceCameraPos.xyz - OUT.positionWS);
				half3 H = normalize(L + V);

				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));

				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				half3 spec = _SpecColor.rgb * pow(NdotH, _Shininess);
				OUT.gouraudLit = diffuse + spec;

				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				// 0: Normal Debug
				if (_Mode < 0.5h)
				{
					half3 n = normalize(IN.normalWS);
					return half4(n * 0.5h + 0.5h, 1.0h);
				}

				Light mainLight = GetMainLight();
				half3 lightColor = mainLight.color;

				// 1: Flat
				if (_Mode < 1.5h)
				{
					half3 dpdx = ddx(IN.positionWS);
					half3 dpdy = ddy(IN.positionWS);
					half3 faceN = normalize(cross(dpdy, dpdx));
					half3 L = normalize(-mainLight.direction);

					half NdotL = saturate(dot(faceN, L));
					half3 col = _BaseColor.rgb * lightColor * NdotL;
					return half4(col, 1.0h);
				}

				// 2: Gouraud
				if (_Mode < 2.5h)
				{
					return half4(IN.gouraudLit, 1.0h);
				}

				// 3: Phong
				{
					half3 N = normalize(IN.normalWS);
					half3 L = normalize(-mainLight.direction);
					half3 V = normalize(_WorldSpaceCameraPos.xyz - IN.positionWS);
					half3 H = normalize(L + V);

					half NdotL = saturate(dot(N, L));
					half NdotH = saturate(dot(N, H));

					half3 diffuse = _BaseColor.rgb * lightColor * NdotL;
					half3 spec = _SpecColor.rgb * pow(NdotH, _Shininess);

					return half4(diffuse + spec, 1.0h);
				}
			}
			ENDHLSL
		}
	}
}