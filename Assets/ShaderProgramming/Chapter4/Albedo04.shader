Shader "ShaderProgramming/Chapter4/Albedo04"
{
	Properties
	{
		_BaseMap ("Albedo Map", 2D) = "white" {}
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				float4 _BaseMap_ST;
				half _Shininess;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
				float2 uv         : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
				half3 normalWS     : TEXCOORD1;
				float2 uv          : TEXCOORD2;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
				Light mainLight = GetMainLight();
				half3 N = normalize(IN.normalWS);
				half3 L = normalize(mainLight.direction);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 H = normalize(L + V);
				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));
				half3 radiance = mainLight.color * mainLight.distanceAttenuation;
				half3 diffuse = albedo.rgb * radiance * NdotL;
				half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);

				return half4(diffuse + specular, albedo.a);
			}
			ENDHLSL
		}
	}
}
