Shader "ShaderProgramming/Chapter4/PhongNormal04"
{
	Properties
	{
		_BaseMap ("Albedo Map", 2D) = "white" {}
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		[Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
		_NormalScale ("Normal Scale", Range(0,2)) = 1
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
		_Ambient ("Ambient", Color) = (0.05,0.05,0.05,1)
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

			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half4 _Ambient;
				float4 _BaseMap_ST;
				float4 _NormalMap_ST;	// Normal map tiling and offset
				half _NormalScale;
				half _Shininess;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
				float4 tangentOS  : TANGENT;
				float2 uv         : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
				half3 normalWS     : TEXCOORD1;
				half4 tangentWS    : TEXCOORD2;
				float2 uv          : TEXCOORD3;
			};

			half3 ShadePhong(Light light, half3 albedo, half3 N, half3 V)
			{
				half3 L = normalize(light.direction);
				half3 H = normalize(L + V);
				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));
				half3 radiance = light.color * light.distanceAttenuation;
				half3 diffuse = albedo * radiance * NdotL;
				half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
				return diffuse + specular;
			}

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.tangentWS = half4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w * GetOddNegativeScale());
				OUT.uv = IN.uv;
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				float2 baseUv = TRANSFORM_TEX(IN.uv, _BaseMap);
				float2 normalUv = TRANSFORM_TEX(IN.uv, _NormalMap);
				
				half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUv) * _BaseColor;
				half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, normalUv), _NormalScale);

				half3 N = normalize(IN.normalWS);
				half3 T = normalize(IN.tangentWS.xyz);
				half3 B = cross(N, T) * IN.tangentWS.w;

				half3 normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(T, B, N)));
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);

				half3 color = _Ambient.rgb * albedoSample.rgb;
				color += ShadePhong(GetMainLight(), albedoSample.rgb, normalWS, V);

				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);
					color += ShadePhong(light, albedoSample.rgb, normalWS, V);
				LIGHT_LOOP_END
				#endif

				return half4(color, albedoSample.a);
			}
			ENDHLSL
		}
	}
}