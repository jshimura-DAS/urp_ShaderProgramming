Shader "ShaderProgramming/Chapter3/PhongPoint03"
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
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _FORWARD_PLUS

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
				half3  normalWS    : TEXCOORD1;
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
				half3 N = normalize(IN.normalWS);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 color = 0;

				// ポイントライトはAdditional Lightsとして届く
				// ライトの位置を使って方向と距離減衰を計算済みのLightが返る
				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);

					half3 L = normalize(light.direction);
					half3 H = normalize(L + V);
					half NdotL = saturate(dot(N, L));
					half NdotH = saturate(dot(N, H));

					// distanceAttenuationに距離による暗くなり方が入っている
					half3 radiance = light.color * light.distanceAttenuation;
					color += _BaseColor.rgb * radiance * NdotL;
					color += _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
				LIGHT_LOOP_END
				#endif

				return half4(color, 1.0h);
			}
			ENDHLSL
		}
	}
}
